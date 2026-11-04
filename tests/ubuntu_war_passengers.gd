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
func stage_path(who: String) -> String: return "res://work/ubuntu-war-passengers-"+who+".stage.json"
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
	if role!="passenger": return
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/ubuntu-war-passengers-"+label_text+".png")
func control(apc: WarVehicle,throttle: float,fire: bool) -> void:
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
	NavalStorage.write_json("res://tests/ubuntu-war-passengers-"+role+".json",report);print(JSON.stringify(report))
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
func operator_flow() -> void:
	var actor:=game.local_player as WarPlayer
	var apc:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	check(not apc.destroyed and apc.driver==0 and apc.team==actor.war_team,"friendly Guarani is available at its real team base")
	if not failures.is_empty() or not await move_to(apc.global_position+Vector3(0,0,4.4)): return
	game.vehicle_system.request_command("enter",{"id":apc.vehicle_id})
	if not await wait_for(func():return actor.vehicle_id==apc.vehicle_id and apc.driver==actor.peer_id,"operator boarding"): return
	check(apc.seat_of(actor.peer_id)==0,"first real entrant receives the authoritative operator seat")
	stage("aboard")
	if not await wait_for(func():return reached("passenger","aboard") and reached("opponent","both-seated"),"passenger and third account seat agreement"): return
	var start:=apc.global_position;var ammo_before:=apc.ammo
	var until:=Time.get_ticks_msec()+1100;var sent_at:=0
	while Time.get_ticks_msec()<until:
		await process_frame
		if Time.get_ticks_msec()-sent_at<50: continue
		sent_at=Time.get_ticks_msec();control(apc,.22,true)
	control(apc,0,false)
	check(await wait_for(func():return apc.ammo<ammo_before and apc.global_position.distance_to(start)>1,"operator movement and mounted shot"),"central operator moves the hull and fires real ammunition")
	await wait_for(func():return absf(apc.speed)<.05,"hull comes to rest",4.)
	stage("parked",{"ammo":apc.ammo})
	var own_orbit: float=game.vehicle_system.orbit_yaw
	if not await wait_for(func():return reached("passenger","denials-checked"),"passenger authority and independent look checks"): return
	check(is_equal_approx(game.vehicle_system.orbit_yaw,own_orbit),"passenger look never changes the operator's independent camera")
	game.vehicle_system.request_command("exit",{})
	if not await wait_for(func():return actor.vehicle_id.is_empty() and apc.driver==int(shared("passenger").get("id",0)),"server promotion after operator exit"): return
	check(actor.position.y>=WarTerrain.height_at(actor.position.x,actor.position.z)+.05,"former operator exits above real collision terrain")
	stage("promoted")
	if not await wait_for(func():return reached("passenger","exited"),"promoted operator shot and safe exit"): return
	check(await wait_for(func():return apc.seats.is_empty() and apc.driver==0,"operator final empty-seat snapshot",4),"both connected clients agree that final safe exit empties every seat")
	stage("complete")
func passenger_flow() -> void:
	var actor:=game.local_player as WarPlayer
	var manager:=game.vehicle_system as WarVehicles
	var apc:=manager.vehicles.v_guarani as WarVehicle
	if not await wait_for(func():return reached("operator","aboard"),"operator enters before passenger"): return
	if not await move_to(apc.global_position+Vector3(-2,0,4.4)): return
	manager.request_command("enter",{"id":apc.vehicle_id})
	if not await wait_for(func():return actor.vehicle_id==apc.vehicle_id and apc.seat_of(actor.peer_id)>0,"passenger boarding"): return
	check(apc.driver==int(shared("operator").get("id",0)) and apc.seats.size()==2,"native passenger receives both authenticated seat identities")
	check(await wait_for(func():return manager.camera.current and game.player_in_vehicle,"passenger chase camera"),"passenger receives an independent vehicle camera")
	check(actor.body_collision.disabled and not actor.body_root.visible and not actor.weapon_root.visible,"passenger infantry body, weapon and collision are disabled while seated")
	stage("aboard")
	if not await wait_for(func():return reached("operator","parked"),"operator finishes real drive and firing"): return
	var ammo_before:=apc.ammo;var ammo_personal:=int(actor.ammo.fal);var held_before:=game.grenades_system.rounds.size()
	var turret_before:=apc.turret_yaw;var camera_before:=manager.orbit_yaw
	actor.apply_look(Vector2(180,-60));await create_timer(.2).timeout
	check(absf(manager.orbit_yaw-camera_before)>.2 and absf(angle_difference(turret_before,apc.turret_yaw))<.03,"passenger can look independently without steering the turret")
	click(MOUSE_BUTTON_RIGHT);press(KEY_X);press(KEY_G);actor.fire()
	check(not manager.zoom and not manager.thermal and not actor.grenade_selected and int(actor.ammo.fal)==ammo_personal,"passenger controls cannot enable optics, thermal, grenades or personal firearm shots")
	manager.rpc_id(1,"command","reload",{})
	game.rpc_id(1,"server_shot_request",7001,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,"fal",0)
	game.rpc_id(1,"server_prime_grenade",actor.life_id,7001)
	for index in 10:
		manager.rpc_id(1,"control",9000+index,{"throttle":1.,"steer":1.,"fire":true,"aim":apc.global_position+Vector3(0,150,0),"occupancy":apc.control_epoch,"vehicle":apc.vehicle_id,"life":actor.life_id})
		await create_timer(.06).timeout
	check(apc.ammo==ammo_before and apc.reload_left==0 and absf(apc.speed)<.05,"central server rejects passenger control/fire/reload injection after the operator used its magazine")
	check(int(actor.ammo.fal)==ammo_personal and actor.grenade_held_id.is_empty() and game.grenades_system.rounds.size()==held_before,"central server rejects passenger personal-shot and grenade RPCs")
	check(apc.driver==int(shared("operator").get("id",0)),"malicious passenger packets cannot steal the reserved driver seat")
	await capture("passenger")
	stage("denials-checked")
	if not await wait_for(func():return reached("operator","promoted") and apc.driver==actor.peer_id and apc.seat_of(actor.peer_id)==0,"passenger promotion"): return
	check(manager._local_is_operator(),"departing operator promotes the connected passenger through authoritative seat snapshots")
	var shots_before:=apc.ammo
	control(apc,0,true)
	if not await wait_for(func():return apc.ammo<shots_before,"promoted operator shot",4): return
	control(apc,0,false)
	check(apc.ammo<shots_before,"promoted operator can fire a newly validated mounted shot")
	await create_timer(.4).timeout
	manager.request_command("exit",{})
	if not await wait_for(func():return actor.vehicle_id.is_empty() and apc.driver==0 and apc.seats.is_empty(),"promoted operator safe exit"): return
	check(await wait_for(func():return actor.camera.current and not actor.body_collision.disabled,"infantry restored after exit"),"final exit restores infantry camera and collision")
	check(actor.position.y>=WarTerrain.height_at(actor.position.x,actor.position.z)+.05,"promoted operator exits on valid terrain above the ground")
	await capture("safe-exit");stage("exited")
	await wait_for(func():return reached("operator","complete") and reached("opponent","complete"),"all observers finish")
func opponent_flow() -> void:
	var apc:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	if not await wait_for(func():return reached("passenger","aboard"),"both friendly accounts board"): return
	var operator_id:=int(shared("operator").get("id",0));var passenger_id:=int(shared("passenger").get("id",0))
	check(await wait_for(func():return apc.driver==operator_id and apc.seat_of(passenger_id)>0,"third account seat snapshot"),"opposing third account receives the same operator and passenger seats")
	stage("both-seated")
	if not await wait_for(func():return reached("operator","promoted"),"operator leaves and passenger promoted"): return
	check(await wait_for(func():return apc.driver==passenger_id and apc.seat_of(passenger_id)==0,"third account promotion snapshot"),"opposing third account receives authoritative passenger promotion")
	if not await wait_for(func():return reached("passenger","exited"),"promoted operator exits"): return
	check(await wait_for(func():return apc.driver==0 and apc.seats.is_empty(),"third account final vacancy"),"all three accounts agree on final empty vehicle occupancy")
	stage("complete")
