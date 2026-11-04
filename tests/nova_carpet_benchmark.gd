extends SceneTree
var game: WarGame
var nova_lab: Node3D
var carpet_stream: Node3D
var pre_hidden: GeometryInstance3D
var max_primitives:=0.
var max_objects:=0.
var label:="before193"
var samples: Array[float]=[]
var gpu: Array[float]=[]
var processing: Array[float]=[]
var physics: Array[float]=[]
var duration_usec:=24000000
const ROUTE_POINTS:=[Vector2(-150,-650),Vector2(-150,-440),Vector2(-140,-180),Vector2(-90,20),Vector2(170,25),Vector2(240,180)]

func route_point(progress: float) -> Vector2:
	var segment: float=clampf(progress,0.,1.)*(ROUTE_POINTS.size()-1)
	var i:=mini(floori(segment),ROUTE_POINTS.size()-2)
	var a: Vector2=ROUTE_POINTS[maxi(0,i-1)];var b: Vector2=ROUTE_POINTS[i]
	var c: Vector2=ROUTE_POINTS[i+1];var d: Vector2=ROUTE_POINTS[mini(ROUTE_POINTS.size()-1,i+2)]
	return b.cubic_interpolate(c,a,d,segment-i)

func move_route_camera(camera: Camera3D,progress: float) -> void:
	var p:=route_point(progress);var target:=route_point(minf(1.,progress+.012))
	if p.distance_squared_to(target)<.0001: target=route_point(maxf(0.,progress-.012));target=p+(p-target)
	camera.position=WarTerrain.point(p.x,p.y)+Vector3.UP*2.2
	camera.look_at(WarTerrain.point(target.x,target.y)+Vector3.UP*1.6)
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
	if "--qa-bot-profile" in OS.get_cmdline_user_args(): game=load("res://tests/nova_bot_profile_game.gd").new()
	elif "--bot-motion-lod" in OS.get_cmdline_user_args(): game=load("res://tests/perf200_bench_game.gd").new()
	else: game=WarGame.new()
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
	game.third_person=true;game.local_player._update_view();game.ui_focus.close_all()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if "--nova-grama" in OS.get_cmdline_user_args():
		if "--verify-toggle" in OS.get_cmdline_user_args():
			for node: MultiMeshInstance3D in game.world_root.find_children("*","MultiMeshInstance3D",true,false):
				if node.multimesh and node.multimesh.mesh==WarVegetation.grass_mesh(): pre_hidden=node;node.hide();break
		nova_lab=load("res://tests/nova_grama_lab.gd").new();nova_lab.ground_only="--nova-ground-only" in OS.get_cmdline_user_args();nova_lab.details_only="--nova-details-only" in OS.get_cmdline_user_args();game.world_root.add_child(nova_lab)
		var activation_start:=Time.get_ticks_msec()
		if not nova_lab.activate(): push_error("Nova Grama failed");quit(2);return
		if "--biome-trees" in OS.get_cmdline_user_args():
			var tree_stats: Dictionary=load("res://tests/nova_grama_biome_trees.gd").new().activate(nova_lab)
			nova_lab.counts["tree_reclassification"]=tree_stats
		elif "--biome-trees2" in OS.get_cmdline_user_args():
			nova_lab.tree_controller=load("res://tests/nova_grama_biome_trees_inplace.gd").new()
			var tree_stats: Dictionary=nova_lab.tree_controller.activate(nova_lab)
			nova_lab.counts["tree_reclassification"]=tree_stats
		nova_lab.counts["activation_ms"]=Time.get_ticks_msec()-activation_start
		if "--audit-biome" in OS.get_cmdline_user_args():
			var audit: Dictionary=load("res://tests/nova_grama_audit.gd").new().run(nova_lab)
			print("NOVA_AUDIT ",JSON.stringify(audit))
			if audit.grass_in_burnt!=0: push_error("Grass found in burned biome");quit(3);return
		print("NOVA_COUNTS ",JSON.stringify(nova_lab.counts))
		if "--merge-cells" in OS.get_cmdline_user_args():
			var merged: Dictionary=load("res://tests/nova_grama_regroup.gd").new().merge(nova_lab)
			print("NOVA_REGROUP ",JSON.stringify(merged));await process_frame
	var camera:=Camera3D.new();camera.far=3000;root.add_child(camera);camera.position=WarTerrain.point(-80,-315)+Vector3(0,2.5,10);camera.look_at(WarTerrain.point(-80,-260)+Vector3.UP*.4);camera.make_current()
	var route_enabled: bool="--camera-route" in OS.get_cmdline_user_args()
	if route_enabled: move_route_camera(camera,0.)
	if "--carpet-stream" in OS.get_cmdline_user_args():
		carpet_stream=load("res://tests/nova_grass_stream.gd").new();game.world_root.add_child(carpet_stream)
		if not carpet_stream.configure(game.world_root,camera): push_error("carpet stream failed");quit(2);return
		while not carpet_stream.pending.is_empty(): await process_frame
	var marker:=MotionProbe.new();game.world_root.add_child(marker)
	marker.global_position=camera.global_position-camera.global_basis.z*80-camera.global_basis.x*10
	marker.speed_vector=camera.global_basis.x*2.
	marker.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON if selective else Node.PHYSICS_INTERPOLATION_MODE_OFF
	if selective: marker.get_global_transform_interpolated();marker.reset_physics_interpolation()
	# Natural rendering loop; do not force a separate draw.
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if EngineDebugger.is_active() and EngineDebugger.has_profiler("servers"): EngineDebugger.profiler_enable("servers",true,[128])
	var start:=Time.get_ticks_usec();var previous:=start;var start_wall:=Time.get_unix_time_from_system();var draws:=0.;var peak:=0;var actors:=0
	var motion_frames: Array=[];var occupied_samples:=0;var bot_vehicles_peak:=0
	print("BENCH_START ",label," seconds=",duration_usec/1000000," actors=",game.players.size())
	GamePerformanceProbe.start()
	var diagnosis: Array=[];var phase:=0;var phase_at:=start
	var duration:=48000000 if "--diagnose" in OS.get_cmdline_user_args() else duration_usec
	while Time.get_ticks_usec()-start<duration:
		await process_frame
		if route_enabled: move_route_camera(camera,clampf(float(Time.get_ticks_usec()-start-3000000)/float(maxi(1,int(duration)-3000000)),0.,1.))
		# The normal engine loop presents each frame.
		var now:=Time.get_ticks_usec()
		if now-start>3000000:
			samples.append((now-previous)*.001);draws=maxf(draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));peak=maxi(peak,game.war_fx.active_slots.size());actors=maxi(actors,game.players.size())
			max_primitives=maxf(max_primitives,Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));max_objects=maxf(max_objects,Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()));processing.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			var displayed:=marker.get_global_transform_interpolated().origin if selective else marker.global_position
			motion_frames.append([float(now-start)*.001,float(now-previous)*.001,camera.unproject_position(displayed).x,camera.unproject_position(marker.global_position).x,Engine.get_physics_interpolation_fraction()])
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
	result.nova_grama="--nova-grama" in OS.get_cmdline_user_args();result.nova_ground_only="--nova-ground-only" in OS.get_cmdline_user_args();result.merged_cells="--merge-cells" in OS.get_cmdline_user_args();result.nova_counts=nova_lab.counts if is_instance_valid(nova_lab) else {};result.max_primitives=max_primitives;result.max_objects=max_objects
	result.nova_details_only="--nova-details-only" in OS.get_cmdline_user_args()
	result.carpet_stream="--carpet-stream" in OS.get_cmdline_user_args()
	if is_instance_valid(carpet_stream): result.carpet_stream_stats={"created":carpet_stream.created,"retired":carpet_stream.retired_count,"remaining_cells":carpet_stream.cells.size(),"pending":carpet_stream.pending.size(),"max_build_ms":carpet_stream.max_build_ms}
	result.natural_render_loop=true;result.camera_route=route_enabled;result.frame_p99_ms=sorted[mini(sorted.size()-1,ceili(sorted.size()*.99)-1)];result.median_fps=1000./sorted[sorted.size()/2]
	var over33:=0;var over50:=0
	for v: float in samples:
		if v>33.: over33+=1
		if v>50.: over50+=1
	result.over33_frames_per_minute=over33*60000./total;result.over50_frames=over50;result.sample_ms=total
	if route_enabled: result.note="Fixed camera path, one native offline client and 17 bots; camera is scripted, not a walking player. Same seed does not force identical AI; not remote clients."
	result.nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);result.static_memory_mib=Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.;result.video_memory_mib=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.
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
	print("BENCH_RESULT ",JSON.stringify({"label":label,"fps":result.fps,"low":result.one_percent_low,"worst_ms":result.worst_ms,"draw_calls":draws,"triangles":max_primitives,"resolution":result.resolution}))
	if "--captures" in OS.get_cmdline_user_args(): await capture_views(camera)
	if "--verify-toggle" in OS.get_cmdline_user_args() and not await verify_toggle(): quit(4);return
	if EngineDebugger.is_active() and EngineDebugger.is_profiling("servers"): EngineDebugger.profiler_enable("servers",false)
	game.show_menu();game.queue_free();camera.queue_free();await process_frame;await process_frame;quit()

func verify_toggle() -> bool:
	if not is_instance_valid(nova_lab): return false
	var material_records: Array=nova_lab.surfaces.duplicate();var visual_records: Array=nova_lab.legacy.duplicate()
	var tree_records: Array=nova_lab.tree_controller.originals.duplicate() if nova_lab.tree_controller else []
	var generated: Array=nova_lab.generated.duplicate()
	nova_lab.deactivate();await process_frame;await process_frame
	var failures: Array[String]=[]
	for item in material_records:
		if is_instance_valid(item.node) and item.node.material_override!=item.material: failures.append("terrain material")
	for item in visual_records:
		if is_instance_valid(item.node):
			if item.node.visible!=item.visible: failures.append("visibility")
	for item in tree_records:
		if is_instance_valid(item.node) and (item.node.multimesh!=item.multimesh or item.node.custom_aabb!=item.aabb): failures.append("tree material or bounds")
	for node in generated:
		if is_instance_valid(node): failures.append("generated node still alive")
	if not is_instance_valid(pre_hidden) or pre_hidden.visible: failures.append("pre-hidden batch was revealed")
	print("NOVA_TOGGLE_TEST ",JSON.stringify({"ok":failures.is_empty(),"failures":failures,"terrain_sectors":material_records.size(),"tree_batches":tree_records.size()}))
	return failures.is_empty()

func capture_views(camera: Camera3D) -> void:
	var cycle: WarDayNight=game.world_root.find_child("WarDayNight",true,false)
	var thermal: WarThermal=game.vehicle_system.get_node_or_null("Thermal")
	if not cycle or not thermal: print("CAPTURE_FAIL no cycle/thermal");return
	cycle.set_process(false);game.hud_layer.visible=false
	for mode in ["day","night","thermal"]:
		cycle.apply_time(0.0 if mode=="day" else 490.0,true)
		thermal.set_enabled(mode=="thermal")
		for distance in [3.,20.,60.]:
			var target:=WarTerrain.point(-80,-320)
			camera.global_position=target+Vector3(0,1.7,distance)
			camera.look_at(target+Vector3.UP*.2)
			for frame in 3: await process_frame # The normal engine loop presents each frame.
			var image:=root.get_texture().get_image()
			var path:="res://work/nova-grama-%s-%sm.png"%[mode,int(distance)]
			image.save_png(ProjectSettings.globalize_path(path));print("CAPTURE ",path)
	thermal.set_enabled(false)
	cycle.apply_time(0.,true)
	var burned:=WarTerrain.point(-80,-155)
	camera.global_position=burned+Vector3(0,2.,5.);camera.look_at(burned+Vector3.UP*.2)
	for frame in 3: await process_frame # The normal engine loop presents each frame.
	var path:="res://work/nova-grama-burnt-day.png"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path));print("CAPTURE ",path)



