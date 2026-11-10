extends SceneTree
## Captures of the actual Godot Forward+ V2, not generated concept art.
const W=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	DisplayServer.window_set_size(Vector2i(1440,810))
	root.content_scale_size=Vector2i(1440,810)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var scene:=Node3D.new()
	scene.name="FavelaV2DensidadeReal"
	root.add_child(scene)
	var result:Dictionary=W.build(scene,true)
	var ambience:=Environment.new()
	var sky:=Sky.new()
	var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("#6f9fbf")
	sky_mat.sky_horizon_color=Color("#d0dfeb")
	sky_mat.ground_bottom_color=Color("#6a6f64")
	sky.sky_material=sky_mat
	ambience.sky=sky
	ambience.background_mode=Environment.BG_SKY
	ambience.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	ambience.ambient_light_energy=.62
	var env:=WorldEnvironment.new()
	env.environment=ambience
	scene.add_child(env)
	var sunlight:=DirectionalLight3D.new()
	sunlight.rotation_degrees=Vector3(-42,-36,0)
	sunlight.light_energy=1.0
	scene.add_child(sunlight)
	var camera:=Camera3D.new()
	camera.fov=70
	camera.far=1200
	scene.add_child(camera)
	camera.make_current()
	var shots:Array[Dictionary]=[
		{"id":"geral","from":Vector2(145,301),"look":Vector2(-75,-109),
			"height":245.0,"target":17.0},
		{"id":"becos","from":Vector2(-122,102),"look":Vector2(-15,-42),
			"height":64.0,"target":10.0},
		{"id":"morro-oeste","from":Vector2(-285,-90),"look":Vector2(-194,-185),
			"height":93.0,"target":28.0}
	]
	var saved:=0
	for shot:Dictionary in shots:
		var from:Vector2=shot["from"]
		var to:Vector2=shot["look"]
		camera.global_position=Vector3(from.x,T.height_at(from.x,from.y)+float(shot["height"]),from.y)
		camera.look_at(Vector3(to.x,T.height_at(to.x,to.y)+float(shot["target"]),to.y))
		for j in 40:await process_frame
		await RenderingServer.frame_post_draw
		var path: String="res://work/favela-v2-densidade-"+str(shot["id"])+".png"
		var code:=root.get_texture().get_image().save_png(path)
		if code==OK:saved+=1
		print("FAVELA_V2_DENSITY_CAPTURE ",JSON.stringify({
			"id":shot["id"],"saved":code,
			"path":ProjectSettings.globalize_path(path)}))
	print("FAVELA_V2_DENSITY_VISUAL_QA ",JSON.stringify({
		"pass":saved==shots.size(),"screenshots":saved,
		"main_houses":result["main"]["main_houses"],
		"west_houses":result["west"]["houses"],
		"alleys":result["alleys_and_details"]["passages"],
		"foliage":result["alleys_and_details"]["foliage_instances"],
		"foliage_batches":result["alleys_and_details"]["foliage_batches"],
		"mountain_shapes":result["alleys_and_details"]["rock_crest_colliders"],
		"occluders":result["visual_policy"]["occluders"]}))
	scene.queue_free()
	quit(0 if saved==shots.size() else 1)
