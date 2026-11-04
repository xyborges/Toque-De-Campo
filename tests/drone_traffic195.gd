extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var actor:=game.local_player as WarPlayer
	actor.set_physics_process(true)
	await physics_frame
	var position_before:=actor.global_position
	game.vehicle_system.launch_drone(actor.peer_id)
	await physics_frame;await physics_frame
	var drone:=game.vehicle_system.find_target(actor.vehicle_id) as WarDrone
	check(is_instance_valid(drone),"drone is created and controlled")
	check(actor.global_position.distance_to(position_before)<.1,"operator remains in the original position")
	check(actor.body_root.visible and not actor.weapon_root.visible and is_instance_valid(actor.drone_controller) and actor.drone_controller.visible,"operator hides the gun and holds a controller")
	check(not actor.body_collision.disabled,"operator remains physically vulnerable")
	if is_instance_valid(drone):
		drone.simulate(1.,{"throttle":1.,"yaw":0.})
		check(drone.velocity.length()>16. and drone.velocity.length()<=16.1,"drone movement reaches the intended increased speed")
		game.vehicle_system.release(actor.peer_id,true)
		await physics_frame;await physics_frame
		check(drone.falling and actor.vehicle_id.is_empty() and is_instance_valid(actor.drone_controller) and not actor.drone_controller.visible,"leaving returns control and makes the drone fall")
		game.vehicle_system._destroy_drone(drone,2);game.members[actor.peer_id].drone_used=false
		game.vehicle_system.launch_drone(actor.peer_id);var last_drone:=game.vehicle_system.find_target(actor.vehicle_id) as WarDrone
		actor.take_damage(200.,"chest",2);await physics_frame
		check(actor.hp<=0 and actor.vehicle_id.is_empty() and is_instance_valid(last_drone) and last_drone.falling,"death releases the operator and sends the drone into a fall")
	var director:=load("res://modes/war/scripts/bot_director.gd").new() as WarBotDirector
	director.game=game
	var follower:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	var lead:=game.vehicle_system.vehicles.v_abrams as WarVehicle
	follower.global_position=Vector3(0,5,0);follower.rotation=Vector3.ZERO;follower.speed=4.
	lead.global_position=Vector3(0,5,-12);lead.rotation=Vector3.ZERO;lead.speed=1.
	await physics_frame;await physics_frame
	var record: Dictionary={}
	var decision:=director._traffic_plan(follower,record)
	check(not decision.is_empty(),"bot detects slower vehicle ahead")
	check(bool(decision.get("brake",false)) or decision.has("point"),"bot selects a clear overtaking path or stops")
	lead.global_position=Vector3(200,5,-200);record.traffic={};await physics_frame;game.war_clock+=.5
	check(director._traffic_plan(follower,record).is_empty(),"clear path does not trigger overtaking")
	lead.global_position=Vector3(0,5,-12)
	var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var volume:=BoxShape3D.new()
	volume.size=Vector3(30,4,2);collision.shape=volume;wall.add_child(collision);wall.position=Vector3(0,6,-5);game.world_root.add_child(wall)
	record.traffic={};await physics_frame;await physics_frame;game.war_clock+=.5
	check(bool(director._traffic_plan(follower,record).get("brake",false)),"blocked passing corridors make the bot stop")
	director.free()
	game.show_menu();game.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
