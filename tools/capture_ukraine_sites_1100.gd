extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	var world:=Node3D.new();root.add_child(world);WarWorld.build(world,true)
	world.get_node("WarWeather").set_process(false)
	var camera:=Camera3D.new();camera.far=1800;camera.near=.1;camera.fov=68;world.add_child(camera);camera.make_current()
	for entry in [["east-road",Vector3(870,38,370),Vector3(975,19,450)],["east-facade",Vector3(816,27,340),Vector3(862,12,355)],["west-facade",Vector3(-708,26,-218),Vector3(-732,20,-260)]]:
		camera.position=entry[1];camera.look_at(entry[2])
		for frame in 8:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/ukraine-1100-"+str(entry[0])+".png")
	print("UKRAINE_SITES_CAPTURED 3");world.free();await process_frame;await physics_frame;quit()
