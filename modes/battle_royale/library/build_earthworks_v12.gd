extends "res://modes/battle_royale/library/build_library_v2.gd"
## Build two compact earthworks. Explicit authoring only, never overwrite scenes.
func run() -> void:
	prepare_materials()
	earthwork("erosion_berm_v12", 1.42, 2.8, 0)
	earthwork("wadi_bank_v12", .96, 3.6, 1)
	print("AFGHAN_EARTHWORK_V12 ", JSON.stringify({"written":written,"preserved":skipped}))
	quit()

func earthwork(id: String, peak: float, width: float, variant: int) -> void:
	var path := DIR + id + ".tscn"
	if FileAccess.file_exists(path):
		skipped.append(id)
		return
	var body := StaticBody3D.new()
	body.name = id
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("library_id", id)
	body.set_meta("br_library", true)
	body.set_meta("surface", "dirt")
	body.set_meta("resistance", "earthwork")
	body.set_meta("height_m", peak)
	body.set_meta("footprint", Vector2(15, width * 2.0))
	body.set_meta("collision_persistent", true)
	body.set_meta("lod_profile", "physical_cover")
	body.set_meta("lod_near_end", 2300.0)
	body.set_meta("lod_far_end", 2300.0)
	body.set_meta("individual_shadows", false)
	var x_values: Array[float] = [-7.5, -4.2, 0.0, 3.7, 7.5]
	var bands: Array[PackedVector3Array] = []
	var shape_points := PackedVector3Array()
	for band in 4:
		var strip := PackedVector3Array()
		for i in 5:
			var height: float = peak * [0.12, 0.76, 1.0, 0.83, 0.13][i]
			var offset := .19 * sin(float(i) * 1.8 + float(variant) * 1.7)
			var z: float = [-width, -.67, .74, width][band]
			var y: float = -.22 if band == 0 or band == 3 else height + offset
			var point := Vector3(x_values[i], y, z)
			strip.append(point)
			shape_points.append(point)
		bands.append(strip)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in 3:
		for i in 4:
			var a: Vector3 = bands[band][i]
			var b: Vector3 = bands[band][i+1]
			var c: Vector3 = bands[band+1][i+1]
			var d: Vector3 = bands[band+1][i]
			triangle(st, a, c, b, variant)
			triangle(st, a, d, c, variant)
	# End caps below the surface; no unsupported overhangs.
	triangle(st, bands[0][0], bands[1][0], bands[3][0], variant)
	triangle(st, bands[1][0], bands[2][0], bands[3][0], variant)
	triangle(st, bands[0][4], bands[3][4], bands[1][4], variant)
	triangle(st, bands[1][4], bands[3][4], bands[2][4], variant)
	st.generate_normals()
	st.index()
	var raw: ArrayMesh = st.commit()
	raw.surface_set_material(0, materials.adobe)
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, raw.surface_get_arrays(0), [], {}, materials.adobe)
	importer.generate_lods(60.0, 25.0, [])
	var visual := MeshInstance3D.new()
	visual.name = "Geometry"
	visual.mesh = importer.get_mesh() if importer.get_mesh() != null else raw
	visual.visibility_range_end = 2300.0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	var shape := ConvexPolygonShape3D.new()
	shape.points = shape_points
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	marker(body, "GroundAnchor", Vector3.ZERO)
	sockets(body, Vector3(-7.5, 0, 0), Vector3(7.5, 0, 0), "erosion_shoulder", width * 2.0, true)
	set_owners(body, body)
	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, path)
	if err == OK: written.append(id)
	else: push_error("Failed saving earthwork " + path)
	body.free()

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, variant: int) -> void:
	for point: Vector3 in [a, b, c]:
		st.set_color(Color(.88, .82, .68) if variant == 0 else Color(.76, .77, .65))
		st.set_uv(Vector2(point.x * .16, point.y * .2 + point.z * .16))
		st.add_vertex(point)
