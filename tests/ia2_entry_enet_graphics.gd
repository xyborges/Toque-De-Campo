extends SceneTree

# Real WarGame over ENet/DTLS: one headless authority plus two graphical clients.
# All roles use isolated QA account storage. Run via work/entrada-mapas/run-enet.py.
var role: String="server"
var operation: String="favela"
var label: String="enet"
var game: WarGame
var warnings: Array[String]=[]
var frame_records: Array[Dictionary]=[]
var frame_ms: Array[float]=[]
var physics_ms: Array[float]=[]
var gpu_ms: Array[float]=[]
var pipeline_begin: Dictionary={}
var pipeline_end: Dictionary={}
var max_tick_steps:=0
var multistep_frames:=0
var spike_50:=0
var spike_100:=0
var unfocused_frames:=0
var bot_states_ready_ms: float=-1
var join_ready_ms: float=-1
var join_unix_ms:=0
var began_usec:=0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):role=argument.trim_prefix("--role=")
		if argument.begins_with("--operation="):operation=argument.trim_prefix("--operation=")
		if argument.begins_with("--label="):label=argument.trim_prefix("--label=")
	_run.call_deferred()

func _pct(values: Array[float]) -> Dictionary:
	if values.is_empty():return {}
	var v:=values.duplicate()
	v.sort()
	var total:=0.0
	for number: float in values:total+=number
	var n:=v.size()
	return {"n":n,"mean":total/n,"p50":v[mini(n-1,ceili(n*.50)-1)],
		"p95":v[mini(n-1,ceili(n*.95)-1)],
		"p99":v[mini(n-1,ceili(n*.99)-1)],"max":v[-1]}

func _pipeline() -> Dictionary:
	return {
		"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
		"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		"specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
	}

func _save_and_exit() -> void:
	var bot_members:=0
	for member: Dictionary in game.members.values():
		if bool(member.get("bot",false)):bot_members+=1
	var result: Dictionary={
		"label":label,"role":role,"operation":operation,
		"valid_connection":game.online,"join_ready":game.join_ready,
		"join_ready_ms":join_ready_ms,"join_unix_ms":join_unix_ms,
		"bot_states_ready_ms":bot_states_ready_ms,
		"bots_seen":bot_members,"remote_player_count":game.players.size(),
		"members":game.members.size(),
		"authority":game.multiplayer.is_server(),
		"flags":{"housing":OS.get_environment("TDC_IA2_HOUSING_CACHE"),"terrain":OS.get_environment("TDC_IA2_TERRAIN_FACES")},
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"gpu":RenderingServer.get_video_adapter_name(),
		"frame_ms":_pct(frame_ms),"physics_ms":_pct(physics_ms),
		"gpu_ms":_pct(gpu_ms),"frames_over_50ms":spike_50,"frames_over_100ms":spike_100,
		"max_physics_steps_per_frame":max_tick_steps,"multistep_frames":multistep_frames,
		"unfocused_frames":unfocused_frames,"pipeline_start":pipeline_begin,
		"pipeline_end":pipeline_end,"frames":frame_records,"warnings":warnings,
		"world_build_ms":game.world_build_ms,
		"finished_unix_ms":int(Time.get_unix_time_from_system()*1000.0)
	}
	var path: String="res://work/entrada-mapas/enet/"+label+"-"+role+".json"
	var absolute_path:=ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file:=FileAccess.open(absolute_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result))
		file.close()
	print("IA2_ENET_METRICS ",JSON.stringify(result.duplicate(true).merged({"frames":[]},true)))
	game.queue_free()
	await process_frame
	quit(0 if warnings.is_empty() and join_ready_ms>0 else 2)

func _run() -> void:
	if role not in ["server","client1","client2"] or operation not in ["favela","afghan"]:
		push_error("IA2_ENET_INVALID_ROLE");quit(3);return
	if role=="client1":
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
	began_usec=Time.get_ticks_usec()
	game=WarGame.new()
	game.operation_id=operation
	game.set_meta("test_mode",true)
	game.set_meta("war_test",true)
	if role=="server":
		# Local isolated LAN authority: never request production login tickets.
		# Test role only; does not touch launcher, services or production server.
		game.set_meta("online_bots_test",true)
	game.set_meta("war_visual_preview",true)
	root.add_child(game)
	game.nickname_input.text="ia2-"+role
	game.address_input.text="127.0.0.1"
	if role=="server":
		game.host_game("pvp")
		await _run_server()
	else:await _run_client()
	await _save_and_exit()

func _run_server() -> void:
	var deadline:=Time.get_ticks_msec()+120000
	while not (game.online and game.multiplayer.is_server()) and Time.get_ticks_msec()<deadline:await process_frame
	if not game.online:
		warnings.append("authority_not_listening")
		return
	join_ready_ms=(Time.get_ticks_usec()-began_usec)*.001
	join_unix_ms=int(Time.get_unix_time_from_system()*1000.0)
	print("IA2_ENET_HOST_READY ",join_unix_ms)
	var sample_start:=Time.get_ticks_usec()
	var prev_usec:=sample_start
	var prev_steps:=Engine.get_physics_frames()
	while Time.get_ticks_usec()-sample_start<125000000:
		await process_frame
		var now:=Time.get_ticks_usec()
		var delta: float=(now-prev_usec)*.001
		if delta>50:spike_50+=1
		if delta>100:spike_100+=1
		frame_ms.append(delta)
		var phys: float=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		physics_ms.append(phys)
		var steps:=Engine.get_physics_frames()-prev_steps
		max_tick_steps=maxi(steps,max_tick_steps)
		if steps>1:multistep_frames+=1
		frame_records.append({"t":int(Time.get_unix_time_from_system()*1000.0),"ms":delta,"physics_ms":phys,"ticks":steps})
		prev_usec=now
		prev_steps=Engine.get_physics_frames()
		if FileAccess.file_exists("res://work/entrada-mapas/enet/STOP_"+label):break

func _run_client() -> void:
	await game.join_game("pvp")
	var deadline:=Time.get_ticks_msec()+120000
	while not (game.join_ready and is_instance_valid(game.local_player)) and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:
		warnings.append("join_ready_timeout")
		return
	join_ready_ms=(Time.get_ticks_usec()-began_usec)*.001
	join_unix_ms=int(Time.get_unix_time_from_system()*1000.0)
	print("IA2_ENET_CLIENT_READY ",role," ",join_unix_ms)
	var team:=0 if role=="client1" else 1
	game.request_deploy(team,"soldier","fal" if team==0 else "ak",WarRules.launcher_for_team(team),"base")
	game.ui_focus.close_all()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	DisplayServer.window_move_to_foreground()
	pipeline_begin=_pipeline()
	var sample_start:=Time.get_ticks_usec()
	var prev_usec:=sample_start
	var prev_steps:=Engine.get_physics_frames()
	var limit:=66000000 if role=="client1" else 31000000
	while Time.get_ticks_usec()-sample_start<limit:
		await process_frame
		var now:=Time.get_ticks_usec()
		var delta: float=(now-prev_usec)*.001
		frame_ms.append(delta)
		var phys: float=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		physics_ms.append(phys)
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		var steps:=Engine.get_physics_frames()-prev_steps
		max_tick_steps=maxi(steps,max_tick_steps)
		if steps>1:multistep_frames+=1
		if delta>50:spike_50+=1
		if delta>100:spike_100+=1
		if not DisplayServer.window_is_focused():unfocused_frames+=1
		if bot_states_ready_ms<0 and game.players.size()>=29:
			bot_states_ready_ms=(now-began_usec)*.001
			print("IA2_ENET_28_BOTS_READY ",role," ",bot_states_ready_ms)
		frame_records.append({"t":int(Time.get_unix_time_from_system()*1000.0),"ms":delta,
			"physics_ms":phys,"gpu_ms":gpu_ms[-1],"ticks":steps,"actors":game.players.size()})
		prev_usec=now
		prev_steps=Engine.get_physics_frames()
	pipeline_end=_pipeline()
	if bot_states_ready_ms<0:warnings.append("missing_remote_bots")
