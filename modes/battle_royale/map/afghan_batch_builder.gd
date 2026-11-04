extends RefCounted
## Build one static cell from source meshes. Cached by the caller after building.
const CELL_SIZE := 160.0

static func build(entries: Array, cell: Vector2i) -> ArrayMesh:
	var groups: Dictionary = {}
	for entry: Dictionary in entries:
		var source: Mesh = entry.get("source")
		if source == null:
			continue
		var transform: Transform3D = entry.get("transform", Transform3D.IDENTITY)
		transform.origin -= Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
		var tint: Color = entry.get("tint", Color.WHITE)
		var normal_basis := transform.basis.inverse().transposed()
		var handedness := -1.0 if transform.basis.determinant() < 0.0 else 1.0
		for surface in source.get_surface_count():
			if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var material := source.surface_get_material(surface)
			var key: int = material.get_instance_id() if material != null else 0
			if not groups.has(key):
				groups[key] = {"material": material, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "tangents": PackedFloat32Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array(), "has_normals": false, "has_tangents": false, "has_uv": false, "has_uv2": false}
			var group: Dictionary = groups[key]
			var arrays: Array = source.surface_get_arrays(surface)
			var src_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array else PackedVector3Array()
			var src_tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array else PackedFloat32Array()
			var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array else PackedVector2Array()
			var src_uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array else PackedVector2Array()
			var src_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
			var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var vertices: PackedVector3Array = group.vertices
			var normals: PackedVector3Array = group.normals
			var tangents: PackedFloat32Array = group.tangents
			var uv: PackedVector2Array = group.uv
			var uv2: PackedVector2Array = group.uv2
			var colors: PackedColorArray = group.colors
			var indices: PackedInt32Array = group.indices
			var base := vertices.size()
			group.has_normals = group.has_normals or src_normals.size() == src_vertices.size()
			group.has_tangents = group.has_tangents or src_tangents.size() == src_vertices.size() * 4
			group.has_uv = group.has_uv or src_uv.size() == src_vertices.size()
			group.has_uv2 = group.has_uv2 or src_uv2.size() == src_vertices.size()
			for i in src_vertices.size():
				vertices.append(transform * src_vertices[i])
				normals.append((normal_basis * src_normals[i]).normalized() if i < src_normals.size() else Vector3.UP)
				var tangent := Vector3(1, 0, 0)
				var w := 1.0
				if 4 * i + 3 < src_tangents.size():
					tangent = (transform.basis * Vector3(src_tangents[4*i], src_tangents[4*i+1], src_tangents[4*i+2])).normalized()
					w = src_tangents[4*i+3] * handedness
				tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, w]))
				uv.append(src_uv[i] if i < src_uv.size() else Vector2.ZERO)
				uv2.append(src_uv2[i] if i < src_uv2.size() else Vector2.ZERO)
				colors.append((src_colors[i] if i < src_colors.size() else Color.WHITE) * tint)
			if src_indices.is_empty():
				for i in src_vertices.size(): indices.append(base + i)
			else:
				for i in src_indices: indices.append(base + i)
			group.vertices = vertices; group.normals = normals; group.tangents = tangents
			group.uv = uv; group.uv2 = uv2; group.colors = colors; group.indices = indices
			groups[key] = group
	var importer := ImporterMesh.new()
	var fallback := ArrayMesh.new()
	for group: Dictionary in groups.values():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.vertices
		arrays[Mesh.ARRAY_COLOR] = group.colors
		arrays[Mesh.ARRAY_INDEX] = group.indices
		if group.has_normals: arrays[Mesh.ARRAY_NORMAL] = group.normals
		if group.has_tangents: arrays[Mesh.ARRAY_TANGENT] = group.tangents
		if group.has_uv: arrays[Mesh.ARRAY_TEX_UV] = group.uv
		if group.has_uv2: arrays[Mesh.ARRAY_TEX_UV2] = group.uv2
		fallback.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		fallback.surface_set_material(fallback.get_surface_count()-1, group.material)
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, group.material)
	if fallback.get_surface_count() == 0:
		return fallback
	importer.generate_lods(60.0, 25.0, [])
	var result := importer.get_mesh()
	return result if result != null and result.get_surface_count() == fallback.get_surface_count() else fallback
