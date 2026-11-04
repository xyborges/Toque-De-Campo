extends SceneTree
## Normal frame loop, real local actors and physical movement. Not WAN capacity.
const DEFINITIONS=preload("res://scripts/maps/definition.gd")
const ADAPTER=preload("res://tools/maps/adapter.gd")
var id:="ukraine"
var output:="res://work/maps-benchmark"
var duration:=120.
var pairs:=5
var participants:=18
var mode:="ab"
var game: Node3D
var manager: Node3D
var reports: Array[Dictionary]=[]
var actor: GamePlayer
var route: Array[Vector3]=[]
var start_pose:=Vector3.ZERO
var waypoint:=1
var moving:=false
var travelled:=0.
var previous_position:=Vector3.ZERO
var driver: Driver
class Driver extends Node:
	var owner_benchmark: SceneTree
	func _physics_process(delta: float) -> void:owner_benchmark.drive(delta)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):id=arg.trim_prefix("--map=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="):duration=clampf(float(arg.trim_prefix("--seconds=")),5.,120.)
		if arg.begins_with("--pairs="):pairs=clampi(int(arg.trim_prefix("--pairs=")),1,5)
		if arg.begins_with("--participants="):participants=clampi(int(arg.trim_prefix("--participants=")),2,40)
		if arg.begins_with("--bench-mode="):mode=arg.trim_prefix("--bench-mode=")
	run.call_deferred()

func drive(_delta: float) -> void:
	if not moving or not is_instance_valid(actor) or route.is_empty():return
	if actor.hp<=0:return
	travelled+=actor.global_position.distance_to(previous_position);previous_position=actor.global_position
	var goal: Vector3=route[waypoint];var direction:=goal-actor.global_position;direction.y=0
	if direction.length()<2.:waypoint=(waypoint+1)%route.size();return
	actor.yaw=atan2(-direction.x,-direction.z);actor.rotation.y=actor.yaw
	# QA game ignores mouse motion, so desktop cursor movement cannot steer it.
	Input.action_press("move_forward")

func write_report(path: String,data: Dictionary) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()

func run() -> void:
	if DisplayServer.get_name()=="headless" or not DEFINITIONS.current(id):push_error("Graphical renderer and current prepared map required");quit(2);return
	seed(193);root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	DirAccess.make_dir_recursive_absolute(output)
	if id=="ukraine":
		game=load("res://tools/maps/benchmark_war.gd").new();game.offline_operation=true;game.offline_participants=participants;game.set_meta("test_mode",true);game.set_meta("nova_grama_preview",true);root.add_child(game)
		var deadline:=Time.get_ticks_msec()+120000
		while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
		if not game.join_ready:quit(3);return
		game.request_deploy(0,"soldier","fal","stinger","base")
		for point in [Vector2(-150,-650),Vector2(-150,-440),Vector2(-140,-180),Vector2(-90,20),Vector2(170,25),Vector2(240,180)]:route.append(WarTerrain.point(point.x,point.y)+Vector3.UP*.15)
	elif id in ["desert","office"]:
		game=load("res://tools/maps/benchmark_infantry.gd").new();game.set_meta("test_mode",true);root.add_child(game)
		game._begin_offline("training" if id=="office" else "desert")
		if id=="office":route=[Vector3(-3.5,.15,4),Vector3(-3.5,.15,-26),Vector3(3.5,.15,-26),Vector3(3.5,.15,4)]
		else:
			for point in [Vector2(-60,-50),Vector2(-60,50),Vector2(60,50),Vector2(60,-50)]:route.append(Vector3(point.x,DesertTerrain.height_at(point.x,point.y)+.16,point.y))
	elif id=="afghan":
		game=load("res://tools/maps/benchmark_br.gd").new();game.set_meta("test_mode",true);root.add_child(game)
		var deadline:=Time.get_ticks_msec()+120000
		while game.phase!="active" and Time.get_ticks_msec()<deadline:await process_frame
		if game.phase!="active":quit(3);return
		# Use a proven connected road near the local spawn; physics remains active.
		var at: Vector3=game.local_player.global_position
		var destinations: Array=game.navigation.spawn_candidates()
		destinations.sort_custom(func(a: Vector3,b: Vector3):return a.distance_squared_to(at)>b.distance_squared_to(at))
		for destination: Vector3 in destinations:
			var path: PackedVector3Array=game.navigation.path_to(at,destination)
			if path.size()>4:
				for p in path:route.append(p+Vector3.UP*.08)
				break
		if route.is_empty():push_error("No physically validated BR route");quit(4);return
	else:
		await naval_render_trial();return
	actor=game.local_player;start_pose=route[0];manager=game.world_root.get_node_or_null("VegetationVisuals")
	if id=="afghan":manager=game.world_root.get_node_or_null("VegetationVisuals")
	if manager==null and id in ["desert","afghan"]:
		manager=load("res://modes/war/scripts/vegetation_visuals.gd").new();game.world_root.add_child(manager)
		manager.initialize(game.afghan_map if id=="afghan" else game.world_root,id)
	if id in ["ukraine","afghan","desert"] and (manager==null or not manager.available):push_error("Prepared grass renderer unavailable");quit(4);return
	game.ui_focus.close_all();game.menu_layer.hide();game.hud_layer.show()
	driver=Driver.new();driver.owner_benchmark=self;root.add_child(driver)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	# Warm both presentations in the real renderer before starting the route.
	for level in [0,2,0]:
		if manager:manager.apply_level(level)
		actor.global_position=start_pose;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
		await create_timer(2.).timeout
	for pair in pairs:
		await trial("a"+str(pair+1),0)
		await trial("b"+str(pair+1),2 if mode=="ab" else 0)
	await trial("a"+str(pairs+1),0)
	var summary:={"map":id,"source_hash":DEFINITIONS.identity(id).hash,"mode":mode,"seconds":duration,"pairs":pairs,"requested_participants":participants,"reports":reports,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Real offline actors and input-driven physical route. Live bots are not frozen. The War observer is protected from lethal damage for repeatability. Not WAN multiplayer capacity or a full round.","acceptance":acceptance()}
	write_report(output+"/"+id+"-measure.json",summary);print("MAP_BENCHMARK ",JSON.stringify(summary.acceptance))
	Input.action_release("move_forward");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.queue_free();await process_frame;quit(0 if summary.acceptance.approved else 1)

func trial(label: String,level: int) -> void:
	moving=false;Input.action_release("move_forward")
	if manager:manager.apply_level(level)
	if id=="ukraine":
		seed(193);game.war_clock=0.;game.reset_operation()
		game.request_deploy(0,"soldier","fal","stinger","base")
	# Same entry pose per trial, never teleport during the recorded route.
	actor.global_position=start_pose;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation();waypoint=1
	await create_timer(1.).timeout
	previous_position=actor.global_position;travelled=0.;moving=true
	var frames: Array[float]=[];var start:=Time.get_ticks_usec();var last:=start;var peak_draw:=0.;var peak_memory:=0.;var alive:=true
	while Time.get_ticks_usec()-start<duration*1000000.:
		await process_frame
		var now:=Time.get_ticks_usec();frames.append((now-last)*.001);last=now
		peak_draw=maxf(peak_draw,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_memory=maxf(peak_memory,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.)
		alive=alive and actor.hp>0
	moving=false;Input.action_release("move_forward")
	var sorted:=frames.duplicate();sorted.sort();var over33:=0;var over50:=0;var total:=0.
	for frame in frames:
		total+=frame
		if frame>33.:over33+=1
		if frame>50.:over50+=1
	var result:={"label":label,"level":level,"median_fps":1000./sorted[sorted.size()/2],"p99_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*.99)-1)],"worst_ms":sorted.back(),"over33_per_min":over33*60000./total,"over50":over50,"draw_peak":peak_draw,"video_memory_mib":peak_memory,"distance_m":travelled,"alive":alive,"participants":game.players.size(),"frame_ms":frames,"pool_nodes":manager.streamer.created if manager else 0,"pool_update_max_ms":manager.streamer.max_build_ms if manager else 0.}
	result.valid=alive and travelled>duration*.5 and (game.players.size()==participants if id=="ukraine" else true)
	reports.append(result);write_report(output+"/"+id+"-"+label+".json",result)
	print("MAP_TRIAL ",JSON.stringify({"map":id,"label":label,"fps":result.median_fps,"p99":result.p99_ms,"worst":result.worst_ms,"metres":travelled,"valid":result.valid}))

func acceptance() -> Dictionary:
	var reasons: Array[String]=[]
	if duration<120. or pairs<5:reasons.append("Smoke run: five pairs of 120 seconds are required")
	if mode!="ab":reasons.append("A/A noise reference only")
	for row: Dictionary in reports:
		if not row.valid:reasons.append("Invalid physical route or participant count: "+str(row.label))
		if row.worst_ms>50.:reasons.append("Frame above 50 ms: "+str(row.label))
		if row.video_memory_mib>4096.:reasons.append("Video memory budget exceeded")
	for i in pairs:
		var before: Dictionary=reports[i*2];var candidate: Dictionary=reports[i*2+1];var after: Dictionary=reports[i*2+2]
		if candidate.median_fps<minf(before.median_fps,after.median_fps)*.95:reasons.append("Median FPS regression: "+str(candidate.label))
		if candidate.p99_ms>maxf(before.p99_ms,after.p99_ms) or candidate.over33_per_min>maxf(before.over33_per_min,after.over33_per_min):reasons.append("Tail frame-time regression: "+str(candidate.label))
	return {"performance_pass":reasons.is_empty(),"approved":false,"reasons":reasons,"pending":["Independent A/A noise series","Visual parity","Multiplayer validation"]}

func naval_render_trial() -> void:
	# Preserve naval rules; do not pretend a camera-only test certifies gameplay.
	var adapter:=ADAPTER.new();adapter.configure("naval");adapter.build(root,true)
	var camera:=Camera3D.new();adapter.world.add_child(camera);camera.position=Vector3(0,35,200);camera.look_at(Vector3.ZERO);camera.make_current()
	await create_timer(2.).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/naval-render.png")
	write_report(output+"/naval-measure.json",{"map":"naval","acceptance":{"approved":false,"reasons":["Naval gameplay requires real ship route and combat; this render smoke does not certify performance"]}})
	adapter.world.free();quit(1)
