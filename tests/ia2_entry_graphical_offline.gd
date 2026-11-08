extends SceneTree

# Graphical 1080p first-30-seconds probe, with 28 local bots.
# NOT network client or substitute for ENet authoritative replication.
var operation: String="favela"
var run_label: String="offline-graphical"
var frame_ms: Array[float]=[]
var gpu_ms: Array[float]=[]
var phys_ms: Array[float]=[]
var pipeline_start: Dictionary={}
var pipeline_end: Dictionary={}
var focus_lost:=0
var spikes50:=0
var spikes100:=0
var max_ticks:=0
var multistep:=0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--operation="):operation=arg.trim_prefix("--operation=")
		if arg.begins_with("--label="):run_label=arg.trim_prefix("--label=")
	_run.call_deferred()

func _stats(data: Array[float]) -> Dictionary:
	if data.is_empty():return {}
	var sorted:=data.duplicate()
	sorted.sort()
	var total:=0.
	for value in data:total+=value
	var n:=sorted.size()
	return {"count":n,"mean":total/n,"p50":sorted[mini(n-1,ceili(.50*n)-1)],
		"p95":sorted[mini(n-1,ceili(.95*n)-1)],
		"p99":sorted[mini(n-1,ceili(.99*n)-1)],"max":sorted[-1]}

func _pipelines() -> Dictionary:
	return {"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
		"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		"specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}

func _run() -> void:
	if DisplayServer.get_name()=="headless" or operation not in ["favela","afghan"]:
		print("IA2_ENTRY_GRAPHICS_INVALID_DISPLAY");quit(2);return
	Engine.max_fps=0
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size=Vector2i(1920,1080)
	root.scaling_3d_scale=1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure()
	GameOptions.values.merge(GameOptions.PRESETS["Médio"],true)
	GameOptions.values["scale"]=1.0
	GameOptions.values["fps"]=0
	GameOptions.values["vsync"]=false
	var started:=Time.get_ticks_usec()
	var game:=WarGame.new()
	game.operation_id=operation
	game.offline_operation=true
	game.offline_participants=29
	game.set_meta("test_mode",true)
	game.set_meta("war_test",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+180000
	while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:
		print("IA2_ENTRY_GRAPHICS_TIMEOUT world");quit(3);return
	var ready_ms=(Time.get_ticks_usec()-started)*.001
	var ready_unix_ms=int(Time.get_unix_time_from_system()*1000)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	DisplayServer.window_move_to_foreground()
	pipeline_start=_pipelines()
	game.request_deploy(0,"soldier","fal","stinger","base")
	var bots_at_start=game.bot_director.bots.size() if is_instance_valid(game.bot_director) else -1
	var window_start:=Time.get_ticks_usec()
	var previous_usec:=window_start
	var previous_ticks:=Engine.get_physics_frames()
	while Time.get_ticks_usec()-window_start<30000000:
		await process_frame
		var now:=Time.get_ticks_usec()
		var frame=(now-previous_usec)*.001
		frame_ms.append(frame)
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		if frame>50.:spikes50+=1
		if frame>100.:spikes100+=1
		if not DisplayServer.window_is_focused():focus_lost+=1
		var steps:=Engine.get_physics_frames()-previous_ticks
		max_ticks=maxi(max_ticks,steps)
		if steps>1:multistep+=1
		previous_ticks=Engine.get_physics_frames()
		previous_usec=now
	pipeline_end=_pipelines()
	var bots_observed=game.bot_director.bots.size() if is_instance_valid(game.bot_director) else -1
	var deployed:=0
	if is_instance_valid(game.bot_director):
		for bot_id in game.bot_director.bots:
			var actor=game.players.get(bot_id) as WarPlayer
			if is_instance_valid(actor) and actor.deployed:deployed+=1
	var result: Dictionary={"label":run_label,"operation":operation,
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"screen":root.get_texture().get_size(),"render_scale":root.scaling_3d_scale,
		"join_ready_ms":ready_ms,"join_unix_ms":ready_unix_ms,
		"sample_started_unix_ms":int(Time.get_unix_time_from_system()*1000.)-30000,
		"flags":{"housing":OS.get_environment("TDC_IA2_HOUSING_CACHE"),
		"terrain":OS.get_environment("TDC_IA2_TERRAIN_FACES")},
		"world_ms":game.world_build_ms,"bots_at_start":bots_at_start,
		"bots_end":bots_observed,"deployed_end":deployed,
		"frame_ms":_stats(frame_ms),"gpu_ms":_stats(gpu_ms),
		"physics_ms":_stats(phys_ms),"frames_over_50":spikes50,
		"frames_over_100":spikes100,"max_ticks":max_ticks,
		"multi_tick_frames":multistep,"unfocused_frames":focus_lost,
		"pipeline_start":pipeline_start,"pipeline_end":pipeline_end}
	print("IA2_ENTRY_GRAPHICS ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if bots_observed==28 and deployed>=26 and frame_ms.size()>100 else 2)
