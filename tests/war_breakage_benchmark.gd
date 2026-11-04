extends SceneTree
var game: WarGame
var scenario_done:=false
var scenario_errors: Array[String]=[]
var scenario_events: Array=[]
var active_debris_peak:=0
var blast_centre:=Vector3.ZERO
var benchmark_start_usec:=0
var label:="before193"
var samples: Array[float]=[]
var gpu: Array[float]=[]
var processing: Array[float]=[]
var physics: Array[float]=[]
var duration_usec:=24000000
class MotionProbe extends Node3D:
	var speed_vector:=Vector3.ZERO
	func _physics_process(delta: float) -> void: position+=speed_vector*delta
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg.begins_with("--seconds="): duration_usec=int(float(arg.trim_prefix("--seconds="))*1000000)
		if arg.begins_with("--ticks="): Engine.physics_ticks_per_second=int(arg.trim_prefix("--ticks="))
	run.call_deferred()
func run() -> void:
	seed(193)
	# A benchmark-only switch: never enable globally on players' installations.
	var selective: bool="--selective-interpolation" in OS.get_cmdline_user_args()
	physics_interpolation="--interpolation" in OS.get_cmdline_user_args() or selective
	if selective: root.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0;root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	if "--exact-resolution" in OS.get_cmdline_user_args(): root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	game=load("res://tests/war_breakage_fixture.gd").new()
	game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: quit(1);return
	print("BENCH_WORLD_READY ",label," backend=",ProjectSettings.get_setting("physics/3d/physics_engine")," trees=",game.world_root.get_meta("war_tree_count",0)," grass=",game.world_root.get_meta("war_grass_count",0))
	if "--count12" in OS.get_cmdline_user_args(): game.offline_participants=12
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(4).timeout
	if "--bots-stopped" in OS.get_cmdline_user_args(): game.bot_director.stop()
	if "--bots-no-vehicles" in OS.get_cmdline_user_args():
		for id in game.bot_director.bots:
			if not (game.players[id] as WarPlayer).vehicle_id.is_empty(): game.vehicle_system.release(id,true)
			game.bot_director.bots[id].boarded_once=true
	if "--no-hitbox-monitoring" in OS.get_cmdline_user_args():
		for actor: WarPlayer in game.players.values():
			for region: Area3D in actor.hit_regions.values(): region.monitoring=false
	if selective:
		# Benchmark-only proof of concept: actor/hull physics is interpolated,
		# but mouse-driven cameras, particles, the sea and network snapshots
		# retain their existing independent presentation updates.
		for actor: WarPlayer in game.players.values():
			actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
			actor.camera_pivot.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
			actor.reset_physics_interpolation()
		for vehicle: WarVehicle in game.vehicle_system.vehicles.values():
			if not vehicle is WarShip:
				vehicle.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
				vehicle.reset_physics_interpolation()
	game.install_tree_index();game.qa_breakage_enabled="--breakage" in OS.get_cmdline_user_args()
	blast_centre=find_forest_cluster()
	game.third_person=true;game.local_player._update_view();game.ui_focus.close_all()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var camera:=Camera3D.new();camera.far=3000;root.add_child(camera);camera.position=WarTerrain.point(0,-160)+Vector3(0,16,15);camera.look_at(WarTerrain.point(0,50));camera.make_current()
	game.qa_camera=camera;scenario.call_deferred()
	var marker:=MotionProbe.new();game.world_root.add_child(marker)
	marker.global_position=camera.global_position-camera.global_basis.z*80-camera.global_basis.x*10
	marker.speed_vector=camera.global_basis.x*2.
	marker.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON if selective else Node.PHYSICS_INTERPOLATION_MODE_OFF
	if selective: marker.get_global_transform_interpolated();marker.reset_physics_interpolation()
	RenderingServer.render_loop_enabled=false
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if EngineDebugger.is_active() and EngineDebugger.has_profiler("servers"): EngineDebugger.profiler_enable("servers",true,[128])
	var start:=Time.get_ticks_usec();benchmark_start_usec=start;var previous:=start;var start_wall:=Time.get_unix_time_from_system();var draws:=0.;var peak:=0;var actors:=0
	var motion_frames: Array=[];var occupied_samples:=0;var bot_vehicles_peak:=0
	print("BENCH_START ",label," seconds=",duration_usec/1000000," actors=",game.players.size())
	GamePerformanceProbe.start()
	var diagnosis: Array=[];var phase:=0;var phase_at:=start
	var duration:=48000000 if "--diagnose" in OS.get_cmdline_user_args() else duration_usec
	while Time.get_ticks_usec()-start<duration:
		await process_frame;RenderingServer.force_draw(false)
		var now:=Time.get_ticks_usec()
		if now-start>3000000:
			samples.append((now-previous)*.001);draws=maxf(draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));peak=maxi(peak,game.war_fx.active_slots.size());actors=maxi(actors,game.players.size())
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()));processing.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			var displayed:=marker.get_global_transform_interpolated().origin if selective else marker.global_position
			motion_frames.append([float(now-start)*.001,float(now-previous)*.001,camera.unproject_position(displayed).x,camera.unproject_position(marker.global_position).x,Engine.get_physics_interpolation_fraction()])
			var presenter: Object=game.real_tree_index.presentation.get_ref() if game.real_tree_index.presentation else null
			if is_instance_valid(presenter):
				var active:=0
				for slot in presenter.pool:
					if slot.active: active+=1
				active_debris_peak=maxi(active_debris_peak,active)
			var aboard:=0
			for id in game.bot_director.bots:
				var bot:=game.players.get(id) as WarPlayer
				if is_instance_valid(bot) and not bot.vehicle_id.is_empty(): aboard+=1
			bot_vehicles_peak=maxi(bot_vehicles_peak,aboard)
			if aboard>0: occupied_samples+=1
		previous=now
		if "--diagnose" in OS.get_cmdline_user_args() and phase<2 and now-phase_at>16000000:
			diagnosis.append({"phase":phase,"fps":samples.size()*1000/maxf(1,samples.reduce(func(a,b):return a+b,0.)),"gpu_ms":gpu.reduce(func(a,b):return a+b,0.)/maxi(1,gpu.size()),"physics_ms":physics.reduce(func(a,b):return a+b,0.)/maxi(1,physics.size())})
			phase+=1;phase_at=now;samples.clear();gpu.clear();processing.clear();physics.clear()
			if phase==1: game.vehicle_system.set_physics_process(false)
			if phase==2: game.bot_director.enabled=false
	var total:=0.;var sorted:=samples.duplicate();sorted.sort();var slow:=maxi(1,ceili(samples.size()*.01));var tail:=0.
	for v in samples: total+=v
	for i in slow: tail+=sorted[sorted.size()-i-1]
	var result:={"label":label,"seed":193,"interpolation":physics_interpolation,"selective_interpolation":selective,"ticks_per_second":Engine.physics_ticks_per_second,"fps":samples.size()*1000/total,"one_percent_low":slow*1000/tail,"frame_mean_ms":total/samples.size(),"frame_p95_ms":sorted[int(sorted.size()*.95)],"worst_ms":sorted.back(),"actors":actors,"maximum_projectiles":peak,"draw_calls":draws,"diagnostics":game.bot_director.diagnostics,"resolution":str(root.get_texture().get_size()),"gpu":RenderingServer.get_video_adapter_name(),"note":"One native offline client, actual bots/world, stationary observation of central front. Seed is fixed; simulation timing and AI decisions can differ between runs. Not remote clients."}
	result.breakage_enabled=game.qa_breakage_enabled;result.scenario_done=scenario_done;result.scenario_errors=scenario_errors
	result.note="Um cliente Guerra offline, 17 bots, quatro blindados conduzidos por adaptador de teste e três explosões; câmera acompanha alvos. Mesmo mapa e semente; trajetórias e tempos ainda podem divergir. Não mede clientes remotos."
	var target_positions: Array=[]
	for p: Vector3 in game.qa_targets: target_positions.append([p.x,p.y,p.z])
	result.scenario_events=scenario_events;result.target_positions=target_positions;result.destroyed_trees=game.real_tree_index.model.broken.size();result.active_debris_peak=active_debris_peak
	result.blast_centre=[blast_centre.x,blast_centre.y,blast_centre.z]
	result.window_size=str(DisplayServer.window_get_size());result.screen_size=str(DisplayServer.screen_get_size());result.viewport_rect=str(root.get_visible_rect().size);result.content_scale_size=str(root.content_scale_size);result.render_texture_size=str(root.get_texture().get_size())
	result.start_unix=start_wall;result.end_unix=Time.get_unix_time_from_system();result.bot_vehicles_peak=bot_vehicles_peak;result.bot_vehicles_sample_fraction=float(occupied_samples)/maxi(1,samples.size())
	result.bots_stopped="--bots-stopped" in OS.get_cmdline_user_args();result.bots_no_vehicles="--bots-no-vehicles" in OS.get_cmdline_user_args()
	result.bot_motion_lod="--bot-motion-lod" in OS.get_cmdline_user_args()
	if result.bot_motion_lod:
		result.lod_counters={"deferred_ticks":game.bot_director.deferred_ticks,"full_rate_ticks":game.bot_director.full_rate_ticks,"reduced_steps":game.bot_director.reduced_steps}
	result.motion_probe={"description":"Controlled constant-velocity target moving perpendicular to stationary camera; each entry is elapsed ms, frame duration ms, displayed x pixels, physics x pixels, physics interpolation fraction.","frames":motion_frames}
	for pair in [["gpu_ms",gpu],["process_ms",processing],["physics_ms",physics]]: result[pair[0]]=pair[1].reduce(func(a,b):return a+b,0.)/maxi(1,pair[1].size())
	GamePerformanceProbe.stop();result.probe=GamePerformanceProbe.report();result.diagnosis=diagnosis
	result.physics_backend=ProjectSettings.get_setting("physics/3d/physics_engine","GodotPhysics3D")
	NavalStorage.write_json("res://work/"+label+"-offline.json",result)
	print("BENCH_RESULT ",JSON.stringify({"label":label,"fps":result.fps,"low":result.one_percent_low,"worst_ms":result.worst_ms,"destroyed":result.destroyed_trees,"pool_peak":active_debris_peak,"scenario_done":scenario_done,"scenario_errors":scenario_errors}))
	if EngineDebugger.is_active() and EngineDebugger.is_profiling("servers"): EngineDebugger.profiler_enable("servers",false)
	game.show_menu();game.queue_free();camera.queue_free();await process_frame;await process_frame;quit()

func find_forest_cluster() -> Vector3:
	var best:=Vector3.ZERO;var best_count:=-1
	for cell: Vector2i in game.real_tree_index.cells:
		for entry: Dictionary in game.real_tree_index.cells[cell]:
			var point: Vector3=entry.position
			if absf(point.x)>1100 or absf(point.z)>1100: continue
			var count:=0
			for dx in range(-1,2):
				for dz in range(-1,2):
					for nearby: Dictionary in game.real_tree_index.cells.get(cell+Vector2i(dx,dz),[]):
						if Vector3(nearby.position).distance_squared_to(point)<144.: count+=1
			if count>best_count: best_count=count;best=point
	return best

func scenario() -> void:
	await create_timer(4.).timeout
	for kind in ["guarani","bmp2","abrams","t90"]:
		var hit: Dictionary=await game.drive_into_real_tree(kind)
		if hit.is_empty(): scenario_errors.append("vehicle "+kind);return
		scenario_events.append({"kind":kind,"elapsed_ms":float(Time.get_ticks_usec()-benchmark_start_usec)*.001,"cell":str(hit.cell),"index":hit.index})
		await create_timer(.25).timeout
	if game.qa_targets.is_empty(): scenario_errors.append("missing target positions");return
	game.qa_camera.global_position=blast_centre+Vector3(-22,11,26);game.qa_camera.look_at(blast_centre+Vector3.UP*2.)
	for i in 3:
		var point:=WarTerrain.point(blast_centre.x+i*3.,blast_centre.z)
		game.vehicle_system.explode(0,point,600.,18.,"tank","qa:benchmark:blast:%d"%i)
		scenario_events.append({"kind":"blast","elapsed_ms":float(Time.get_ticks_usec()-benchmark_start_usec)*.001,"broken":game.real_tree_index.model.broken.size()})
		await create_timer(.25).timeout
	scenario_done=true
