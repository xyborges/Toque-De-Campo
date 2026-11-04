extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func wait_for(condition: Callable,label_text: String,seconds:=14.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if condition.call(): return true
	failures.append("timeout: "+label_text);print("FAIL timeout ",label_text);return false
func phase(value: String) -> void: game.phase=value;game._broadcast("qa_phase",[value])
func run() -> void:
	game=load("res://tests/war_tv168_network_fixture.gd").new();game.set_meta("war_host",role=="server");game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	elif await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed,"client deployment",35.):
		game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await client_flow()
	var report:={"role":role,"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/war-tv168-network-"+role+".json",report);print(JSON.stringify(report));game.show_menu();game.queue_free();await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==3,"three clients",45.): return
	var named: Dictionary={}
	for actor: WarPlayer in game.players.values(): named[str(actor.name)]=actor
	var operator:=named.operator as WarPlayer;var passenger:=named.passenger as WarPlayer;var enemy:=named.enemy as WarPlayer
	game._deploy(operator.peer_id,0,"soldier","fal","rpg","base");game._deploy(enemy.peer_id,1,"soldier","fal","rpg","base");game._deploy(passenger.peer_id,0,"soldier","fal","rpg","base")
	var manager:=game.vehicle_system as WarVehicles;var vehicle:=manager.vehicles.v_guarani as WarVehicle
	vehicle.position=WarTerrain.point(-440,280);vehicle.heading=0;vehicle.rotation=Vector3.ZERO;vehicle.aim(.1,vehicle.position+Vector3(0,100,-600),true)
	for actor in [operator,passenger]:
		actor.position=WarTerrain.point(vehicle.position.x+(-3.9 if actor==operator else 3.9),vehicle.position.z)+Vector3.UP*.2;actor.velocity=Vector3.ZERO;game._broadcast("qa_pose",[actor.peer_id,actor.position,0.,0.])
	phase("enter")
	if not await wait_for(func():return vehicle.driver==operator.peer_id,"operator enters"): return
	phase("passenger")
	if not await wait_for(func():return vehicle.seat_of(passenger.peer_id)==1,"passenger enters"): return
	phase("fire")
	if not await wait_for(func():return manager.tv.flights.size()==1,"TV launched through native input"): return
	var id: String=manager.tv.flights.keys()[0];var shot: Dictionary=game.war_fx.find_round(id);var direction: Vector3=shot.velocity.normalized()
	if not await wait_for(func():return game.reports.has("guided"),"client guided checks"): return
	check(game.reports.guided.states>=8 and game.reports.guided.error<.12,"operator receives authoritative TV states and camera remains on missile")
	check(direction.angle_to(Vector3(shot.velocity).normalized())>.08,"mouse direction is applied by the server to the flying projectile")
	check(not manager.controls.has(passenger.peer_id),"forged passenger TV controls are rejected")
	check(vehicle.driver==operator.peer_id and vehicle.seat_of(passenger.peer_id)==1,"guidance retains unique operator and passenger reservations")
	check(var_to_bytes([id,1,shot.position,shot.velocity,8.,true,game.war_clock]).size()<1200,"TV state payload stays below MTU")
	phase("release")
	if not await wait_for(func():return not manager.tv.has_link(vehicle.vehicle_id),"C cancels authoritative guidance"): return
	check(shot.active,"abandoned TV missile continues its physical flight")
	if not await wait_for(func():return game.reports.has("returned"),"camera restored"): return
	shot.active=false;manager.explode(operator.peer_id,shot.position,320,4.5,"tv",id)
	if not await wait_for(func():return game.reports.has("observer"),"observer authoritative impact"): return
	check(game.reports.observer.states>=8 and game.reports.observer.finished,"observer receives states and same authoritative impact")
	vehicle.secondary_ammo=1;vehicle.secondary_reserve=4;vehicle.secondary_reload_left=0;vehicle.secondary_fire_wait=0
	phase("second")
	if not await wait_for(func():return manager.tv.has_link(vehicle.vehicle_id),"second launch"): return
	phase("timeout")
	if not await wait_for(func():return not manager.tv.has_link(vehicle.vehicle_id),"control loss breaks TV link"): return
	check(vehicle.driver==operator.peer_id,"control timeout does not create a second operator")
	phase("done");await create_timer(.8).timeout
func key(code: int) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);var release:=event.duplicate();release.pressed=false;Input.parse_input_event(release)
func click() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;Input.parse_input_event(event);await create_timer(.15).timeout;var release:=event.duplicate();release.pressed=false;Input.parse_input_event(release)
func client_flow() -> void:
	var manager:=game.vehicle_system as WarVehicles;var actor:=game.local_player as WarPlayer;var vehicle:=manager.vehicles.v_guarani as WarVehicle
	var handled: Dictionary={};var tracked:="";var deadline:=Time.get_ticks_msec()+65000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if game.phase=="done":
			manager.set_physics_process(true);check(not manager.tv.viewing(),"flight end/timeout restores the normal camera");return
		if game.phase=="fire" and role=="enemy" and tracked.is_empty() and not manager.tv.flights.is_empty(): tracked=str(manager.tv.flights.keys()[0])
		if role=="enemy" and not tracked.is_empty() and not manager.tv.flights.has(tracked) and not handled.has("observer"):
			handled.observer=true;game.rpc_id(1,"qa_tv_report","observer",{"states":manager.tv.states_received,"finished":not game.war_fx.find_round(tracked).get("active",false)})
		if handled.has(game.phase): continue
		handled[game.phase]=true;print("PHASE ",role," ",game.phase)
		if game.phase=="enter" and role=="operator": manager.rpc_id(1,"command","enter",{"id":vehicle.vehicle_id})
		elif game.phase=="passenger" and role=="passenger": manager.rpc_id(1,"command","enter",{"id":vehicle.vehicle_id})
		elif game.phase in ["fire","second"] and role=="operator":
			if not await wait_for(func():return manager._local_is_operator(),"operator camera"): return
			if vehicle.selected=="primary": key(KEY_Q)
			if not await wait_for(func():return vehicle.selected=="secondary" and vehicle.secondary_ammo==1 and vehicle.secondary_fire_wait==0,"TV readiness"): return
			manager.orbit_pitch=.20;manager.aim_point=vehicle.position+Vector3(0,120,-600)
			await create_timer(.35).timeout;await click()
			if not await wait_for(func():return manager.tv.viewing(),"TV camera from shot"): return
			check(not actor.view_root.visible and not actor.weapon_root.visible and not manager.thermal,"no personal first-person arms or thermal in TV camera")
			if game.phase=="fire":
				manager.look(Vector2(-300,-65));await create_timer(1.4).timeout
				var shot: Dictionary=game.war_fx.find_round(manager.tv.view_id);var error:=manager.camera.global_position.distance_to(shot.position)
				check(error<.12,"native camera follows actual synchronized missile")
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/war168-tv-network.png")
				game.rpc_id(1,"qa_tv_report","guided",{"states":manager.tv.states_received,"error":error})
		elif game.phase=="fire" and role=="passenger":
			if not await wait_for(func():return not manager.tv.flights.is_empty(),"passenger sees flying missile"): return
			var id: String=manager.tv.flights.keys()[0]
			manager.rpc_id(1,"control",999999,{"aim":Vector3(0,100,-100),"occupancy":vehicle.control_epoch,"vehicle":vehicle.vehicle_id,"life":actor.life_id,"tv_id":id,"guide":true,"tv_direction":Vector3.LEFT})
			manager.rpc_id(1,"command","tv_release",{"id":id})
			check(not manager.tv.viewing() and not manager._local_is_operator(),"passenger cannot take over missile camera or guidance")
		elif game.phase=="release" and role=="operator":
			key(KEY_C);await create_timer(.25).timeout
			check(not manager.tv.viewing() and manager.camera.current and manager.camera.global_position.distance_to(vehicle.optic.global_position)<.15,"C returns to vehicle optic without losing seat")
			game.rpc_id(1,"qa_tv_report","returned",{"ok":true})
		elif game.phase=="timeout" and role=="operator":
			manager.set_physics_process(false);await create_timer(1.).timeout
			check(not manager.tv.viewing(),"missing input stream loses link on server and returns camera")
			manager.set_physics_process(true)
	failures.append("scenario timeout at "+game.phase)


