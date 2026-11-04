extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func run() -> void:
	game=WarGame.new();game.offline_operation=true;root.add_child(game)
	var deadline:=Time.get_ticks_msec()+35000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: failures.append("offline startup");finish();return
	game.request_deploy(0,"soldier","fal","stinger","base")
	deadline=Time.get_ticks_msec()+12000
	while game.players.size()<WarRules.OFFLINE_PARTICIPANTS and Time.get_ticks_msec()<deadline: await process_frame
	check(game.players.size()==WarRules.OFFLINE_PARTICIPANTS,"normal offline War deploys its configured population")
	var positions: Dictionary={}
	for id in game.players: positions[id]=game.players[id].position
	await create_timer(1.5).timeout
	var moved:=0
	for id in game.players:
		if id!=1 and game.players[id].position.distance_to(positions.get(id,game.players[id].position))>.4: moved+=1
	check(moved>=8,"offline bots move on the revised terrain")
	game.bot_director.stop();var actor:=game.local_player as WarPlayer
	game.third_person=true;game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;actor._update_view()
	for point in [Vector2(-500,-30),Vector2(0,65),Vector2(-170,-20)]:
		actor.position=WarTerrain.point(point.x,point.y)+Vector3.UP*.12;actor.velocity=Vector3.ZERO;actor.yaw=0;actor.rotation.y=0
		await physics_frame;Input.action_press("move_forward")
		for frame in 50: await physics_frame
		Input.action_release("move_forward")
		var terrain_height:=WarTerrain.height_at(actor.position.x,actor.position.z)
		check(actor.position.is_finite() and actor.position.y>=terrain_height-.12 and actor.position.y<terrain_height+2,"player remains on physical terrain while walking: "+str(point))
		check(not actor.view_root.visible,"TPP walking does not display first-person arms")
	var manager:=game.vehicle_system as WarVehicles
	for kind in WarRules.VEHICLES:
		var vehicle:=manager.vehicles["v_"+str(kind)] as WarVehicle
		var x: float={"guarani":-430.,"bmp2":-120.,"abrams":110.,"t90":430.}[kind]
		var z:=25*sin(x*.009);vehicle.position=WarTerrain.point(x,z)+Vector3.UP*.10;vehicle.speed=0;vehicle.velocity=Vector3.ZERO
		var direction:=Vector3(1,0,25*.009*cos(x*.009)).normalized();vehicle.heading=atan2(-direction.x,-direction.z);vehicle.rotation=Vector3(0,vehicle.heading,0)
		actor.apply_identity(vehicle.team,"soldier");game.members[1].team=vehicle.team
		actor.position=WarTerrain.point(x-3.8,z)+Vector3.UP*.15;actor.velocity=Vector3.ZERO
		await physics_frame;manager.command_for(1,"enter",{"id":vehicle.vehicle_id})
		check(actor.vehicle_id==vehicle.vehicle_id and vehicle.driver==1,"operator boards on the actual road: "+str(kind))
		if actor.vehicle_id!=vehicle.vehicle_id: continue
		await process_frame;await process_frame;manager.vehicle_view.external=true;manager.orbit_pitch=-.17;manager.orbit_yaw=vehicle.heading
		var start:=vehicle.position;var minimum_gap:=100.;var maximum_gap:=-100.
		Input.action_press("move_forward")
		for frame in 120:
			await physics_frame
			var gap:=vehicle.position.y-WarTerrain.height_at(vehicle.position.x,vehicle.position.z);minimum_gap=minf(minimum_gap,gap);maximum_gap=maxf(maximum_gap,gap)
		Input.action_release("move_forward")
		var distance_value:=vehicle.position.distance_to(start)
		check(distance_value>5 and minimum_gap>-.15 and maximum_gap<2.,"vehicle drives over relief without falling through or floating: "+str(kind))
		measurements.append({"kind":kind,"distance":distance_value,"ground_gap_min":minimum_gap,"ground_gap_max":maximum_gap})
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/war-map169-drive-"+str(kind)+".png")
		manager.release(1,true);manager._respawn_vehicle(vehicle)
	finish()
func finish() -> void:
	Input.action_release("move_forward")
	NavalStorage.write_json("res://tests/war-map169-gameplay-results.json",{"checks":checks,"failures":failures,"measurements":measurements})
	print(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}));game.show_menu();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
