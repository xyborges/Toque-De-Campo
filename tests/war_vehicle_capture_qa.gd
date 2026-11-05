extends SceneTree
# Capture regression: infantry, motorcycle and armoured occupants must all count.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("WAR_VEHICLE_CAPTURE_FAIL "+label)

func _initialize() -> void:
	_run.call_deferred()

func _spawn_member(game: WarGame,peer: int,team: int,position: Vector3) -> WarPlayer:
	var actor:=game._spawn_player(peer,false,false,position) as WarPlayer
	actor.apply_identity(team,"soldier")
	actor.deployed=true;actor.hp=100.;actor.set_physics_process(false)
	game.members[peer]={"team":team,"role":"soldier","deployed":true,"bot":true,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	return actor

func _board(game: WarGame,actor: WarPlayer,vehicle: WarVehicle) -> void:
	var seat:=vehicle.allocate_seat(actor.peer_id)
	actor.vehicle_id=vehicle.vehicle_id
	game.members[actor.peer_id].vehicle=vehicle.vehicle_id
	game.members[actor.peer_id].vehicle_seat=seat
	game.members[actor.peer_id].vehicle_role="operator" if seat==0 else "passenger"
	actor.body_collision.set_deferred("disabled",true)
	game.vehicle_system.sync_occupants(vehicle)

func _capture_ticks(game: WarGame,seconds: int) -> void:
	for i in seconds:
		game._physics_process(1.0)

func _run() -> void:
	var game:=WarGame.new()
	game.operation_id=WarOperation.AFGHAN
	game.offline_operation=true
	game.set_meta("war_test",true);game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+40000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready:
		check(false,"game not ready");quit(1);return
	game.set_physics_process(false)
	if game.bot_director: game.bot_director.stop()
	if game.vehicle_system:
		game.vehicle_system.set_physics_process(false)
	var point: Vector3=WarRules.OBJECTIVES["A"].position
	var enemy:=_spawn_member(game,18001,1,WarRules.BASES[1])
	var bike_rider:=_spawn_member(game,18002,0,point)
	var bike:=game.vehicle_system.vehicles["v_bike_0_0"] as WarVehicle
	bike.global_position=WarTerrain.point(point.x,point.z)+Vector3.UP*.35
	_board(game,bike_rider,bike)
	check(game._capture_eligible(bike_rider.peer_id),"bike rider is capture eligible")
	check(game._capture_position(bike_rider.peer_id).distance_to(bike.global_position)<.01,"bike rider captures at vehicle authority position")
	game.objective_states["A"]=WarRules.fresh_objectives()["A"]
	_capture_ticks(game,19)
	check(int(game.objective_states["A"].owner)==0,"motorcycle can capture neutral objective")

	game.objective_states["A"]=WarRules.fresh_objectives()["A"]
	game.vehicle_system.reset_occupancy()
	bike_rider.vehicle_id="";game.members[bike_rider.peer_id].vehicle="";game.members[bike_rider.peer_id].vehicle_seat=-1
	bike_rider.global_position=WarRules.BASES[0]
	var tank_driver:=_spawn_member(game,18003,0,point)
	var tank:=game.vehicle_system.vehicles["v_abrams"] as WarVehicle
	tank.global_position=WarTerrain.point(point.x,point.z)+Vector3.UP*.55
	_board(game,tank_driver,tank)
	check(game._capture_eligible(tank_driver.peer_id),"tank driver is capture eligible")
	_capture_ticks(game,19)
	check(int(game.objective_states["A"].owner)==0,"armoured driver can capture objective")

	game.objective_states["A"]=WarRules.fresh_objectives()["A"]
	var passenger:=_spawn_member(game,18004,0,point)
	_board(game,passenger,tank)
	check(game._capture_eligible(passenger.peer_id),"armoured passenger is capture eligible")
	game._physics_process(1.0)
	check(int(game.objective_states["A"].count[0])==2,"driver and passenger both contribute capture strength")

	var fake:=_spawn_member(game,18005,0,point)
	fake.vehicle_id=tank.vehicle_id
	game.members[fake.peer_id].vehicle=tank.vehicle_id
	check(not game._capture_eligible(fake.peer_id),"spoofed vehicle id without authoritative seat cannot capture")
	print("WAR_VEHICLE_CAPTURE ",JSON.stringify({"ok":failures.is_empty(),"checks":9,"owner":game.objective_states["A"].owner,"count":game.objective_states["A"].count}))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
