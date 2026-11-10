extends SceneTree
## GPU A/B pilot. Use in a SEPARATE Godot process with 1080p and no competing workload.
const Map=preload("res://modes/war/scripts/favela_map.gd")
const SAMPLES:=180
var world: Node3D
var camera: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func _sample(p: Vector3,target: Vector3) -> Dictionary:
	camera.global_position=p
	camera.look_at(target,Vector3.UP)
	for i in 60: await process_frame
	var durations: Array[float]=[]
	var draws: Array[float]=[]
	var prior:=Time.get_ticks_usec()
	for i in SAMPLES:
		await process_frame
		var now:=Time.get_ticks_usec()
		durations.append(float(now-prior)*.001)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prior=now
	durations.sort()
	var sum:=0.0
	var draw_sum:=0.0
	for t in durations:sum+=t
	for n in draws:draw_sum+=n
	var mean:=sum/maxf(durations.size(),1)
	return {"mean_ms":snappedf(mean,.01),"fps":snappedf(1000./maxf(mean,.01),.01),
		"p50_ms":durations[89],"p95_ms":durations[170],"p99_ms":durations[178],
		"draw_calls_mean":snappedf(draw_sum/maxf(draws.size(),1),.1)}

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Requires a real GPU and a graphical display; headless is not evidence of occlusion performance")
		quit(2)
		return
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var enabled:=OS.get_cmdline_user_args().has("--favela-occlusion-pilot")
	root.get_viewport().use_occlusion_culling=enabled
	world=Node3D.new()
	root.add_child(world)
	var map:=Map.new() as WarFavelaMap
	map.render_visuals=true
	world.add_child(map)
	var began:=Time.get_ticks_msec()
	map.build()
	var build_ms:=Time.get_ticks_msec()-began
	camera=Camera3D.new()
	world.add_child(camera)
	camera.current=true
	camera.far=1700.
	var results: Dictionary={}
	for location: Vector2 in [Vector2(-320,180),Vector2(0,0),Vector2(350,-310)]:
		var y:=Map.height_at(location.x,location.y)
		var at:=Vector3(location.x,y+6.,location.y)
		var look:=Vector3(location.x+80.,Map.height_at(location.x+80.,location.y-80.)+8.,location.y-80.)
		results[str(location)]=await _sample(at,look)
	print("FAVELA_OCCLUSION_BENCH ",JSON.stringify({
		"enabled":enabled,"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"screen":"1920x1080","build_ms":build_ms,
		"occluder_count":map.find_children("*","OccluderInstance3D",true,false).size(),
		"map_build":map.build_metrics,"views":results
	}))
	world.queue_free()
	await process_frame
	quit(0)
