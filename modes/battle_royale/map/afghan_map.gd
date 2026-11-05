extends Node3D
class_name BRAfghanMap
## Bounded 2 km Afghan valley. Authoritative and client geometry share samples.
## Does not touch WarTerrain, its coast, its cache or user-authored scenes.
const HALF:=1000.0
const STEP:=5.0
const TILE:=200.0
const GRID:=41
const LIB:="res://modes/battle_royale/library/"
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const ENVIRONMENT=preload("res://modes/battle_royale/map/afghan_environment.gd")
const TACTICAL_DENSITY=preload("res://modes/battle_royale/map/afghan_tactical_density.gd")
const BATCH_BUILDER=preload("res://modes/battle_royale/map/afghan_batch_builder.gd")
const BUILDINGS:=["adobe_house_v2","terrace_house_v2","farm_store_v2","qala_compound_v2","stone_ruin_v2"]
static var VILLAGES: Array[Vector3]=LAND.village_centres()
const COUNTS:=LAND.COUNTS
@export var seed:=712907
@export var warm_atmosphere:=true
var render_visuals:=true
var built:=false
var terrain_material: ShaderMaterial
var build_metrics: Dictionary={}
var batch_cache_hits:=0
var batch_cache_misses:=0
var wall_bodies: Dictionary={}
var piece_scenes: Dictionary={}
var terrain_shadow_material: StandardMaterial3D
static var _height_samples: Dictionary={}
static var _loot_cache: Array[Vector3]=[]
static var _spawn_cache: Array[Vector3]=[]
static var _marker_cache: Dictionary={}
static var _mesh_signatures: Dictionary={}
static var _prepared: Resource
static var _prepared_checked:=false

static func _landform(x: float,z: float) -> float:
	return LAND.natural_height(x,z)

static func _raw_height(x: float,z: float) -> float:
	return LAND.rawheight(x,z)

static func _sample(ix: int,iz: int) -> float:
	if not _prepared_checked:
		_prepared_checked=true
		var path:="res://modes/battle_royale/map/prepared/afghan_heights.res"
		if ResourceLoader.exists(path) and not "--terrain-uncached" in OS.get_cmdline_user_args():
			var data: Resource=load(path)
			var valid: bool=data.spacing==STEP and data.heights.size()==data.side*data.side
			if OS.has_feature("editor"):valid=valid and data.source_hash==FileAccess.get_sha256("res://modes/battle_royale/map/afghan_landform.gd")
			if valid:_prepared=data
	if _prepared and ix>=_prepared.minimum and iz>=_prepared.minimum and ix<_prepared.minimum+_prepared.side and iz<_prepared.minimum+_prepared.side:
		return _prepared.heights[(iz-_prepared.minimum)*_prepared.side+ix-_prepared.minimum]
	var key:=Vector2i(ix,iz)
	if not _height_samples.has(key): _height_samples[key]=_raw_height(ix*STEP,iz*STEP)
	return float(_height_samples[key])

static func height_at(x: float,z: float) -> float:
	var ix:=floori(x/STEP);var iz:=floori(z/STEP)
	var fx:=x/STEP-ix;var fz:=z/STEP-iz
	var a:=_sample(ix,iz);var b:=_sample(ix+1,iz);var c:=_sample(ix,iz+1);var d:=_sample(ix+1,iz+1)
	return a+fx*(b-a)+fz*(c-a) if fx+fz<=1. else d+(1.-fx)*(c-d)+(1.-fz)*(b-d)

static func point(x: float,z: float) -> Vector3: return Vector3(x,height_at(x,z),z)

static func accessible(p: Vector3) -> bool:
	if absf(p.x)>940. or absf(p.z)>940.: return false
	var dx:=(height_at(p.x+2.,p.z)-height_at(p.x-2.,p.z))/4.
	var dz:=(height_at(p.x,p.z+2.)-height_at(p.x,p.z-2.))/4.
	return Vector2(dx,dz).length()<tan(deg_to_rad(38.))

static func building_layout() -> Array[Dictionary]:
	return LAND.building_layout()

static func spawn_candidates() -> Array[Vector3]:
	if not _spawn_cache.is_empty(): return _spawn_cache
	for road: Dictionary in LAND.roads():
		if road.kind!="village": continue
		for i in range(1,road.points.size()-1,2):
			var p: Vector3=road.points[i];p=point(p.x,p.z)
			if accessible(p) and not is_water(p): _spawn_cache.append(p+Vector3.UP*.18)
	return _spawn_cache

static func loot_points() -> Array[Vector3]:
	if not _loot_cache.is_empty(): return _loot_cache
	for record in building_layout():
		var id: String=BUILDINGS[int(record.variant)]
		var transform:=Transform3D(Basis(Vector3.UP,float(record.yaw)).scaled(record.scale),record.position)
		for marker: Vector3 in _loot_markers(id): _loot_cache.append(transform*marker)
	_loot_cache.append_array(agricultural_loot_points())
	_loot_cache.append_array(settlement_loot_points())
	return _loot_cache

static func settlement_loot_points() -> Array[Vector3]:
	# Authored ground anchors in villages and along village roads, validated
	# against the same accessibility/slope/water rules as spawns. These keep
	# loot on walkable ground without adding arbitrary drops in crop fields.
	var result: Array[Vector3]=[]
	var seen: Dictionary={}
	var accept: Callable=func(p: Vector3):
		if not p.is_finite() or absf(p.x)>940. or absf(p.z)>940.:return
		if not accessible(p) or is_water(p):return
		var key:=Vector2i(roundi(p.x/3.),roundi(p.z/3.))
		if seen.has(key):return
		seen[key]=true
		result.append(p+Vector3.UP*.15)
	for centre: Vector3 in LAND.village_centres():
		accept.call(centre)
	for road: Dictionary in LAND.roads():
		if str(road.get("kind",""))!="village":continue
		var pts: Array=road.get("points",[])
		for i in range(2,pts.size()-2,3):
			var q: Vector3=pts[i]
			accept.call(Vector3(q.x,height_at(q.x,q.z),q.z))
	return result

static func _loot_markers(id: String) -> Array[Vector3]:
	if _marker_cache.has(id): return _marker_cache[id]
	var node: Node3D=load(LIB+id+".tscn").instantiate();var result: Array[Vector3]=[]
	for child in node.get_children():
		if child is Marker3D and str(child.name).begins_with("Loot"): result.append(child.position)
	node.free();_marker_cache[id]=result;return result

static var _prop_bounds: Dictionary={}

static func grounded_prop(id: String, transform: Transform3D) -> Variant:
	if not _prop_bounds.has(id):
		var node: Node3D=load(LIB+id+".tscn").instantiate()
		var bounds:=AABB();var first:=true
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			var local:=mesh.transform;var parent:=mesh.get_parent() as Node3D
			while parent and parent!=node:local=parent.transform*local;parent=parent.get_parent() as Node3D
			var box: AABB=local*mesh.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
		node.free();_prop_bounds[id]=bounds
	var bounds: AABB=_prop_bounds[id]
	if bounds.size==Vector3.ZERO:return transform
	var low:=INF;var high:=-INF
	for dx in [bounds.position.x,bounds.end.x]:
		for dz in [bounds.position.z,bounds.end.z]:
			var sample: Vector3=transform*Vector3(dx,bounds.position.y,dz)
			var height:=height_at(sample.x,sample.z);low=minf(low,height);high=maxf(high,height)
	if high-low>.45:return null
	transform.origin.y=(low+high)*.5-bounds.position.y*transform.basis.get_scale().y
	return transform

static func agricultural_loot_points() -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for field: Dictionary in LAND.farmland_layout():
		var crate: Vector3=field.crate;var base:=point(crate.x,crate.z)
		var grounded: Variant=grounded_prop("farm_crate_v2",Transform3D(Basis.IDENTITY,base))
		if grounded==null:continue
		for marker: Vector3 in _loot_markers("farm_crate_v2"): result.append(grounded*marker)
	return result

static func is_water(p: Vector3) -> bool:
	return absf(p.x-LAND.stream_center(p.z))<3.5 and p.y<LAND.stream_water_height(p.z)+.15

func build() -> void:
	if built: return
	built=true
	var start:=Time.get_ticks_msec()
	if render_visuals:
		terrain_material=ShaderMaterial.new();terrain_material.shader=preload("res://modes/battle_royale/map/afghan_ground.gdshader")
		terrain_material.set_shader_parameter("rural_detail_enabled",not "--afghan-cover-before" in OS.get_cmdline_user_args())
		terrain_material.set_shader_parameter("sand",load("res://assets/environment/materials/sand-albedo.png"))
		terrain_material.set_shader_parameter("gravel",load("res://assets/environment/materials/concrete-albedo.png"))
		terrain_material.set_shader_parameter("rock",load("res://assets/environment/materials/rock-albedo.png"))
		terrain_material.set_shader_parameter("biome_mask",load("res://modes/battle_royale/map/afghan_biomes.png"))
		terrain_material.set_shader_parameter("soil_normal",load("res://assets/environment/materials/sand-normal.png"))
		terrain_material.set_shader_parameter("agriculture",LAND.agriculture_texture())
		if preload("res://modes/battle_royale/map/afghan_ground_cache.gd").valid() and not "--ground-unbaked" in OS.get_cmdline_user_args():
			terrain_material.set_shader_parameter("baked_color",load("res://modes/battle_royale/map/afghan_ground_baked.png"))
			terrain_material.set_shader_parameter("baked_enabled",true)
	for iz in 10:
		for ix in 10: _terrain_tile(ix,iz)
	_settlements()
	_scatter()
	# User additions are a separate authored scene. Generators only read it.
	if ResourceLoader.exists("res://modes/battle_royale/scenes/map_additions.tscn"):
		var additions: Node3D=load("res://modes/battle_royale/scenes/map_additions.tscn").instantiate();add_child(additions)
		if not render_visuals:
			for visual: Node in additions.find_children("*","GeometryInstance3D",true,false): visual.free()
	if render_visuals: _horizon()
	build_metrics={"terrain_tiles":100,"terrain_near_triangles":320000,"houses":building_layout().size(),"building_variants":5,"spawn_candidates":spawn_candidates().size(),"loot_positions":loot_points().size(),"farms":LAND.farmland_layout().size(),"build_ms":Time.get_ticks_msec()-start,"visuals":render_visuals,"batch_cache_hits":batch_cache_hits,"batch_cache_misses":batch_cache_misses}
	build_metrics["environment"]=get_meta("afghan_environment",{})
	build_metrics["tactical_density"]=get_meta("afghan_density",{})
	build_metrics["density_stage2"]=get_meta("afghan_density_stage2",{})
	build_metrics["density_stage3"]=get_meta("afghan_density_stage3",{})
	build_metrics["context"]=get_meta("afghan_context",{})
	set_meta("br_build_metrics",build_metrics)

func _indices(stride: int) -> PackedInt32Array:
	var indices:=PackedInt32Array()
	for z in range(0,GRID-1,stride):
		for x in range(0,GRID-1,stride):
			var a:=z*GRID+x;var b:=a+stride;var c:=a+GRID*stride;var d:=c+stride
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	return indices

func _terrain_tile(ix: int,iz: int) -> void:
	var origin:=Vector3(ix*TILE-HALF,0,iz*TILE-HALF)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	for z in GRID:
		for x in GRID:
			var wx:=origin.x+x*STEP;var wz:=origin.z+z*STEP
			vertices.append(Vector3(x*STEP,height_at(wx,wz),z*STEP))
			if render_visuals: normals.append(Vector3(height_at(wx-2.,wz)-height_at(wx+2.,wz),4.,height_at(wx,wz-2.)-height_at(wx,wz+2.)).normalized())
	var indices:=_indices(1);var faces:=PackedVector3Array()
	for i in indices: faces.append(vertices[i])
	var body:=StaticBody3D.new();body.name="AfghanTerrain_%d_%d"%[ix,iz];body.position=origin;body.collision_layer=1;body.collision_mask=0;body.set_meta("surface","dirt");add_child(body)
	var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces)
	var col:=CollisionShape3D.new();col.shape=shape;body.add_child(col)
	if not render_visuals: return
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	# Keep each tile edge at full resolution in every LOD to prevent cracks.
	var mesh:=ArrayMesh.new()
	var levels: Dictionary={80.:_lod_indices(2),220.:_lod_indices(4)}
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],levels)
	var view:=MeshInstance3D.new();view.name="Surface";view.mesh=mesh;view.material_override=terrain_material;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;body.add_child(view)
	if warm_atmosphere:_terrain_shadow(body,vertices,normals,indices)

func _terrain_shadow(body: Node3D,vertices: PackedVector3Array,normals: PackedVector3Array,indices: PackedInt32Array) -> void:
	# Flat soil does not cast useful terrain shadows but used to shadow itself
	# into thin bands. Keep the actual hill/embankment triangles as casters;
	# the visible ground still receives shadows from hills, trees and actors.
	var casters:=PackedInt32Array()
	for i in range(0,indices.size(),3):
		var a:=vertices[indices[i]];var b:=vertices[indices[i+1]];var c:=vertices[indices[i+2]]
		if absf((b-a).cross(c-a).normalized().y)<.94:casters.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
	if casters.is_empty():return
	if not terrain_shadow_material:terrain_shadow_material=StandardMaterial3D.new()
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=casters
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var shadow:=MeshInstance3D.new();shadow.name="TerrainShadowCaster";shadow.mesh=mesh;shadow.material_override=terrain_shadow_material;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;body.add_child(shadow)

func _lod_indices(stride: int) -> PackedInt32Array:
	# Boundary fans retain every original tile-edge sample, without T-junctions
	# against coarser interior blocks or a neighbouring tile at a different LOD.
	var result:=PackedInt32Array()
	for z in range(0,GRID-1,stride):
		for x in range(0,GRID-1,stride):
			if x>0 and z>0 and x+stride<GRID-1 and z+stride<GRID-1:
				var a:=z*GRID+x;var b:=a+stride;var c:=a+GRID*stride;result.append_array(PackedInt32Array([a,b,c,b,c+stride,c]));continue
			var perimeter:=PackedInt32Array()
			for fx in range(x,x+stride,1 if z==0 else stride):perimeter.append(z*GRID+fx)
			for fz in range(z,z+stride,1 if x+stride==GRID-1 else stride):perimeter.append(fz*GRID+x+stride)
			for fx in range(x+stride,x,-1 if z+stride==GRID-1 else -stride):perimeter.append((z+stride)*GRID+fx)
			for fz in range(z+stride,z,-1 if x==0 else -stride):perimeter.append(fz*GRID+x)
			var centre: int=(z+stride/2)*GRID+x+stride/2
			for i in perimeter.size():result.append_array(PackedInt32Array([centre,perimeter[i],perimeter[(i+1)%perimeter.size()]]))
	return result

func _settlements() -> void:
	var village_visuals: Dictionary={}
	for record in building_layout():
		var id: String=BUILDINGS[int(record.variant)]
		var transform:=Transform3D(Basis(Vector3.UP,float(record.yaw)).scaled(record.scale),record.position)
		add_piece(id,transform,village_visuals,record.tint)
	finish_static_batches(village_visuals,2300.,true)

func add_piece(id: String,transform: Transform3D,groups: Dictionary,tint:=Color.WHITE) -> Node3D:
	if not piece_scenes.has(id):piece_scenes[id]=load(LIB+id+".tscn")
	var object: Node3D=piece_scenes[id].instantiate();object.transform=transform
	if id in ["clothesline_v2","woodpile_v2","haystack_v2","farm_crate_v2","village_well_v2"]:
		var grounded: Variant=grounded_prop(id,transform)
		if grounded==null:
			set_meta("rejected_unstable_props",int(get_meta("rejected_unstable_props",0))+1)
			object.free();return null
		transform=grounded;object.transform=transform
	var compound: bool=id in ["courtyard_wall_v2","field_bank_v10","field_wall_v10"]
	if not compound:add_child(object)
	for child in object.get_children():
		if child is MeshInstance3D:
			if render_visuals:
				var cell:=Vector2i(floori(transform.origin.x/160.),floori(transform.origin.z/160.))
				var key: String=id+":"+str(cell)
				if not groups.has(key): groups[key]={"mesh":child.mesh,"transforms":[],"colors":[]}
				groups[key].transforms.append(transform*child.transform);groups[key].colors.append(tint)
			child.free()
	if compound:
		# Static compound per cell reduces broad-phase bodies without changing
		# any individual wall shape or its world transform. No runtime mutation.
		var cell:=Vector2i(floori(transform.origin.x/160.),floori(transform.origin.z/160.))
		var body_key: Variant=cell if id=="courtyard_wall_v2" else str(cell)+":"+id
		if not wall_bodies.has(body_key):
			var body:=StaticBody3D.new();body.name="WallCollisions_%d_%d_%s"%[cell.x,cell.y,id];body.position=Vector3(cell.x*160.,0,cell.y*160.);body.collision_layer=1;body.collision_mask=0;body.set_meta("surface","dirt" if id=="field_bank_v10" else "stone");body.set_meta("library_id",id);add_child(body);wall_bodies[body_key]=body
		var body: StaticBody3D=wall_bodies[body_key]
		for child in object.get_children():
			if child is CollisionShape3D:
				var world_transform: Transform3D=transform*child.transform
				child.owner=null;object.remove_child(child);body.add_child(child);child.transform=body.transform.affine_inverse()*world_transform
		object.free();return body
	return object

func finish_batches(groups: Dictionary,reach: float,shadows:=false) -> void:
	if not render_visuals: return
	for key in groups:
		var data: Dictionary=groups[key];var transforms: Array=data.transforms
		if transforms.is_empty(): continue
		var origin: Vector3=transforms[0].origin
		var local: Array=[]
		for t: Transform3D in transforms: t.origin-=origin;local.append(t)
		_multimesh(str(key),data.mesh,local,minf(reach,150.) if data.has("far_mesh") else reach,shadows,data.get("colors",[]))
		(get_child(-1) as Node3D).position=origin
		if data.has("far_mesh"):
			_multimesh(str(key)+"_Far",data.far_mesh,local,reach,false,data.get("colors",[]))
			var far:=get_child(-1) as GeometryInstance3D;far.position=origin;far.visibility_range_begin=150.

func finish_static_batches(groups: Dictionary,reach: float,shadows:=false) -> void:
	if not render_visuals: return
	# Join each material within a spatial cell; colliders remain separate and
	# identical to the server. Static buildings never need per-object updates.
	var cells: Dictionary={}
	for value: Dictionary in groups.values():
		var source: Mesh=value.mesh
		for index in value.transforms.size():
			var transform: Transform3D=value.transforms[index]
			var cell:=Vector2i(floori(transform.origin.x/160.),floori(transform.origin.z/160.))
			if not cells.has(cell): cells[cell]=[]
			var tint: Color=value.colors[index] if index<value.colors.size() else Color.WHITE
			cells[cell].append({"source":source,"transform":transform,"tint":tint})
	for cell: Vector2i in cells:
		var signature:=PackedByteArray()
		for entry: Dictionary in cells[cell]:
			var source: Mesh=entry.source
			var mesh_id:=source.get_instance_id()
			if not _mesh_signatures.has(mesh_id):
				var ctx:=HashingContext.new();ctx.start(HashingContext.HASH_SHA256)
				for surface in source.get_surface_count():
					ctx.update(var_to_bytes(source.surface_get_arrays(surface)))
					var material:=source.surface_get_material(surface)
					ctx.update(var_to_bytes(material.resource_path if material else ""))
				_mesh_signatures[mesh_id]=ctx.finish()
			signature.append_array(var_to_bytes([_mesh_signatures[mesh_id],entry.transform,entry.tint,"lod-color-v2"]))
		var key_hash:=HashingContext.new();key_hash.start(HashingContext.HASH_SHA256);key_hash.update(signature)
		var cached_path: String="res://modes/battle_royale/map/baked/"+key_hash.finish().hex_encode()+".res"
		var merged: ArrayMesh=load(cached_path) as ArrayMesh if ResourceLoader.exists(cached_path) else null
		if not merged:
			batch_cache_misses+=1
			merged=BATCH_BUILDER.build(cells[cell],cell)
			# Explicit authoring only; ordinary gameplay never writes project files.
			if "--bake-afghan-static" in OS.get_cmdline_user_args() and (OS.has_feature("editor") or OS.has_feature("qa")):
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://modes/battle_royale/map/baked"))
				ResourceSaver.save(merged,cached_path)
		else: batch_cache_hits+=1
		var view:=MeshInstance3D.new();view.name="StaticCell_%d_%d"%[cell.x,cell.y]
		view.position=Vector3(cell.x*160.,0,cell.y*160.);view.mesh=merged;view.visibility_range_end=reach
		view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)

func _multimesh(label: String,mesh: Mesh,transforms: Array,reach: float,shadows:=false,colors: Array=[]) -> void:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.use_colors=not colors.is_empty();mm.instance_count=transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
		if not colors.is_empty(): mm.set_instance_color(i,colors[i])
	var view:=MultiMeshInstance3D.new();view.name=label;view.multimesh=mm;view.visibility_range_end=reach;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(view)

func _scatter() -> void:
	ENVIRONMENT.populate(self)
	TACTICAL_DENSITY.populate(self)

func _horizon() -> void:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	# Visual-only mountain ring continues beyond the square; no collision nodes.
	var edge:=int(HALF*2./STEP);var count:=edge*4
	for ring in 10:
		for i in count:
			var side:=i/edge;var t:=float(i%edge)/edge
			var p: Vector2=[Vector2(lerpf(-HALF,HALF,t),-HALF),Vector2(HALF,lerpf(-HALF,HALF,t)),Vector2(lerpf(HALF,-HALF,t),HALF),Vector2(-HALF,lerpf(HALF,-HALF,t))][side]
			var boundary_height:=height_at(p.x,p.y)
			var angle:=atan2(p.y,p.x)
			p*=1.+ring*.24
			# More than one broad radial strip, otherwise the far mountains
			# become giant triangular planes when viewed from the valley.
			var ridge:=pow(.5+.5*sin(angle*5.3+ring*.61+sin(angle*2.7)),1.35)
			var distant:=100.+ridge*170.+32.*sin(angle*11.7-ring*.45)
			var height:=boundary_height if ring==0 else lerpf(boundary_height,distant,smoothstep(0.,4.,float(ring)))
			vertices.append(Vector3(p.x,height,p.y));normals.append(Vector3.UP)
	for ring in 9:
		for i in count:
			var a:=ring*count+i;var b:=ring*count+(i+1)%count;var c:=a+count;var d:=b+count;indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var raw:=ArrayMesh.new();raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface:=SurfaceTool.new();surface.create_from(raw,0);surface.generate_normals()
	var mesh:=surface.commit()
	var view:=MeshInstance3D.new();view.name="DistantMountainsNoCollision";view.mesh=mesh;view.material_override=terrain_material;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(view)
	if warm_atmosphere:
		var material:=ShaderMaterial.new();material.shader=preload("res://modes/battle_royale/map/afghan_horizon.gdshader")
		view.material_override=material
		for node in get_parent().get_children():
			if node is BRAfghanAtmosphere: node.distant_material=material;break
