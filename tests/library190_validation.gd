extends SceneTree
var checks:=0
var failures: Array[String]=[]
var timings: Dictionary={}
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)
func ray(point: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*8,point-Vector3.UP*12,1)
	return scene.get_world_3d().direct_space_state.intersect_ray(query)
func run() -> void:
	scene=Node3D.new();root.add_child(scene)
	check(WarPrefabFactory.ITEMS.size()==24,"catalogue contains twenty-four reusable objects")
	for id in WarInfrastructureFactory.ITEMS:
		var visual:=WarMapContent.instantiate(scene,WarPrefabFactory.PATH+id+".tscn",Vector3(-1000+checks*20,80,0),true)
		var server:=WarMapContent.instantiate(scene,WarPrefabFactory.PATH+id+".tscn",visual.position,false)
		var first:=visual.find_children("*","CollisionShape3D",true,false);var second:=server.find_children("*","CollisionShape3D",true,false)
		check(not first.is_empty() and first.size()==second.size(),id+" same collision count with/without rendering")
		check(server.find_children("*","GeometryInstance3D",true,false).is_empty(),id+" no render nodes on authority")
		for i in first.size(): check(first[i].global_transform.is_equal_approx(second[i].global_transform),id+" same collision transform")
		check(WarModuleSnap.sockets(visual).size()>=2,id+" has compatible end points")
		if id!="trincheira_escavavel_6m":
			for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
				if not mesh.mesh is ArrayMesh: continue
				for surface in mesh.mesh.get_surface_count():
					var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
					var valid:=true
					for t in range(0,indices.size(),3):
						var a:=indices[t];var b:=indices[t+1];var c:=indices[t+2]
						if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a])>.00001: valid=false;break
					check(valid,id+" visible faces have outward clockwise winding")
		visual.queue_free();server.queue_free()
	var straight:=load(WarPrefabFactory.PATH+"estrada_12m.tscn").instantiate() as Node3D;scene.add_child(straight);straight.owner=scene
	var curved:=load(WarPrefabFactory.PATH+"estrada_curva_90.tscn").instantiate() as Node3D;scene.add_child(curved);curved.owner=scene;curved.position=Vector3(0,0,-11)
	var snap:=WarModuleSnap.nearest(curved,scene)
	check(not snap.is_empty(),"curve finds nearby straight end")
	curved.global_transform=snap.transform
	check(snap.source.global_position.distance_to(snap.target.global_position)<.001,"connector positions coincide")
	check(snap.source.global_basis.z.dot(snap.target.global_basis.z)<-.999,"connectors face opposite directions")
	curved.scale=Vector3(1.2,1,1.4);straight.scale=Vector3(.9,1,1.7)
	snap=WarModuleSnap.nearest(curved,scene);var original_scale:=curved.global_basis.get_scale();curved.global_transform=snap.transform
	check(curved.global_basis.get_scale().is_equal_approx(original_scale),"snapping preserves the moving module's scale")
	check(snap.source.global_position.distance_to(snap.target.global_position)<.001,"scaled modules still connect at the exact end point")
	straight.queue_free();curved.queue_free()
	var ramp:=load(WarPrefabFactory.PATH+"estrada_rampa_12m.tscn").instantiate() as Node3D;ramp.position=Vector3(30,10,0);scene.add_child(ramp)
	await physics_frame;await physics_frame
	for z in [-5.5,-3.,0.,3.,5.5]:
		var hit:=ray(Vector3(30,10,z));var expected: float=10+1.5*(6-z)/12
		check(not hit.is_empty() and absf(Vector3(hit.position).y-expected)<.003,"ramp collision follows the sloping surface")
	ramp.queue_free();await process_frame
	for angle in [0.,.37,PI*.5]:
		WarTerrainEdits.configure([])
		var at:=Vector3(350,WarTerrain.height_at(350,350),350)
		var uncut:=at.y
		var trench:=load(WarPrefabFactory.PATH+"trincheira_escavavel_6m.tscn").instantiate() as WarTrenchModule;trench.position=at;trench.rotation.y=angle
		var records:=WarTerrainEdits.collect(trench,Transform3D.IDENTITY,[]);trench.free();WarTerrainEdits.configure(records)
		check(records.size()==1,"trench supplies one excavation, not two nested ones")
		check(absf(WarTerrain.height_at(at.x,at.z)-(uncut-1.5))<.003,"trench actually lowers the terrain")
		var selected: Array[Vector2i]=[]
		for key: Vector2i in WarTerrainEdits.active_tiles: selected.append(key)
		var start:=Time.get_ticks_usec();var patch:=Node3D.new();scene.add_child(patch);WarTerrain.build(patch,true,selected)
		timings["patch_"+str(angle)]=float(Time.get_ticks_usec()-start)*.001
		await physics_frame;await physics_frame
		var basis:=Basis(Vector3.UP,angle)
		for z in [-6.,-3.,-1.,0.,1.,3.,6.]:
			for x in [-1.5,-.7,0.,.7,1.5]:
				var point:=at+basis*Vector3(x,0,z);var hit:=ray(point)
				check(not hit.is_empty() and absf(float(hit.position.y)-WarTerrain.height_at(point.x,point.z))<.012,"mesh/collision/sample agree across rotated trench and chunk corner")
		var collision: Dictionary={}
		for body in patch.get_children():
			if not body is StaticBody3D: continue
			collision[str(body.name)]=body.get_child(0).shape.get_faces()
		var authority:=Node3D.new();scene.add_child(authority);WarTerrain.build(authority,false,selected)
		for body in authority.get_children():
			if body is StaticBody3D: check(body.get_child(0).shape.get_faces()==collision[str(body.name)],"authority has exactly the same terrain triangles")
		authority.queue_free()
		if angle==0.:
			var player:=CharacterBody3D.new();player.collision_layer=4;player.collision_mask=1;player.floor_snap_length=.45
			var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.75;shape.shape=capsule;shape.position.y=.875;player.add_child(shape);scene.add_child(player)
			player.position=at+Vector3(0,3,8)
			for frame in 330:
				player.velocity=Vector3(0,player.velocity.y-9.81/60.,-2.);GameStepMotion.move(player,1./60.);await physics_frame
			check(player.position.y<uncut-1.2 and player.position.z<at.z,"character walks down into the cut without jumping")
			for frame in 330:
				player.velocity=Vector3(0,player.velocity.y-9.81/60.,2.);GameStepMotion.move(player,1./60.);await physics_frame
			check(player.position.z>at.z+7 and absf(player.position.y-WarTerrain.height_at(player.position.x,player.position.z))<.1,"character walks back out over the end ramp")
			player.queue_free()
		patch.queue_free();await process_frame;WarTerrainEdits.configure([])
		check(absf(WarTerrain.height_at(at.x,at.z)-uncut)<.001,"removing a trench restores the original terrain")
	for depth in [.8,2.8]:
		WarTerrainEdits.configure([])
		var ground:=WarTerrain.height_at(350,350)
		var module:=load(WarPrefabFactory.PATH+"trincheira_escavavel_6m.tscn").instantiate() as WarTrenchModule
		module.position=Vector3(350,ground,350);module.depth=depth
		WarTerrainEdits.configure(WarTerrainEdits.collect(module,Transform3D.IDENTITY,[]))
		check(absf(WarTerrain.height_at(350,350)-(ground-depth))<.01,"minimum/maximum depth changes the actual terrain")
		check(is_equal_approx(module.get_node("Revestimento").scale.y,depth/1.5),"lining height follows the selected excavation depth")
		module.excavate=false
		check(WarTerrainEdits.collect(module,Transform3D.IDENTITY,[]).is_empty(),"excavation can be disabled without keeping a hidden stamp")
		module.free()
	WarTerrainEdits.prepared=false;WarTerrainEdits.prepare()
	check(WarTerrainEdits.replaced_lots.size()==8,"eight village houses come from the editable layer")
	check(WarTerrainEdits.road_zones.size()==3,"only replaced road stretches suppress their previous surface")
	check(WarTerrainEdits.edits.filter(func(e):return e.get("source","")=="trench").size()==6,"six trenches are registered identically from saved scenes")
	check(WarTerrainEdits.edits.filter(func(e):return e.kind=="cut" and e.get("source","")!="trench").size()>=20,"quay foundations recess the land rather than letting it cover their surface")
	var spans:=WarTerrainEdits.remaining_road(Vector2(-1160,100),Vector2(-980,100))
	check(spans.size()==1 and absf(spans[0].x-1./3.)<.0001,"legacy road is clipped exactly at the modular join")
	scene.queue_free();await process_frame;await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"timings_ms":timings};NavalStorage.write_json("res://tests/library190-validation-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
