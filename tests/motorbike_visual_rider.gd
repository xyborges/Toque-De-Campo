extends SceneTree

var checks:=0
var failures: Array[String]=[]
var game: BattleRoyaleGame

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool,message: String) -> void:
	checks+=1
	print(("PASS " if condition else "FAIL ")+message)
	if not condition: failures.append(message)

func all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(all_meshes(child))
	return result

func capture(bike: WarVehicle,actor: GamePlayer,label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	# Gameplay fixture opens the BR lobby on top of the test subject.
	# Hide UI only in this disposable QA scene, not in production.
	for ui in root.find_children("*","CanvasLayer",true,false): ui.hide()
	for control in root.find_children("*","Control",true,false): control.hide()
	var camera:=Camera3D.new()
	game.world_root.add_child(camera)
	camera.global_position=bike.global_position+bike.global_basis*Vector3(2.5,2.2,-3.3)
	camera.look_at(bike.global_position+Vector3(0,1.1,0))
	camera.fov=52.
	camera.make_current()
	await create_timer(.20).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("user://motorbike-rider-"+label+".png")
	camera.queue_free()

func run() -> void:
	game=load("res://tests/br_completion_fixture.gd").new()
	game.set_meta("br_host",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.flat_world()
	game.online=false
	game.phase="active"
	game.br_generation=3
	var system:=load("res://tests/br_motorbikes_fixture.gd").new() as BRMotorbikes
	system.game=game
	game.motorbikes=system
	game.world_root.add_child(system)
	var bike: WarVehicle=system.bikes.br_bike_00
	var actor:=game._spawn_player(1,true,false,Vector3(0,.07,0)) as GamePlayer
	actor.hp=100
	actor.life_id=4
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.vehicle_id=bike.vehicle_id
	var motor:=bike as Node
	if motor.get("model")==null:
		var visual:=load("res://modes/war/equipment/motorbike.tscn").instantiate() as Node3D
		bike.add_child(visual)
		motor.set("model",visual)
		motor.set("handlebar",visual.get_node("Steering"))
		bike.wheels.clear()
		bike.wheels.append(visual.get_node("RearWheel"))
		bike.wheels.append(visual.get_node("Steering/FrontWheel"))
	var model:=motor.get("model") as Node3D
	var steering:=motor.get("handlebar") as Node3D
	check(model!=null and steering!=null,"motorcycle model and steering pivot instantiated")
	check(model.get_node_or_null("SeatAnchor")!=null and model.get_node_or_null("LeftFootPeg")!=null,"seat and rider footrest anchors exist")
	check(bike.wheels.size()==2 and steering.get_node_or_null("FrontWheel")!=null,"front and rear wheels keep independent pivots")
	check(model.get_node_or_null("Steering/GripLeft")!=null and model.get_node_or_null("Steering/GripRight")!=null,"hands follow true handlebar grip markers")
	check(all_meshes(model).size()>10 and all_meshes(model).size()<110,"detailed bike model remains within draw-node budget")
	bike.steering=1.
	bike.speed=16.
	for _i in 45: motor.animate_running_gear(1./60.)
	check(steering.rotation.y<-.30,"positive/right steering points the visual front wheel right")
	check(model.rotation.z<-.18,"right turn banks the motorcycle to the right")
	check(absf(model.rotation.z)<deg_to_rad(19.1),"bank angle stays under safety cap")
	bike.rotation.y=.67
	bike.heading=0.
	actor.global_position=bike.global_position+bike.global_basis*Vector3(0,.07,0)
	motor.pose_rider(actor)
	check(absf(angle_difference(actor.rotation.y,bike.rotation.y))<.001,"rider follows presented vehicle yaw, not stale heading")
	check(absf(actor.body_root.rotation.z-model.rotation.z)<.01,"rider banks in sync with the motorcycle")
	check(actor.body_root.position.y>.20 and actor.body_root.position.z>.10,"pelvis is seated on the saddle rather than inside the engine")
	for side in ["l","r"]:
		var arm:=actor.avatar_parts["arm_"+side] as Node3D
		check(float(arm.get_meta("grip_error",99.))<.035,side+" hand reaches moving handlebar via IK")
	await capture(bike,actor,"right")
	bike.steering=-1.
	for _i in 85: motor.animate_running_gear(1./60.)
	motor.pose_rider(actor)
	check(steering.rotation.y>.30,"negative/left steering points the visual wheel left")
	check(model.rotation.z>.18,"left turn banks the motorcycle to the left")
	check(actor.body_root.rotation.z>.18,"rider banks left in sync")
	await capture(bike,actor,"left")
	bike.steering=0.
	bike.speed=0.
	for _i in 80: motor.animate_running_gear(1./60.)
	check(absf(steering.rotation.y)<.01 and absf(model.rotation.z)<.01,"bike returns smoothly to upright steering at rest")
	motor.reset_rider_pose(actor)
	check(actor.body_root.position.is_zero_approx() and actor.body_root.rotation.is_zero_approx(),"dismount clears motorcycle-specific body transforms")
	check(actor.avatar_parts.head.rotation.is_zero_approx() and actor.avatar_parts.torso.rotation.is_zero_approx(),"dismount clears head and torso lean")
	actor.vehicle_id=""
	game.free()
	await process_frame
	print("MOTORBIKE_VISUAL_RIDER %d checks %d failures"%[checks,failures.size()])
	if not failures.is_empty(): print(JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
