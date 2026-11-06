extends SceneTree
# Reproducible, uncapped 1920x1080 Medium / 100% performance fixture.
# Saves measured data; never changes published servers or saved preferences.
var operation:="afghan"
var duration:=28.
var warmup:=8.
var label:="local"
var qa_presentation_only:=false
var qa_frozen_scene:=false
var brain_off:=false
var fps_cap:=0
var game: WarGame
var camera: Camera3D
var samples: Array[float]=[]
var gpu_samples: Array[float]=[]
var cpu_samples: Array[float]=[]
var physics_samples: Array[float]=[]
var spikes: Array[Dictionary]=[]
var max_draws:=0.
var max_vram:=0.
var max_nodes:=0.
var tick_deltas: Dictionary={}
var pipeline_total: Dictionary={"mesh":0,"surface":0,"draw":0,"specialization":0}
var pipeline_previous: Dictionary={}
var max_collision_pairs:=0.0
var pipeline_spike_count:=0
var slowdown_threshold:=33.

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--operation="):operation=WarOperation.normalize(argument.trim_prefix("--operation="))
		if argument.begins_with("--duration="):duration=clampf(float(argument.trim_prefix("--duration=")),10.,120.)
		if argument.begins_with("--warmup="):warmup=clampf(float(argument.trim_prefix("--warmup=")),4.,30.)
		if argument.begins_with("--label="):label=argument.trim_prefix("--label=")
		if argument=="--qa-presentation-only":qa_presentation_only=true
		if argument=="--ia2-brain-off":brain_off=true
		if argument=="--qa-frozen-scene":qa_frozen_scene=true;qa_presentation_only=true
		if argument.begins_with("--fps-cap="):fps_cap=maxi(0,int(argument.trim_prefix("--fps-cap=")))
	run.call_deferred()

func fail(reason: String) -> void:
	push_error("PERF_1080P_INVALID: "+reason)
	quit(2)

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():return {}
	var ordered:=values.duplicate();ordered.sort()
	var sum:=0.
	for v: float in values:sum+=v
	var n:=ordered.size()
	var worst_count:=maxi(1,ceili(n*.01))
	var worst_sum:=0.
	for index in range(n-worst_count,n):worst_sum+=ordered[index]
	return {"average_fps":1000.*n/sum,"one_percent_low_fps":1000.*worst_count/worst_sum,"mean_ms":sum/n,"p50_ms":ordered[mini(n-1,ceili(n*.50)-1)],"p95_ms":ordered[mini(n-1,ceili(n*.95)-1)],"p99_ms":ordered[mini(n-1,ceili(n*.99)-1)],"max_ms":ordered[-1],"samples":n}

# Offline does NOT send packets. This models 10 Hz payload serialization
# for one ready peer; it excludes RPC metadata, ENet/UDP, encryption and
# retransmission. Executed after FPS collection to prevent timing pollution.
func _estimate_replication() -> Dictionary:
	var actors: Array[WarPlayer]=[]
	for id: int in game.bot_director.bot_ids:
		var actor:=game.players.get(id) as WarPlayer
		if is_instance_valid(actor) and actor.deployed:actors.append(actor)
	var start:=Time.get_ticks_usec()
	var packets:=0
	var bytes_total:=0
	var states:=0
	for tick in 20:
		var batch: Array=[]
		for actor in actors:
			batch.append([actor.peer_id,actor.global_position,actor.yaw,actor.pitch,actor.weapon_id,actor.hp,actor.crouched,actor.life_id,actor.kills,actor.deaths,2 if actor.iron_sights else (1 if actor.aiming else 0),actor.lean,tick+1])
			if batch.size()>=4:
				bytes_total+=var_to_bytes([batch]).size()
				packets+=1
				states+=batch.size()
				batch=[]
		if not batch.is_empty():
			bytes_total+=var_to_bytes([batch]).size()
			packets+=1
			states+=batch.size()
	var time_ms:float=(Time.get_ticks_usec()-start)*.001
	return {"real_network_peers":0,"actual_network_bytes_per_sec":null,
		"mode":"offline serialization estimate only; 20 synthetic ticks at 10 Hz",
		"bots":actors.size(),"payload_bytes_per_sec_per_peer":bytes_total/2.0,
		"model_packets_per_sec_per_peer":packets/2.0,
		"model_states_per_sec_per_peer":states/2.0,
		"serialization_cpu_ms_per_second":time_ms/2.0}

func run() -> void:
	if DisplayServer.get_name()=="headless":fail("GPU benchmark requires a window");return
	seed(712907)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size=Vector2i(1920,1080)
	root.scaling_3d_scale=1.
	Engine.max_fps=fps_cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure()
	GameOptions.values.merge(GameOptions.PRESETS["Médio"],true)
	GameOptions.values["scale"]=1.0
	GameOptions.values["fps"]=0
	GameOptions.values["vsync"]=false
	game=preload("res://tests/ia2_cost_game.gd").new()
	game.operation_id=operation
	game.offline_operation=true
	game.offline_participants=29
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:fail("world not ready");return
	game.request_deploy(0,"soldier","fal","stinger","base")
	var bots_deadline:=Time.get_ticks_msec()+40000
	while (not is_instance_valid(game.bot_director) or game.bot_director.bots.size()<28) and Time.get_ticks_msec()<bots_deadline:await process_frame
	if not is_instance_valid(game.bot_director) or game.bot_director.bots.size()!=28:fail("not 28 bots");return
	var deployed:=0
	for id in game.bot_director.bots:
		var actor:=game.players.get(id) as WarPlayer
		if is_instance_valid(actor) and actor.deployed:deployed+=1
	if deployed!=28:fail("deployed="+str(deployed));return
	if qa_presentation_only:
		# Diagnostic upper bound only: characters stay deployed/rendered while
		# authority bots do not run pathfinding, vehicle driving or attacks.
		# This is NOT equivalent to a real network client.
		game.bot_director.set_physics_process(false)
	if qa_frozen_scene:
		game.set_physics_process(false)
		for other: GamePlayer in game.players.values():
			other.set_physics_process(false)
		if is_instance_valid(game.vehicle_system):game.vehicle_system.set_physics_process(false)
	game.ui_focus.close_all()
	camera=Camera3D.new()
	camera.far=2200.
	camera.fov=70.
	game.world_root.add_child(camera)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var origin:=Vector2(-85,-20) if operation=="favela" else (Vector2(-260,70) if operation=="afghan" else Vector2(-260,-115))
	var start_point:=WarTerrain.point(origin.x,origin.y)
	camera.global_position=start_point+Vector3(-58,27,78)
	camera.look_at(start_point+Vector3.UP*1.5)
	camera.make_current()
	await create_timer(warmup).timeout
	root.scaling_3d_scale=1.
	Engine.max_fps=fps_cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rendered: Vector2i=root.get_texture().get_size()
	var actual_scale:=root.scaling_3d_scale
	print("PERF_1080P_READY op=",operation," bots=",deployed," texture=",rendered," scale=",actual_scale," medium=",GameOptions.values.get("lod_quality")," renderer=",RenderingServer.get_current_rendering_method())
	if rendered!=Vector2i(1920,1080) or not is_equal_approx(actual_scale,1.0):fail("actual rendered resolution/scale mismatch");return
	if brain_off: game.bot_director.set("brain_off",true)
	IA2CostMetrics.start()
	GamePerformanceProbe.start({"operation":operation,"label":label})
	GameStepMotion.qa_reset()
	pipeline_previous={"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}
	var started:=Time.get_ticks_usec()
	var measurement_start_unix_ms:=int(Time.get_unix_time_from_system()*1000.)
	var focused_on_start:=DisplayServer.window_is_focused()
	var last_focus:=focused_on_start
	var focus_frames:=0
	var unfocused_frames:=0
	var focus_transitions:=0
	var focus_changes: Array[Dictionary]=[]
	var minimum_bots: int=game.bot_director.bots.size()
	var bot_population_checks:=0
	var next_population_sample:=started
	var last:=started
	var previous_physics:=Engine.get_physics_frames()
	while Time.get_ticks_usec()-started<duration*1000000.:
		await process_frame
		IA2CostMetrics.touch_frame()
		var now:=Time.get_ticks_usec()
		var elapsed:float=(now-started)*.000001
		var ms:float=(now-last)*.001;last=now
		var focused:=DisplayServer.window_is_focused()
		focus_frames+=1
		if not focused:unfocused_frames+=1
		if focused!=last_focus:
			focus_transitions+=1
			if focus_changes.size()<128:
				focus_changes.append({"elapsed_s":elapsed,"focused":focused})
			last_focus=focused
		if now>=next_population_sample:
			if is_instance_valid(game.bot_director):
				minimum_bots=mini(minimum_bots,game.bot_director.bots.size())
			else:
				minimum_bots=0
			bot_population_checks+=1
			next_population_sample=now+1000000
		var pipeline_now: Dictionary={"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}
		var new_pipelines: Dictionary={}
		for key: String in pipeline_total:
			var change:=maxi(0,int(pipeline_now[key])-int(pipeline_previous.get(key,0)))
			pipeline_total[key]=int(pipeline_total[key])+change
			new_pipelines[key]=change
		pipeline_previous=pipeline_now
		if ms>slowdown_threshold and (int(new_pipelines.mesh)+int(new_pipelines.surface)+int(new_pipelines.draw))>0:pipeline_spike_count+=1
		var tick_delta:=Engine.get_physics_frames()-previous_physics
		previous_physics=Engine.get_physics_frames()
		tick_deltas[tick_delta]=int(tick_deltas.get(tick_delta,0))+1
		samples.append(ms)
		gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		max_draws=maxf(max_draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		max_vram=maxf(max_vram,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		max_nodes=maxf(max_nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		max_collision_pairs=maxf(max_collision_pairs,Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
		if ms>33. and spikes.size()<3000:
			spikes.append({"t":elapsed,"frame_ms":ms,"gpu_ms":gpu_samples[-1],"physics_ms":physics_samples[-1],"script_ms":cpu_samples[-1],"physics_ticks":tick_delta,"new_pipelines":new_pipelines})
	var measurement_end_unix_ms:=int(Time.get_unix_time_from_system()*1000.)
	var bots_at_end: int=game.bot_director.bots.size() if is_instance_valid(game.bot_director) else 0
	GamePerformanceProbe.stop()
	IA2CostMetrics.stop()
	var times:=_stats(samples)
	var over33:=0
	var over50:=0
	var over100:=0
	for dt in samples:
		if dt>33.:over33+=1
		if dt>50.:over50+=1
		if dt>100.:over100+=1
	var result: Dictionary={"operation":operation,"label":label,"renderer":RenderingServer.get_current_rendering_method(),"gpu_name":RenderingServer.get_video_adapter_name(),"requested_resolution":[1920,1080],"render_texture":[rendered.x,rendered.y],"internal_scale":actual_scale,"preset":"Médio com escala 100%; fps e VSync desligados","actual_bots":deployed,"actual_bots_end":bots_at_end,"players":game.players.size(),"qa_presentation_only":qa_presentation_only,"qa_frozen_scene":qa_frozen_scene,"fps_cap":fps_cap,"collection_protocol":"war-1080p-28-bots-focus-gpu-v2","frames":times,"frame_time_trace_ms":samples,"measurement_window_unix_ms":{"start":measurement_start_unix_ms,"end":measurement_end_unix_ms},"focus":{"start_focused":focused_on_start,"focused_frames":focus_frames-unfocused_frames,"unfocused_frames":unfocused_frames,"total_frames":focus_frames,"transitions":focus_transitions,"change_events":focus_changes},"bot_population":{"minimum":minimum_bots,"at_end":bots_at_end,"samples":bot_population_checks},"actual_vsync":DisplayServer.window_get_vsync_mode(),"actual_fps_cap":Engine.max_fps,"gpu_ms":_stats(gpu_samples),"process_ms":_stats(cpu_samples),"physics_ms":_stats(physics_samples),"median_fps":1000./float(times.p50_ms),"over33_per_min":over33*60./duration,"over50_per_min":over50*60./duration,"over100_count":over100,"draw_calls_max":max_draws,"reported_gpu_mib_max":max_vram/1048576.,"nodes_max":max_nodes,"collision_pairs_max":max_collision_pairs,"pipeline_compilations_during_measurement":pipeline_total,"frames_over_33ms_with_new_pipelines":pipeline_spike_count,"spikes":spikes,"physics_ticks_per_frame":tick_deltas,"scoped_probe":GamePerformanceProbe.report(),"step_stats":GameStepMotion.qa_report(),"duration":duration,"warmup_seconds":warmup,"scope":"Offline WarGame, 28 deployed bots, fixed stationary camera near objective C (Favela), Afghan village or Ukraine B; no remote client, uncapped; after warmup.","valid":true}
	result["ia2_phase1"]={"brain_off":brain_off,"profiling":IA2CostMetrics.report(),"replication_offline_estimate":_estimate_replication()}
	var output:="res://work/benchmark-results/"+label+".json"
	NavalStorage.write_json(output,result)
	print("PERF_1080P_RESULT ",JSON.stringify({"label":label,"operation":operation,"median_fps":result.median_fps,"p95_ms":times.p95_ms,"p99_ms":times.p99_ms,"over33_per_min":result.over33_per_min,"gpu_ms_mean":result.gpu_ms.mean_ms,"bots":deployed,"texture":rendered,"scale":actual_scale}))
	# QA-only: avoid explicit teardown of the large scripted Afghan world
	# after the completed sample; normal SceneTree exit handles ownership.
	quit(0)
