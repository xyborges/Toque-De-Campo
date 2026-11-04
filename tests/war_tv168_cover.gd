extends SceneTree
var game: WarGame
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	var manager:=game.vehicle_system as WarVehicles;manager.set_process(false)
	var actor:=game.local_player as WarPlayer;var vehicle:=manager.vehicles.v_guarani as WarVehicle
	vehicle.position=Vector3(0,20,0);vehicle.rotation=Vector3.ZERO;vehicle.aim(.1,Vector3(0,22,-500),true);vehicle.allocate_seat(1);actor.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id;vehicle.selected="secondary"
	manager._process(.1);manager._fire_vehicle(vehicle)
	var shot: Dictionary=game.war_fx.find_round(manager.tv.view_id)
	if shot.is_empty(): failures.append("no launch")
	else:
		var direction: Vector3=shot.velocity.normalized();var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6,6,.6);shape.shape=box;wall.add_child(shape);game.world_root.add_child(wall);wall.position=Vector3(shot.position)+direction*40;wall.look_at(wall.position+direction)
		var victim:=game.players[2] as WarPlayer;victim.position=Vector3(shot.position)+direction*42-Vector3.UP*.8
		await physics_frame;await physics_frame
		for tick in 90:
			game.war_clock+=1./120.;game.war_fx._step(shot,1./120.)
			if not shot.active: break
		if shot.active: failures.append("missile did not physically collide with cover")
		if manager.tv.viewing() or manager.tv.has_flight(vehicle.vehicle_id): failures.append("real collision did not end guidance/camera")
		if victim.hp!=100: failures.append("blast crossed solid cover: hp="+str(victim.hp))
		print("IMPACT ",{"position":shot.position,"wall":wall.position,"victim_hp":victim.hp,"active":shot.active,"guidance":manager.tv.flights.size()})
	NavalStorage.write_json("res://tests/war-tv168-cover-results.json",{"checks":3,"failures":failures});print(JSON.stringify(failures));game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
