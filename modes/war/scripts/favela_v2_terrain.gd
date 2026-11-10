extends RefCounted
## Favela V2 / Etapa 2: malha de relevo, mesma colisao no cliente e na autoridade.
## Chunk + grade 5m reutilizam os mesmos samples; nao modifica a Favela publica.
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const TERRAIN_CHUNK=preload("res://modes/war/library/favela_v2_terrain_chunk.tscn")
const ROCK_FACE=preload("res://modes/war/library/favela_v2_rock_barrier.tscn")
const STEP:=5.0
const CHUNK:=100.0
const BOUNDS=TOPO.BOUNDS
const COLS:=129 # (640 / 5) + 1
const ROWS:=135 # (670 / 5) + 1
const CLIFF_HEIGHT:=14.0
const CLIFF_WIDTH:=8.0
## Rock geology runs along TWO isolated hillside outcrops. It never
## encloses the neighborhood in a perimeter, bowl, or ring. Bots use the
## explicit topology; central_hub -> portal_oeste is its ONLY access.
const WEST_CLIFF_A=[
	Vector2(-286,-257),Vector2(-254,-222),
	Vector2(-221,-187),Vector2(-176,-193)
]
const WEST_CLIFF_B=[
	Vector2(-300,135),Vector2(-273,103),Vector2(-245,83)
]
# Uphill war: police starts below, criminals defend the summit.
# The western houses remain a SIDE BRANCH from central_hub, never a
# shortcut to base_norte. Height values are deliberate gameplay anchors.
const NODE_HEIGHTS={
	"base_sul":10.0,"rua_baixa":14.0,"curva_entrada":21.0,
	"praca":30.0,"central_hub":40.0,"mercadinho":49.0,
	"escada_central":58.0,"retorno_alto":66.0,
	"rua_norte":78.0,"acesso_norte":87.0,"base_norte":98.0,
	"campinho":35.0,"curva_leste":44.0,"beco_leste":57.0,
	"praceta_leste":66.0,
	"portal_oeste":43.0,"beco_baixo":47.0,
	"escada_sul":55.0,"patio_oeste":61.0,
	"escada_longa":70.0,"plato_casas":77.0,
	"mirante":83.0,"beco_meio":56.0,"escada_curta":70.0,
	"plato_telha":82.0
}
static var _samples:=PackedFloat32Array()
static var _segments: Array[Dictionary]=[]
static var _cliff_segments: Array[Dictionary]=[]

static func reset_cache()->void:
	_samples=PackedFloat32Array()
	_segments.clear()
	_cliff_segments.clear()

static func _closest(p: Vector2,a: Vector2,b: Vector2)->Dictionary:
	var ab:=b-a
	var t:=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.01),0.0,1.0)
	var foot:=a+ab*t
	return {"distance":p.distance_to(foot),"t":t}

static func _setup()->void:
	if not _segments.is_empty():return
	for link: Dictionary in TOPO.LINKS:
		var points:=TOPO.polyline(link)
		var route_length:=TOPO.length_of(link)
		var walked:=0.0
		var h_start: float=NODE_HEIGHTS[str(link["a"])]
		var h_end: float=NODE_HEIGHTS[str(link["b"])]
		for i in points.size()-1:
			var a: Vector2=points[i]
			var b: Vector2=points[i+1]
			var span:=a.distance_to(b)
			if span<.01:continue
			var altitude_a:=lerpf(h_start,h_end,walked/maxf(route_length,.01))
			walked+=span
			var altitude_b:=lerpf(h_start,h_end,walked/maxf(route_length,.01))
			_segments.append({"a":a,"b":b,"h0":altitude_a,
				"h1":altitude_b,"half_width":float(link["width"])*.5,
				"min":Vector2(minf(a.x,b.x)-15.0,minf(a.y,b.y)-15.0),
				"max":Vector2(maxf(a.x,b.x)+15.0,maxf(a.y,b.y)+15.0)})
	for contour in [WEST_CLIFF_A,WEST_CLIFF_B]:
		for i in contour.size()-1:
			_cliff_segments.append({"a":contour[i],"b":contour[i+1]})

static func _natural(p: Vector2)->float:
	# True hillside: the landmass climbs continuously from SOUTH (police)
	# toward NORTH (traffickers). No perimeter uplift / crater / circular
	# HILL_CONTOURS: the whole city is built ON the slope, not inside it.
	var climb:=clampf((260.0-p.y)/560.0,0.0,1.0)
	var ascent:=8.0+94.0*pow(climb,1.08)
	# An elongated western shoulder, not a separate hill or walled ring.
	# Its crest follows the climb as a natural meandering ridge.
	var west_spine_x:=-187.0+25.0*sin((p.y+100.0)*.011)
	var distance_spine:=(p.x-west_spine_x)/115.0
	var shoulder:=16.0*pow(climb,.86)*exp(-.5*distance_spine*distance_spine)
	# Large scale terracing + small drainage gullies: few dominant
	# elevation bands, so players read "I am climbing" from any street.
	var step_band:=.75*sin((p.y+35.0)*.036)*smoothstep(.12,.85,climb)
	var erosion:=2.2*sin(.021*p.x+.010*p.y)*sin(.015*p.y)
	var grain:=.55*sin(.082*p.x)*cos(.073*p.y)
	# Northern ridge at the BACK of the western cul-de-sac. It blocks a
	# direct on-foot cut toward the traffickers' base while staying clear
	# of the official S-road. Unlike the rejected ring-wall, these are
	# broad earth/stone mountains, shared by the visual + physical mesh.
	var ridge_center_z:=-231.0+7.0*sin(p.x*.029)
	var ridge_fade_x:=smoothstep(-309.0,-285.0,p.x)*(1.0-smoothstep(-123.0,-100.0,p.x))
	var northern_ridge:=31.5*ridge_fade_x*exp(-.5*pow((p.y-ridge_center_z)/10.0,2.0))
	# A separate natural outer shoulder deters wandering around the
	# western edge of the dead-end district; the entry at l00 stays open.
	var west_center_x:=-295.0+5.0*sin(p.y*.021)
	var flank:=17.0*exp(-.5*pow((p.x-west_center_x)/13.0,2.0))
	flank*=smoothstep(-255.0,-204.0,p.y)*(1.0-smoothstep(105.0,153.0,p.y))
	return ascent+shoulder+step_band+erosion+grain+northern_ridge+flank

static func _height_raw(p: Vector2)->float:
	var natural:=_natural(p)
	var cliff:=0.0
	for wall: Dictionary in _cliff_segments:
		var a: Vector2=wall["a"]
		var b: Vector2=wall["b"]
		if p.x<minf(a.x,b.x)-18.0 or p.x>maxf(a.x,b.x)+18.0:continue
		if p.y<minf(a.y,b.y)-18.0 or p.y>maxf(a.y,b.y)+18.0:continue
		var distance: float=_closest(p,a,b)["distance"]
		cliff=maxf(cliff,CLIFF_HEIGHT*exp(-.5*pow(distance/CLIFF_WIDTH,2.0)))
	natural+=cliff
	var best_dist:=INF
	var best_road_alt:=natural
	var best_width:=0.0
	for road: Dictionary in _segments:
		var low: Vector2=road["min"]
		var high: Vector2=road["max"]
		if p.x<low.x or p.x>high.x or p.y<low.y or p.y>high.y:continue
		var projection:=_closest(p,road["a"],road["b"])
		var distance: float=projection["distance"]
		if distance<best_dist:
			best_dist=distance
			best_width=float(road["half_width"])
			best_road_alt=lerpf(float(road["h0"]),float(road["h1"]),float(projection["t"]))
	var ground:=natural
	if best_dist<best_width+11.0:
		var blend:=1.0-smoothstep(best_width+1.0,best_width+11.0,best_dist)
		ground=lerpf(natural,best_road_alt,blend)
	# Actual terraces: safe team spawns and the original prefab football field
	# need locally level SOIL. All platforms share this exact physics mesh.
	for base_id in ["base_sul","base_norte"]:
		var base_p:Vector2=TOPO.NODES[base_id]["p"]
		var dist:=p.distance_to(base_p)
		if dist<27.0:
			ground=lerpf(float(NODE_HEIGHTS[base_id]),ground,smoothstep(18.0,27.0,dist))
	var field:Vector2=TOPO.NODES["campinho"]["p"]
	var field_u:=maxf(absf(p.x-field.x)/25.0,absf(p.y-field.y)/16.0)
	if field_u<1.45:
		ground=lerpf(float(NODE_HEIGHTS["campinho"]),ground,smoothstep(1.02,1.45,field_u))
	return ground

static func _ensure_samples()->void:
	if not _samples.is_empty():return
	_setup()
	_samples.resize(COLS*ROWS)
	for z in ROWS:
		for x in COLS:
			var p:=BOUNDS.position+Vector2(float(x),float(z))*STEP
			_samples[z*COLS+x]=_height_raw(p)

static func _height_index(x: int,z: int)->float:
	return _samples[clampi(z,0,ROWS-1)*COLS+clampi(x,0,COLS-1)]

static func height_at(x: float,z: float)->float:
	_ensure_samples()
	var px:=clampf((x-BOUNDS.position.x)/STEP,0.0,float(COLS-1)-.0001)
	var pz:=clampf((z-BOUNDS.position.y)/STEP,0.0,float(ROWS-1)-.0001)
	var ix:=floori(px)
	var iz:=floori(pz)
	var u:=px-float(ix)
	var v:=pz-float(iz)
	var a:=_height_index(ix,iz)
	var b:=_height_index(ix+1,iz)
	var c:=_height_index(ix,iz+1)
	var e:=_height_index(ix+1,iz+1)
	if u+v<=1.0:return a+(b-a)*u+(c-a)*v
	return e+(c-e)*(1.0-u)+(b-e)*(1.0-v)

static func _normal_at(x: int,z: int)->Vector3:
	var left:=_height_index(x-1,z)
	var right:=_height_index(x+1,z)
	var down:=_height_index(x,z-1)
	var up:=_height_index(x,z+1)
	return Vector3((left-right)/(2.0*STEP),1.0,(down-up)/(2.0*STEP)).normalized()

static func _terrain_material()->StandardMaterial3D:
	# Keep the original Favela's sand material assets. One shared material
	# across 49 chunks with triplanar UVs on the physical hillside.
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color.WHITE
	mat.albedo_texture=load("res://assets/environment/materials/sand-albedo.png")
	mat.normal_enabled=true
	mat.normal_scale=.38
	mat.normal_texture=load("res://assets/environment/materials/sand-normal.png")
	mat.roughness=.98
	mat.roughness_texture=load("res://assets/environment/materials/sand-roughness.png")
	mat.uv1_triplanar=true
	mat.uv1_scale=Vector3(.075,.075,.075)
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mat

static func _tile_mesh(x0:int,z0:int,nx:int,nz:int)->ArrayMesh:
	var verts:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for z in nz+1:
		for x in nx+1:
			var ix:=x0+x
			var iz:=z0+z
			var h:=_height_index(ix,iz)
			var normal:=_normal_at(ix,iz)
			verts.append(Vector3(BOUNDS.position.x+float(ix)*STEP,
				h,BOUNDS.position.y+float(iz)*STEP))
			normals.append(normal)
			var slope:=1.0-normal.y
			var high:=clampf((h-8.0)/115.0,0.0,1.0)
			var color:=Color("#e4cdb0").lerp(Color("#c0b5a4"),high)
			color=color.lerp(Color("#92938a"),smoothstep(.17,.46,slope)*.50)
			colors.append(color)
	for z in nz:
		for x in nx:
			var a:=z*(nx+1)+x
			var b:=a+1
			var c:=a+nx+1
			var e:=c+1
			indices.append_array(PackedInt32Array([a,b,c,b,e,c]))
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func _road_material()->StandardMaterial3D:
	# Reuse original Favela concrete; no white debug roads across hills.
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("#c8c0b1")
	material.albedo_texture=load("res://assets/environment/materials/concrete-albedo.png")
	material.roughness=.97
	material.normal_enabled=true
	material.normal_scale=.34
	material.normal_texture=load("res://assets/environment/materials/concrete-normal.png")
	material.uv1_triplanar=true
	material.uv1_scale=Vector3(.085,.085,.085)
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	return material

static func _roads_preview(parent: Node3D)->int:
	# No physical road plane: tracks only mark the flattened *physical* soil.
	var verts:=PackedVector3Array()
	var colors:=PackedColorArray()
	var normals:=PackedVector3Array()
	var indices:=PackedInt32Array()
	var total:=0
	for link: Dictionary in TOPO.LINKS:
		var points:=TOPO.polyline(link)
		var width:=float(link["width"])
		var tint:=Color("#c6c3b7") if str(link["kind"])=="rua" else Color("#a69b84")
		if str(link["kind"])=="escada":tint=Color("#c2b19d")
		for j in points.size()-1:
			var a:=points[j]
			var b:=points[j+1]
			var axis: Vector2=(b-a).normalized()
			var side:=Vector2(-axis.y,axis.x)
			var count:=maxi(1,ceili(a.distance_to(b)/4.0))
			for k in count:
				var pt0:=a.lerp(b,float(k)/float(count))
				var pt1:=a.lerp(b,float(k+1)/float(count))
				var first:=verts.size()
				for center in [pt0,pt1]:
					for sign in [-1.0,1.0]:
						var q: Vector2=center+side*width*.5*float(sign)
						verts.append(Vector3(q.x,height_at(q.x,q.y)+.075,q.y))
						colors.append(tint)
						normals.append(Vector3.UP)
				indices.append_array(PackedInt32Array([first,first+2,first+1,first+1,first+2,first+3]))
				total+=2
	if verts.is_empty():return 0
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var road_mesh:=ArrayMesh.new()
	road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new()
	node.name="TracadoV2VisualSemColisao"
	node.mesh=road_mesh
	node.material_override=_road_material()
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return total

static var _rock_visual_material: StandardMaterial3D

static func _rock_material()->StandardMaterial3D:
	if _rock_visual_material!=null:return _rock_visual_material
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("#b6a08b")
	material.albedo_texture=load("res://assets/environment/materials/rock-albedo.png")
	material.roughness=1.0
	material.normal_enabled=true
	material.normal_scale=.65
	material.normal_texture=load("res://assets/environment/materials/rock-normal.png")
	material.uv1_triplanar=true
	material.uv1_scale=Vector3(.14,.14,.14)
	_rock_visual_material=material
	return material

static func _rock_bank_mesh(a: Vector2,b: Vector2,center_height: float)->ArrayMesh:
	# Five short geological outcrops, never a closed artificial wall.
	# Irregular crest and foot share ONE mesh for visualization + physics.
	var length:=a.distance_to(b)
	var subdivisions:=maxi(2,ceili(length/4.2))
	var verts:=PackedVector3Array()
	for i in subdivisions+1:
		var t:=float(i)/float(subdivisions)
		var p:=a.lerp(b,t)
		var x:=length*(t-.5)
		var local_height:=height_at(p.x,p.y)
		var ridge:=local_height+4.1+sin(float(i)*1.7)*1.1
		var low:=local_height-7.5
		var width:=1.8+sin(float(i)*1.13)*.35
		verts.append(Vector3(x,low-center_height,-width))
		verts.append(Vector3(x,ridge-center_height,-width*.58))
		verts.append(Vector3(x,ridge-center_height,width*.58))
		verts.append(Vector3(x,low-center_height,width))
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in subdivisions:
		var start:=i*4
		var next:=(i+1)*4
		for face in 4:
			var k:=(face+1)%4
			for index in [start+face,next+face,start+k,start+k,next+face,next+k]:
				tool.add_vertex(verts[index])
	for index in [0,2,1,0,3,2]:
		tool.add_vertex(verts[index])
	var end:=subdivisions*4
	for index in [end,end+1,end+2,end,end+2,end+3]:
		tool.add_vertex(verts[index])
	tool.generate_normals()
	return tool.commit()

static func _build_west_rock_faces(parent: Node3D,visuals: bool)->int:
	_setup()
	var count:=0
	for segment: Dictionary in _cliff_segments:
		var a: Vector2=segment["a"]
		var b: Vector2=segment["b"]
		var axis: Vector2=(b-a).normalized()
		var center: Vector2=(a+b)*.5
		var ground_y:=height_at(center.x,center.y)
		var body:=ROCK_FACE.instantiate() as StaticBody3D
		body.name="AfloramentoMorro_%02d" %count
		body.position=Vector3(center.x,ground_y,center.y)
		body.rotation.y=atan2(-axis.y,axis.x)
		parent.add_child(body)
		var rock_mesh:=_rock_bank_mesh(a,b,ground_y)
		var shape:=rock_mesh.create_trimesh_shape()
		shape.backface_collision=true
		(body.get_node("ParedeFisica") as CollisionShape3D).shape=shape
		if visuals:
			var view:=body.get_node("RochaVisivel") as MeshInstance3D
			view.mesh=rock_mesh
			view.material_override=_rock_material()
		count+=1
	return count

static func build(parent: Node3D,visuals: bool=true)->Dictionary:
	_ensure_samples()
	var holder:=Node3D.new()
	holder.name="FavelaV2Terreno"
	parent.add_child(holder)
	var material: StandardMaterial3D=_terrain_material() if visuals else null
	var tiles_x:=ceili(BOUNDS.size.x/CHUNK)
	var tiles_z:=ceili(BOUNDS.size.y/CHUNK)
	var chunk_count:=0
	var triangles:=0
	for tz in tiles_z:
		for tx in tiles_x:
			var ix0:=roundi(float(tx)*CHUNK/STEP)
			var iz0:=roundi(float(tz)*CHUNK/STEP)
			var nx:=mini(roundi(CHUNK/STEP),COLS-1-ix0)
			var nz:=mini(roundi(CHUNK/STEP),ROWS-1-iz0)
			if nx<=0 or nz<=0:continue
			var mesh:=_tile_mesh(ix0,iz0,nx,nz)
			var scene:=TERRAIN_CHUNK.instantiate() as StaticBody3D
			scene.name="Celula_%02d_%02d" %[tx,tz]
			holder.add_child(scene)
			var collision:=scene.get_node("SoloFisico") as CollisionShape3D
			collision.shape=mesh.create_trimesh_shape()
			var view:=scene.get_node("TerrenoVisual") as MeshInstance3D
			if visuals:
				view.mesh=mesh
				view.material_override=material
			triangles+=nx*nz*2
			chunk_count+=1
	var rock_count:=_build_west_rock_faces(holder,visuals)
	var road_tris:=_roads_preview(holder) if visuals else 0
	return {"chunks":chunk_count,"terrain_triangles":triangles,
		"collision_shapes":chunk_count+rock_count,"road_visual_triangles":road_tris,
		"west_rock_faces":rock_count,"west_cliff_segments":_cliff_segments.size(),
		"bounds":BOUNDS.size,"grid_vertices":_samples.size(),"visuals":visuals}
