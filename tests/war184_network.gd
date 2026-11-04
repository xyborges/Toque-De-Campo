extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(test: Callable,label: String,seconds:=25.0) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	failures.append("timeout "+label);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func run() -> void:
	game=load("res://tests/war184_network_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
	if role=="server": game.set_meta("war_host",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server()
	else:
		await game.join_game("pvp")
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join"):
			game.request_deploy(1 if role=="enemy" else 0,"soldier","fal","rpg","base")
			if await wait_for(func():return game.local_player.deployed,"deploy"): await client()
	NavalStorage.write_json("res://tests/war184-network-"+role+".json",{"checks":checks,"failures":failures,"role":role})
	print(JSON.stringify({"checks":checks,"failures":failures,"role":role}))
	game.show_menu();game.queue_free();await create_timer(.5).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
	if not await wait_for(func():return game.members.size()==3 and game.members.values().all(func(m):return m.deployed),"deploy all",55): return
	var actors: Dictionary={}
	for actor: WarPlayer in game.players.values(): actors[str(actor.name)]=actor
	var operator:=actors.operator as WarPlayer;var passenger:=actors.passenger as WarPlayer
	game.members[operator.peer_id].shield=0.;game.members[passenger.peer_id].shield=0.
	var base:=WarRules.BASES[0]+Vector3(0,.2,30)
	for actor: WarPlayer in [operator,passenger]:
		actor.global_position=base+Vector3(5 if actor==passenger else 0,0,0);actor.set_meta("fixture_freeze",true)
		game._broadcast("qa_pose",[actor.peer_id,actor.global_position,0.,0.])
	var ammo:=int(operator.ammo.fal)
	phase("shoot")
	if not await wait_for(func():return game.reports.has("tpp"),"TPP shot"): return
	check(operator.ammo.fal<=ammo-3,"server accepts FAL at maximum shoulder distance in three directions")
	operator.position=base;operator.remove_meta("fixture_freeze");game.network_guard.motion.erase(operator.peer_id)
	game._broadcast("qa_pose",[operator.peer_id,base,0.,0.]);phase("stairs")
	if not await wait_for(func():return game.reports.has("stairs"),"network stairs"): return
	check(operator.global_position.y>WarRules.BASES[0].y+.5 and operator.global_position.z<26,"authority accepts natural stair climbing through normal movement validation")
	var ship:=game.vehicle_system.vehicles.v_naval_assault_0 as WarShip
	for actor: WarPlayer in [operator,passenger]:
		actor.set_meta("fixture_freeze",true);actor.global_position=ship.global_position+Vector3(0,4.2,6.2);game._broadcast("qa_pose",[actor.peer_id,actor.global_position,0.,0.])
	phase("operator-board")
	if not await wait_for(func():return ship.driver==operator.peer_id,"operator boards"): return
	phase("passenger-board")
	if not await wait_for(func():return ship.seat_of(passenger.peer_id)==1,"passenger boards"): return
	phase("boat-view")
	if not await wait_for(func():return game.reports.has("view"),"naval camera"): return
	check(ship.seat_of(operator.peer_id)==0 and ship.seat_of(passenger.peer_id)==1,"server keeps one operator and one separate passenger")
	var rounds_before:=ship.ammo
	phase("ship-fire")
	if not await wait_for(func():return game.reports.has("ship-fired"),"naval fire"): return
	check(ship.ammo<=rounds_before-3,"server fires real naval rounds using the third-person camera controls")
	var direction: Vector3=-ship.muzzle.global_basis.z.normalized()
	var aimed: Vector3=ship.aim_target-ship.muzzle.global_position
	check(Vector2(direction.x,direction.z).normalized().dot(Vector2(aimed.x,aimed.z).normalized())>.99,"world turret yaw follows the camera target independently of the hull")
	ship.global_position=Vector3(-1200,0,-650);ship.speed=0;game.vehicle_system.sync_occupants(ship)
	phase("exit")
	if not await wait_for(func():return operator.vehicle_id.is_empty(),"remote operator exits"): return
	check(ship.driver==passenger.peer_id and ship.seat_of(passenger.peer_id)==0,"exiting operator promotes only the remaining passenger")
	check(WarCoast.wet(operator.global_position.x,operator.global_position.z) and operator.global_position.y> -2,"remote exit stays at the water surface")
	phase("passenger-exit")
	if not await wait_for(func():return passenger.vehicle_id.is_empty(),"second occupant exits"): return
	check(ship.seats.is_empty() and ship.driver==0,"last exit clears all seat and driver reservations")
	var pole:=game.power_grid.poles.port_1_1 as WarPowerPole
	game._apply_hit(actors.enemy.peer_id,{"collider":pole},140,"chest","fal",Vector3.RIGHT)
	check(pole.broken,"server projectile damage breaks an environmental pole")
	phase("broken")
	if not await wait_for(func():return game.reports.has("operator-pole") and game.reports.has("passenger-pole"),"replicated destruction"): return
	var saved:=game.power_grid.snapshot()
	for actor: WarPlayer in game.players.values(): game.rpc_id(actor.peer_id,"war_poles_state",saved)
	phase("baseline")
	if not await wait_for(func():return game.reports.has("operator-baseline") and game.reports.has("passenger-baseline"),"late state"): return
	phase("done");await create_timer(.6).timeout
func client() -> void:
	var actor:=game.local_player as WarPlayer;var manager:=game.vehicle_system as WarVehicles
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var seen: Dictionary={}
	while await wait_for(func():return game.phase not in seen,"phase",40):
		var current: String=game.phase;seen[current]=true
		if current=="done": return
		if current=="shoot" and role=="operator":
			game.third_person=true;actor.shoulder_distance=4;actor.shoulder_arm.spring_length=4
			for heading in [0.,PI*.5,PI]:
				actor.yaw=heading;actor.rotation.y=heading;actor.pitch=0;actor.camera_pivot.rotation.x=0
				await physics_frame;await physics_frame;actor._update_camera_collision(.016)
				game.send_player_state(actor);await create_timer(.1).timeout
				actor.fire_cooldown=0;actor.fire();await create_timer(.15).timeout
			game.rpc_id(1,"qa_report","tpp")
		elif current=="stairs" and role=="operator":
			actor.yaw=0;actor.rotation.y=0;actor.pitch=0
			await create_timer(.25).timeout
			Input.action_press("move_forward");await create_timer(.85).timeout;Input.action_release("move_forward")
			await create_timer(.25).timeout
			check(actor.global_position.y>WarRules.BASES[0].y+.5 and actor.global_position.z<26,"remote player climbs actual stair collision without jumping")
			game.rpc_id(1,"qa_report","stairs")
		elif current=="operator-board" and role=="operator": manager.request_command("enter",{"id":"v_naval_assault_0"})
		elif current=="passenger-board" and role=="passenger": manager.request_command("enter",{"id":"v_naval_assault_0"})
		elif current=="boat-view" and role=="operator":
			await create_timer(.3).timeout
			var ship:=manager.find_target(actor.vehicle_id) as WarShip
			manager._process(.016)
			check(manager.vehicle_view.external and manager.camera is NavalCamera,"client uses shared Naval external camera")
			var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;manager._input(right)
			for i in 45: manager._process(1./60)
			print("ZOOM_STATE ",manager.zoom," ",manager.camera.fov," ",actor.vehicle_id," ",manager.last_control_role)
			check(manager.zoom and manager.camera.fov<15,"remote operator has toggle third-person zoom")
			manager.toggle_thermal();check(manager.thermal,"remote ship accepts thermal outside first person")
			manager.toggle_thermal()
			game.rpc_id(1,"qa_report","view")
		elif current=="ship-fire" and role=="operator":
			var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;manager._input(press)
			await create_timer(.8).timeout
			press.pressed=false;manager._input(press);await create_timer(.2).timeout
			check(manager.shot_events.size()>=3,"client receives the authoritative naval projectile events")
			game.rpc_id(1,"qa_report","ship-fired")
		elif current=="exit" and role=="operator":
			manager.request_interact()
			check(await wait_for(func():return actor.vehicle_id.is_empty(),"local exit"),"server confirms exit on client")
			check(actor.in_water(),"client restores swimming after exit")
		elif current=="passenger-exit" and role=="passenger": manager.request_interact()
		elif current=="broken" and role!="enemy":
			check(await wait_for(func():return game.power_grid.poles.port_1_1.broken,"broken pole"),"pole destruction replicates")
			check(not game.power_grid.poles.port_1_3.energized,"power outage replicates")
			game.rpc_id(1,"qa_report",role+"-pole")
		elif current=="baseline" and role!="enemy":
			check(game.power_grid.snapshot().size()==1,"repeated baseline does not duplicate debris or wires")
			game.rpc_id(1,"qa_report",role+"-baseline")
