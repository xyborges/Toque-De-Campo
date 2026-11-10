extends SceneTree
## Genuine Forward+ Godot screenshots from the assembled physical V2 map.
const WORLD=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")

func _initialize()->void:
	_run.call_deferred()

func _marker(parent: Node3D,id: String,title: String,color: Color)->void:
	var p:Vector2=TOPO.NODES[id]["p"]
	var origin:=Vector3(p.x,T.height_at(p.x,p.y),p.y)
	var base:=CylinderMesh.new()
	base.top_radius=3.4
	base.bottom_radius=3.4
	base.height=.45
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=color
	paint.roughness=.85
	var shape:=MeshInstance3D.new()
	shape.mesh=base
	shape.material_override=paint
	shape.position=origin+Vector3.UP*.22
	parent.add_child(shape)
	var sign:=Label3D.new()
	sign.text=title
	sign.font_size=68
	sign.pixel_size=.077
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate=Color.WHITE
	sign.outline_modulate=Color("#181f23")
	sign.outline_size=11
	sign.no_depth_test=true
	sign.position=origin+Vector3.UP*9.0
	parent.add_child(sign)

func _run()->void:
	DisplayServer.window_set_size(Vector2i(1440,810))
	root.content_scale_size=Vector2i(1440,810)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var scene:=Node3D.new()
	scene.name="FavelaV2AscensaoReal"
	root.add_child(scene)
	var result:Dictionary=WORLD.build(scene,true)
	var env:=Environment.new()
	var sky:=Sky.new()
	var mat:=ProceduralSkyMaterial.new()
	mat.sky_top_color=Color("#78a6d2")
	mat.sky_horizon_color=Color("#d7e3ed")
	mat.ground_bottom_color=Color("#777368")
	sky.sky_material=mat
	env.sky=sky
	env.background_mode=Environment.BG_SKY
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy=.50
	var world_sky:=WorldEnvironment.new()
	world_sky.environment=env
	scene.add_child(world_sky)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-41,-26,0)
	sun.light_energy=.95
	scene.add_child(sun)
	_marker(scene,"base_sul","POLICIA  |  BASE BAIXA",Color("#1f343c"))
	_marker(scene,"base_norte","TRAFICANTES  |  TOPO",Color("#b93439"))
	for i in WORLD.STAGE_NODES.size():
		_marker(scene,WORLD.STAGE_NODES[i],WORLD.STAGE_LETTERS[i],Color("#cf7e44"))
	var camera:=Camera3D.new()
	camera.fov=68.0
	camera.far=1250.0
	scene.add_child(camera)
	camera.make_current()
	var shots:Array[Dictionary]=[
		{"id":"geral","from":Vector2(130,315),"look":Vector2(-80,-100),
			"height":235.0,"focus_height":12.0},
		{"id":"vale","from":Vector2(-230,305),"look":Vector2(-48,-122),
			"height":42.0,"focus_height":32.0},
		{"id":"meio","from":Vector2(258,100),"look":Vector2(-70,-115),
			"height":153.0,"focus_height":14.0},
		{"id":"topo","from":Vector2(-156,-322),"look":Vector2(20,-25),
			"height":124.0,"focus_height":18.0}
	]
	var saved:=0
	for shot:Dictionary in shots:
		var a:Vector2=shot["from"]
		var b:Vector2=shot["look"]
		camera.global_position=Vector3(a.x,T.height_at(a.x,a.y)+float(shot["height"]),a.y)
		camera.look_at(Vector3(b.x,T.height_at(b.x,b.y)+float(shot["focus_height"]),b.y))
		for f in 25:await process_frame
		await RenderingServer.frame_post_draw
		var output:String="res://work/favela-v2-ascensao-"+str(shot["id"])+".png"
		var code:=root.get_texture().get_image().save_png(output)
		if code==OK:saved+=1
		print("ASCENSAO_VIEW ",JSON.stringify({"id":shot["id"],"saved":code,
			"path":ProjectSettings.globalize_path(output)}))
	print("FAVELA_V2_ASCENSAO_VISUAL_QA ",JSON.stringify({
		"pass":saved==shots.size(),"screenshots":saved,
		"world_metrics":result}))
	scene.queue_free()
	quit(0 if saved==shots.size() else 1)
