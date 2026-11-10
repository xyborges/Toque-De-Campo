extends SceneTree
## Forward+ visual preview: first populated sector, not public War map.
const TERRAIN=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:=Node3D.new()
	world.name="FavelaV2PrimeiroBairro"
	root.add_child(world)
	var terrain_metrics:=TERRAIN.build(world,true)
	var west_metrics:=WEST.build(world,true)
	var environment:=Environment.new()
	var sky:=Sky.new()
	var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("#6e99c7")
	sky_mat.sky_horizon_color=Color("#c5d8ec")
	sky_mat.ground_bottom_color=Color("#797368")
	sky.sky_material=sky_mat
	environment.background_mode=Environment.BG_SKY
	environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy=.38
	var env:=WorldEnvironment.new()
	env.environment=environment
	world.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-46,-35,0)
	sun.light_energy=.85
	world.add_child(sun)
	var cam:=Camera3D.new()
	cam.fov=72.0
	cam.far=1300.0
	world.add_child(cam)
	cam.make_current()
	var shots: Array[Dictionary]=[
		{"name":"bairro-geral","from":Vector2(-395,145),"to":Vector2(-255,-68),"alt":145.0,"target_alt":12.0},
		{"name":"escadao","from":Vector2(-248,89),"to":Vector2(-317,12),"alt":35.0,"target_alt":5.0},
		{"name":"miolo-entrada","from":Vector2(-88,38),"to":Vector2(-225,10),"alt":30.0,"target_alt":4.0},
		{"name":"plato-mirante","from":Vector2(-375,-184),"to":Vector2(-285,-108),"alt":55.0,"target_alt":3.0}
	]
	var saved:=0
	for i in shots.size():
		var shot:Dictionary=shots[i]
		var a:Vector2=shot["from"]
		var b:Vector2=shot["to"]
		cam.global_position=Vector3(a.x,TERRAIN.height_at(a.x,a.y)+float(shot["alt"]),a.y)
		cam.look_at(Vector3(b.x,TERRAIN.height_at(b.x,b.y)+float(shot["target_alt"]),b.y))
		for frame in 18:await process_frame
		await RenderingServer.frame_post_draw
		var file: String="res://work/favela-v2-"+str(shot["name"])+".png"
		var ok:=root.get_texture().get_image().save_png(file)
		if ok==OK:saved+=1
		print("FAVELA_V2_WEST_VIEW ",JSON.stringify({"path":ProjectSettings.globalize_path(file),
			"saved":ok,"id":shot["name"]}))
	print("FAVELA_V2_WEST_VISUAL_QA ",JSON.stringify({
		"pass":saved==shots.size(),"saved":saved,
		"west":west_metrics,"terrain_chunks":terrain_metrics.chunks}))
	world.queue_free()
	quit(0 if saved==shots.size() else 1)
