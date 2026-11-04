extends SceneTree
const Afghan=preload("res://modes/battle_royale/map/afghan_map.gd")
const Atmosphere=preload("res://modes/battle_royale/map/afghan_atmosphere.gd")
const Legacy=preload("res://work/afghan-map-before-20261028/legacy_map.gd")
var label:="br-atmosphere-preview"
var enhanced:=false
var seconds:=24.
var warmup:=8.
var scene: Node3D
var camera: Camera3D
var map: Node3D
var context: Node3D
var actors: Array[GamePlayer]=[]
var lights: GameDayNight
var capture_only:=false
var rendered_frames:=0
class Context extends "res://scripts/main.gd":
	var phase:="active"
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _process(_delta: float) -> void: pass
	func _input(_event: InputEvent) -> void: pass
	func _unhandled_input(_event: InputEvent) -> void: pass
	func update_hud() -> void: pass
	func _new_player() -> GamePlayer: return BRPlayer.new()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg.begins_with("--seconds="): seconds=float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--warmup="): warmup=float(arg.trim_prefix("--warmup="))
	enhanced="--after" in OS.get_cmdline_user_args();capture_only="--captures" in OS.get_cmdline_user_args()
	run.call_deferred()

func set_view(index: int) -> void:
	var c:=Vector3(-180,0,570)
	var views: Array=[
		[c+Vector3(-105,82,148),c+Vector3(8,4,-30)],
		[c+Vector3(0,2.1,50),c+Vector3(4,2.8,-70)],
		[Vector3(-460,Legacy.height_at(-460,760)+32,760),Vector3(0,48,-520)]]
	var location: Vector3=views[index][0]
	if index<2: location.y+=Legacy.height_at(c.x,c.z)
	var target: Vector3=views[index][1]
	if index<2: target.y+=Legacy.height_at(c.x,c.z)
	camera.position=location;camera.look_at(target)

func create_map() -> Node3D:
	return Afghan.new() if enhanced else Legacy.new()

func run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Graphical benchmark required");quit(1);return
	RenderingServer.frame_post_draw.connect(func():rendered_frames+=1)
	root.title="Toque de Campo — Afeganistão · Luz A/B (teste)"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_size=Vector2i(1920,1080);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.msaa_3d=Viewport.MSAA_DISABLED;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	context=Context.new();context.profile.owned=GameWeapons.INFANTRY_IDS.duplicate();context.map_kind="afghan";root.add_child(context)
	scene=Node3D.new();context.add_child(scene);context.world_root=scene
	if enhanced: lights=Atmosphere.install(scene)
	else: context._build_lighting();lights=context.day_night
	map=create_map();map.warm_atmosphere=enhanced;scene.add_child(map);map.build()
	for index in 18:
		var c: Vector3=Afghan.VILLAGES[0]
		var p: Vector3=map.point(c.x+(index%6-2.5)*5,c.z+18+(index/6)*8)
		var actor: GamePlayer=context._spawn_player(index+1,false,false,p)
		actor.set_physics_process(false);actor.set_process(false)
		actor.body_collision.disabled=true
		actor.weapon_id="fal" if index%2==0 else "ak";actor.owned=[actor.weapon_id];actor.loadout=[actor.weapon_id]
		actor._refresh_weapon();actor._animate_walk();actors.append(actor)
	camera=Camera3D.new();camera.fov=70;camera.far=5500;scene.add_child(camera);camera.make_current();set_view(0)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var warm_start:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm_start<int(warmup*1000000): await process_frame
	if "--diagnose" in OS.get_cmdline_user_args():
		await diagnose();cleanup();return
	if "--ground-paired" in OS.get_cmdline_user_args():
		await ground_paired();cleanup();return
	if capture_only:
		var views: Array=[]
		for i in 3:
			set_view(i)
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/"+label+"-view%d.png"%i)
			views.append({"view":i,"camera":var_to_str(camera.transform),"resolution":str(root.get_texture().get_size())})
		NavalStorage.write_json("res://work/"+label+"-cameras.json",{"label":label,"views":views,"metrics":map.build_metrics})
		print("BR_ATMOSPHERE_CAPTURES ",label);cleanup();return
	set_view(0)
	var times: Array[float]=[];var gpu: Array[float]=[];var draws: Array[float]=[]
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var start:=Time.get_ticks_usec();var previous:=start;var frame:=0;var start_unix:=Time.get_unix_time_from_system()
	var last_draw:=rendered_frames;var draw_time:=start
	while Time.get_ticks_usec()-start<int(seconds*1000000):
		await process_frame
		var now:=Time.get_ticks_usec();var elapsed: float=(now-start)*.000001
		if rendered_frames!=last_draw:draw_time=now;last_draw=rendered_frames
		if now-draw_time>200000 or DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED:
			push_error("Benchmark stopped drawing; sample discarded");context.free();quit(2);return
		times.append(float(now-previous)*.001);previous=now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		for i in actors.size():
			var actor: GamePlayer=actors[i]
			actor.rotation.y=sin(elapsed*.3+i)*.5
			actor.velocity=Vector3(0,0,3.)
			# Pose time is deterministic; no wall-clock sin() from the original
			# locomotion is included in the before/after comparison.
			actor.avatar_parts.leg_l.rotation.x=sin(elapsed*8.+i)*.25
			actor.avatar_parts.leg_r.rotation.x=-sin(elapsed*8.+i)*.25
		frame+=1
	var sorted:=times.duplicate();sorted.sort()
	var slow_count:=maxi(1,ceili(sorted.size()*.01));var slow:=0.
	for i in range(sorted.size()-slow_count,sorted.size()): slow+=sorted[i]
	var sum: float=times.reduce(func(a,b):return a+b,0.)
	var report:={"label":label,"enhanced":enhanced,"seed":712907,"actors":actors.size(),"scenario":"fixed camera; 18 deterministic animated infantry; visual isolation, no network","physics_ticks":Engine.physics_ticks_per_second,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.get_texture().get_size().x,root.get_texture().get_size().y],"window_size":str(DisplayServer.window_get_size()),"warmup_seconds":warmup,"sample_seconds":seconds,"frames":times.size(),"fps":times.size()*1000./sum,"one_percent_low":1000./(slow/slow_count),"worst_ms":sorted[-1],"p99_ms":sorted[mini(sorted.size()-1,floori(sorted.size()*.99))],"gpu_ms":gpu.reduce(func(a,b):return a+b,0.)/gpu.size(),"draw_calls":draws.reduce(func(a,b):return a+b,0.)/draws.size(),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"camera_transform":var_to_str(camera.transform),"start_unix":start_unix,"end_unix":Time.get_unix_time_from_system()}
	NavalStorage.write_json("res://work/"+label+".json",report)
	print("BR_ATMOSPHERE_BENCH ",JSON.stringify(report))
	cleanup()

func cleanup() -> void:
	context.free();quit()

func ground_paired() -> void:
	var reports: Array=[]
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for index in 7:
		var baked:=index%2==1
		map.terrain_material.set_shader_parameter("baked_enabled",baked)
		await create_timer(2.).timeout
		var samples: Array[float]=[];var gpu:=0.;var hitches: Array=[]
		var start:=Time.get_ticks_usec();var previous:=start;var last_draw:=rendered_frames;var draw_time:=start
		while Time.get_ticks_usec()-start<16000000:
			await process_frame
			var now:=Time.get_ticks_usec();var ms: float=(now-previous)*.001;previous=now;samples.append(ms)
			if rendered_frames!=last_draw:draw_time=now;last_draw=rendered_frames
			if now-draw_time>200000 or DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED:
				NavalStorage.write_json("res://work/afghan-ground-paired.json",{"valid":false,"reason":"Window not rendering; comparison discarded"});quit(2);return
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			if ms>33.:hitches.append({"unix":Time.get_unix_time_from_system(),"ms":ms,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.})
			var elapsed: float=(now-start)*.000001
			for i in actors.size():
				actors[i].rotation.y=sin(elapsed*.3+i)*.5
				actors[i].avatar_parts.leg_l.rotation.x=sin(elapsed*8.+i)*.25
				actors[i].avatar_parts.leg_r.rotation.x=-sin(elapsed*8.+i)*.25
		var total: float=samples.reduce(func(a,b):return a+b,0.);samples.sort();var count:=maxi(1,ceili(samples.size()*.01));var worst_sum:=0.
		for i in range(samples.size()-count,samples.size()):worst_sum+=samples[i]
		var row:={"index":index,"baked":baked,"fps":samples.size()*1000./total,"low":count*1000./worst_sum,"worst_ms":samples[-1],"gpu_ms":gpu/samples.size(),"hitches":hitches}
		reports.append(row);print("GROUND_PAIRED ",index," ",baked," FPS=",row.fps," LOW=",row.low," WORST=",row.worst_ms)
	NavalStorage.write_json("res://work/afghan-ground-paired.json",{"valid":true,"resolution":[1920,1080],"actors":18,"seed":712907,"samples":reports})

func diagnose() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var rows: Array=[]
	var plain:=StandardMaterial3D.new();plain.albedo_color=Color("827968");plain.roughness=1.
	var original: Material=map.terrain_material
	for variant in ["normal","ground_plain","normal","no_shadows","normal","no_actors","normal"]:
		for body in map.get_children():
			if str(body.name).begins_with("AfghanTerrain_"):
				body.get_node("Surface").material_override=plain if variant=="ground_plain" else original
		lights.sun.shadow_enabled=variant!="no_shadows"
		for actor in actors: actor.visible=variant!="no_actors"
		await create_timer(2.).timeout
		var times: Array[float]=[];var gpu:=0.;var cpu:=0.;var start:=Time.get_ticks_usec();var previous:=start
		while Time.get_ticks_usec()-start<8000000:
			await process_frame
			var now:=Time.get_ticks_usec();times.append((now-previous)*.001);previous=now
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		var total: float=times.reduce(func(a,b):return a+b,0.);times.sort()
		var row:={"variant":variant,"fps":times.size()*1000./total,"worst_ms":times[-1],"gpu_ms":gpu/times.size(),"render_cpu_ms":cpu/times.size(),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		rows.append(row);print("PROBE ",JSON.stringify(row))
	NavalStorage.write_json("res://work/"+label+"-probe.json",{"samples":rows})
