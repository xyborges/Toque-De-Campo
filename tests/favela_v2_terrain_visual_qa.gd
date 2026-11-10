extends SceneTree
## Capturas 3D do terreno físico da V2 usando Godot Forward+/GTX 1650.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:=Node3D.new()
	world.name="FavelaV2WorldBlockout"
	root.add_child(world)
	var metrics:=T.build(world,true)
	var sky:=Sky.new()
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("#7ba6d6")
	sky_material.sky_horizon_color=Color("#c1d7e8")
	sky_material.ground_bottom_color=Color("#756f62")
	sky.sky_material=sky_material
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_SKY
	environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy=.38
	var env:=WorldEnvironment.new()
	env.environment=environment
	world.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-46.0,-33.0,0.0)
	sun.light_energy=.82
	world.add_child(sun)
	var cam:=Camera3D.new()
	cam.fov=72.0
	cam.far=1400.0
	world.add_child(cam)
	cam.make_current()
	var shots: Array[Dictionary]=[
		{"name":"geral","from":Vector2(-350,260),"to":Vector2(40,-55),"alt":240.0,"target_alt":12.0},
		{"name":"morro_esquerdo","from":Vector2(-385,0),"to":Vector2(-265,-80),"alt":92.0,"target_alt":4.0},
		{"name":"portao_central","from":Vector2(-98,36),"to":Vector2(-230,5),"alt":29.0,"target_alt":6.0}
	]
	var files:=0
	for i in shots.size():
		var shot: Dictionary=shots[i]
		var start: Vector2=shot["from"]
		var target: Vector2=shot["to"]
		cam.global_position=Vector3(start.x,T.height_at(start.x,start.y)+float(shot["alt"]),start.y)
		cam.look_at(Vector3(target.x,T.height_at(target.x,target.y)+float(shot["target_alt"]),target.y))
		for frame in 24:await process_frame
		await RenderingServer.frame_post_draw
		var path: String="res://work/favela-v2-terreno-"+str(shot["name"])+".png"
		var error:=root.get_texture().get_image().save_png(path)
		if error==OK:files+=1
		print("FAVELA_V2_TERRAIN_VIEW ",JSON.stringify({"path":ProjectSettings.globalize_path(path),
			"saved":error,"image":shot["name"]}))
	print("FAVELA_V2_TERRAIN_VISUAL_QA ",JSON.stringify({
		"pass":files==shots.size(),"images_saved":files,
		"chunks":metrics.chunks,"triangles":metrics.terrain_triangles,
		"road_triangles":metrics.road_visual_triangles}))
	world.queue_free()
	quit(0 if files==shots.size() else 1)
