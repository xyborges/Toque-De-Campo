extends SceneTree
const Afghan = preload("res://modes/battle_royale/map/afghan_map.gd")
const Atmosphere = preload("res://modes/battle_royale/map/afghan_atmosphere.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var scene := Node3D.new()
	root.add_child(scene)
	Atmosphere.install(scene)
	var map := Afghan.new()
	scene.add_child(map)
	var start_ms := Time.get_ticks_msec()
	map.build()
	var camera := Camera3D.new()
	camera.far = 5000.0
	camera.fov = 72.0
	scene.add_child(camera)
	camera.make_current()
	var before := "--afghan-density-stage2-before" in OS.get_cmdline_user_args()
	var label := "before" if before else "after"
	var sites := [[Vector2(-175, 150), Vector2(-260, 70), 22.0], [Vector2(-50, 210), Vector2(30, 110), 18.0], [Vector2(-825, 300), Vector2(-260, 70), 32.0]]
	for i in sites.size():
		var camera_p: Vector2 = sites[i][0]
		var focus_p: Vector2 = sites[i][1]
		var elevation: float = sites[i][2]
		camera.position = map.point(camera_p.x, camera_p.y) + Vector3.UP * elevation
		var focus: Vector3 = map.point(focus_p.x, focus_p.y) + Vector3.UP * 2.0
		camera.look_at(focus)
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://work/afghan-stage2-" + label + "-view" + str(i) + ".png"
		var save_error := root.get_texture().get_image().save_png(output)
		print("AFGHAN_STAGE2_SCREEN ", output, " result=", save_error)
		print("AFGHAN_STAGE2_DRAWS view=", i, " count=", RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	print("AFGHAN_STAGE2_VISUAL ", JSON.stringify({"before":before,"elapsed_ms":Time.get_ticks_msec()-start_ms,"density":map.get_meta("afghan_density_stage2",{})}))
	scene.free()
	quit()
