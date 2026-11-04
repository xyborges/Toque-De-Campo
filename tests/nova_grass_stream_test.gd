extends SceneTree

const Stream=preload("res://tests/nova_grass_stream.gd")
const Lab=preload("res://tests/nova_grama_lab.gd")
var errors: Array[String]=[]

class FlatStream extends "res://tests/nova_grass_stream.gd":
	var empty_cells:=false
	var commits: Dictionary={}
	func _patch_allowed(_p: Vector2) -> bool: return not empty_cells
	func _ground_pose(p: Vector2,rng: RandomNumberGenerator) -> Transform3D:
		return Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(p.x,0.,p.y))
	func _commit_cell(poses: Array[Transform3D]) -> MultiMeshInstance3D:
		commits[_building.id]=poses.duplicate()
		if poses.is_empty(): return null
		var node:=MultiMeshInstance3D.new();world.add_child(node);return node

func check(ok: bool,message: String) -> void:
	if not ok: errors.append(message)

func _initialize() -> void: run.call_deferred()

func step_until_idle(stream: Node3D,limit:=1000) -> bool:
	for i in limit:
		stream._process(1./60.)
		if stream.pending.is_empty() and stream.retired.is_empty(): return true
	return false

func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera)
	var rejected:=Stream.new();root.add_child(rejected)
	if DisplayServer.get_name()=="headless":
		check(not rejected.configure(world,camera) and not rejected.initialised and rejected.mask==null and rejected.mesh==null,"headless rejects visual configuration before allocation")
	rejected.queue_free()
	# Inject only the scheduler's dependencies; this tests queue bounds and
	# ownership without constructing the actual terrain or renderer resources.
	var stream:=FlatStream.new();root.add_child(stream)
	stream.world=world;stream.observer=camera;stream.initialised=true;stream.set_process(false)
	stream._process(1./60.)
	check(stream.created==0 and stream.pending.size()==25,"first frame slices candidates rather than allocating a whole cell")
	check(step_until_idle(stream),"initial cells complete within bounded work")
	check(stream.cells.size()==25 and stream.created==25,"initial working set contains exactly 25 cells")
	check(stream.max_candidates_per_frame<=12,"candidate generation stays within per-frame count budget")
	var first: Array=stream.commits[Vector2i.ZERO].duplicate()
	# Continuous observer teleports used to starve retirement and grow cells
	# forever; the new scheduler must remain bounded while queues are rebuilt.
	for i in 60:
		camera.position.x=float(i+1)*100.
		stream._process(1./60.)
		check(stream.cells.size()<=25,"movement keeps retained cell count bounded")
	check(step_until_idle(stream),"final destination eventually finishes")
	check(stream.cells.size()==25 and stream.peak_cell_count<=25,"stale cells do not survive indefinitely")
	for id: Vector2i in stream.cells: check(stream.requested.has(id),"only requested final cells remain")
	camera.position=Vector3.ZERO
	check(step_until_idle(stream),"return to original destination completes")
	check(stream.commits[Vector2i.ZERO]==first,"regenerated cell uses deterministic transforms")
	stream.clear()
	check(stream.cells.is_empty() and stream.pending.is_empty() and not stream.initialised,"rollback clears scheduler state")
	check(not camera.is_queued_for_deletion() and not world.is_queued_for_deletion(),"rollback preserves map and observer")
	var empty:=FlatStream.new();root.add_child(empty);empty.world=world;empty.observer=camera;empty.initialised=true;empty.empty_cells=true;empty.set_process(false)
	check(step_until_idle(empty),"empty biome cells settle without retrying every frame")
	var empty_created: int=empty.created;empty._process(1./60.)
	check(empty_created==25 and empty.created==empty_created,"empty cell sentinels avoid repeated generation")
	empty.clear()
	var footprint:=Stream.new();root.add_child(footprint);var mask:=Lab.new()
	mask.image=Image.create(1024,1024,false,Image.FORMAT_RGBA8);mask.image.fill(Color8(48,150,54));footprint.mask=mask
	check(footprint._field_footprint(Vector2.ZERO),"green footprint is accepted")
	mask.image.set_pixel(512,512,Color8(108,65,50))
	check(not footprint._field_footprint(Vector2.ZERO),"burnt texel inside footprint rejects entire patch")
	check(not footprint._field_footprint(Vector2(1749.8,0)),"patch outside map is rejected")
	footprint.clear();stream.queue_free();empty.queue_free();footprint.queue_free();world.queue_free()
	await process_frame
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"scope":"isolated scheduler/biome tests; no full-map performance measurement"}))
	quit(0 if errors.is_empty() else 1)
