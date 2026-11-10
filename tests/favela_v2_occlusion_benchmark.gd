extends SceneTree
## GPU-only AB sampling of V2 scene. Launch in separate foreground processes.
const WORLD=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const POLICY=preload("res://modes/war/scripts/favela_v2_visual_optimization.gd")
const SAMPLES:=150
var camera:Camera3D

func _initialize()->void:
	_run.call_deferred()

func _sample(where:Vector2,aim:Vector2)->Dictionary:
	camera.global_position=Vector3(where.x,T.height_at(where.x,where.y)+5.8,where.y)
	camera.look_at(Vector3(aim.x,T.height_at(aim.x,aim.y)+4.5,aim.y))
	for _w in 75:await process_frame
	var times:Array[float]=[]
	var draw_calls:Array[float]=[]
	var last:=Time.get_ticks_usec()
	for _i in SAMPLES:
		await process_frame
		var current:=Time.get_ticks_usec()
		times.append(float(current-last)*.001)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		last=current
	times.sort()
	var sum:=0.0
	var draws:=0.0
	for t in times:sum+=t
	for c in draw_calls:draws+=c
	var average:=sum/float(SAMPLES)
	return {"mean_ms":snappedf(average,.01),
		"fps":snappedf(1000.0/maxf(average,.01),.1),
		"p50_ms":snappedf(times[74],.01),
		"p95_ms":snappedf(times[142],.01),
		"p99_ms":snappedf(times[148],.01),
		"draw_calls_mean":snappedf(draws/float(SAMPLES),.1)}

func _run()->void:
	if DisplayServer.get_name()=="headless":
		push_error("Graphical GPU required. Headless FPS numbers are INVALID.")
		quit(2)
		return
	var enabled:=POLICY.enabled_by_command_line()
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:=Node3D.new()
	root.add_child(world)
	var began:=Time.get_ticks_msec()
	var built:Dictionary=WORLD.build(world,true)
	var build_ms:=Time.get_ticks_msec()-began
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.light_energy=1.0
	world.add_child(sun)
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#8695a4")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#b3b2b0")
	env.ambient_light_energy=.5
	var sky:=WorldEnvironment.new()
	sky.environment=env
	world.add_child(sky)
	camera=Camera3D.new()
	camera.fov=72.0
	camera.far=1000.0
	world.add_child(camera)
	camera.make_current()
	var views:Dictionary={}
	# Three street positions, not overhead screenshots; occlusion matters
	# when solid houses obstruct other houses, especially around bends.
	var shots: Array[Dictionary]=[
		{"id":"baixa","from":"rua_baixa","target":"praca"},
		{"id":"miolo","from":"central_hub","target":"mercadinho"},
		{"id":"alta","from":"rua_norte","target":"base_norte"}
	]
	for shot:Dictionary in shots:
		var src:Vector2=TOPO.NODES[str(shot["from"])]["p"]
		var dst:Vector2=TOPO.NODES[str(shot["target"])]["p"]
		views[str(shot["id"])]=await _sample(src,dst)
	var policy:Dictionary=built["visual_policy"]
	print("FAVELA_V2_OCCLUSION_BENCH ",JSON.stringify({
		"enabled":enabled,
		"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"resolution":"1920x1080","build_ms":build_ms,
		"occluders":policy.occluders,"lod_details":policy.lod_details,
		"houses":policy.houses,"cell_m":policy.cell_m,
		"views":views}))
	world.queue_free()
	await process_frame
	quit(0)
