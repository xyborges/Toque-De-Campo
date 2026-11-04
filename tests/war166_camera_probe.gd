extends SceneTree
var failures: Array[String]=[]
var checks:=0
var game: WarGame
var actor: WarPlayer
var label:="166-before"
var poses: Array[Dictionary]=[]
var saved_flash:=false
var pending_flash:=false
func capture_flash() -> void:
	if pending_flash and not saved_flash and not output.is_empty():
		saved_flash=true
		root.get_texture().get_image().save_png(output.path_join("war166-camera-flash-"+label+".png"))
var sampling:=false
var fps:=144
var view_refreshes:=0
func record_pose() -> void:
	if not sampling or not is_instance_valid(actor) or not is_instance_valid(actor.shoulder_arm): return
	pending_flash=actor.camera.position.z<.1 and actor.shoulder_arm.get_hit_length()>1
	poses.append({"frame":Engine.get_process_frames(),"physics":Engine.get_physics_frames(),"camera_z":actor.camera.position.z,"hit":actor.shoulder_arm.get_hit_length(),"eye_distance":actor.camera.global_position.distance_to(actor.camera_pivot.global_position),"visible_body":actor.body_root.visible,"fpp":actor.view_root.visible,"parent":str(actor.camera.get_parent().name),"third_person":game.third_person,"iron":actor.iron_sights})
var output:=""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps="): fps=int(arg.trim_prefix("--fps="))
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg.begins_with("--report-root="): output=arg.trim_prefix("--report-root=")
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func run() -> void:
	Engine.max_fps=fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.frame_pre_draw.connect(record_pose)
	RenderingServer.frame_post_draw.connect(capture_flash)
	game=WarGame.new();game.offline_operation=true;root.add_child(game)
	var deadline:=Time.get_ticks_msec()+35000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: quit(1);return
	game.request_deploy(0,"soldier","fal","stinger","base")
	deadline=Time.get_ticks_msec()+15000
	while game.players.size()<12 and Time.get_ticks_msec()<deadline: await process_frame
	game.bot_director.stop();actor=game.local_player
	game.third_person=true;game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;actor._update_view()
	await process_frame
	check(game.gameplay_input_allowed() and actor.camera.current,"normal War offline accepts native movement and mouse look")
	# A physical wall retracts the actual SpringArm. Freeze only locomotion
	# during this contact check, so its solver cannot push the body away.
	actor.set_physics_process(false)
	var wall:=StaticBody3D.new();wall.collision_layer=1
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,3,.08);collider.shape=box;wall.add_child(collider);game.world_root.add_child(wall)
	wall.global_position=actor.camera_pivot.to_global(Vector3(0,0,.24));wall.rotation.y=actor.yaw
	await physics_frame;await physics_frame
	actor._update_camera_collision(0);actor._update_grenade_pose()
	check(actor.camera_close and actor.shoulder_arm.get_hit_length()<.42,"a real wall retracts the shoulder SpringArm into the reported short-camera state")
	var resurrected:=actor.view_root.visible
	check(not resurrected,"the post-collision animation cannot resurrect an FPP clone in TPP")
	RenderingServer.force_draw(false)
	if not output.is_empty(): root.get_texture().get_image().save_png(output.path_join("war165-movement-"+label+"-near.png"))
	wall.queue_free();actor.set_physics_process(true);actor._update_view();await physics_frame
	sampling=true
	var leaks:=0;var distance_value:=0.;var yaw_start:=actor.yaw;var yaw_range:=0.;var previous:=actor.position
	Input.action_press("move_forward")
	for frame in 420:
		var event:=InputEventMouseMotion.new();event.relative=Vector2(14 if frame<210 else -14,sin(frame*.025)*1.0)
		Input.parse_input_event(event)
		if frame%53==0: actor._update_view();view_refreshes+=1
		await process_frame
		if actor.view_root.visible: leaks+=1
		distance_value+=actor.position.distance_to(previous);previous=actor.position
		yaw_range=maxf(yaw_range,absf(actor.yaw-yaw_start))
		if frame in [105,210,315] and not output.is_empty():
			RenderingServer.force_draw(false);root.get_texture().get_image().save_png(output.path_join("war165-movement-"+label+"-"+str(frame)+".png"))
	sampling=false
	Input.action_release("move_forward")
	check(distance_value>10 and yaw_range>TAU*.9,"player walks and turns through a full horizontal field of view on the actual War map")
	check(leaks==0 and game.third_person,"no FPP presentation appears during movement and horizontal looking")
	check(actor.camera.current and not game.death_view.active,"the personal shoulder camera remains active")
	var bad_frames:=0;var max_error:=0.0
	for pose: Dictionary in poses:
		if pose.third_person and not pose.iron and float(pose.hit)>1:
			if float(pose.camera_z)<.1: bad_frames+=1
			max_error=maxf(max_error,absf(float(pose.camera_z)-float(pose.hit)))
	check(bad_frames==0,"every rendered open-terrain TPP frame keeps the solved shoulder distance, including between physics ticks")
	check(max_error<.025,"camera translation agrees with the actual SpringArm solution after mouse/view refreshes")
	var report: Dictionary={"label":label,"checks":checks,"failures":failures,"fpp_visible_after_collision_pose":resurrected,"fpp_frames":leaks,"distance_walked":distance_value,"yaw_range_degrees":rad_to_deg(yaw_range),"frames":420,"native":true,"poses":poses,"fps_cap":fps,"eye_frames":bad_frames,"maximum_arm_error":max_error,"view_refreshes":view_refreshes}
	if not output.is_empty():
		var file:=FileAccess.open(output.path_join("war165-movement-"+label+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	var summary:=report.duplicate();summary.erase("poses");print(JSON.stringify(summary));game.show_menu();game.queue_free();await process_frame;await process_frame;await create_timer(.4).timeout
	quit(0 if failures.is_empty() or label.contains("before") else 1)
