extends SceneTree
# End-to-end authoritative boarding test with an offline WarGame world.
var game: WarGame
var manager: WarVehicles
var checks:=0
var failures: Array[String]=[]

func assert_ok(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error("PILOT_TAKEOVER_FAIL "+label)

func _initialize() -> void:
	_run.call_deferred()

func _place_near(peer: int,vehicle: WarVehicle) -> void:
	var actor:=game.players.get(peer) as WarPlayer
	actor.global_position=WarTerrain.point(vehicle.global_position.x-3.5,vehicle.global_position.z)+Vector3.UP*.2
	actor.velocity=Vector3.ZERO
	actor.hp=100.
	actor.deployed=true

func _board(peer: int,vehicle: WarVehicle) -> void:
	_place_near(peer,vehicle)
	manager.command_for(peer,"enter",{"id":vehicle.vehicle_id})

func _run() -> void:
	game=WarGame.new()
	game.offline_operation=true
	game.operation_id=WarOperation.AFGHAN
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+35000
	while not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	if not game.join_ready:
		push_error("PILOT_TAKEOVER_FAIL game not ready")
		quit(1)
		return
	game.set_physics_process(false)
	manager=game.vehicle_system as WarVehicles
	manager.set_physics_process(false)
	manager.set_process(false)
	if game.bot_director: game.bot_director.stop()
	for peer in range(701,709):
		var actor:=game._spawn_player(peer,false,false,WarTerrain.point(-440,800)) as WarPlayer
		actor.apply_identity(0,"soldier")
		actor.hp=100.
		actor.deployed=true
		actor.set_physics_process(false)
		game.members[peer]={"team":0,"role":"soldier","deployed":true,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.,"bot":peer==701}
	# Newly parked heavy vehicles must not initially overlap the terrain
	# or base fortifications after the exact original-base swap.
	for kind in ["guarani","bmp2","abrams","t90"]:
		var parked:=manager.vehicles["v_"+kind] as WarVehicle
		var bay:=WarOperation.armor_bay(WarOperation.AFGHAN,parked.team,kind in ["abrams","t90"])
		assert_ok(Vector2(parked.spawn_position.x,parked.spawn_position.z).distance_to(Vector2(bay.x,bay.z))<.1,kind+" spawn is on its assigned military road bay")
		var contact:=KinematicCollision3D.new()
		var overlapping:=parked.test_move(parked.global_transform,Vector3.ZERO,contact,.001,true)
		assert_ok(not overlapping or contact.get_depth()<.03,kind+" starts clear of base geometry")
	var vehicle:=manager.vehicles["v_guarani"] as WarVehicle
	vehicle.global_position=WarTerrain.point(-420,810)+Vector3.UP*.35
	vehicle.heading=0.
	vehicle.rotation.y=0.
	await physics_frame
	_board(701,vehicle)
	assert_ok(vehicle.driver==701,"bot first boards as driver")
	_board(702,vehicle)
	assert_ok(vehicle.driver==702 and vehicle.seat_of(702)==0 and vehicle.seat_of(701)>0,"human takes BOT pilot seat without removing BOT passenger")
	assert_ok(game.members[701].vehicle_role=="passenger" and game.members[702].vehicle_role=="operator","identities follow pilot swap")
	_board(703,vehicle)
	assert_ok(vehicle.driver==702 and vehicle.seat_of(703)>0,"existing human pilot cannot be displaced")
	manager.reset_occupancy()
	await physics_frame
	_board(701,vehicle)
	# Construct a legitimate full-seat snapshot with a BOT operator and
	# human passengers. command_for() intentionally makes every entering
	# human the pilot, so it cannot be used to populate this fixture.
	for peer in range(703,708):
		var slot:=vehicle.allocate_seat(peer)
		var passenger:=game.players[peer] as WarPlayer
		passenger.vehicle_id=vehicle.vehicle_id
		game.members[peer].vehicle=vehicle.vehicle_id
		game.members[peer].vehicle_seat=slot
		game.members[peer].vehicle_role="passenger"
		passenger.body_collision.set_deferred("disabled",true)
		passenger._set_hitboxes_enabled(false)
	manager.sync_occupants(vehicle)
	await physics_frame
	assert_ok(vehicle.driver==701 and vehicle.seats.size()==vehicle.seat_capacity(),"full vehicle has BOT pilot and human passengers")
	_board(702,vehicle)
	assert_ok(vehicle.driver==702 and vehicle.seat_of(702)==0 and vehicle.seat_of(701)==-1,"full vehicle safely dismounts BOT driver instead of promoting human passenger")
	var preserved:=true
	for peer in range(703,708):
		preserved=preserved and vehicle.seat_of(peer)>0 and str(game.members[peer].vehicle_role)=="passenger"
	assert_ok(preserved,"all human passengers remain seated")
	_board(708,vehicle)
	assert_ok(vehicle.driver==702 and vehicle.seat_of(708)<0,"human cannot replace another human pilot")
	print("PILOT_TAKEOVER_INTEGRATION ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
