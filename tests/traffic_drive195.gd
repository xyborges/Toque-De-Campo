extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var manager:=game.vehicle_system as WarVehicles
	var actor:=game.local_player as WarPlayer;var follower:=manager.vehicles.v_guarani as WarVehicle;var lead:=manager.vehicles.v_abrams as WarVehicle
	for vehicle: WarVehicle in manager.vehicles.values(): vehicle.global_position=Vector3(1000,100,1000)
	var origin:=WarTerrain.point(-100,100)+Vector3.UP*.15
	var floor:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,1,200);collision.shape=box;floor.add_child(collision);floor.position=origin+Vector3(0,-.6,0);game.world_root.add_child(floor)
	follower.global_position=origin;follower.heading=0;follower.rotation=Vector3.ZERO;follower.speed=0;follower.allocate_seat(1);actor.vehicle_id=follower.vehicle_id;game.members[1].vehicle=follower.vehicle_id
	lead.global_position=origin+Vector3(0,0,-15);lead.rotation=Vector3.ZERO;lead.speed=0
	var director:=load("res://modes/war/scripts/bot_director.gd").new() as WarBotDirector;director.game=game
	var record: Dictionary={"objective":"A","vehicle_goal":"A","vehicle_path":[origin+Vector3(0,0,-110)],"vehicle_index":0,"boarding_until":0.,"vehicle_check_at":0.,"last_position":origin,"vehicle_stuck":0.,"target":0,"line_clear":false}
	await physics_frame;await physics_frame
	var closest:=INF;var max_side:=0.;var initial_position:=follower.global_position
	for tick in 1800:
		game.war_clock+=1./60.;director._drive(actor,record,1./60.)
		follower.simulate(1./60.,manager.controls.get(1,{}))
		closest=minf(closest,Vector2(follower.position.x-lead.position.x,follower.position.z-lead.position.z).length());max_side=maxf(max_side,absf(follower.position.x-origin.x))
		await physics_frame
	var moved:=follower.global_position.distance_to(initial_position)
	print("TRAFFIC_ACTUAL ",{"distance_moved":moved,"side":max_side,"closest":closest,"follower":follower.global_position,"lead":lead.global_position,"record":record,"speed":follower.speed,"control":manager.controls.get(1,{}),"seat":actor.vehicle_id})
	if moved<2: failures.append("vehicle did not move")
	if closest<3.0: failures.append("vehicle approached the rear too closely")
	if max_side<1.0 and follower.global_position.z<lead.global_position.z: failures.append("passed without safe lateral clearance")
	if follower.global_position.z>lead.global_position.z: failures.append("overtake was not completed")
	director.free();game.show_menu();game.queue_free();await process_frame
	print(JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
