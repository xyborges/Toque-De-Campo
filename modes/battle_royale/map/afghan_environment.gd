extends RefCounted
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const CONTEXT=preload("res://modes/battle_royale/map/afghan_context.gd")
const FIELD_COVER=preload("res://modes/battle_royale/map/afghan_field_cover.gd")
const LIB:="res://modes/battle_royale/library/"
static var detail_meshes: Dictionary={}
static var road_material: ShaderMaterial
const CROP_CLUSTERS:=300

static func populate(map: Node3D) -> void:
	var scenery: Dictionary={};var plants: Dictionary={};var details: Dictionary={}
	var rng:=RandomNumberGenerator.new();rng.seed=712907
	for road: Dictionary in LAND.roads():
		if map.render_visuals: _road(map,road)
	_bridges(map,scenery)
	if map.render_visuals:_irrigation(map)
	for farm: Dictionary in LAND.farmland_layout():
		var crate: Vector3=farm.crate;crate=map.point(crate.x,crate.z)
		map.add_piece("farm_crate_v2",Transform3D(Basis.IDENTITY,crate),scenery)
		var hay:=crate+Vector3(2.,0,0);hay.y=map.height_at(hay.x,hay.z)
		map.add_piece("haystack_v2",Transform3D(Basis(Vector3.UP,.3),hay),scenery)
		_field_boundaries(map,farm,scenery)
		if map.render_visuals: _field(map,farm,details,rng)
		else:
			# The visual client draws three random values per crop cluster.
			# Consume the same sequence on authority without creating geometry,
			# so later collidable rocks and trees have identical positions.
			for _i in CROP_CLUSTERS:
				rng.randf_range(-1.,1.);rng.randf_range(-1.,1.);rng.randf_range(-PI,PI)
	for index in LAND.building_layout().size():
		var record: Dictionary=LAND.building_layout()[index]
		var p: Vector3=record.position;var yaw: float=record.yaw
		var prop: String="woodpile_v2" if index%3==0 else ("clothesline_v2" if index%3==1 else "courtyard_wall_v2")
		var offset:=Vector3(-3.7,0,-8.) if index%3==0 else (Vector3(-8.,0,-1.0) if index%3==1 else Vector3(0,0,-10.5))
		offset=offset.rotated(Vector3.UP,yaw);var location: Vector3=map.point(p.x+offset.x,p.z+offset.z)
		map.add_piece(prop,Transform3D(Basis(Vector3.UP,yaw),location),scenery)
	for region in LAND.village_centres().size():
		var c: Vector3=LAND.village_centres()[region]
		var p: Vector3=map.point(c.x-8,c.z+3)
		map.add_piece("village_well_v2",Transform3D(Basis.IDENTITY,p),scenery)
	_properties(map,scenery,plants,details)
	_settlement_props(map,scenery,plants)
	_street_trees(map,plants)
	_water_groves(map,plants)
	# Dry scrub and pebbles are short-range, scriptless and collision-free.
	for index in 2800:
		var x:=rng.randf_range(-980,980);var z:=rng.randf_range(-980,980)
		var candidate:=Vector3(x,0,z)
		if _in_lot(candidate) or LAND.in_farmland(Vector2(x,z),5.) or _near_path(candidate,8.) or absf(x-LAND.stream_center(z))<15.: continue
		var p: Vector3=map.point(x,z)
		var scale:=rng.randf_range(.65,1.45)
		var id: String="dry_cluster_v3" if index%3==0 else "pebble_patch_v3"
		var angle:=rng.randf_range(-PI,PI)
		var color:=Color(rng.randf_range(.85,1.1),rng.randf_range(.85,1.05),.92)
		var slope:=Vector2(map.height_at(x+3.,z)-map.height_at(x-3.,z),map.height_at(x,z+3.)-map.height_at(x,z-3.))/6.
		if map.render_visuals and (id!="pebble_patch_v3" or slope.length()<.25):_detail(details,id,Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale),p),color)
		# The user removed hillside rocks. Keep the later vegetation sequence
		# stable while omitting the former large outcrop instances entirely.
		if index%33==0:
			rng.randf_range(1.4,3.3);rng.randf_range(-PI,PI)
	# Green vegetation follows the water rather than filling dry mountains.
	for i in 320:
		var z:=rng.randf_range(-930,930);var x:=LAND.stream_center(z)+(1 if i%2==0 else -1)*rng.randf_range(14,35)
		var p: Vector3=map.point(x,z)
		if _in_lot(p) or _near_path(p,8): continue
		var scale:=rng.randf_range(.65,1.1)
		map.add_piece("willow_v7" if i%5==0 else "poplar_v7",Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*scale),p),plants,Color(.91,rng.randf_range(.94,1.08),.88))
	for farm: Dictionary in LAND.farmland_layout():
		if farm.crop=="fallow":
			for row in 3:
				for column in 4:
					var p: Vector3=map.point(farm.position.x+(column-1.5)*10.,farm.position.z+(row-1)*15.)
					map.add_piece("willow_v7",Transform3D(Basis(Vector3.UP,row*.8+column*.7).scaled(Vector3.ONE*(.55+.04*((row+column)%3))),p),plants)
		for i in 7:
			var x: float=farm.position.x-float(farm.side)*(float(farm.size.x)*.5+5.)
			var z: float=farm.position.z-farm.size.y*.5+5.+i*(farm.size.y-10.)/6.
			var p: Vector3=map.point(x,z)
			if _near_path(p,6.): continue
			map.add_piece("poplar_v7",Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*rng.randf_range(.65,.9)),p),plants)
	CONTEXT.populate(map,scenery,plants,details,_detail)
	FIELD_COVER.populate(map,details,_detail)
	for key: String in plants:
		var id:=key.get_slice(":",0).replace("_v7","_far_v7")
		var cache: String="far:"+id
		if not detail_meshes.has(cache):
			var tree: Node3D=load(LIB+id+".tscn").instantiate();detail_meshes[cache]=tree.get_node("Geometry").mesh;tree.free()
		plants[key]["far_mesh"]=detail_meshes[cache]
	map.finish_static_batches(scenery,1200.,true);map.finish_batches(plants,650.,true)
	if map.render_visuals:
		map.finish_batches(details,85.,false)
		_stream(map)
	var tree_count:=0;var shrub_count:=0
	for key: String in plants:
		if key.begins_with("garden_shrub"):shrub_count+=plants[key].transforms.size()
		else:tree_count+=plants[key].transforms.size()
	map.set_meta("afghan_environment",{"green_tree_count":tree_count,"shrubs":shrub_count,"small_detail_budget":2800,"crop_clusters_per_field":CROP_CLUSTERS,"fields":LAND.farmland_layout().size(),"loot_only_on_crates_in_fields":true})

static func _water_groves(map: Node3D,plants: Dictionary) -> void:
	# Small stands grow on the outside of the wet bank, not on roads or lots.
	# A separate fixed sequence keeps this addition independent of colliders
	# later in populate() and identical in graphical and headless execution.
	for grove in 32:
		var z: float=-900.+grove*58.;var sign_value: float=-1. if grove%2==0 else 1.
		var centre:=Vector2(LAND.stream_center(z)+sign_value*39.,z)
		for i in 7:
			var q:=centre+Vector2(sin(i*2.4+grove)*9.,cos(i*2.4+grove)*12.)
			var p: Vector3=map.point(q.x,q.y)
			if _in_lot(p) or LAND.in_farmland(q,3.) or _near_path(p,7.):continue
			map.add_piece("willow_v7" if i%3==0 else "poplar_v7",Transform3D(Basis(Vector3.UP,i*.91+grove).scaled(Vector3.ONE*(.65+.06*(i%4))),p),plants)

static func _context_clear(p: Vector3,owner: Dictionary) -> bool:
	if _near_path(p,4.) or LAND.in_farmland(Vector2(p.x,p.z),1.):return false
	for other: Dictionary in LAND.building_layout():
		if other==owner:continue
		if Vector2(p.x-other.position.x,p.z-other.position.z).length()<float(other.radius)+2.:return false
	return true

static func _properties(map: Node3D,scenery: Dictionary,plants: Dictionary,details: Dictionary) -> void:
	for index in LAND.building_layout().size():
		var house: Dictionary=LAND.building_layout()[index];var origin: Vector3=house.position
		var basis:=Basis(Vector3.UP,house.yaw)
		# Back/side walls form a yard, leaving the full front approach open.
		for offset: Vector3 in [Vector3(-9,0,-13),Vector3(-3,0,-13),Vector3(3,0,-13),Vector3(9,0,-13),Vector3(-13,0,-8),Vector3(13,0,-8)]:
			var p: Vector3=origin+basis*offset;p.y=map.height_at(p.x,p.z)
			if not _context_clear(p,house):continue
			var rotation: float=house.yaw+(PI*.5 if absf(offset.x)>12. else 0.)
			map.add_piece("courtyard_wall_v2",Transform3D(Basis(Vector3.UP,rotation).scaled(Vector3(1.,.64,1.)),p-Vector3.UP*.08),scenery)
		for i in 4:
			var offset:=Vector3((-1 if i%2==0 else 1)*(15.+index%3),0,-12.+(i/2)*18.)
			var p: Vector3=origin+basis*offset;p.y=map.height_at(p.x,p.z)
			if not _context_clear(p,house):continue
			map.add_piece("poplar_v7" if i%3==0 else "willow_v7",Transform3D(Basis(Vector3.UP,index*.71+i).scaled(Vector3.ONE*(.65+float((i+index)%4)*.1)),p),plants)
			# Low ground cover stays near the tree/yard, not a uniform carpet.
			for tuft in 6:
				var t:=p+Vector3(sin(tuft*2.4)*2.3,0,cos(tuft*2.4)*2.3);t.y=map.height_at(t.x,t.z)
				if map.render_visuals:_detail(details,"dry_cluster_v3",Transform3D(Basis(Vector3.UP,tuft*.8).scaled(Vector3.ONE*.8),t),Color(.67,.75,.48))
		var prop:=origin+basis*Vector3(float(house.garden_side)*11.5,0,-9.);prop.y=map.height_at(prop.x,prop.z)
		if _context_clear(prop,house):map.add_piece("farm_crate_v2" if index%2==0 else "woodpile_v2",Transform3D(basis,prop),scenery)
		for i in 8:
			var p: Vector3=origin+basis*Vector3(float(house.garden_side)*(12.5+(i%2)*2.5),0,-11.+(i/2)*3.)
			p.y=map.height_at(p.x,p.z)
			if not _context_clear(p,house):continue
			map.add_piece("garden_shrub_v7",Transform3D(Basis(Vector3.UP,i*.7+index).scaled(Vector3.ONE*(.75+float(index%3)*.12)),p),plants)

static func _settlement_props(map: Node3D,scenery: Dictionary,plants: Dictionary) -> void:
	# Extra detail follows inhabited/farm contexts instead of being scattered
	# uniformly across open desert. Existing library scenes keep shared meshes,
	# collision and LOD behavior through the normal batch path.
	for index in LAND.building_layout().size():
		var house: Dictionary=LAND.building_layout()[index]
		var basis:=Basis(Vector3.UP,float(house.yaw));var origin: Vector3=house.position
		var choices: Array[String]=["market_stall","farm_work_corner_v8","collapsed_farm_wall_v8","woodpile_v2","haystack_v2"]
		var id:=choices[index%choices.size()]
		var local:=Vector3(10.5 if index%2==0 else -10.5,0,8.5+(index%3)*2.)
		var p: Vector3=origin+basis*local;p.y=map.height_at(p.x,p.z)
		if _context_clear(p,house):map.add_piece(id,Transform3D(basis,p),scenery)
		if index%2==0:
			var shrub:=origin+basis*Vector3(-float(house.garden_side)*15.,0,11.);shrub.y=map.height_at(shrub.x,shrub.z)
			if _context_clear(shrub,house):map.add_piece("tamarisk_v10",Transform3D(Basis(Vector3.UP,index*.43).scaled(Vector3.ONE*(.72+.06*(index%4))),shrub),plants)

static func _street_trees(map: Node3D,plants: Dictionary) -> void:
	var count:=0
	for road: Dictionary in LAND.roads():
		if road.kind not in ["village","secondary","main"]:continue
		for i in range(2,road.points.size()-1,5):
			if count>=320:return
			var p: Vector3=road.points[i];var delta: Vector3=(road.points[i+1]-road.points[i-1]).normalized()
			var side:=delta.cross(Vector3.UP)
			for sign_value: int in [-1,1]:
				var candidate: Vector3=p+side*sign_value*(float(road.width)*.5+4.+(i%3));candidate.y=map.height_at(candidate.x,candidate.z)
				if _in_lot(candidate) or LAND.in_farmland(Vector2(candidate.x,candidate.z),1.) or absf(candidate.x-LAND.stream_center(candidate.z))<10.:continue
				map.add_piece("poplar_v7",Transform3D(Basis(Vector3.UP,i*.79).scaled(Vector3.ONE*(.7+float(i%4)*.07)),candidate),plants)
				count+=1

static func _field_boundaries(map: Node3D,farm: Dictionary,groups: Dictionary) -> void:
	# Reuse the authored wall and its collision. A wide opening faces the
	# headland; crop access and the crate are never fenced off.
	var outline: PackedVector2Array=farm.outline
	for edge in outline.size():
		var a: Vector2=outline[edge];var b: Vector2=outline[(edge+1)%outline.size()]
		var count:=ceili(a.distance_to(b)/15.);var span: float=a.distance_to(b)/count
		var direction: Vector2=(b-a).normalized()
		for i in count:
			var at:=a.lerp(b,(i+.5)/count);var point: Vector3=map.point(at.x,at.y)
			if point.distance_to(Vector3(farm.gate.x,point.y,farm.gate.y))<17.:continue
			if _near_path(point,5.) or LAND.channel_distance(at)<3.:continue
			map.add_piece("courtyard_wall_v2",Transform3D(Basis(Vector3.UP,atan2(-direction.y,direction.x)).scaled(Vector3(span/6.,.32,1.)),point-Vector3.UP*.08),groups)

static func _detail(groups: Dictionary,id: String,transform: Transform3D,color:=Color.WHITE) -> void:
	var cell:=Vector2i(floori(transform.origin.x/80.),floori(transform.origin.z/80.))
	var key:=id+str(cell)
	if not groups.has(key):
		if not detail_meshes.has(id):
			var source: Node3D=load(LIB+id+".tscn").instantiate()
			var geometry:=source.get_node("Geometry") as MeshInstance3D
			var mesh: Mesh=geometry.mesh
			if geometry.material_override:
				mesh=mesh.duplicate()
				for surface in mesh.get_surface_count():mesh.surface_set_material(surface,geometry.material_override)
			detail_meshes[id]=mesh;source.free()
		groups[key]={"mesh":detail_meshes[id],"transforms":[],"colors":[]}
	groups[key].transforms.append(transform);groups[key].colors.append(color)

static func _in_lot(p: Vector3) -> bool:
	for record: Dictionary in LAND.building_layout():
		if Vector2(p.x-record.position.x,p.z-record.position.z).length()<float(record.radius)+4.: return true
	return false

static func _near_path(p: Vector3,width: float) -> bool:
	# The landform index stores every segment in all 64 m cells touched by
	# its bounding box plus 24 m. All callers here request at most 8 m.
	return float(LAND._near_road(Vector2(p.x,p.z)).distance)<width

static func _mesh(map: Node3D,label: String,vertices: PackedVector3Array,indices: PackedInt32Array,material: Material,uvs:=PackedVector2Array()) -> void:
	if vertices.is_empty(): return
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,indices.size(),3):
		var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
		var face:=PackedInt32Array([a,c,b]) if Plane(vertices[a],vertices[b],vertices[c]).normal.y<0. else PackedInt32Array([a,b,c])
		for index in face:
			st.set_uv(uvs[index] if uvs.size()==vertices.size() else Vector2(vertices[index].x,vertices[index].z)*.2);st.add_vertex(vertices[index])
	st.generate_normals();st.index()
	var node:=MeshInstance3D.new();node.name=label;node.mesh=st.commit();node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;map.add_child(node)

static func _road(map: Node3D,road: Dictionary) -> void:
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array();var uvs:=PackedVector2Array();var points: Array=road.points;var distance:=0.
	for i in points.size()-1:
		var from: Vector3=points[i];var to: Vector3=points[i+1]
		var steps:=maxi(1,ceili(from.distance_to(to)/3.))
		var side: Vector3=(to-from).cross(Vector3.UP).normalized()*float(road.width)*.5
		var side_from: Vector3=(points[i+1]-points[maxi(0,i-1)]).cross(Vector3.UP).normalized()*float(road.width)*.5
		var side_to: Vector3=(points[mini(points.size()-1,i+2)]-points[i]).cross(Vector3.UP).normalized()*float(road.width)*.5
		for j in steps:
			var a:=from.lerp(to,float(j)/steps);var b:=from.lerp(to,float(j+1)/steps)
			var span:=a.distance_to(b);var end_distance:=distance+span
			if absf(a.x-LAND.stream_center(a.z))<6. or absf(b.x-LAND.stream_center(b.z))<6.: continue
			var edge_a: Vector3=side_from.lerp(side_to,float(j)/steps)*(1.+.06*sin(a.x*.13+a.z*.15))
			var edge_b: Vector3=side_from.lerp(side_to,float(j+1)/steps)*(1.+.06*sin(b.x*.13+b.z*.15))
			var polygon:=PackedVector2Array()
			for p: Vector3 in [a-edge_a,a+edge_a,b+edge_b,b-edge_b]:polygon.append(Vector2(p.x,p.z))
			# Clip the road skin to the exact 5 m terrain triangles. Draping one
			# wide quad across several triangles made it cut through the ground.
			var lift: float={"main":.065,"secondary":.060,"village":.055,"access":.050,"farm":.045,"mountain":.040}.get(road.kind,.045)
			_road_on_triangles(map,polygon,a,b,side,float(road.width),distance,end_distance,vertices,indices,uvs,lift)
			distance=end_distance
	if not road_material:
		road_material=ShaderMaterial.new();road_material.shader=preload("res://modes/battle_royale/map/afghan_road.gdshader");road_material.set_shader_parameter("soil",load("res://assets/environment/materials/concrete-albedo.png"))
		if preload("res://modes/battle_royale/map/afghan_ground_cache.gd").valid():
			road_material.set_shader_parameter("ground_color",load("res://modes/battle_royale/map/afghan_ground_baked.png"));road_material.set_shader_parameter("ground_ready",true)
	_mesh(map,"DirtRoad",vertices,indices,road_material,uvs)

static func _road_on_triangles(map: Node3D,polygon: PackedVector2Array,from: Vector3,to: Vector3,side: Vector3,width: float,start_distance: float,end_distance: float,vertices: PackedVector3Array,indices: PackedInt32Array,uvs: PackedVector2Array,lift: float) -> void:
	var lo:=polygon[0];var hi:=polygon[0]
	for p in polygon:lo=lo.min(p);hi=hi.max(p)
	var origin:=Vector2(from.x,from.z);var direction:=Vector2(to.x-from.x,to.z-from.z)
	var across:=Vector2(side.x,side.z).normalized()
	for x in range(floori(lo.x/5.),floori(hi.x/5.)+1):
		for z in range(floori(lo.y/5.),floori(hi.y/5.)+1):
			var a:=Vector2(x*5.,z*5.);var b:=a+Vector2(5,0);var c:=a+Vector2(0,5);var d:=a+Vector2(5,5)
			for triangle: PackedVector2Array in [PackedVector2Array([a,b,c]),PackedVector2Array([b,d,c])]:
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(polygon,triangle):
					var faces:=Geometry2D.triangulate_polygon(clipped)
					if faces.is_empty():continue
					var offset:=vertices.size()
					for p in clipped:
						vertices.append(map.point(p.x,p.y)+Vector3.UP*lift)
						var along:=clampf((p-origin).dot(direction)/maxf(.00001,direction.length_squared()),0.,1.)
						uvs.append(Vector2(.5+(p-origin).dot(across)/width,lerpf(start_distance,end_distance,along)))
					for i in range(0,faces.size(),3):
						var fa:=offset+faces[i];var fb:=offset+faces[i+1];var fc:=offset+faces[i+2]
						if (vertices[fb]-vertices[fa]).cross(vertices[fc]-vertices[fa]).y<0.:indices.append_array(PackedInt32Array([fa,fc,fb]))
						else:indices.append_array(PackedInt32Array([fa,fb,fc]))

static func _stream(map: Node3D) -> void:
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
	for z in range(-960,960,3):
		var x:=LAND.stream_center(z);var next_x:=LAND.stream_center(z+3)
		var width:=1.8+.25*sin(z*.017)
		var start:=vertices.size()
		vertices.append_array(PackedVector3Array([Vector3(x-width,LAND.stream_water_height(z),z),Vector3(x+width,LAND.stream_water_height(z),z),Vector3(next_x-width,LAND.stream_water_height(z+3),z+3),Vector3(next_x+width,LAND.stream_water_height(z+3),z+3)]))
		indices.append_array(PackedInt32Array([start,start+2,start+1,start+1,start+2,start+3]))
	var material:=ShaderMaterial.new();material.shader=preload("res://modes/battle_royale/map/afghan_water.gdshader")
	_mesh(map,"ShallowCreek",vertices,indices,material)

static func _field(map: Node3D,farm: Dictionary,groups: Dictionary,rng: RandomNumberGenerator) -> void:
	var half: Vector2=farm.size*.5
	# Low crop clusters, not the cancelled tall-grass prototype. No collisions.
	var columns:=maxi(1,roundi(farm.size.x/3.));var rows:=ceili(float(CROP_CLUSTERS)/columns)
	for i in CROP_CLUSTERS:
		var x: float=farm.position.x-half.x+(i%columns+.5)*farm.size.x/columns+rng.randf_range(-.6,.6)
		var z: float=farm.position.z-half.y+(i/columns+.5)*farm.size.y/rows+rng.randf_range(-.6,.6)
		var angle:=rng.randf_range(-PI,PI)
		if not Geometry2D.is_point_in_polygon(Vector2(x,z),farm.outline):continue
		var p: Vector3=map.point(x,z)
		_detail(groups,"crop_patch_v3",Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(1.45,1.3,1.45)),p),Color("b6ac73") if farm.crop=="wheat" else Color("6f8a50"))

static func _irrigation(map: Node3D) -> void:
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
	for channel: Dictionary in LAND.irrigation_layout():
		for pair in [[channel.a,channel.b],[channel.b,channel.c]]:
			var a: Vector2=pair[0];var b: Vector2=pair[1]
			var side: Vector2=(b-a).normalized().orthogonal()*1.1
			var count:=maxi(1,ceili(a.distance_to(b)/3.))
			for i in count:
				var from: Vector2=a.lerp(b,float(i)/count);var to: Vector2=a.lerp(b,float(i+1)/count)
				# A lane crossing retains its surface. Bed marks resume beyond it.
				if _near_path(Vector3(from.x,0,from.y),5.):continue
				var start:=vertices.size()
				for p: Vector2 in [from-side,from+side,to-side,to+side]:vertices.append(map.point(p.x,p.y)+Vector3.UP*.025)
				indices.append_array(PackedInt32Array([start,start+1,start+2,start+1,start+3,start+2]))
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("504d3b");mat.roughness=1.
	_mesh(map,"IrrigationBeds",vertices,indices,mat)

static func _bridges(map: Node3D,groups: Dictionary) -> void:
	var placed: Array[Vector3]=[]
	for road: Dictionary in LAND.roads():
		for i in road.points.size()-1:
			var a: Vector3=road.points[i];var b: Vector3=road.points[i+1]
			var da:=a.x-LAND.stream_center(a.z);var db:=b.x-LAND.stream_center(b.z)
			if da*db>0 or absf(da-db)<.01: continue
			var p:=a.lerp(b,clampf(da/(da-db),0,1));p.y=LAND.stream_water_height(p.z)+.35
			var near:=false
			for other in placed:
				if other.distance_to(p)<18.: near=true;break
			if near: continue
			placed.append(p)
			var direction: Vector3=(b-a).normalized();var yaw:=atan2(direction.x,direction.z)
			map.add_piece("rural_bridge_v2",Transform3D(Basis(Vector3.UP,yaw),p),groups)


