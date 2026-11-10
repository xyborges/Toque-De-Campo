extends SceneTree
## Four Forward+ snapshots of the genuine South->North uphill profile.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
func _initialize()->void:
	_run.call_deferred()

func _marker(world:Node3D,id:String,color:Color)->void:
	var p:Vector2=TOPO.NODES[id]["p"]
	var height:float=T.height_at(p.x,p.y)
	var center:=Vector3(p.x,height,p.y)
	var base:=CylinderMesh.new()
	base.top_radius=3.3
	base.bottom_radius=3.3
	base.height=.28
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=.89
	var cyl:=MeshInstance3D.new()
	cyl.name="PreviewBase_"+id
	cyl.mesh=base
	cyl.material_override=mat
	cyl.position=center+Vector3.UP*.20
	world.add_child(cyl)
	var pole:=CylinderMesh.new()
	pole.top_radius=.095
	pole.bottom_radius=.095
	pole.height=7.0
	var m:=MeshInstance3D.new()
	m.mesh=pole
	m.material_override=mat
	m.position=center+Vector3.UP*3.6
	world.add_child(m)

func _run()->void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:=Node3D.new()
	root.add_child(world)
	var ground:=T.build(world,true)
	var built:=WEST.build(world,true)
	var houses:Node=world.get_node("FavelaV2MorroEsquerdo/ResidenciasEscalonadas")
	var detail_count:=0
	var unexpected_colliders:=0
	var variants:Dictionary={}
	for house:Node in houses.get_children():
		var code:=str(house.get_meta("house_variant",-1))
		variants[code]=int(variants.get(code,0))+1
		var physical_body:=house.get_node("Body") as StaticBody3D
		if physical_body.collision_layer!=1:unexpected_colliders+=1
		for child:Node in house.get_children():
			if not str(child.name).begins_with("Reuso_"):continue
			detail_count+=1
			for collision:CollisionObject3D in child.find_children("*","CollisionObject3D",true,false):
				if collision.collision_layer!=0:unexpected_colliders+=1
	_marker(world,"base_sul",Color("#262b32"))
	_marker(world,"base_norte",Color("#d64045"))
	var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("#719bca")
	sky_mat.sky_horizon_color=Color("#c1d1df")
	var sky:=Sky.new()
	sky.sky_material=sky_mat
	var en:=Environment.new()
	en.background_mode=Environment.BG_SKY
	en.sky=sky
	en.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	en.ambient_light_energy=.48
	var settings:=WorldEnvironment.new()
	settings.environment=en
	world.add_child(settings)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-43,-28,0)
	sun.light_energy=.95
	world.add_child(sun)
	var camera:=Camera3D.new()
	camera.fov=75.0
	camera.far=1450.0
	world.add_child(camera)
	camera.make_current()
	var shots:Array[Dictionary]=[
		{"id":"visao-do-vale","from":Vector2(-275,265),"to":Vector2(-205,-175),"alt":88.0,"target_alt":17.0},
		{"id":"topo-traficantes","from":Vector2(-320,-270),"to":Vector2(-198,75),"alt":64.0,"target_alt":1.0},
		{"id":"morro-esquerdo","from":Vector2(-380,110),"to":Vector2(-266,-85),"alt":105.0,"target_alt":6.0},
		{"id":"casas-reutilizadas","from":Vector2(-260,83),"to":Vector2(-307,-20),"alt":39.0,"target_alt":7.0}
	]
	var saved:=0
	for shot:Dictionary in shots:
		var a:Vector2=shot["from"]
		var b:Vector2=shot["to"]
		if str(shot["id"])=="casas-reutilizadas" and houses.get_child_count()>8:
			var home:=houses.get_child(8) as Node3D
			camera.global_position=home.global_transform*Vector3(0,6.8,17)
			camera.look_at(home.global_transform*Vector3(0,3.1,0))
		else:
			camera.global_position=Vector3(a.x,T.height_at(a.x,a.y)+float(shot["alt"]),a.y)
			camera.look_at(Vector3(b.x,T.height_at(b.x,b.y)+float(shot["target_alt"]),b.y))
		for frame in 22:await process_frame
		await RenderingServer.frame_post_draw
		var path:String="res://work/favela-v2-uphill-"+str(shot["id"])+".png"
		var err:=root.get_texture().get_image().save_png(path)
		if err==OK:saved+=1
		print("FAVELA_V2_UPHILL_VIEW ",JSON.stringify({
			"id":shot["id"],"saved":err,"path":ProjectSettings.globalize_path(path)}))
	var model_ok:bool=(detail_count==int(built.reused_facade_modules)
		and unexpected_colliders==0 and variants.size()==5)
	print("FAVELA_V2_UPHILL_VISUAL_QA ",JSON.stringify({
		"pass":saved==shots.size() and model_ok,"screenshots":saved,
		"build":built,"terrain_chunks":ground.chunks,
		"police_height":T.NODE_HEIGHTS["base_sul"],
		"trafficker_height":T.NODE_HEIGHTS["base_norte"],
		"verified_reused_details":detail_count,
		"unexpected_detail_colliders":unexpected_colliders,
		"verified_variants":variants.size()}))
	world.queue_free()
	quit(0 if saved==shots.size() and model_ok else 1)
