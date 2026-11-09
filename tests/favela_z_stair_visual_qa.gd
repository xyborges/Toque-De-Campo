extends SceneTree
## Graphical regression captures of the western Z staircase (Forward+).
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var world:=Node3D.new()
	root.add_child(world)
	WarWorld.build(world,true)
	var cam:=Camera3D.new()
	cam.fov=73.0
	cam.far=1800.0
	world.add_child(cam)
	cam.make_current()
	var sites: Array=[
		[Vector2(-306,154),Vector2(-294,126),9.0],
		[Vector2(-303,109),Vector2(-277,78),4.6],
		[Vector2(-284,38),Vector2(-256,-15),4.4]
	]
	for i in sites.size():
		var from: Vector2=sites[i][0]
		var at: Vector2=sites[i][1]
		var elevation: float=sites[i][2]
		cam.global_position=WarFavelaMap.point(from.x,from.y)+Vector3.UP*elevation
		cam.look_at(WarFavelaMap.point(at.x,at.y)+Vector3.UP*1.4)
		for frame in 18:await process_frame
		await RenderingServer.frame_post_draw
		var output: String="res://work/favela-z-stair-view-"+str(i)+".png"
		var error:=root.get_texture().get_image().save_png(output)
		print("FAVELA_Z_STAIR_VIEW ",JSON.stringify({"image":output,"saved":error,"index":i}))
	world.queue_free()
	quit()
