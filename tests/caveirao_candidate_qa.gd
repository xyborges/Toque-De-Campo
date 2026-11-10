extends SceneTree
## Static scene import/geometry QA only. This is not a playable WarVehicle.
var failures: Array[String] = []
var mesh_nodes := 0
var triangles := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	print(("PASS " if condition else "FAIL ") + description)
	if not condition:
		failures.append(description)

func _scan_visual(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_nodes += 1
		var m := node.mesh as Mesh
		if m != null:
			for i in m.get_surface_count():
				if m.surface_get_primitive_type(i) == Mesh.PRIMITIVE_TRIANGLES:
					var arrays := m.surface_get_arrays(i)
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	for child in node.get_children():
		_scan_visual(child)

func _run() -> void:
	var src := load("res://modes/war/library/caveirao_cinza.tscn") as PackedScene
	_check(src != null, "Caveirao scene loadable")
	if src == null:
		quit(1)
		return
	var vehicle := src.instantiate() as Node3D
	root.add_child(vehicle)
	_check(vehicle.get_meta("library_id","") == "caveirao_cinza", "Reusable library ID preserved")
	_check(vehicle.get_meta("model_variant","") == "caminhao_bicudo", "Conventional hood variant")
	_check(vehicle.get_meta("lod_far",0.0) >= 200.0, "LOD metadata present")
	var visual := vehicle.get_node_or_null("VisualCaveirao")
	_check(visual != null, "Imported GLB visual exists")
	if visual:
		_scan_visual(visual)
	_check(mesh_nodes > 0 and triangles > 0, "GLB contains renderable triangle meshes")
	var body := vehicle.get_node_or_null("Corpo") as StaticBody3D
	var collisions := 0
	if body != null:
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D and not child.disabled:
				collisions += 1
	_check(body != null and body.collision_layer == 1 and collisions == 3,
		"Three explicit cabin/hood/hull physical colliders")
	_check(not (vehicle is WarVehicle), "Static library asset; not falsely certified as playable")
	print("CAVEIRAO_CANDIDATE_QA ", JSON.stringify({
		"ok": failures.is_empty(), "failures":failures,
		"render_mesh_nodes":mesh_nodes, "triangle_count":triangles,
		"colliders":collisions, "playable":false
	}))
	vehicle.queue_free()
	await process_frame
	quit.call_deferred(0 if failures.is_empty() else 1)
