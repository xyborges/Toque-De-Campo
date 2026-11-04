extends SceneTree

var role:="operator"
var game: WarGame
var accounts: NavalAccounts
var checks:=0
var failures: Array[String]=[]
var samples: Dictionary={}
var control_sequence:=100
var stage_values: Dictionary={"phases":{}}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func stage_path(who: String) -> String: return "res://work/ubuntu-war-tv168-"+who+".stage.json"
func shared(who: String) -> Dictionary: return NavalStorage.read_json(stage_path(who))
func reached(who: String,value: String) -> bool: return shared(who).get("phases",{}).has(value)
func stage(value: String,extra: Dictionary={}) -> void:
	stage_values.phase=value;stage_values.phases[value]=true
	stage_values.merge(extra,true)
	if is_instance_valid(game) and is_instance_valid(game.local_player): stage_values.id=game.local_player.peer_id
	NavalStorage.write_json(stage_path(role),stage_values)
func wait_for(condition: Callable,label_text: String,seconds:=18.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if condition.call(): return true
		for who in ["operator","opponent","passenger"]:
			if who!=role and reached(who,"failed"):
				failures.append("peer failed before "+label_text);return false
		await process_frame
	failures.append("timeout: "+label_text);return false
func click(button: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed;Input.parse_input_event(event)
func press(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func capture(label_text: String) -> void:
	if role!="operator": return
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/ubuntu-war-tv168-"+label_text+".png")
func old_control(apc: WarVehicle,throttle: float,fire: bool) -> void:
	control_sequence+=1
	game.vehicle_system.rpc_id(1,"control",control_sequence,{"throttle":throttle,"steer":0.,"aim":apc.global_position+Vector3(140,12,-80),"fire":fire,"occupancy":apc.control_epoch,"vehicle":apc.vehicle_id,"life":game.local_player.life_id})
func move_to(point: Vector3) -> bool:
	var actor:=game.local_player as WarPlayer
	var until:=Time.get_ticks_msec()+10000;var sent_at:=Time.get_ticks_msec();var previous:=actor.position
	while Time.get_ticks_msec()<until:
		await process_frame
		var now:=Time.get_ticks_msec();var elapsed:=float(now-sent_at)*.001
		if elapsed<.05: continue
		sent_at=now
		var flat:=Vector2(point.x-previous.x,point.z-previous.z)
		if flat.length()<.15: return true
		var step:=flat.limit_length(5.8*minf(elapsed,.1))
		previous=WarTerrain.point(previous.x+step.x,previous.z+step.y)+Vector3.UP*.12
		actor.position=previous
		game.rpc_id(1,"server_player_state",previous,actor.yaw,0.,"fal",false,0,actor.life_id)
	failures.append("timeout: ordinary legal player-state approach to APC");return false
func authenticate() -> bool:
	var base:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var third_path:="res://work/ubuntu-war-passenger-credentials.json"
	var credentials: Dictionary=base.host if role=="operator" else (base.guest if role=="passenger" else NavalStorage.read_json(third_path))
	accounts=NavalAccounts.new();root.add_child(accounts)
	var action:="register" if role=="opponent" and not bool(credentials.get("registered",false)) else "login"
	var response: Dictionary=await accounts.sign_in(action,str(credentials.username),str(credentials.password))
	if action=="register" and not bool(response.get("ok",false)):
		response=await accounts.sign_in("login",str(credentials.username),str(credentials.password))
	var ok:=bool(response.get("ok",false)) and accounts.validated_session
	check(ok,"real QA account authenticates over verified TLS with signed profile")
	if role=="opponent" and ok:
		credentials.registered=true;NavalStorage.write_json(third_path,credentials)
	return ok
func run() -> void:
	Engine.max_fps=60
	if await authenticate():
		game=WarGame.new();game.accounts_service=accounts;root.add_child(game)
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.players.size()>=3,"three authenticated central players",35):
			check(not game.testing and game._central_pvp(),"central authority uses production account validation without a test bypass")
			check(game.players.size()==3,"the smoke operation contains only its three QA participants")
			if failures.is_empty():
				game.local_player.set_physics_process(false);game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
				game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
				stage("joined")
				await deploy_ordered()
				if failures.is_empty():
					if role=="operator": await operator_flow()
					elif role=="passenger": await passenger_flow()
					else: await opponent_flow()
	stage("finished" if failures.is_empty() else "failed")
	var report: Dictionary={"role":role,"checks":checks,"failures":failures,"samples":samples,"fixture":"Three real QA accounts and production Ubuntu ENet authority. Coordinated via local stage files only. Infantry approach uses legal 5.8 m/s server_player_state packets; vehicle commands and malicious passenger packets use existing RPCs. No privileged server teleport, test account mode, service token or authority fixture."}
	NavalStorage.write_json("res://tests/ubuntu-war-tv168-"+role+".json",report);print(JSON.stringify(report))
	if is_instance_valid(game): game.show_menu();game.queue_free()
	await create_timer(.5).timeout
	if is_instance_valid(accounts): accounts.queue_free()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;quit(0 if failures.is_empty() else 1)
func deploy_ordered() -> void:
	if role=="opponent":
		if not await wait_for(func():return reached("operator","deployed"),"operator team zero deployment"): return
	elif role=="passenger":
		if not await wait_for(func():return reached("opponent","deployed"),"balanced opposing team deployment"): return
	game.request_deploy(1 if role=="opponent" else 0,"soldier","fal","rpg","base")
	if not await wait_for(func():return game.local_player.deployed,"validated class deployment"): return
	check(game.local_player.war_team==(1 if role=="opponent" else 0),"team/class deployment follows balanced zero-one-zero admission")
	stage("deployed")
	await wait_for(func():return reached("operator","deployed") and reached("opponent","deployed") and reached("passenger","deployed"),"all three deployments")
func tv_control(apc: WarVehicle,fire: bool) -> void:
	var manager:=game.vehicle_system as WarVehicles
	control_sequence+=1
	var input: Dictionary={"throttle":0.,"steer":0.,"fire":fire,"aim":apc.global_position+Vector3(0,150,-600),"occupancy":apc.control_epoch,"vehicle":apc.vehicle_id,"life":game.local_player.life_id}
	if manager.tv.viewing(): input.tv_id=manager.tv.view_id;input.guide=true;input.tv_direction=manager.tv.direction()
	manager.rpc_id(1,"control",control_sequence,input)
func operator_flow() -> void:
	var actor:=game.local_player as WarPlayer;var manager:=game.vehicle_system as WarVehicles;var apc:=manager.vehicles.v_guarani as WarVehicle
	if not await move_to(apc.global_position+Vector3(0,0,4.4)): return
	manager.request_command("enter",{"id":apc.vehicle_id})
	if not await wait_for(func():return apc.driver==actor.peer_id and actor.vehicle_id==apc.vehicle_id,"operator boarding"): return
	stage("aboard")
	if not await wait_for(func():return reached("passenger","aboard"),"passenger boarding"): return
	manager.request_command("weapon",{})
	if not await wait_for(func():return apc.selected=="secondary","APC TV selection"): return
	var until:=Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<until: tv_control(apc,false);await create_timer(.05).timeout
	until=Time.get_ticks_msec()+2500
	while Time.get_ticks_msec()<until and not manager.tv.viewing(): tv_control(apc,true);await create_timer(.05).timeout
	check(manager.tv.viewing(),"production Ubuntu accepts a finite TV missile from the real APC marker")
	if not manager.tv.viewing(): return
	var id:=manager.tv.view_id;var shot: Dictionary=game.war_fx.find_round(id);var direction: Vector3=shot.velocity.normalized();stage("fired",{"shot":id})
	manager.look(Vector2(-140,-45));until=Time.get_ticks_msec()+1500
	while Time.get_ticks_msec()<until and manager.tv.viewing(): tv_control(apc,false);await create_timer(.05).timeout
	check(manager.tv.states_received>=8,"production missile delivers authoritative snapshots to operator")
	check(manager.tv.viewing() and manager.camera.global_position.distance_to(shot.position)<.12,"native camera remains on the synchronized real projectile")
	check(direction.angle_to(Vector3(shot.velocity).normalized())>.03,"real server applies steering while preserving bounded missile motion")
	check(apc.secondary_ammo==0 and apc.secondary_reserve==5 and apc.driver==actor.peer_id,"TV consumes one round without losing or sharing operator seat")
	await capture("guiding")
	manager.tv.request_release();check(await wait_for(func():return not manager.tv.viewing(),"cancel TV camera"),"C abandons link and returns vehicle optic")
	check(await wait_for(func():return manager.camera.current and manager.camera.global_position.distance_to(apc.optic.global_position)<.15,"optic restoration"),"vehicle FPP optic is restored without personal arms")
	stage("cancelled")
	if not await wait_for(func():return reached("passenger","checked") and reached("opponent","checked"),"observer confirmations"): return
	manager.request_command("exit",{})
	check(await wait_for(func():return actor.vehicle_id.is_empty(),"operator safe exit"),"operator exits safely after TV control")
	stage("complete")
	await wait_for(func():return reached("passenger","complete"),"passenger final exit")
func passenger_flow() -> void:
	var actor:=game.local_player as WarPlayer;var manager:=game.vehicle_system as WarVehicles;var apc:=manager.vehicles.v_guarani as WarVehicle
	if not await wait_for(func():return reached("operator","aboard"),"operator boarding"): return
	if not await move_to(apc.global_position+Vector3(-2,0,4.4)): return
	manager.request_command("enter",{"id":apc.vehicle_id})
	if not await wait_for(func():return apc.seat_of(actor.peer_id)>0,"passenger boarding"): return
	stage("aboard")
	if not await wait_for(func():return reached("operator","fired"),"TV launch"): return
	var id:=str(shared("operator").get("shot",""))
	manager.rpc_id(1,"command","tv_release",{"id":id})
	manager.rpc_id(1,"control",999999,{"throttle":1.,"steer":1.,"fire":true,"aim":Vector3.ZERO,"occupancy":apc.control_epoch,"vehicle":apc.vehicle_id,"life":actor.life_id,"tv_id":id,"guide":true,"tv_direction":Vector3.LEFT})
	if not await wait_for(func():return reached("operator","cancelled"),"operator return"): return
	check(not manager.tv.viewing() and apc.seat_of(actor.peer_id)>0,"passenger remains transported without missile camera or controls")
	check(manager.tv.states_received>=8,"passenger receives the same authoritative missile states")
	stage("checked")
	if not await wait_for(func():return reached("operator","complete") and apc.driver==actor.peer_id,"promotion after operator safe exit"): return
	manager.request_command("exit",{})
	check(await wait_for(func():return actor.vehicle_id.is_empty() and apc.driver==0,"final safe exit"),"TV operation leaves no ghost operator reservation")
	stage("complete")
func opponent_flow() -> void:
	var manager:=game.vehicle_system as WarVehicles
	if not await wait_for(func():return reached("operator","cancelled"),"operator TV cancelled"): return
	var id:=str(shared("operator").get("shot",""))
	check(manager.tv.states_received>=8 and not manager.tv.viewing(),"opposing account observes synchronized TV flight without controlling it")
	# The shared test file is updated immediately after local camera return;
	# the reliable authority message still needs to cross ENet to this peer.
	check(await wait_for(func():return not manager.tv.flights.has(id) or not bool(manager.tv.flights[id].linked),"authoritative TV unlink",5),"opposing observer receives the operator's link cancellation")
	stage("checked")
	await wait_for(func():return reached("operator","complete") and reached("passenger","complete"),"operation complete")
	stage("complete")
