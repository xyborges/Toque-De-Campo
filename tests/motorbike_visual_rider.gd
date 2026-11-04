extends SceneTree

const BIKE := preload("res://modes/war/scripts/motorbike.gd")
var checks := 0
var failures: Array[String] = []
var game: BattleRoyaleGame

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL ", label)

func occupant(peer: int) -> GamePlayer:
	var actor := game._spawn_player(peer,peer==1,false,Vector3.ZERO)
	actor.hp = 100
	actor.set_physics_process(false)
	actor.set_process(false)
	return actor

func check_contact(actor: GamePlayer, seat: Marker3D, grips: Array[Marker3D], pegs: Array[Marker3D], label: String) -> void:
	var pelvis := actor.body_root.get_node("Pelvis") as Node3D
	check(actor.body_root.to_global(pelvis.position+Vector3.DOWN*.10).distance_to(seat.global_position)<.005,label+" stays seated")
	check(actor.body_root.global_basis.x.distance_to(seat.global_basis.x)<.005,label+" shares the bike bank")
	for index in 2:
		var side := "L" if index==0 else "R"
		var arm := actor.avatar_parts["arm_"+side.to_lower()] as Node3D
		var hand := arm.get_node("Hand"+side) as Node3D
		check(hand.global_position.distance_to(grips[index].global_position)<.015,label+" hand "+side+" stays on grip")
		var leg: Dictionary = actor.stance.leg_parts[side]
		var sole: Vector3 = leg.shoe.to_global(Vector3(0,float(leg.sole_y),0))
		check(sole.distance_to(pegs[index].global_position)<.035,label+" boot "+side+" stays on peg, error "+str(sole.distance_to(pegs[index].global_position)))

func capture(bike: WarVehicle, label: String) -> void:
	var directory := OS.get_environment("MOTO_QA_DIR")
	if DisplayServer.get_name()=="headless" or directory.is_empty(): return
	for ui in root.find_children("*","CanvasLayer",true,false): ui.hide()
	for control in root.find_children("*","Control",true,false): control.hide()
	var camera := Camera3D.new()
	game.world_root.add_child(camera)
	camera.global_position = bike.to_global(Vector3(3.15,2.1,-2.35 if label=="right" else 2.35))
	camera.look_at(bike.global_position+Vector3.UP)
	camera.fov = 44.
	camera.make_current()
	await create_timer(.2).timeout
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(directory.path_join("motorbike-"+label+".png"))==OK,"capture "+label)
	camera.queue_free()

func run() -> void:
	game = load("res://tests/br_completion_fixture.gd").new()
	game.set_meta("br_host",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.flat_world()
	game.online = false
	var bike := BIKE.new()
	bike.kind = "bike_0"
	bike.vehicle_id = "v_bike_qa"
	bike.position.y = -.09
	game.world_root.add_child(bike)
	var driver := occupant(1)
	var passenger := occupant(2)
	check(bike.allocate_seat(1)==0 and bike.allocate_seat(2)==1 and bike.allocate_seat(3)==-1,"two distinct seat slots")
	check(bike.wheels.size()==2 and bike.wheels[1].get_parent()==bike.handlebar,"independent front and rear pivots")
	if DisplayServer.get_name()!="headless":
		var mesh_count := bike.model.find_children("*","MeshInstance3D",true,false).size()
		check(mesh_count>=8 and mesh_count<=25,"model detail is grouped into "+str(mesh_count)+" mesh instances")
	bike.rotation = Vector3(.10,.66,.09)
	bike.heading = 0.
	bike.speed = 16.
	for turn: float in [1.,-1.]:
		bike.steering = turn
		for _frame in 90: bike.animate_running_gear(1./60.)
		check((bike.handlebar.basis*Vector3.FORWARD).x*turn>.30,"front wheel points in the requested direction")
		check((bike.model.basis*Vector3.UP).x*turn>.27,"bike banks toward the inside of the turn")
		check(absf(bike.bank)<=bike.MAX_BANK,"bike bank is bounded")
		for actor: GamePlayer in [driver,passenger]:
			actor.vehicle_id = bike.vehicle_id
			actor.global_position = bike.to_global(bike.seat_position(bike.seat_of(actor.peer_id)))
			bike.pose_rider(actor)
		check(absf(angle_difference(driver.rotation.y,bike.rotation.y))<.001,"rider follows presented yaw")
		check(not driver.view_root.visible,"rider has no duplicate first-person arms")
		check_contact(driver,bike.driver_seat,bike.driver_grips,bike.driver_pegs,"driver")
		check_contact(passenger,bike.pillion_seat,bike.pillion_grips,bike.pillion_pegs,"passenger")
		await capture(bike,"right" if turn>0 else "left")
	bike.speed = 0.
	bike.steering = 0.
	for _frame in 100: bike.animate_running_gear(1./60.)
	check(bike.model.rotation.length()<.005 and absf(bike.handlebar.rotation.y)<.005,"bike settles upright at rest")
	driver.vehicle_id = ""
	BIKE.reset_rider_pose(driver)
	check(driver.body_root.rotation.is_zero_approx() and absf(driver.body_root.position.z)<.001,"dismount restores infantry body transform")
	check(driver.stance.leg_parts.L.knee.rotation.is_zero_approx(),"dismount restores knee pose")
	game.free()
	await process_frame
	if "--war-moto-flow" in OS.get_cmdline_user_args():
		await check_war_boarding()
	print("MOTORBIKE_VISUAL_RIDER %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func check_war_boarding() -> void:
	var war := WarGame.new()
	war.set_meta("war_host",true)
	war.set_meta("war_test",true)
	war.set_meta("test_mode",true)
	root.add_child(war)
	war.set_physics_process(false)
	var manager := war.vehicle_system as WarVehicles
	manager.set_physics_process(false)
	manager.set_process(false)
	war.war_fx.set_physics_process(false)
	var riders: Array[WarPlayer] = []
	for peer in [701,702]:
		var actor := war._spawn_player(peer,false,false,Vector3.ZERO) as WarPlayer
		actor.set_physics_process(false)
		actor.deployed=true
		actor.hp=100.
		war.members[peer]={"team":0,"role":"soldier","deployed":true,"vehicle":"","vehicle_seat":-1,"vehicle_role":"","charges":3,"shield":0.,"gadget":"rpg","pending":{}}
		war._register_match_stat(actor)
		riders.append(actor)
	for team in [0,1]:
		var bike: WarVehicle = manager.vehicles["v_bike_%d_0"%team]
		bike.position = WarTerrain.point(-450,280)
		bike.rotation = Vector3.ZERO
		await physics_frame
		await physics_frame
		for actor in riders:
			actor.apply_identity(team,"soldier")
			war.members[actor.peer_id].team=team
			actor.position=WarTerrain.point(-453.9,280)+Vector3.UP*.2
			manager.command_for(actor.peer_id,"enter",{"id":bike.vehicle_id})
		check(bike.driver==701 and bike.seat_of(702)==1,"War team %d boards both seats" % team)
		bike.speed=12.
		bike.steering=1.
		bike.animate_running_gear(.2)
		manager.sync_occupants(bike)
		check(riders[1].body_root.global_basis.x.distance_to(bike.model.global_basis.x)<.005,
			"War team %d presents the passenger on the banked bike" % team)
		check(manager.release(701,true) and bike.driver==702 and riders[0].body_root.rotation.is_zero_approx(),
			"War team %d promotes passenger and resets the dismounted pose" % team)
		manager.reset_occupancy()
		check(bike.seats.is_empty() and riders[1].body_root.rotation.is_zero_approx(),
			"War team %d round reset clears the seated pose" % team)
	war.free()
	await process_frame
