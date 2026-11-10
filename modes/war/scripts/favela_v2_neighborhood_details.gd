extends RefCounted
## Lightweight alleys and hillside vegetation: shared materials, no new
## collision nodes, no scripts per decoration. Not navigable bot shortcuts.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const SHRUB=preload("res://modes/war/library/favela_arbusto_encosta.tscn")
const CELL_SIZE:=92.0
# The northern western hillside ends in a rocky crest, not a playable
# shortcut to the traffickers' base. Unlike a perimeter ring, this is ONE
# broken geological ridge behind the west houses.
const RIDGE_NORTH=[
	Vector2(-296,-230),Vector2(-247,-234),
	Vector2(-198,-229),Vector2(-155,-233),Vector2(-118,-227)
]
const ROCK=preload("res://modes/war/library/favela_v2_rock_barrier.tscn")

static func _alley_mesh(alleys:Array[Dictionary])->ArrayMesh:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for alley:Dictionary in alleys:
		var a:Vector2=alley["a"]
		var b:Vector2=alley["to"]
		var direction:Vector2=(b-a).normalized()
		var right:=Vector2(-direction.y,direction.x)
		var half:float=float(alley["width"])*.5
		var n:=maxi(1,ceili(a.distance_to(b)/2.5))
		for i in n:
			var p:Vector2=a.lerp(b,float(i)/float(n))
			var q:Vector2=a.lerp(b,float(i+1)/float(n))
			var p0:=p-right*half
			var p1:=p+right*half
			var q0:=q-right*half
			var q1:=q+right*half
			var v0:=Vector3(p0.x,T.height_at(p0.x,p0.y)+.065,p0.y)
			var v1:=Vector3(p1.x,T.height_at(p1.x,p1.y)+.065,p1.y)
			var v2:=Vector3(q0.x,T.height_at(q0.x,q0.y)+.065,q0.y)
			var v3:=Vector3(q1.x,T.height_at(q1.x,q1.y)+.065,q1.y)
			for point:Vector3 in [v0,v1,v2,v1,v3,v2]:
				tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()

static func _distance_to_roads(p:Vector2)->float:
	var closest:=INF
	for road:Dictionary in TOPO.LINKS:
		var points:=TOPO.polyline(road)
		for i in points.size()-1:
			var foot:=Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1])
			closest=minf(closest,p.distance_to(foot)-float(road["width"])*.5)
	return closest

static func plan_scrub(houses:Array[Dictionary])->Array[Transform3D]:
	# Vegetation only on rocky hillside slopes and edges; the actual favela
	# is mostly masonry. Reuses the shrub mesh already in the game's library.
	var random:=RandomNumberGenerator.new()
	random.seed=20261110
	var results:Array[Transform3D]=[]
	var attempts:=0
	while results.size()<190 and attempts<4200:
		attempts+=1
		var x:=random.randf_range(TOPO.BOUNDS.position.x+18,TOPO.BOUNDS.end.x-18)
		var z:=random.randf_range(TOPO.BOUNDS.position.y+18,TOPO.BOUNDS.end.y-18)
		var p:=Vector2(x,z)
		# Mostly outer ridges; avoid a grassy blanket of the streets.
		if not (x< -215.0 or x>255.0 or z< -245.0):continue
		if _distance_to_roads(p)<9.0:continue
		var near_house:=false
		for h:Dictionary in houses:
			if p.distance_squared_to(h["pos"])<95.0:
				near_house=true
				break
		if near_house:continue
		var s:=random.randf_range(.52,1.23)
		var transform:=Transform3D(Basis(Vector3.UP,random.randf_range(-PI,PI)).scaled(
			Vector3(s,s*.85,s)),Vector3(x,T.height_at(x,z),z))
		results.append(transform)
	return results

static func _shrub_multimeshes(parent:Node3D,transforms:Array[Transform3D])->int:
	var sample:=SHRUB.instantiate() as Node3D
	var model:=sample.get_node("Forma") as MeshInstance3D
	var mesh:Mesh=model.mesh
	var material:Material=model.material_override
	var bins:Dictionary={}
	for transform:Transform3D in transforms:
		var at:Vector3=transform.origin
		var bin:=Vector2i(floori(at.x/CELL_SIZE),floori(at.z/CELL_SIZE))
		if not bins.has(bin):bins[bin]=[]
		bins[bin].append(transform)
	var count:=0
	for key:Vector2i in bins.keys():
		var poses:Array=bins[key]
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=mesh
		mm.instance_count=poses.size()
		for i in poses.size():mm.set_instance_transform(i,poses[i])
		var view:=MultiMeshInstance3D.new()
		view.name="ArbustosMorro_%s_%s"%[key.x,key.y]
		view.multimesh=mm
		view.material_override=material
		view.visibility_range_end=180.0
		view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(view)
		count+=1
	sample.free()
	return count

static func _northern_rock_crest(parent:Node3D,visuals:bool)->int:
	var count:=0
	for i in RIDGE_NORTH.size()-1:
		var a:Vector2=RIDGE_NORTH[i]
		var b:Vector2=RIDGE_NORTH[i+1]
		var axis:Vector2=(b-a).normalized()
		var middle:Vector2=(a+b)*.5
		var center_y:=T.height_at(middle.x,middle.y)
		var body:=ROCK.instantiate() as StaticBody3D
		body.name="CristaRochosaNorte_%02d"%count
		body.position=Vector3(middle.x,center_y,middle.y)
		body.rotation.y=atan2(-axis.y,axis.x)
		parent.add_child(body)
		var mesh:=T._rock_bank_mesh(a,b,center_y)
		var collider:=mesh.create_trimesh_shape()
		collider.backface_collision=true
		(body.get_node("ParedeFisica") as CollisionShape3D).shape=collider
		if visuals:
			var view:=body.get_node("RochaVisivel") as MeshInstance3D
			view.mesh=mesh
			view.material_override=T._rock_material()
		count+=1
	return count

static func build(parent:Node3D,visuals:bool,alleys:Array[Dictionary],
		houses:Array[Dictionary])->Dictionary:
	var stats:Dictionary={"passages":alleys.size(),"passage_meshes":0,
		"foliage_instances":0,"foliage_batches":0,
		"rock_crest_colliders":0,"decorative_colliders":0}
	var group:=Node3D.new()
	group.name="BecosEEncostasV2"
	parent.add_child(group)
	# Physical rock face is authoritative on dedicated server and client.
	# Decorative passages, trash, vegetation never add a collider.
	stats["rock_crest_colliders"]=_northern_rock_crest(group,visuals)
	if not visuals:return stats
	if not alleys.is_empty():
		var paths:=MeshInstance3D.new()
		paths.name="PisoBecosConcretoSemColisao"
		paths.mesh=_alley_mesh(alleys)
		paths.material_override=T._road_material()
		paths.visibility_range_end=370.0
		paths.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(paths)
		stats["passage_meshes"]=1
	var foliage:=plan_scrub(houses)
	stats["foliage_instances"]=foliage.size()
	stats["foliage_batches"]=_shrub_multimeshes(group,foliage)
	return stats
