extends SceneTree
const PROBE=preload("res://scripts/pose_cost_probe.gd")
var operation:="favela"
var label:="smoke"
var duration:=20.
var warmup:=8.
var game: WarGame
var frame_times: Array[float]=[]
var physics_times: Array[float]=[]
var frame_trace: Array=[]
var failures: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pose-map="):operation=arg.trim_prefix("--pose-map=")
		elif arg.begins_with("--tag="):label=arg.trim_prefix("--tag=")
		elif arg.begins_with("--seconds="):duration=float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--warmup="):warmup=float(arg.trim_prefix("--warmup="))
	run.call_deferred()
func stats(values: Array[float]) -> Dictionary:
	if values.is_empty():return {}
	var a:=values.duplicate();a.sort();var total:=0.
	for v in a:total+=v
	return {"mean_ms":total/a.size(),"p99_ms":a[maxi(0,ceili(a.size()*.99)-1)],"max_ms":a[-1],"samples":a.size()}
func run() -> void:
	var visual:=DisplayServer.get_name()!="headless"
	seed(712907)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size=Vector2i(1920,1080);root.scaling_3d_scale=1.
	Engine.max_fps=0 if visual else 60
	if visual:DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure();GameOptions.values.merge(GameOptions.PRESETS[GameOptions.PRESETS.keys()[1]],true)
	GameOptions.values.merge({"scale":1.,"vsync":false,"fps":0},true)
	# Source-only perf fixture: map validation hash is not a production release.
	preload("res://scripts/maps/definition.gd").checked[operation]=true
	game=WarGame.new();game.operation_id=operation;game.offline_operation=true;game.offline_participants=29
	game.set_meta("test_mode",true);game.set_meta("war_mode",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+150000
	while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:failures.append("join timeout");await finish({});return
	game.request_deploy(0,"soldier","fal",WarRules.launcher_for_team(0),"base")
	deadline=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(game.bot_director) and game.bot_director.bots.size()==28 and game.local_player.deployed:break
	if not is_instance_valid(game.bot_director) or game.bot_director.bots.size()!=28:failures.append("not 28 bots");await finish({});return
	game.ui_focus.close_all()
	if visual:
		var camera:=Camera3D.new();camera.far=2200.;camera.fov=70.;game.world_root.add_child(camera)
		var point:=WarTerrain.point(-85.,-20.)
		camera.global_position=point+Vector3(-58,27,78);camera.look_at(point+Vector3.UP*1.5);camera.make_current()
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		DisplayServer.window_move_to_foreground()
	await create_timer(warmup).timeout
	if visual:
		if not DisplayServer.window_is_focused():DisplayServer.window_move_to_foreground();await create_timer(.75).timeout
		if RenderingServer.get_current_rendering_method()!="forward_plus":failures.append("not forward_plus")
		if Vector2i(root.get_texture().get_size())!=Vector2i(1920,1080):failures.append("not 1080p")
	if not failures.is_empty():await finish({});return
	PROBE.reset();PROBE.collecting=PROBE.enabled
	var diagnostics_before: Dictionary=game.bot_director.diagnostics.duplicate()
	var begin:=Time.get_ticks_usec();var start_epoch:=Time.get_unix_time_from_system()
	var first_tick:=Engine.get_physics_frames();var previous_tick:=first_tick;var last:=begin
	var focus_lost:=0;var min_bots:=28;var multi:=0;var max_tick:=0
	var population_samples: Array=[];var next_population:=begin
	print("POSE_WINDOW_BEGIN ",JSON.stringify({"unix":start_epoch,"ticks_usec":begin,"label":label,"pid":OS.get_process_id()}))
	while (Time.get_ticks_usec()-begin)*.000001<duration:
		await process_frame
		var now:=Time.get_ticks_usec();var tick:=Engine.get_physics_frames();var delta_ticks:=tick-previous_tick
		var frame_ms:=(now-last)*.001
		frame_times.append(frame_ms);physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		frame_trace.append([now,Time.get_unix_time_from_system(),frame_ms,delta_ticks,physics_times[-1],RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()) if visual else 0.])
		if delta_ticks>1:multi+=1
		max_tick=maxi(max_tick,delta_ticks)
		if visual and not DisplayServer.window_is_focused():focus_lost+=1
		min_bots=mini(min_bots,game.bot_director.bots.size())
		if now>=next_population:
			next_population=now+1000000
			var active:=0;var embarked:=0;var dead:=0
			for id in game.bot_director.bots:
				var actor:=game.players[id] as WarPlayer
				if actor.deployed:active+=1
				if actor.hp<=0:dead+=1
				if not actor.vehicle_id.is_empty():embarked+=1
			population_samples.append([now,active,embarked,dead])
		last=now;previous_tick=tick
	PROBE.collecting=false
	var end_epoch:=Time.get_unix_time_from_system();var total_ticks:=Engine.get_physics_frames()-first_tick
	print("POSE_WINDOW_END ",JSON.stringify({"unix":end_epoch,"ticks_usec":Time.get_ticks_usec(),"label":label}))
	var deltas: Dictionary={}
	for key in game.bot_director.diagnostics:deltas[key]=int(game.bot_director.diagnostics[key])-int(diagnostics_before.get(key,0))
	if focus_lost>0:failures.append("focus lost")
	if min_bots!=28:failures.append("bot population")
	var teams:=[0,0]
	for id in game.bot_director.bots:teams[int(game.bot_director.bots[id].team)]+=1
	if teams!=[14,14]:failures.append("team population")
	if not PROBE.stack.is_empty():failures.append("unclosed probe scopes")
	set_meta("population_samples",population_samples)
	await finish({"visual":visual,"enabled":PROBE.enabled,"map":operation,"window_unix":[start_epoch,end_epoch],"duration_s":(last-begin)*.000001,"frame":stats(frame_times),"physics":stats(physics_times),"fps":1000./stats(frame_times).get("mean_ms",INF),"ticks":total_ticks,"tick_hz":total_ticks/maxf(.001,(last-begin)*.000001),"multi_tick_frames":multi,"max_ticks_per_frame":max_tick,"focus_lost":focus_lost,"bots":min_bots,"combat":deltas,"probe":PROBE.report(total_ticks,frame_times.size()),"frame_columns":["ticks_usec","unix","frame_ms","physics_ticks","engine_physics_ms","gpu_ms"],"frame_trace":frame_trace})
func finish(result: Dictionary) -> void:
	result.label=label;result.failures=failures;result.valid=failures.is_empty()
	result.code_commit=OS.get_environment("POSE_CODE_COMMIT")
	result.population_samples=get_meta("population_samples",[])
	var out:=ProjectSettings.globalize_path("res://work/pose-scopes-20261107")
	DirAccess.make_dir_recursive_absolute(out)
	var file:=FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result));file.close()
	print("POSE_SCOPES_RESULT ",JSON.stringify({"label":label,"valid":result.valid,"frames":frame_times.size(),"failure":failures}))
	if is_instance_valid(game):game.queue_free()
	await process_frame;quit(0 if failures.is_empty() else 2)
