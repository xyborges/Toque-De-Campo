extends SceneTree
## A/B Forward+ GPU: exact same V2 houses, lights, camera and authoritative
## collision; optional Terrain3D renderer + optional real ProtonScatter shrubs.
const WORLD=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const SCAT=preload("res://tests/favela_v2_scatter_pilot.gd")
const GRID:=256
const SPACING:=4.0
const SAMPLES:=120
var camera:Camera3D
func _initialize()->void:
	_run.call_deferred()

func _measure(src:Vector2,dst:Vector2)->Dictionary:
	camera.global_position=Vector3(src.x,T.height_at(src.x,src.y)+7.0,src.y)
	camera.look_at(Vector3(dst.x,T.height_at(dst.x,dst.y)+6.0,dst.y))
	for i in 75:await process_frame
	var frame_times:Array[float]=[]
	var draws:Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for i in SAMPLES:
		await process_frame
		var t:=Time.get_ticks_usec()
		frame_times.append(float(t-previous)*.001)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		previous=t
	frame_times.sort()
	var sum:=0.0
	var draw_sum:=0.0
	for t in frame_times:sum+=t
	for dr in draws:draw_sum+=dr
	return {"mean_ms":snappedf(sum/SAMPLES,.02),
		"p50_ms":snappedf(frame_times[59],.02),
		"p95_ms":snappedf(frame_times[113],.02),
		"p99_ms":snappedf(frame_times[118],.02),
		"fps":snappedf(1000.0/maxf(sum/SAMPLES,.01),.1),
		"draw_calls":snappedf(draw_sum/SAMPLES,.1)}

func _run()->void:
	if DisplayServer.get_name()=="headless":
		push_error("Headless cannot benchmark terrain/GPU plugins")
		quit(2)
		return
	var args:=OS.get_cmdline_user_args()
	var terrain3d:=args.has("--terrain3d")
	var mode:="proton" if args.has("--proton") else ("native" if args.has("--native") else "none")
	var began:=Time.get_ticks_msec()
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:=Node3D.new()
	root.add_child(world)
	camera=Camera3D.new()
	camera.fov=72.0
	camera.far=950.0
	world.add_child(camera)
	camera.make_current()
	var baseline:Dictionary=WORLD.build(world,true)
	var base_build_ms:=Time.get_ticks_msec()-began
	var terrain_import_ms:=0
	var imported_regions:=0
	if terrain3d:
		var t0:=Time.get_ticks_msec()
		# Hide only the original 49 ground meshes. Original collision, roads,
		# houses, rock barricades and stairs remain IDENTICAL.
		var existing:=world.get_node("FavelaV2EstruturaAscensao/FavelaV2Terreno")
		for child:Node in existing.get_children():
			if child.name.begins_with("Celula_"):
				(child.get_node("TerrenoVisual") as GeometryInstance3D).visible=false
		var terrain:Node3D=ClassDB.instantiate("Terrain3D")
		terrain.name="Terrain3DRenderOnlyV2"
		terrain.set("region_size",GRID)
		terrain.set("vertex_spacing",SPACING)
		terrain.set("collision_mode",4)
		world.add_child(terrain)
		terrain.call("set_camera",camera)
		await process_frame
		var image:=Image.create(GRID,GRID,false,Image.FORMAT_RF)
		for z in GRID:
			for x in GRID:
				var qx:float=-512.0+float(x)*SPACING
				var qz:float=-512.0+float(z)*SPACING
				image.set_pixel(x,z,Color(T.height_at(qx,qz),0,0,1))
		var images:Array[Image]=[]
		images.resize(3)
		images[0]=image
		var data:Object=terrain.get("data")
		data.call("import_images",images,Vector3(-512,0,-512),0.0,1.0)
		imported_regions=data.call("get_regions_active").size()
		terrain_import_ms=Time.get_ticks_msec()-t0
	var scatter_ms:=0
	var shrubs:=0
	if mode!="none":
		var transforms:=SCAT.make_transforms()
		shrubs=transforms.size()
		var prop:Dictionary=SCAT.create_proton(world,transforms) if mode=="proton" else SCAT.create_native(world,transforms)
		scatter_ms=int(prop["build_ms"])
	var scene_build_ms:=Time.get_ticks_msec()-began
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-31,0)
	light.light_energy=1.0
	world.add_child(light)
	var ambience:=Environment.new()
	ambience.background_mode=Environment.BG_COLOR
	ambience.background_color=Color("#8798a8")
	ambience.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	ambience.ambient_light_color=Color("#bcbab2")
	ambience.ambient_light_energy=.44
	var sky:=WorldEnvironment.new()
	sky.environment=ambience
	world.add_child(sky)
	var views:Dictionary={}
	for id_pair in [["baixa","rua_baixa","praca"],["miolo","central_hub","mercadinho"],["alta","rua_norte","base_norte"]]:
		var src:Vector2=TOPO.NODES[id_pair[1]]["p"]
		var dst:Vector2=TOPO.NODES[id_pair[2]]["p"]
		views[str(id_pair[0])]=await _measure(src,dst)
	print("FAVELA_V2_TERRAIN_SCATTER_BENCH ",JSON.stringify({
		"pass":true,"terrain3d":terrain3d,"scatter":mode,"shrubs":shrubs,
		"original_houses":int(baseline["main"]["main_houses"])+int(baseline["west"]["houses"]),
		"original_terrain_phys_shapes":baseline["terrain"]["collision_shapes"],
		"terrain_regions":imported_regions,"terrain_import_ms":terrain_import_ms,
		"scatter_build_ms":scatter_ms,"original_v2_build_ms":base_build_ms,
		"combined_startup_ms":scene_build_ms,
		"renderer":"Forward+","gpu":RenderingServer.get_rendering_device().get_device_name(),
		"resolution":"1920x1080","views":views}))
	world.queue_free()
	await process_frame
	quit(0)
