extends Node3D

# QA-only presentation. No authoritative logic, collision or per-blade nodes.
# A shared mesh/material is instanced only around the observer. Generation is
# sliced into candidate budgets; the budget is not a guarantee of frame time.
const LAB=preload("res://tests/nova_grama_lab.gd")
const CARPET=preload("res://tests/nova_grass_carpet.gd")
const CELL:=20.0
const PATCH:=2.0
const RADIUS:=2
const MAX_CELLS:=(RADIUS*2+1)*(RADIUS*2+1)
const CANDIDATES_PER_FRAME:=12
const MAP_HALF:=1750.0
# Conservative allowance for blade width, lean on slopes and vertex wind.
const FOOTPRINT_HALF:=PATCH*.5+.85
var world: Node3D
var observer: Camera3D
var mask: Node3D
var mesh: ArrayMesh
var material: ShaderMaterial
var cells: Dictionary={}
var requested: Dictionary={}
var pending: Array[Vector2i]=[]
var retired: Array[Vector2i]=[]
var centre:=Vector2i(2147483647,2147483647)
var created:=0
var retired_count:=0
var max_build_ms:=0.0
var max_cell_cpu_ms:=0.0
var max_candidates_per_frame:=0
var peak_cell_count:=0
var initialised:=false
var _building: Dictionary={}

func _ready() -> void:
	set_process(initialised)

func configure(target_world: Node3D,target_camera: Camera3D) -> bool:
	if initialised or not is_inside_tree() or DisplayServer.get_name()=="headless": return false
	if not is_instance_valid(target_world) or not target_world.is_inside_tree() or not is_instance_valid(target_camera) or not target_camera.is_inside_tree(): return false
	world=target_world;observer=target_camera;mask=LAB.new()
	if not mask.load_map(): mask.free();mask=null;world=null;observer=null;return false
	var factory: Node3D=CARPET.new();mesh=factory._blade_mesh();factory.free()
	material=ShaderMaterial.new();material.shader=load("res://tests/nova_grass_carpet.gdshader")
	initialised=true;set_process(true);_requeue();return true

func clear() -> void:
	# Queue only nodes owned by this instance; the map and original batches
	# are never mutated. Queued cells are hidden immediately for rollback.
	initialised=false;set_process(false);_building.clear()
	for item: Variant in cells.values():
		if is_instance_valid(item):
			item.hide()
			if not item.is_queued_for_deletion(): item.queue_free()
	cells.clear();requested.clear();pending.clear();retired.clear()
	if is_instance_valid(mask): mask.free()
	mask=null;mesh=null;material=null;world=null;observer=null
	centre=Vector2i(2147483647,2147483647)

func _exit_tree() -> void:
	clear()

func _requeue() -> void:
	if not is_instance_valid(observer): return
	var pos:=observer.global_position
	var next:=Vector2i(floori(pos.x/CELL),floori(pos.z/CELL))
	if next==centre: return
	centre=next;requested.clear();pending.clear();retired.clear()
	for x in range(-RADIUS,RADIUS+1):
		for z in range(-RADIUS,RADIUS+1): requested[centre+Vector2i(x,z)]=true
	# An unfinished old cell may be abandoned, but never attached later at
	# a stale position after a teleport or fast observer movement.
	if not _building.is_empty() and not requested.has(_building.id): _building.clear()
	for id: Vector2i in requested:
		if not cells.has(id): pending.append(id)
	pending.sort_custom(func(a: Vector2i,b: Vector2i):
		var da:=Vector2(a-centre).length_squared();var db:=Vector2(b-centre).length_squared()
		if da!=db: return da<db
		return a.x<b.x or (a.x==b.x and a.y<b.y))
	for id: Vector2i in cells:
		if not requested.has(id): retired.append(id)

func _process(_delta: float) -> void:
	if not initialised: return
	if not is_instance_valid(observer) or not is_instance_valid(world): clear();return
	_requeue()
	# Retire first: otherwise continuous motion could keep adding new cells
	# while retirement starves, allowing the working set to grow unbounded.
	if not retired.is_empty():
		var id: Vector2i=retired.pop_front();var old: Variant=cells.get(id)
		if is_instance_valid(old): old.hide();old.queue_free()
		cells.erase(id);retired_count+=1
		return
	if pending.is_empty(): return
	var started:=Time.get_ticks_usec()
	if _building.is_empty():
		var id: Vector2i=pending.front()
		var rng:=RandomNumberGenerator.new();rng.seed=id.x*71231+id.y*93187+329
		_building={"id":id,"cursor":0,"poses":[],"rng":rng,"cpu_ms":0.0}
	var count:=0;var candidates:=int(CELL/PATCH)*int(CELL/PATCH)
	while count<CANDIDATES_PER_FRAME and int(_building.cursor)<candidates:
		var cursor:=int(_building.cursor);_building.cursor=cursor+1;count+=1
		var id: Vector2i=_building.id
		var p:=Vector2(id.x*CELL,id.y*CELL)+Vector2((cursor/int(CELL/PATCH)+.5)*PATCH,(cursor%int(CELL/PATCH)+.5)*PATCH)
		if not _patch_allowed(p): continue
		var pose:=_ground_pose(p,_building.rng)
		_building.poses.append(pose)
	max_candidates_per_frame=maxi(max_candidates_per_frame,count)
	if int(_building.cursor)>=candidates:
		var id: Vector2i=_building.id
		var poses: Array[Transform3D]=[];poses.assign(_building.poses)
		# The queue retains the current cell until it is finished, so a
		# caller waiting for pending to empty also waits for its final build.
		cells[id]=_commit_cell(poses);pending.erase(id);created+=1
		peak_cell_count=maxi(peak_cell_count,cells.size())
	var work_ms:=float(Time.get_ticks_usec()-started)*.001
	max_build_ms=maxf(max_build_ms,work_ms);_building.cpu_ms=float(_building.cpu_ms)+work_ms
	if int(_building.cursor)>=candidates:
		max_cell_cpu_ms=maxf(max_cell_cpu_ms,float(_building.cpu_ms));_building.clear()

func _field_footprint(p: Vector2) -> bool:
	if not is_instance_valid(mask): return false
	var image: Image=mask.image
	if image==null or image.is_empty(): return false
	# Test every mask texel touched by the conservative footprint. Merely
	# testing the centre/corners can miss a narrow burnt stripe in a PNG.
	var first:=p-Vector2.ONE*FOOTPRINT_HALF;var last:=p+Vector2.ONE*FOOTPRINT_HALF
	if first.x< -MAP_HALF or first.y< -MAP_HALF or last.x>MAP_HALF or last.y>MAP_HALF: return false
	var size:=Vector2(image.get_width(),image.get_height())
	var first_pixel:=(first+Vector2.ONE*MAP_HALF)/(MAP_HALF*2.)*size
	var last_pixel:=(last+Vector2.ONE*MAP_HALF)/(MAP_HALF*2.)*size
	for x in range(clampi(floori(first_pixel.x),0,image.get_width()-1),clampi(floori(last_pixel.x),0,image.get_width()-1)+1):
		for z in range(clampi(floori(first_pixel.y),0,image.get_height()-1),clampi(floori(last_pixel.y),0,image.get_height()-1)+1):
			var texel_centre:=(Vector2(x+.5,z+.5)/size)*(MAP_HALF*2.)-Vector2.ONE*MAP_HALF
			if int(mask.biome(texel_centre))!=0: return false
	return true

func _patch_allowed(p: Vector2) -> bool:
	return _field_footprint(p) and WarVegetation.clear_site(p,true) and WarRoads.distance(p)>=10. and WarTerrain.trench_distance(p)>=6.

func _ground_pose(p: Vector2,rng: RandomNumberGenerator) -> Transform3D:
	var point:=WarTerrain.point(p.x,p.y)
	var normal:=Vector3(WarTerrain.height_at(p.x-.4,p.y)-WarTerrain.height_at(p.x+.4,p.y),.8,WarTerrain.height_at(p.x,p.y-.4)-WarTerrain.height_at(p.x,p.y+.4)).normalized()
	var yaw:=rng.randi_range(0,3)*PI*.5;var scale:=Vector3(1.,rng.randf_range(.82,1.15),1.)
	var pose:=Transform3D(Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,yaw)*Basis.from_scale(scale),point)
	return world.global_transform.affine_inverse()*pose

func _commit_cell(poses: Array[Transform3D]) -> MultiMeshInstance3D:
	if poses.is_empty(): return null
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=poses.size()
	for i in poses.size(): mm.set_instance_transform(i,poses[i])
	var node:=MultiMeshInstance3D.new();node.name="GrassStreamCell";node.multimesh=mm;node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=50.;world.add_child(node)
	return node
