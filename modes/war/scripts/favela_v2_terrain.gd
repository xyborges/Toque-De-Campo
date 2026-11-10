extends RefCounted
## Favela V2 / Etapa 2: malha de relevo, mesma colisao no cliente e na autoridade.
## Chunk + grade 5m reutilizam os mesmos samples; nao modifica a Favela publica.
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const TERRAIN_CHUNK=preload("res://modes/war/library/favela_v2_terrain_chunk.tscn")
const ROCK_FACE=preload("res://modes/war/library/favela_v2_rock_barrier.tscn")
const STEP:=5.0
const CHUNK:=100.0
const BOUNDS=TOPO.BOUNDS
const COLS:=171 # (850 / 5) + 1
const ROWS:=121 # (600 / 5) + 1
const CLIFF_HEIGHT:=23.0
const CLIFF_WIDTH:=5.5
## The west hillside is bounded by rocky contours with ONE opening at
## (-155, 14), facing central_hub. No path crosses the perimeter elsewhere.
const WEST_CLIFF_A=[
	Vector2(-402,-215),Vector2(-409,-104),Vector2(-409,10),
	Vector2(-402,75),Vector2(-351,96),Vector2(-295,93),
	Vector2(-227,75),Vector2(-184,48),Vector2(-154,26)
]
const WEST_CLIFF_B=[
	Vector2(-153,2),Vector2(-179,-13),Vector2(-191,-50),
	Vector2(-194,-101),Vector2(-199,-148),Vector2(-222,-175),
	Vector2(-260,-197),Vector2(-329,-204),Vector2(-402,-215)
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
	# South-to-north hill: steep overall ascent, local roads terraced to
	# the NODE_HEIGHTS above. No flat square map between bases anymore.
	var base:=47.0-p.y*.132+1.8*sin(p.x*.015)*cos(p.y*.012)
	var d:=Vector2((p.x+283.0)/148.0,(p.y+60.0)/145.0)
	base+=12.0*exp(-.5*d.length_squared())
	for hill: Dictionary in TOPO.HILL_CONTOURS:
		var center: Vector2=hill["center"]
		var radius: Vector2=hill["radius"]
		var q:=Vector2((p.x-center.x)/radius.x,(p.y-center.y)/radius.y)
		var rim:=absf(q.length()-1.0)
		base+=4.0*exp(-.5*pow(rim/.17,2.0))
	# Irregular earthen banks hide the technical rectangular mesh border;
	# the intended walkable footprint stays contained within organic hills.
	var dist_edge:=minf(minf(p.x-BOUNDS.position.x,BOUNDS.end.x-p.x),
		minf(p.y-BOUNDS.position.y,BOUNDS.end.y-p.y))
	var drift:=43.0+8.0*sin(p.x*.019)+5.0*cos(p.y*.024)
	var margin:=clampf((drift-dist_edge)/maxf(drift,1.0),0.0,1.0)
	base+=19.0*margin*margin
	return base

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
	if best_dist<best_width+11.0:
		var blend:=1.0-smoothstep(best_width+1.0,best_width+11.0,best_dist)
		return lerpf(natural,best_road_alt,blend)
	return natural

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
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("#baa184")
	mat.vertex_color_use_as_albedo=true
	mat.roughness=.95
	mat.metallic=0.0
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
			var alt_color:=clampf((h-14.0)/45.0,0.0,1.0)
			var color:=Color("#827455").lerp(Color("#878078"),alt_color)
			if slope>.22:color=Color("#73695e")
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
	var material:=_terrain_material()
	material.albedo_color=Color("#e7ded0")
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

static func _build_west_rock_faces(parent: Node3D,visuals: bool)->int:
	_setup()
	var count:=0
	for segment: Dictionary in _cliff_segments:
		var a: Vector2=segment["a"]
		var b: Vector2=segment["b"]
		var axis: Vector2=(b-a).normalized()
		var span:=a.distance_to(b)
		var middle: Vector2=(a+b)*.5
		var a_height:=height_at(a.x,a.y)
		var b_height:=height_at(b.x,b.y)
		var middle_height:=height_at(middle.x,middle.y)
		# The visible face joins the ridge; its simple solid is above the crest
		# so the 42cm GameStepMotion solver CANNOT climb through the perimeter.
		var bottom:=minf(minf(a_height,b_height),middle_height)-32.0
		var top:=maxf(maxf(a_height,b_height),middle_height)+5.0
		var block_height:=top-bottom
		var shape:=BoxShape3D.new()
		shape.size=Vector3(span+2.6,block_height,3.2)
		var body:=ROCK_FACE.instantiate() as StaticBody3D
		body.name="FaceRochosaMorro_%02d" %count
		body.position=Vector3(middle.x,(top+bottom)*.5,middle.y)
		body.rotation.y=atan2(-axis.y,axis.x)
		parent.add_child(body)
		(body.get_node("ParedeFisica") as CollisionShape3D).shape=shape
		if visuals:
			var box:=BoxMesh.new()
			box.size=shape.size
			var view:=body.get_node("RochaVisivel") as MeshInstance3D
			view.mesh=box
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
