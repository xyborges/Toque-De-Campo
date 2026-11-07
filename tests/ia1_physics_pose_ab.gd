extends SceneTree
# A/B diagnostic ONLY. A = WarPlayer physics/poses intact.
# B = stop bot WarPlayer._physics_process while keeping bot director
# and GameStepMotion.move active. Never a shipping optimization:
# it freezes hitbox pose, reload/timers and animation progression.
var optimized := false
var label := "diagnostic"
var duration := 14.0
var warmup := 6.0
var game: WarGame
var frames: Array[float] = []
var physics: Array[float] = []
var ticks: Array[int] = []
var failures: Array[String] = []
var focus_lost := 0
var min_bots := 28
var travel := 0.0
var movement_checks := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--disabled-bot-physics="): optimized = arg.trim_prefix("--disabled-bot-physics=") == "1"
		elif arg.begins_with("--tag="): label = arg.trim_prefix("--tag=")
		elif arg.begins_with("--seconds="): duration = clampf(float(arg.trim_prefix("--seconds=")),10.0,40.0)
	_start.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted: total+=v
	var n := sorted.size()
	return {"mean_ms":total/n, "p95_ms":sorted[mini(n-1,ceili(n*.95)-1)],
		"p99_ms":sorted[mini(n-1,ceili(n*.99)-1)],"max_ms":sorted[-1],"samples":n}

func _start() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GRAPHICS_REQUIRED")
		quit(3)
		return
	seed(712907)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size=Vector2i(1920,1080)
	root.scaling_3d_scale=1.0
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure()
	GameOptions.values.merge(GameOptions.PRESETS[GameOptions.PRESETS.keys()[1]],true)
	GameOptions.values["scale"]=1.0
	GameOptions.values["vsync"]=false
	GameOptions.values["fps"]=0
	game=WarGame.new()
	game.operation_id="favela"
	game.offline_operation=true
	game.offline_participants=29
	game.set_meta("test_mode",true)
	game.set_meta("war_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:
		failures.append("join_ready_timeout")
		_finish()
		return
	game.request_deploy(0,"soldier","fal",WarRules.launcher_for_team(0),"base")
	deadline=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if not is_instance_valid(game.bot_director) or game.bot_director.bots.size()!=28:continue
		var ready:=0
		for id in game.bot_director.bots:
			var actor:=game.players.get(id) as WarPlayer
			if is_instance_valid(actor) and actor.deployed:ready+=1
		if ready==28 and is_instance_valid(game.local_player) and game.local_player.deployed:break
	var actors: Array[WarPlayer]=[]
	var teams:=[0,0]
	if is_instance_valid(game.bot_director):
		for id in game.bot_director.bots:
			var actor:=game.players.get(id) as WarPlayer
			if is_instance_valid(actor) and actor.deployed:
				actors.append(actor)
				teams[int(game.bot_director.bots[id].team)]+=1
	if actors.size()!=28 or teams!=[14,14]:
		failures.append("population_or_team_mismatch")
		_finish()
		return
	game.ui_focus.close_all()
	var camera:=Camera3D.new()
	camera.far=2200.0
	camera.fov=70.0
	game.world_root.add_child(camera)
	var point:=WarTerrain.point(-85.,-20.)
	camera.global_position=point+Vector3(-58,27,78)
	camera.look_at(point+Vector3.UP*1.5)
	camera.make_current()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	DisplayServer.window_move_to_foreground()
	await create_timer(warmup).timeout
	if not DisplayServer.window_is_focused():
		DisplayServer.window_move_to_foreground()
		await create_timer(.75).timeout
	if Vector2i(root.get_texture().get_size()) != Vector2i(1920,1080):failures.append("not_1080p")
	if not is_equal_approx(root.scaling_3d_scale,1.0):failures.append("not_full_scale")
	if RenderingServer.get_current_rendering_method()!="forward_plus":failures.append("not_forward_plus")
	if not failures.is_empty():
		_finish()
		return
	# Reset probe AFTER warmup; this includes the normal movement solver.
	GameStepMotion.qa_enabled=true
	GameStepMotion.qa_reset()
	if optimized:
		for actor in actors:actor.set_physics_process(false)
	var previous: Dictionary={}
	for actor in actors: previous[actor.peer_id]=actor.global_position
	var last:=Time.get_ticks_usec()
	var begin:=last
	var previous_tick:=Engine.get_physics_frames()
	var multi:=0
	var max_tick:=0
	var gpu_peak:=0.0
	var next_sample:=Time.get_ticks_msec()+1000
	while (Time.get_ticks_usec()-begin)*.000001<duration:
		await process_frame
		var now:=Time.get_ticks_usec()
		frames.append((now-last)*.001)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		var step:=Engine.get_physics_frames()-previous_tick
		previous_tick=Engine.get_physics_frames()
		ticks.append(step)
		if step>1:multi+=1
		max_tick=maxi(max_tick,step)
		if not DisplayServer.window_is_focused():focus_lost+=1
		if is_instance_valid(game.bot_director):min_bots=mini(min_bots,game.bot_director.bots.size())
		gpu_peak=maxf(gpu_peak,RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		last=now
		if Time.get_ticks_msec()>next_sample:
			next_sample=Time.get_ticks_msec()+1000
			for actor in actors:
				if is_instance_valid(actor):
					travel+=actor.global_position.distance_to(previous.get(actor.peer_id,actor.global_position))
					previous[actor.peer_id]=actor.global_position
			movement_checks+=1
	var valid:=failures.is_empty() and min_bots==28 and focus_lost==0 and frames.size()>120 and movement_checks>4
	if GameStepMotion.qa_moves==0:valid=false;failures.append("movement_solver_inactive")
	var result: Dictionary={
		"label":label,"optimized":optimized,"valid":valid,"failures":failures,
		"bots":min_bots,"teams":teams,"focus_lost":focus_lost,"fps":1000.0/stats(frames).get("mean_ms",INF),
		"frame":stats(frames),"physics":stats(physics),"multi_ticks":multi,
		"total_frames":frames.size(),"max_ticks":max_tick,"gpu_peak_ms":gpu_peak,
		"movement_solver":GameStepMotion.qa_report(),"travel_sum_m":travel,
		"movement_checks":movement_checks,"renderer":RenderingServer.get_current_rendering_method(),
		"resolution":str(root.get_texture().get_size()),
		"caveat":"B freezes bot physics script/animation/hitbox pose; diagnostic upper bound, not a playable optimization"}
	var folder:=ProjectSettings.globalize_path("res://work/diag-physics-poses-20261107")
	DirAccess.make_dir_recursive_absolute(folder)
	var file:=FileAccess.open(folder.path_join(label+".json"),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result,"  "))
		file.close()
	print("PHYS_POSE_QA_RESULT "+JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if valid else 2)

func _finish() -> void:
	print("PHYS_POSE_QA_FAILED "+JSON.stringify(failures))
	if is_instance_valid(game):game.queue_free()
	await process_frame
	quit(3)
