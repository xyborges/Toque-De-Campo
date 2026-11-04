extends SceneTree

# One engine/world across all pairs, natural rendering and seeded round resets.
# This reduces restart/cache variation; it is still a scripted-camera test.
const ROUTE:=[Vector2(-150,-650),Vector2(-150,-440),Vector2(-140,-180),Vector2(-90,20),Vector2(170,25),Vector2(240,180)]
var game: WarGame
var camera: Camera3D
var manager: Node3D
var prefix:="nova-session"
var seconds:=120.0
var pairs:=5
var mode:="aa"
var quality:=2
var baseline_bots: Dictionary={}
var baseline_squads: Dictionary={}
var baseline_director: Dictionary={}
var baseline_clock:=0.0
var reports: Array[Dictionary]=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): prefix=arg.trim_prefix("--label=")
		if arg.begins_with("--seconds="): seconds=clampf(float(arg.trim_prefix("--seconds=")),5,120)
		if arg.begins_with("--pairs="): pairs=clampi(int(arg.trim_prefix("--pairs=")),1,7)
		if arg.begins_with("--bench-mode="): mode=arg.trim_prefix("--bench-mode=")
		if arg.begins_with("--vegetation-level="): quality=clampi(int(arg.trim_prefix("--vegetation-level=")),1,3)
	run.call_deferred()

func route_point(t: float) -> Vector2:
	var segment:=clampf(t,0,1)*(ROUTE.size()-1);var i:=mini(floori(segment),ROUTE.size()-2)
	return Vector2(ROUTE[i]).cubic_interpolate(ROUTE[i+1],ROUTE[maxi(0,i-1)],ROUTE[mini(ROUTE.size()-1,i+2)],segment-i)

func aim_camera(t: float) -> void:
	var p:=route_point(t);var next:=route_point(minf(.99999,t+.012))
	if p.distance_squared_to(next)<.0001: next=p+(p-route_point(maxf(0.,t-.012)))
	camera.global_position=WarTerrain.point(p.x,p.y)+Vector3.UP*2.2
	camera.look_at(WarTerrain.point(next.x,next.y)+Vector3.UP*1.6);camera.make_current()

func run() -> void:
	if DisplayServer.get_name()=="headless" or mode not in ["aa","ab"]: quit(2);return
	seed(193);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);game.set_meta("nova_grama_preview",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: push_error("session world not ready");quit(3);return
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(3).timeout
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	manager=game.world_root.get_node_or_null("VegetationVisuals")
	if manager==null: push_error("session vegetation manager absent");quit(4);return
	manager.apply_level(0)
	baseline_clock=game.war_clock;baseline_bots=game.bot_director.bots.duplicate(true);baseline_squads=game.bot_director.squads.duplicate(true)
	for key in ["think_cursor","think_accumulator","strategy_at","spatial_at","reconcile_clock","broadcast_clock"]: baseline_director[key]=game.bot_director.get(key)
	var cycle:=game.world_root.find_child("WarDayNight",true,false) as WarDayNight
	cycle.set_process(false);cycle.apply_time(0.,true)
	camera=Camera3D.new();camera.far=3000;root.add_child(camera);aim_camera(0.)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	# Draw both variants before recording: first-use compilation/loading is
	# measured separately from the alternating steady movement trials.
	for warm_level in [0,quality,0]:
		manager.apply_level(warm_level);aim_camera(0.)
		await create_timer(.3).timeout
		var warm_until:=Time.get_ticks_msec()+25000
		while is_instance_valid(manager.streamer) and not manager.streamer.pending.is_empty() and Time.get_ticks_msec()<warm_until: await process_frame
		for i in 150:
			aim_camera(float(i)/150.);await process_frame
	for n in pairs:
		await trial("a%d"%(n+1),0)
		await trial("b%d"%(n+1),quality if mode=="ab" else 0)
	await trial("a%d"%(pairs+1),0)
	NavalStorage.write_json("res://work/"+prefix+".json",{"mode":mode,"quality":quality,"reports":reports,"seed":193,"pairs":pairs,"seconds":seconds,"note":"One local world, natural render loop, fixed camera route, seeded round resets and real bots. Not multiplayer or player movement acceptance."})
	manager.apply_level(0);game.queue_free();camera.queue_free();await process_frame;quit()

func trial(label: String,level: int) -> void:
	seed(193);game.war_clock=baseline_clock;game.reset_operation()
	game.bot_director.bots=baseline_bots.duplicate(true);game.bot_director.squads=baseline_squads.duplicate(true)
	for key: String in baseline_director: game.bot_director.set(key,baseline_director[key])
	for id in game.bot_director.bots: game.bot_director._deploy_bot(id)
	game.ui_focus.close_all();game.hud_layer.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	manager.apply_level(level);aim_camera(0.)
	await create_timer(5.).timeout
	var wait_until:=Time.get_ticks_msec()+12000
	while is_instance_valid(manager.streamer) and not manager.streamer.pending.is_empty() and Time.get_ticks_msec()<wait_until: await process_frame
	var samples: Array[float]=[];var draw_peak:=0.;var primitive_peak:=0.;var gpu_total:=0.;var gpu_count:=0
	var start:=Time.get_ticks_usec();var previous:=start;var wall_start:=Time.get_unix_time_from_system()
	while Time.get_ticks_usec()-start<int(seconds*1000000):
		aim_camera(float(Time.get_ticks_usec()-start)/(seconds*1000000))
		await process_frame
		var now:=Time.get_ticks_usec();samples.append(float(now-previous)*.001);previous=now
		draw_peak=maxf(draw_peak,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitive_peak=maxf(primitive_peak,Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		gpu_total+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid());gpu_count+=1
	var ordered:=samples.duplicate();ordered.sort();var total:=0.;var over33:=0;var over50:=0
	for value in samples:
		total+=value
		if value>33: over33+=1
		if value>50: over50+=1
	var low_count:=maxi(1,ceili(ordered.size()*.01));var low_total:=0.
	for i in range(ordered.size()-low_count,ordered.size()): low_total+=ordered[i]
	var result:={"label":label,"level":level,"fps":samples.size()*1000/total,"median_fps":1000/ordered[ordered.size()/2],"p99_ms":ordered[mini(ordered.size()-1,ceili(ordered.size()*.99)-1)],"worst_ms":ordered.back(),"over33_per_min":over33*60000./total,"over50_count":over50,"sample_ms":total,"start_unix":wall_start,"end_unix":Time.get_unix_time_from_system(),"draw_calls":draw_peak,"primitives":primitive_peak,"gpu_ms":gpu_total/maxi(1,gpu_count),"memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.,"actors":game.players.size(),"resolution":str(root.get_texture().get_size()),"stream_max_build_ms":manager.streamer.max_build_ms if is_instance_valid(manager.streamer) else 0.,"frame_ms":samples}
	result["one_percent_low_fps"]=1000.*low_count/low_total
	if game.players.size()!=18: push_error("session participant count changed");quit(5);return
	reports.append(result);NavalStorage.write_json("res://work/"+prefix+"-"+label+".json",result)
	print("SESSION_RESULT ",JSON.stringify({"label":label,"median_fps":result.median_fps,"p99_ms":result.p99_ms,"worst_ms":result.worst_ms,"level":level}))
