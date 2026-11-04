extends SceneTree
const LIB:="res://modes/war/library/"
var reports: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func own_all(root_node: Node,node: Node) -> void:
	for child in node.get_children():
		child.owner=root_node
		if child.scene_file_path.is_empty(): own_all(root_node,child)
func save_scene(node: Node,path: String,own:=true) -> void:
	if own: own_all(node,node)
	var packed:=PackedScene.new();var error:=packed.pack(node)
	assert(error==OK,"pack failed: "+path)
	error=ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS if path.ends_with(".scn") else 0)
	assert(error==OK,"save failed: "+path)
func externalize(node: Node,id: String) -> void:
	var count:=0
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh.resource_path.is_empty():
			ResourceSaver.save(mesh.mesh,LIB+"meshes/"+id+"_%02d.res"%count,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
			count+=1
		if mesh.material_override and mesh.material_override.resource_path.is_empty():
			var mat:=mesh.material_override
			ResourceSaver.save(mat,LIB+"materials/"+id+"_%02d.tres"%count,ResourceSaver.FLAG_CHANGE_PATH);count+=1
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIB+"meshes"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIB+"materials"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://editor/war"))
	if "--map-reference-only" in OS.get_cmdline_user_args(): await map_reference();quit();return
	for id in WarPrefabFactory.ITEMS:
		var path: String=LIB+id+".tscn"
		# Ordinary user-edited scenes are never regenerated implicitly.
		if FileAccess.file_exists(path) and not "--replace-library" in OS.get_cmdline_user_args() and not ("--replace-new" in OS.get_cmdline_user_args() and id in WarInfrastructureFactory.ITEMS) and not ("--replace-details" in OS.get_cmdline_user_args() and id in WarDevastationFactory.ITEMS): continue
		var prefab:=WarPrefabFactory.create(id);root.add_child(prefab)
		externalize(prefab,id);save_scene(prefab,path)
		reports.append({"id":id,"meshes":prefab.find_children("*","MeshInstance3D",true,false).size(),"colliders":prefab.find_children("*","CollisionShape3D",true,false).size()})
		prefab.free()
	if "--prefabs-only" in OS.get_cmdline_user_args(): print("PREFABS_READY ",reports.size());quit();return
	var fixture=load("res://tests/war_optics_fixture.gd").new();root.add_child(fixture)
	fixture.vehicle_system.set_process(false);fixture.set_process(false)
	var actor:=fixture.local_player as WarPlayer
	actor.apply_identity(0,"soldier");actor.weapon_id="fal";actor._refresh_weapon();actor._update_weapon_pose();actor._animate_walk()
	for team in 2:
		actor.apply_identity(team,"soldier")
		actor.weapon_id="fal" if team==0 else "glock";actor._refresh_weapon();actor._update_weapon_pose();actor._animate_walk()
		var soldier:=Node3D.new();soldier.name="SoldadoEquipe"+str(team+1)
		var body:=actor.body_root.duplicate() as Node3D;soldier.add_child(body)
		var weapon:=actor.weapon_root.duplicate() as Node3D;soldier.add_child(weapon)
		for area: Area3D in soldier.find_children("*","Area3D",true,false): area.free()
		root.add_child(soldier);bake_poses(actor,soldier);externalize(soldier,"soldier"+str(team));save_scene(soldier,LIB+"soldado_equipe_"+str(team+1)+".tscn");soldier.free()
	for id in ["fal","glock"]:
		var model: Node3D=FALModel.create() if id=="fal" else GlockModel.create()
		root.add_child(model);externalize(model,id);save_scene(model,LIB+id+"_referencia.tscn");model.free()
	var vehicle: WarVehicle=fixture.vehicle_system.vehicles.v_guarani
	if vehicle.find_children("*","MeshInstance3D",true,false).is_empty(): vehicle.build_model()
	var shell:=Node3D.new();shell.name="GuaraniReferencia"
	for child in vehicle.get_children():
		if child is CollisionShape3D or child is Marker3D: continue
		var copy:=child.duplicate();shell.add_child(copy)
		for area: CollisionObject3D in copy.find_children("*","CollisionObject3D",true,false): area.free()
	root.add_child(shell);externalize(shell,"guarani");save_scene(shell,LIB+"guarani_referencia.tscn");shell.free()
	fixture.queue_free();await process_frame
	gallery()
	if "--map-reference" in OS.get_cmdline_user_args(): await map_reference()
	NavalStorage.write_json("res://work/art188-library-build.json",{"objects":reports})
	print("ART_LIBRARY_READY ",reports.size());quit()

func bake_poses(actor: WarPlayer,soldier: Node3D) -> void:
	var player:=AnimationPlayer.new();player.name="Poses";soldier.add_child(player)
	var library:=AnimationLibrary.new()
	for id in ["mira","inclinar","recarregar"]:
		var animation:=Animation.new();animation.length=float(GameWeapons.ITEMS[actor.weapon_id].reload) if id=="recarregar" else 6.
		animation.loop_mode=Animation.LOOP_LINEAR
		var nodes: Array[Node3D]=[actor.body_root,actor.weapon_root]
		nodes.append_array(actor.body_root.find_children("*","Node3D",true,false))
		nodes.append_array(actor.weapon_root.find_children("*","Node3D",true,false))
		var tracks: Dictionary={}
		for node in nodes:
			if node is Area3D or node is CollisionShape3D or node is Marker3D: continue
			var path: String=String(actor.get_path_to(node))
			if not soldier.has_node(path): continue
			var track:=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,NodePath(path+":transform"));tracks[node]=track
		for frame in int(animation.length*20)+1:
			var time:=frame/20.;var t:=time/animation.length
			actor.pitch=sin(t*TAU)*.65 if id=="mira" else 0.
			actor.lean=sin(t*TAU) if id=="inclinar" else 0.
			actor.reload_weapon=actor.weapon_id if id=="recarregar" else ""
			actor.reload_total=animation.length;actor.reload_left=animation.length-time if id=="recarregar" else 0.
			actor._animate_walk()
			for node: Node3D in tracks: animation.track_insert_key(tracks[node],time,node.transform)
		library.add_animation(id,animation)
	player.add_animation_library("",library)
	actor.pitch=0;actor.lean=0;actor.reload_left=0;actor.reload_weapon="";actor._animate_walk()
func instance(parent: Node3D,id: String,point: Vector3,rotation_y:=0.) -> Node3D:
	var item: Node3D=load(LIB+id+".tscn").instantiate();item.position=point;item.rotation.y=rotation_y;parent.add_child(item);item.owner=parent;return item
func gallery() -> void:
	var scene:=Node3D.new();scene.name="BibliotecaGuerra"
	root.add_child(scene)
	var floor:=WarPrefabFactory.box(scene,"Piso",Vector3(0,-.15,0),Vector3(120,.30,110),"concrete",true)
	floor.material_override=WarArtStyle.material("concrete")
	for entry in [["soldado_equipe_1",Vector3(-2.,0.,0.)],["soldado_equipe_2",Vector3(0.,0.,0.)],["guarani_referencia",Vector3(8.,0.,1.)],["container_20ft",Vector3(-10.,0.,-8.)],["pinheiro",Vector3(-15.,0.,-11.)],["arvore_queimada",Vector3(-18.,0.,-6.)],["trincheira_6m",Vector3(1.,0.,-12.)],["escada_4m",Vector3(-5.,0.,-14.)],["estrada_12m",Vector3(16.,0.,-14.)],["cais_8m",Vector3(13.,0.,12.)],["casa_ruina",Vector3(-13.,0.,10.)],["barreira_concreto",Vector3(-2.,0.,6.)]]:
		var object: Node3D=load(LIB+entry[0]+".tscn").instantiate();object.position=entry[1];scene.add_child(object)
		object.owner=scene
	for entry in [["estrada_curva_90",Vector3(-32.,0.,-23.)],["estrada_cruzamento",Vector3(-8.,0.,-30.)],["estrada_entroncamento",Vector3(8.,0.,-30.)],["estrada_rampa_12m",Vector3(24.,0.,-30.)],["cais_curva_90",Vector3(-32.,0.,26.)],["cais_rampa_8m",Vector3(-8.,0.,20.)],["trincheira_escavavel_6m",Vector3(28.,1.5,12.)]]:
		instance(scene,entry[0],entry[1])
	for entry in [["fachada_atingida",Vector3(-30.,0.,-44.)],["carro_carbonizado",Vector3(-10.,0.,-44.)],["carga_portuaria",Vector3(10.,0.,-44.)],["entulho_tijolos",Vector3(30.,0.,-44.)],["defensa_portuaria",Vector3(-30.,0.,36.)],["laje_desabada",Vector3(-10.,0.,36.)],["canaleta_danificada",Vector3(10.,0.,36.)],["cratera_impacto",Vector3(30.,0.,36.)]]:
		instance(scene,entry[0],entry[1])
	var sun:=DirectionalLight3D.new();sun.name="Luz";sun.rotation_degrees=Vector3(-38,-30,0);sun.light_color=Color("e0ddcf");sun.light_energy=1.35;sun.shadow_enabled=true;scene.add_child(sun)
	var env:=WorldEnvironment.new();env.name="Ambiente";env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("899497");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b7c0bd");env.environment.ambient_light_energy=.55;scene.add_child(env)
	var camera:=Camera3D.new();camera.name="Camera";scene.add_child(camera);camera.position=Vector3(-2,3.7,9);camera.look_at(Vector3(0,1.,0));camera.current=true
	scene.set_script(load("res://editor/war/gallery_view.gd"))
	for child in scene.get_children():
		child.owner=scene
		if child is StaticBody3D: own_all(scene,child)
		if child is MeshInstance3D: continue
	# Instanced library descendants retain their own scene ownership.
	save_scene(scene,"res://editor/war/biblioteca.tscn",false)
	scene.free()
func map_reference() -> void:
	# Reference only: never exported or loaded by the game. The runtime map
	# keeps its proven sector batching, LOD and authoritative colliders.
	var holder:=Node3D.new();holder.name="ReferenciaDoMundo";holder.set_meta("authoring_reference",true);root.add_child(holder)
	WarWorld.build(holder,true)
	var variation:=WarTerrain.material.get_shader_parameter("variation") as NoiseTexture2D
	if variation and variation.get_image(): WarTerrain.material.set_shader_parameter("variation",ImageTexture.create_from_image(variation.get_image()))
	for object: Node in holder.find_children("*","Node",true,false):
		if not is_instance_valid(object): continue
		if object is WarVehicle or object is WarWeather: object.free();continue
		if object is CollisionShape3D: object.free();continue
		if object is StaticBody3D and object.get_child_count()==0: object.free()
	var sea:=MeshInstance3D.new();sea.name="Mar";var plane:=PlaneMesh.new();plane.size=Vector2(7500,7500);sea.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("365960");mat.roughness=.33;sea.material_override=mat;holder.add_child(sea)
	save_scene(holder,"res://editor/war/referencia_mundo.scn")
	holder.free();print("MAP_REFERENCE_READY")
	var heights:=Image.create(701,701,false,Image.FORMAT_RF)
	for z in 701:
		for x in 701: heights.set_pixel(x,z,Color(WarTerrain.height_at(x*5.-1750,z*5.-1750),0,0,1))
	ResourceSaver.save(heights,"res://editor/war/terrain_height.res",ResourceSaver.FLAG_COMPRESS)
