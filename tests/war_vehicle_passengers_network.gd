extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg=="--ticks40": Engine.physics_ticks_per_second=40
	run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func wait_for(condition: Callable,label_text: String,seconds:=10.) -> bool:
	if "--ticks40" in OS.get_cmdline_user_args() and label_text in ["three clients connect","client deployment"]: seconds=90.
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if condition.call(): return true
	failures.append("timeout: "+label_text);print("FAIL timeout: "+label_text);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func pose(actor: WarPlayer,vehicle: WarVehicle,offset: float) -> void:
	var point:=WarTerrain.point(vehicle.position.x+offset,vehicle.position.z)+Vector3.UP*.2
	actor.position=point;actor.velocity=Vector3.ZERO
	actor.set_meta("fixture_warp_point",point)
	game._broadcast("qa_pose",[actor.peer_id,point,0.,0.])
func key(code: int,pressed:=true) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func click(button: int,pressed:=true) -> void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed;Input.parse_input_event(event)
func capture(label_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/war-passenger-network-"+label_text+".png")
func run() -> void:
	game=load("res://tests/war_passenger_network_fixture.gd").new();game.set_meta("war_host",role=="server");game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	elif await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed,"client deployment"):
		game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		await client_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures}
	NavalStorage.write_json(("res://work/war-passengers40-" if "--ticks40" in OS.get_cmdline_user_args() else "res://tests/war-passengers-network-")+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==3,"three clients connect"): return
	var named: Dictionary={}
	for actor: WarPlayer in game.players.values(): named[str(actor.name)]=actor
	var operator:=named.operator as WarPlayer;var passenger:=named.passenger as WarPlayer;var enemy:=named.enemy as WarPlayer
	var operator_id:=operator.peer_id;var passenger_id:=passenger.peer_id
	check(game._deploy(operator_id,0,"soldier","fal","rpg","base"),"operator deployment accepted")
	check(game._deploy(enemy.peer_id,1,"soldier","ak","rpg","base"),"opposing player activates the normal battle")
	check(game._deploy(passenger_id,0,"soldier","fal","rpg","base"),"passenger joins the balanced friendly team")
	await create_timer(.5).timeout
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	vehicle.position=WarTerrain.point(-450,280);vehicle.heading=0.;vehicle.rotation=Vector3.ZERO
	pose(operator,vehicle,-3.9);pose(passenger,vehicle,3.9)
	phase("operator-enter")
	if not await wait_for(func():return vehicle.driver==operator_id,"operator enters first seat"): return
	phase("passenger-enter")
	if not await wait_for(func():return vehicle.seat_of(passenger_id)==1,"friendly passenger enters occupied APC"): return
	check(vehicle.seats.size()==2 and str(game.members[passenger_id].vehicle_role)=="passenger","server reserves distinct roles atomically")
	passenger.ammo.fal=27
	phase("passenger-controls")
	if not await wait_for(func():return game.reports.has("passenger-checked"),"native passenger checks"): return
	check(not game.vehicle_system.controls.has(passenger_id),"passenger sends no regular control packets and injected controls are rejected")
	check(not vehicle.reloading and vehicle.selected=="primary" and passenger.reload_left==0 and passenger.grenade_held_id.is_empty() and game.vehicle_system.drones.is_empty(),"server denies passenger mounted reload and personal reload/grenade/drone requests")
	var before:=vehicle.position;var ammo:=vehicle.ammo
	phase("operator-drive")
	if not await wait_for(func():return vehicle.position.distance_to(before)>2 and vehicle.ammo<ammo,"operator movement and mounted fire"): return
	check(passenger.position.distance_to(vehicle.to_global(vehicle.seat_position(1)))<.15,"authoritative passenger remains attached during vehicle movement")
	phase("operator-exit")
	if not await wait_for(func():return vehicle.driver==passenger_id and operator.vehicle_id.is_empty(),"operator exits and passenger is promoted"): return
	check(not game.vehicle_system.controls.has(operator_id) and not game.vehicle_system.controls.has(passenger_id),"promotion begins with no inherited movement or trigger")
	phase("promoted-input")
	if not await wait_for(func():return game.reports.has("promoted-checked"),"native promoted operator input"): return
	check(vehicle.driver==passenger_id and vehicle.shot_sequence>1,"promoted passenger can operate and fire through normal local input")
	phase("passenger-exit")
	if not await wait_for(func():return vehicle.driver==0 and passenger.vehicle_id.is_empty(),"promoted operator exits safely"): return
	if not await wait_for(func():return game.reports.has("exit-checked"),"native infantry camera restored"): return
	check(passenger.position.y>=WarTerrain.height_at(passenger.position.x,passenger.position.z),"promoted operator returns above actual terrain")
	pose(operator,vehicle,-3.9);pose(passenger,vehicle,3.9)
	phase("operator-reenter")
	if not await wait_for(func():return vehicle.driver==operator_id,"operator reenters"): return
	phase("passenger-reenter")
	if not await wait_for(func():return vehicle.seat_of(passenger_id)==1,"passenger reenters"): return
	phase("operator-disconnect")
	if not await wait_for(func():return game.players.size()==2 and vehicle.driver==passenger_id,"disconnect promotes living passenger"): return
	check(not game.vehicle_system.controls.has(operator_id) and not game.vehicle_system.sequences.has(operator_id) and vehicle.seat_of(operator_id)<0,"disconnect removes old reservation and input state")
	phase("disconnect-promotion")
	if not await wait_for(func():return game.reports.has("disconnect-checked"),"replicated disconnect promotion"): return
	var kills:=int(game.match_stats.rows[enemy.peer_id].kills)
	game.vehicle_system.damage_from_hit(enemy.peer_id,vehicle,100000,"tank",Vector3.FORWARD)
	check(passenger.hp==0 and passenger.vehicle_id.is_empty() and vehicle.driver==0 and vehicle.seats.is_empty(),"destroying an occupied APC kills and releases the promoted operator")
	check(int(game.match_stats.rows[enemy.peer_id].kills)==kills+1,"vehicle occupant death is counted by the real server statistics")
	phase("destroyed")
	if not await wait_for(func():return game.reports.has("destroyed-checked"),"replicated passenger death and cleared seats"): return
	game.reset_operation();check(vehicle.seats.is_empty() and vehicle.driver==0 and game.vehicle_system.controls.is_empty(),"new operation clears every replicated reservation")
	phase("finish");await create_timer(.5).timeout
func client_flow() -> void:
	var actor:=game.local_player as WarPlayer;var handled: Dictionary={};var sequence:=1000;var previous:=""
	var manager:=game.vehicle_system as WarVehicles
	var vehicle:=manager.vehicles.v_guarani as WarVehicle
	var deadline:=Time.get_ticks_msec()+85000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		var current:=str(game.phase)
		if current=="finish": return
		if current=="operator-drive" and role=="operator":
			sequence+=1
			manager.rpc_id(1,"control",sequence,{"throttle":.5,"steer":0.,"aim":vehicle.position+Vector3(0,2,-100),"fire":true,"occupancy":vehicle.control_epoch,"vehicle":vehicle.vehicle_id,"life":actor.life_id})
		if handled.has(current): continue
		handled[current]=true;previous=current
		print("PHASE ",role," ",current)
		if current in ["operator-enter","operator-reenter"] and role=="operator": manager.rpc_id(1,"command","enter",{"id":"v_guarani"})
		elif current in ["passenger-enter","passenger-reenter"] and role=="passenger":
			# The fixture teleports the hull from its base. Let the ordinary
			# interpolated visual catch up before using the real proximity key.
			if not await wait_for(func():return actor.position.distance_to(vehicle.position)<5.,"native nearby vehicle after fixture teleport"): return
			print("PASSENGER_ENTER ",{"actor":actor.position,"vehicle":vehicle.position,"nearby":manager._nearby(actor)!=null,"input":game.gameplay_input_allowed(),"blocked":game.ui_focus.blocked(),"deployed":actor.deployed,"hp":actor.hp})
			key(KEY_F);key(KEY_F,false)
		elif current=="passenger-controls" and role=="passenger":
			if not await wait_for(func():return manager.camera.current and vehicle.seat_of(actor.peer_id)==1,"passenger camera and seat snapshot"): return
			check(str(game.members[actor.peer_id].vehicle_role)=="passenger" and manager.context_text().contains("PASSAGEIRO"),"passenger sees explicit role and exit guidance")
			check(not actor.body_root.visible and actor.body_collision.disabled and not actor.view_root.visible,"passenger body, collision and personal first-person weapon are hidden inside the hull")
			var yaw:=manager.orbit_yaw;var direction:=InputEventMouseMotion.new();direction.relative=Vector2(100,20);Input.parse_input_event(direction)
			await process_frame
			check(absf(manager.orbit_yaw-yaw)>.01,"passenger can orbit an independent external camera")
			Input.action_press("move_forward");click(MOUSE_BUTTON_RIGHT);click(MOUSE_BUTTON_RIGHT,false);key(KEY_X);key(KEY_X,false);click(MOUSE_BUTTON_LEFT)
			manager.rpc_id(1,"control",999,{"throttle":1.,"steer":1.,"aim":Vector3(30,50,40),"fire":true,"occupancy":vehicle.control_epoch,"vehicle":vehicle.vehicle_id,"life":actor.life_id})
			manager.rpc_id(1,"trigger",1000,true,vehicle.control_epoch,vehicle.vehicle_id,actor.life_id)
			manager.rpc_id(1,"command","reload",{});game.rpc_id(1,"server_reload_request","fal");game.rpc_id(1,"server_prime_grenade",actor.life_id,100);manager.rpc_id(1,"command","drone",{})
			await create_timer(.5).timeout;Input.action_release("move_forward");click(MOUSE_BUTTON_LEFT,false)
			check(not manager.zoom and not manager.thermal and not manager.fire_held and manager.camera.fov>60,"passenger cannot enable optic/thermal or hold a vehicle trigger")
			await capture("passenger");game.rpc_id(1,"qa_report","passenger-checked")
		elif current=="operator-exit" and role=="operator": manager.rpc_id(1,"command","exit",{})
		elif current=="promoted-input" and role=="passenger":
			if not await wait_for(func():return vehicle.driver==actor.peer_id and manager._local_is_operator(),"promotion on native client"): return
			var departed: WarPlayer
			for other: WarPlayer in game.players.values():
				if str(other.name)=="operator": departed=other
			check(is_instance_valid(departed) and departed.body_root.visible,"remote player body is restored after leaving the vehicle")
			check(manager.context_text().contains("OPERADOR") and not manager.fire_held,"promotion changes the HUD role without inheriting held fire")
			var ammo:=vehicle.ammo
			Input.action_press("move_forward");click(MOUSE_BUTTON_LEFT);await create_timer(.5).timeout;Input.action_release("move_forward");click(MOUSE_BUTTON_LEFT,false)
			check(await wait_for(func():return vehicle.ammo<ammo,"promoted operator's actual click fires"),"promoted operator controls the APC through actual native input")
			await capture("promoted");game.rpc_id(1,"qa_report","promoted-checked")
		elif current=="passenger-exit" and role=="passenger":
			key(KEY_F);key(KEY_F,false)
			check(await wait_for(func():return actor.vehicle_id.is_empty() and actor.camera.current and not game.player_in_vehicle,"infantry camera after exit"),"safe exit restores the native infantry camera")
			game.rpc_id(1,"qa_report","exit-checked")
		elif current=="operator-disconnect" and role=="operator": game.show_menu();await create_timer(.15).timeout;return
		elif current=="disconnect-promotion" and role=="passenger":
			check(await wait_for(func():return vehicle.driver==actor.peer_id and str(game.members[actor.peer_id].vehicle_role)=="operator","disconnect promotion replication"),"disconnect promotion reaches the remaining client")
			game.rpc_id(1,"qa_report","disconnect-checked")
		elif current=="destroyed" and role=="passenger":
			check(await wait_for(func():return actor.hp<=0 and actor.vehicle_id.is_empty() and vehicle.seats.is_empty(),"destroyed occupied vehicle state"),"remaining client receives occupant death and empty seats")
			game.rpc_id(1,"qa_report","destroyed-checked")
	failures.append("scenario timed out at "+previous)
