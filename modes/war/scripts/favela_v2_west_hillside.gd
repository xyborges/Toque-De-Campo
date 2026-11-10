extends RefCounted
## Favela V2 / Etapa 3A — somente o bairro do morro esquerdo.
## Nenhum link sai desse setor, exceto o portao l00 que existe na topologia.
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const TERRAIN=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const STAIR=preload("res://modes/war/library/favela_v2_stair_tread.tscn")
const HOUSE=preload("res://modes/war/library/favela_casa_laje.tscn")
# Keep the existing Favela library as the source of truth. The V2 only
# composes these saved meshes; it does not regenerate or overwrite them.
const REUSED_FACADES={
	"door":preload("res://modes/war/library/favela_porta_entrada.tscn"),
	"grid":preload("res://modes/war/library/favela_janela_grade.tscn"),
	"wood":preload("res://modes/war/library/favela_janela_madeira.tscn"),
	"awning":preload("res://modes/war/library/favela_toldo.tscn"),
	"comercio":preload("res://modes/war/library/favela_comercio_fachada.tscn"),
	"varal":preload("res://modes/war/library/favela_varal.tscn"),
	"roof_kit":preload("res://modes/war/library/favela_laje_domestica.tscn"),
	"puxadinho":preload("res://modes/war/library/favela_puxadinho_chapa.tscn")
}
const STAIR_IDS=["l02","l03","l04","l07","l09"]
const STEP_RUN:=.765
const EDGE_MARGIN:=1.35
const HOUSE_SCALE:=Vector3(.71,.80,.72)
static var _step_mesh: Mesh
static var _step_material: Material

static func _resources()->void:
	if _step_mesh!=null:return
	var template:=STAIR.instantiate() as StaticBody3D
	var model:=template.get_node("DegrauConcreto") as MeshInstance3D
	_step_mesh=model.mesh
	_step_material=model.material_override
	template.free()

static func _step_pose(point: Vector2,axis: Vector2,width: float)->Transform3D:
	var yaw:=atan2(axis.x,axis.y)
	var basis:=Basis(Vector3.UP,yaw)
	basis=basis.scaled(Vector3(width/2.24,1,1))
	return Transform3D(basis,Vector3(point.x,TERRAIN.height_at(point.x,point.y)+.10,point.y))

static func plan_steps()->Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for link: Dictionary in TOPO.LINKS:
		if not STAIR_IDS.has(str(link["id"])):continue
		var poly:=TOPO.polyline(link)
		var width:=minf(float(link["width"])-.12,2.24)
		var poses: Array[Transform3D]=[]
		for segment in poly.size()-1:
			var a: Vector2=poly[segment]
			var b: Vector2=poly[segment+1]
			var length:=a.distance_to(b)
			var useful:=length-2.0*EDGE_MARGIN
			if useful<1.0:continue
			var n:=maxi(1,ceili(useful/STEP_RUN))
			var pitch:=useful/float(n)
			var axis: Vector2=(b-a)/length
			for j in n:
				var q:=a+axis*(EDGE_MARGIN+(float(j)+.5)*pitch)
				poses.append(_step_pose(q,axis,width))
		result.append({"id":str(link["id"]),"poses":poses,
			"width":width,"route":poly,"total_m":TOPO.length_of(link)})
	return result

static func _shape_for_steps(poses: Array[Transform3D])->ConcavePolygonShape3D:
	_resources()
	var local_faces: PackedVector3Array=_step_mesh.get_faces()
	var faces:=PackedVector3Array()
	faces.resize(poses.size()*local_faces.size())
	var index:=0
	for pose: Transform3D in poses:
		for local_vertex: Vector3 in local_faces:
			faces[index]=pose*local_vertex
			index+=1
	var solid:=ConcavePolygonShape3D.new()
	solid.set_faces(faces)
	return solid

static func _make_flight(parent: Node3D,data: Dictionary,visuals: bool)->void:
	var poses: Array[Transform3D]=data["poses"]
	if poses.is_empty():return
	var body:=StaticBody3D.new()
	body.name="LanceEscada_"+str(data["id"])
	body.collision_layer=1
	body.collision_mask=0
	body.set_meta("surface","concrete")
	parent.add_child(body)
	var shape:=CollisionShape3D.new()
	shape.name="DegrausColisaoAgrupada"
	shape.shape=_shape_for_steps(poses)
	body.add_child(shape)
	if not visuals:return
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=_step_mesh
	mm.instance_count=poses.size()
	for i in poses.size():mm.set_instance_transform(i,poses[i])
	var view:=MultiMeshInstance3D.new()
	view.name="DegrausInstanciados"
	view.multimesh=mm
	view.material_override=_step_material
	view.visibility_range_end=280.0
	view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)

static func _edge_posts(parent: Node3D,flights: Array[Dictionary])->int:
	var rail_mesh:=CylinderMesh.new()
	rail_mesh.top_radius=.028
	rail_mesh.bottom_radius=.028
	rail_mesh.height=1.0
	rail_mesh.radial_segments=7
	var transforms: Array[Transform3D]=[]
	for flight: Dictionary in flights:
		var route: PackedVector2Array=flight["route"]
		var side_offset: float=float(flight["width"])*.5+.26
		for seg in route.size()-1:
			var a:=route[seg]
			var b:=route[seg+1]
			var delta: Vector2=b-a
			var length:=delta.length()
			if length<2.0:continue
			var axis:=delta/length
			var right:=Vector2(axis.y,-axis.x)
			var count:=maxi(2,ceili(length/4.5))
			for sign_side in [-1.0,1.0]:
				var previous:=Vector3.INF
				for i in count+1:
					var point:=a.lerp(b,float(i)/float(count))+right*float(sign_side)*side_offset
					var y:=TERRAIN.height_at(point.x,point.y)
					var base:=Vector3(point.x,y+.2,point.y)
					var cap:=Vector3(point.x,y+1.08,point.y)
					var from:=base+Vector3.UP*.44
					transforms.append(Transform3D(Basis.from_scale(Vector3(1,.88,1)),from))
					if previous.is_finite():
						var mid: Vector3=(previous+cap)*.5
						var stretch: Vector3=cap-previous
						var rotation:=Basis(Quaternion(Vector3.UP,stretch.normalized()))
						transforms.append(Transform3D(rotation.scaled(Vector3(1,stretch.length(),1)),mid))
					previous=cap
	if transforms.is_empty():return 0
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("#555853")
	mat.roughness=.82
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=rail_mesh
	mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var view:=MultiMeshInstance3D.new()
	view.name="CorrimaosMorroSemColisao"
	view.multimesh=mm
	view.material_override=mat
	view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.visibility_range_end=200.0
	parent.add_child(view)
	return transforms.size()

static func _near_cliff(p: Vector2)->bool:
	for contour in [TERRAIN.WEST_CLIFF_A,TERRAIN.WEST_CLIFF_B]:
		for i in contour.size()-1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,contour[i],contour[i+1]))<8.25:
				return true
	return false

static func _near_lane(p: Vector2)->bool:
	for link: Dictionary in TOPO.LINKS:
		var route:=TOPO.polyline(link)
		for seg in route.size()-1:
			var closest:=Geometry2D.get_closest_point_to_segment(p,route[seg],route[seg+1])
			if p.distance_to(closest)<float(link["width"])*.5+4.6:return true
	return false

static func _house_slope(point: Vector2)->float:
	var lo:=INF
	var hi:=-INF
	for offset in [Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3),Vector2.ZERO]:
		var h:=TERRAIN.height_at(point.x+offset.x,point.y+offset.y)
		lo=minf(lo,h)
		hi=maxf(hi,h)
	return hi-lo

static func plan_houses()->Array[Dictionary]:
	var results: Array[Dictionary]=[]
	for road: Dictionary in TOPO.LINKS:
		var id:=str(road["id"])
		if not id.begins_with("l") or id=="l00":continue
		var route:=TOPO.polyline(road)
		for seg in route.size()-1:
			var a: Vector2=route[seg]
			var b: Vector2=route[seg+1]
			var delta:=b-a
			var length:=delta.length()
			var n:=floori((length-4.0)/11.75)
			if n<1:continue
			var axis:=delta/length
			var normal:=Vector2(axis.y,-axis.x)
			for i in n:
				var fraction:=float(i+1)/float(n+1)
				for sign_side in [-1.0,1.0]:
					# Try successively deeper placements to follow the real
					# staggered occupation behind the main alley facade.
					for extra in [6.65,9.2,12.4]:
						var offset: float=float(road["width"])*.5+float(extra)
						var p: Vector2=a.lerp(b,fraction)+normal*float(sign_side)*offset
						if not TOPO.BOUNDS.grow(-15.0).has_point(p):continue
						if p.distance_to(TOPO.NODES["portal_oeste"]["p"])<15.0:continue
						if _near_cliff(p) or _near_lane(p):continue
						if _house_slope(p)>2.70:continue
						var too_close:=false
						for placed: Dictionary in results:
							if p.distance_to(placed["pos"])<11.5:
								too_close=true
								break
						if too_close:continue
						var yaw:=atan2(axis.x,axis.y)
						var h:=TERRAIN.height_at(p.x,p.y)
						results.append({"pos":p,"height":h,"yaw":yaw,
							"edge":id,"side":sign_side})
						break
	return results

static var _shared_wall_materials: Array[Material]=[]

static func _wall_material(variant: int)->Material:
	if _shared_wall_materials.is_empty():
		for shade in ["#b9a68f","#adaaa0","#c0b6a7","#a69787","#b3a88c"]:
			var m:=StandardMaterial3D.new()
			m.albedo_color=Color(shade)
			m.roughness=.96
			_shared_wall_materials.append(m)
	return _shared_wall_materials[posmod(variant,_shared_wall_materials.size())]

static func _reuse_detail(house: Node3D,id: String,at: Vector3)->void:
	var decor:=REUSED_FACADES[id].instantiate() as Node3D
	decor.name="Reuso_"+id
	decor.position=at
	house.add_child(decor)
	# Facades/roof kits are visually reused; the building's existing
	# StaticBody3D remains the *single* combat collider. This prevents
	# roof-support coplanar collisions (the old Favela roof jitter).
	for body: CollisionObject3D in decor.find_children("*","CollisionObject3D",true,false):
		body.collision_layer=0
		body.collision_mask=0

static func _decorate_house(house: Node3D,i: int)->int:
	var shell:=house.get_node_or_null("Edificio") as MeshInstance3D
	if shell!=null:shell.set_surface_override_material(0,_wall_material(i))
	var variant:=posmod(i,5)
	var modules:=0
	# Front (+Z) is the same facade convention as favela_casa_laje.
	_reuse_detail(house,"door",Vector3(-.25,.10,5.10))
	modules+=1
	_reuse_detail(house,"wood" if variant in [1,4] else "grid",
		Vector3(-2.85,3.60,5.12))
	modules+=1
	if variant in [0,2,4]:
		_reuse_detail(house,"awning",Vector3(-.35,2.80,5.13))
		modules+=1
	if variant==3:
		_reuse_detail(house,"comercio",Vector3(.15,0.0,5.15))
		modules+=1
	if variant==0:
		_reuse_detail(house,"puxadinho",Vector3(1.65,7.23,-1.60))
		modules+=1
	elif variant==1:
		_reuse_detail(house,"roof_kit",Vector3(-1.80,7.23,-1.35))
		modules+=1
	else:
		_reuse_detail(house,"varal",Vector3(-1.35,7.22,-1.15))
		modules+=1
	house.set_meta("house_variant",variant)
	return modules

static func _add_houses(parent: Node3D,houses: Array[Dictionary],visuals: bool)->int:
	var holder:=Node3D.new()
	holder.name="ResidenciasEscalonadas"
	parent.add_child(holder)
	# Keep the original house's structural collider on both peers,
	# but the client alone instantiates decorative facade/roof modules.
	var module_count:=0
	for i in houses.size():
		var house: Dictionary=houses[i]
		var p: Vector2=house["pos"]
		var obj:=HOUSE.instantiate() as Node3D
		obj.name="CasaMorro_%03d" %i
		obj.position=Vector3(p.x,float(house["height"])-.3,p.y)
		obj.rotation.y=float(house["yaw"])
		obj.scale=Vector3(HOUSE_SCALE.x,HOUSE_SCALE.y*(1.0+.13*float(i%3)),HOUSE_SCALE.z)
		holder.add_child(obj)
		if visuals:
			module_count+=_decorate_house(obj,i)
		else:
			for mesh: MeshInstance3D in obj.find_children("*","MeshInstance3D",true,false):
				mesh.visible=false
	return module_count

static func build(parent: Node3D,visuals: bool=true,with_houses: bool=true)->Dictionary:
	_resources()
	var root:=Node3D.new()
	root.name="FavelaV2MorroEsquerdo"
	parent.add_child(root)
	var flights:=plan_steps()
	var step_total:=0
	for flight: Dictionary in flights:
		_make_flight(root,flight,visuals)
		step_total+=flight["poses"].size()
	var rail_count:=_edge_posts(root,flights) if visuals else 0
	var houses: Array[Dictionary]=[]
	if with_houses:houses=plan_houses()
	var reused_modules:=_add_houses(root,houses,visuals)
	return {"flights":flights.size(),"treads":step_total,
		"houses":houses.size(),"reused_facade_modules":reused_modules,
		"reused_house_variants":5,"rails":rail_count,
		"physical_stair_bodies":flights.size(),
		"west_gateways":TOPO.left_gate_links().size()}
