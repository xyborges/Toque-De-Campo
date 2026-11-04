extends SceneTree
const Afghan = preload("res://modes/battle_royale/map/afghan_map.gd")
const Atmosphere = preload("res://modes/battle_royale/map/afghan_atmosphere.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var world := Node3D.new()
	root.add_child(world)
	Atmosphere.install(world)
	var map := Afghan.new()
	world.add_child(map)
	var started := Time.get_ticks_msec()
	map.build()
	var cam := Camera3D.new()
	cam.far = 4500.0
	cam.fov = 74.0
	world.add_child(cam)
	cam.make_current()
	var before := "--afghan-density-stage3-before" in OS.get_cmdline_user_args()
	var label := "before" if before else "after"
	var sites := [[Vector2(-290, 150), Vector2(-260, 70), 15.0], [Vector2(-410, 620), Vector2(-340, 570), 12.0], [Vector2(365, -470), Vector2(450, -510), 18.0]]
	for i in sites.size():
		var at: Vector2 = sites[i][0]
		var looking: Vector2 = sites[i][1]
		var up: float = sites[i][2]
		cam.position = map.point(at.x, at.y) + Vector3.UP * up
		cam.look_at(map.point(looking.x, looking.y) + Vector3.UP * 2.0)
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://work/afghan-stage3-" + label + "-view" + str(i) + ".png"
		var saved := root.get_texture().get_image().save_png(path)
		var draws := RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		print("AFGHAN_STAGE3_VIEW ", JSON.stringify({"index":i,"before":before,"image":path,"saved":saved,"draws":draws}))
	print("AFGHAN_STAGE3_VISUAL ", JSON.stringify({"before":before,"build_elapsed_ms":Time.get_ticks_msec()-started,"stage3":map.get_meta("afghan_density_stage3",{})}))
	world.free()
	quit()
