extends SceneTree

var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func overlap(vehicle: WarVehicle) -> Dictionary:
	var hit:=KinematicCollision3D.new()
	if vehicle.test_move(vehicle.global_transform,Vector3.ZERO,hit,.001,true):
		return {"depth":hit.get_depth(),"collider":str(hit.get_collider()),"normal":str(hit.get_normal())}
	return {"depth":0.}

func run() -> void:
	var game:=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+65000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: print("FAIL game not ready");quit(1);return
	game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	if game.bot_director: game.bot_director.stop()
	await physics_frame
	var manager:=game.vehicle_system as WarVehicles
	check(WarRules.VEHICLE_RESPAWN_SECONDS==15.,"armored respawn is 15 seconds")
	for vehicle: WarVehicle in manager.vehicles.values():
		if vehicle is WarShip: continue
		var initial:=overlap(vehicle)
		print("SPAWN_INITIAL ",vehicle.kind," ",JSON.stringify(initial)," position=",vehicle.position)
		check(float(initial.depth)<.03,vehicle.kind+": initial hull clear of ground")
		vehicle.global_position=WarTerrain.point(80,220)+Vector3.UP*5
		vehicle.ground_support.tilt=Basis(Vector3.RIGHT,.4);vehicle.resting=true
		vehicle.destroyed=true;vehicle.respawn_left=15.;vehicle.collision_layer=0
		manager._step_vehicle_respawns(14.9)
		check(vehicle.destroyed and vehicle.respawn_left>0,vehicle.kind+": not before 15 seconds")
		manager._step_vehicle_respawns(.1)
		await physics_frame
		var after:=overlap(vehicle)
		print("SPAWN_RESPAWN ",vehicle.kind," ",JSON.stringify(after)," position=",vehicle.position)
		check(not vehicle.destroyed and vehicle.global_position.is_equal_approx(vehicle.spawn_position),vehicle.kind+": returns to base")
		check(float(after.depth)<.03,vehicle.kind+": respawn hull clear of ground")
		check(vehicle.ground_support.tilt.is_equal_approx(Basis.IDENTITY) and not vehicle.resting,vehicle.kind+": stale slope and rest state cleared")
		for tick in 90:
			vehicle.simulate(1./60.,{});await physics_frame
		var settled:=overlap(vehicle)
		check(float(settled.depth)<.05 and vehicle.global_position.y>WarTerrain.height_at(vehicle.position.x,vehicle.position.z)-.1,vehicle.kind+": remains above the terrain after settling")
	# Occupied bases use another clear location and never spawn inside a wall.
	var apc:=manager.vehicles.v_guarani as WarVehicle
	var blocker:=StaticBody3D.new();blocker.collision_layer=1;blocker.position=apc.spawn_position+Vector3.UP*2.5
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(7,5,8);shape.shape=box;blocker.add_child(shape);game.world_root.add_child(blocker)
	await physics_frame
	apc.destroyed=true;apc.collision_layer=0;apc.respawn_left=0
	manager._respawn_vehicle(apc);await physics_frame
	check(not apc.destroyed and apc.global_position.distance_to(apc.spawn_position)>2 and float(overlap(apc).depth)<.03,"occupied spawn selects a nearby clear position")
	blocker.queue_free();await physics_frame
	var barrier:=StaticBody3D.new();barrier.collision_layer=1;barrier.position=apc.spawn_position+Vector3.UP*4
	var barrier_shape:=CollisionShape3D.new();var barrier_box:=BoxShape3D.new();barrier_box.size=Vector3(60,8,60);barrier_shape.shape=barrier_box;barrier.add_child(barrier_shape);game.world_root.add_child(barrier)
	await physics_frame
	apc.destroyed=true;apc.collision_layer=0;apc.respawn_left=0
	manager._respawn_vehicle(apc)
	check(apc.destroyed and apc.respawn_left>0,"blocked base defers respawn instead of intersecting obstacles")
	barrier.queue_free();await physics_frame
	manager._step_vehicle_respawns(.5)
	check(not apc.destroyed and float(overlap(apc).depth)<.03,"deferred respawn succeeds once base is clear")
	# Even when the destroyed snapshot is lost, the observer snaps to the new
	# base instead of interpolating the old hull through the landscape.
	var remote:=WarVehicle.new();remote.kind="guarani";remote.vehicle_id="spawn_mirror";game.world_root.add_child(remote)
	remote.collision_layer=0;remote.collision_mask=0
	apc.global_position=WarTerrain.point(100,100)+Vector3.UP*3
	var old:=apc.snapshot();remote.receive(old);remote.global_position=old.position
	apc.destroyed=true;apc.collision_layer=0;manager._respawn_vehicle(apc)
	var returned:=apc.snapshot();remote.receive(returned)
	check(remote.global_position.is_equal_approx(apc.global_position),"missed destruction still snaps observer to respawn")
	remote.receive(old)
	check(remote.destination.is_equal_approx(apc.global_position),"older spawn generation cannot restore stale position")
	remote.queue_free()
	var ship:=manager.vehicles.v_naval_assault_0 as WarShip
	check(WarRules.SHIP_RESPAWN_SECONDS==60.,"ship respawn remains 60 seconds")
	ship.destroyed=true;ship.respawn_left=60.;manager._step_vehicle_respawns(15.)
	check(ship.destroyed and is_equal_approx(ship.respawn_left,45.),"15-second armored timer does not shorten ships")
	game.queue_free();await process_frame
	print("SPAWN_TEST ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
