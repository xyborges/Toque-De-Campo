extends RefCounted
## Optional stage 2: erosion shoulders, rural annexes and vegetation pockets.
## No edits to the heightmap, roads, parcels, navigation, or authored scenes.
const LAND = preload("res://modes/battle_royale/map/afghan_landform.gd")
const CONTEXT = preload("res://modes/battle_royale/map/afghan_context.gd")
const ENV = preload("res://modes/battle_royale/map/afghan_environment.gd")
const STAGE3 = preload("res://modes/battle_royale/map/afghan_density_stage3.gd")
const PILOT := Vector2(-260.0, 70.0)
const REACH_COVER := 2300.0

static func _clear(map: Node3D, p: Vector3, footprint: float, existing: Array[Vector3]) -> bool:
	if absf(p.x) > 890.0 or absf(p.z) > 890.0 or not map.accessible(p) or map.is_water(p): return false
	if absf(p.x - LAND.stream_center(p.z)) < 32.0: return false
	if LAND.in_farmland(Vector2(p.x, p.z), footprint + 4.0): return false
	var road: Dictionary = LAND._near_road(Vector2(p.x, p.z))
	if float(road.distance) < float(road.width) * .5 + footprint + 12.0: return false
	for house: Dictionary in LAND.building_layout():
		if Vector2(p.x - house.position.x, p.z - house.position.z).length() < float(house.radius) + footprint + 9.0: return false
	for other: Vector3 in existing:
		if Vector2(p.x - other.x, p.z - other.z).length_squared() < pow(footprint + 13.0, 2.0): return false
	if CONTEXT.gradient(map, p).length() > .22: return false
	return true

static func layout(map: Node3D, earlier: Array[Dictionary]) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 713219
	var occupied: Array[Vector3] = []
	for record: Dictionary in earlier: occupied.append(record.position)
	for record: Dictionary in map.get_meta("afghan_cover_layout", []): occupied.append(record.position)
	var result: Array[Dictionary] = []
	for iz in range(-25, 26):
		for ix in range(-25, 26):
			var x := ix * 36.0 + rng.randf_range(-9.0, 9.0)
			var z := iz * 36.0 + rng.randf_range(-9.0, 9.0)
			var near_pilot := Vector2(x, z).distance_to(PILOT) < 190.0
			var nearest_village := INF
			for centre: Vector2 in LAND.CENTRES:
				nearest_village = minf(nearest_village, Vector2(x, z).distance_to(centre))
			var stream_distance := absf(x - LAND.stream_center(z))
			var dry_wadi := 110.0 + 67.0 * sin(x * .0025) + 26.0 * sin(x * .0065)
			var near_dry_wadi := absf(z - dry_wadi) < 75.0
			var chance := .78 if near_pilot else (.53 if nearest_village < 235.0 or near_dry_wadi else .32)
			if rng.randf() > chance: continue
			var is_annex := nearest_village > 62.0 and nearest_village < 205.0 and (ix * 5 + iz * 3) % 6 == 0
			var kind := "annex" if is_annex else ("wadi" if near_dry_wadi or stream_distance < 155.0 else "berm")
			var p: Vector3 = map.point(x, z)
			var radius := 6.0 if is_annex else 9.0
			if not _clear(map, p, radius, occupied): continue
			var yaw := rng.randf_range(-PI, PI)
			var support: Transform3D = CONTEXT.on_ground(map, p, yaw)
			var max_error := 0.0
			var hx := 3.4 if is_annex else 7.5
			var hz := 2.7 if is_annex else (3.6 if kind == "wadi" else 2.8)
			for dx in [-hx, 0.0, hx]:
				for dz in [-hz, hz]:
					var sample: Vector3 = support * Vector3(dx, 0, dz)
					max_error = maxf(max_error, absf(map.height_at(sample.x, sample.z) - sample.y))
			if max_error > (.24 if is_annex else .34): continue
			var entry := {"kind":kind, "position":p, "yaw":yaw, "pilot":near_pilot}
			result.append(entry)
			occupied.append(p)
	return result

static func _plant(map: Node3D, groups: Dictionary, p: Vector3, angle: float, scale: float, color: Color, near_mesh: Mesh) -> bool:
	if not CONTEXT.clear(p, 4.0, 8.0) or map.is_water(p) or not map.accessible(p): return false
	if LAND.in_farmland(Vector2(p.x, p.z), 1.5): return false
	p.y = map.height_at(p.x, p.z)
	# Pure visual foliage: pack larger 320 m cells, no nodes or colliders per stem.
	var cell := Vector2i(floori(p.x / 320.0), floori(p.z / 320.0))
	var key := "tamarisk_v10:" + str(cell)
	if not groups.has(key):
		groups[key] = {"mesh":near_mesh, "transforms":[], "colors":[]}
	groups[key].transforms.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale), p))
	groups[key].colors.append(color)
	return true

static func _regroup(groups: Dictionary, span: float, replace_mesh: Mesh = null) -> Dictionary:
	var combined: Dictionary = {}
	for name: String in groups:
		var data: Dictionary = groups[name]
		var transforms: Array = data.transforms
		for i in transforms.size():
			var transform: Transform3D = transforms[i]
			var cell := Vector2i(floori(transform.origin.x / span), floori(transform.origin.z / span))
			var family := name.get_slice(":", 0).get_slice("(", 0)
			var key := family + ":" + str(cell)
			if not combined.has(key):
				combined[key] = {"mesh":replace_mesh if replace_mesh != null else data.mesh, "transforms":[], "colors":[]}
			combined[key].transforms.append(transform)
			combined[key].colors.append(data.colors[i] if i < data.colors.size() else Color.WHITE)
	return combined

static func populate(map: Node3D, earlier: Array[Dictionary]) -> void:
	if "--afghan-density-stage2-before" in OS.get_cmdline_user_args():
		map.set_meta("afghan_density_stage2", {"enabled":false, "physical":0, "foliage":0, "details":0})
		return
	var records := layout(map, earlier)
	var earth: Dictionary = {}
	var rural: Dictionary = {}
	var plants: Dictionary = {}
	var details: Dictionary = {}
	var counts := {"berm":0, "wadi":0, "annex":0, "pilot":0, "foliage":0, "details":0}
	for entry: Dictionary in records:
		var id := "rural_annex_v11" if entry.kind == "annex" else ("wadi_bank_v12" if entry.kind == "wadi" else "erosion_berm_v12")
		var base: Transform3D = CONTEXT.on_ground(map, entry.position, entry.yaw)
		map.add_piece(id, base, rural if entry.kind == "annex" else earth)
		counts[entry.kind] += 1
		if entry.pilot: counts.pilot += 1
	var earth_render: Dictionary = _regroup(earth, 640.0)
	map.finish_batches(earth_render, REACH_COVER, false)
	map.finish_static_batches(rural, REACH_COVER, false)
	if map.render_visuals:
		var rng := RandomNumberGenerator.new()
		rng.seed = 713220
		var source: Node3D = load("res://modes/battle_royale/library/tamarisk_v10.tscn").instantiate()
		var near_mesh: Mesh = source.get_node("Geometry").mesh
		# Distinct vegetation pockets beside banks, not a uniform carpet.
		for index in records.size():
			var item: Dictionary = records[index]
			var anchor: Vector3 = item.position
			var turn := float(item.yaw)
			for n in 7:
				var q := anchor + Vector3(sin(turn) * (7.0 + float(n % 3) * 2.3), 0, cos(turn) * (7.0 + float(n % 3) * 2.3)) * (-1.0 if n % 2 == 0 else 1.0)
				q += Vector3(rng.randf_range(-4.5, 4.5), 0, rng.randf_range(-4.5, 4.5))
				if _plant(map, plants, q, rng.randf_range(-PI, PI), rng.randf_range(.62, 1.05), Color(.91, .94, .80), near_mesh):
					counts.foliage += 1
				if n % 2 == 0:
					var d: Vector3 = q + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
					if CONTEXT.clear(d, 4.0, 7.0):
						d.y = map.height_at(d.x, d.z)
						ENV._detail(details, "dry_scrub_patch_v8", Transform3D(Basis(Vector3.UP, turn + n).scaled(Vector3.ONE * .8), d), Color(.87, .85, .65))
						counts.details += 1
		# Dry strips around villages retain a sparse, varied rural silhouette.
		for centre: Vector2 in LAND.CENTRES:
			for i in 52:
				var angle := rng.randf_range(-PI, PI)
				var radius := rng.randf_range(78.0, 235.0)
				var p: Vector3 = map.point(centre.x + cos(angle) * radius, centre.y + sin(angle) * radius)
				if not _plant(map, plants, p, angle, rng.randf_range(.58, .92), Color(.90, .93, .79), near_mesh):
					continue
				counts.foliage += 1
				if i % 3 == 0:
					ENV._detail(details, "pebble_patch_v3", CONTEXT.on_ground(map, p, angle).scaled_local(Vector3.ONE * .75), Color(.85, .81, .70))
					counts.details += 1
		# Near-only details along existing approach routes, with no collider.
		for road: Dictionary in LAND.roads():
			if road.kind not in ["main", "secondary", "village"]: continue
			for i in range(6, road.points.size() - 4, 8):
				var p: Vector3 = road.points[i]
				var tangent: Vector3 = (road.points[i+1] - road.points[i-1]).normalized()
				var across := Vector3(-tangent.z, 0, tangent.x)
				for sign_value in [-1.0, 1.0]:
					var q: Vector3 = p + across * sign_value * (float(road.width) * .5 + 7.0)
					q.y = map.height_at(q.x, q.z)
					if not CONTEXT.clear(q, .7, 3.0) or LAND.in_farmland(Vector2(q.x, q.z), 1.5): continue
					ENV._detail(details, "wild_margin_v9", CONTEXT.on_ground(map, q, float(i) * .33).scaled_local(Vector3(.8, .52, .8)), Color(.79, .82, .58))
					counts.details += 1
		# Near foliage 150m, distant low-poly replacement only.
		var far: Node3D = load("res://modes/battle_royale/library/tamarisk_far_v10.tscn").instantiate()
		var far_mesh: Mesh = far.get_node("Geometry").mesh
		var far_plants: Dictionary = _regroup(plants, 640.0, far_mesh)
		map.finish_batches(plants, 150.0, false)
		var start_children := map.get_child_count()
		map.finish_batches(far_plants, 1800.0, false)
		for i in range(start_children, map.get_child_count()):
			var view := map.get_child(i) as GeometryInstance3D
			if view: view.visibility_range_begin = 150.0
		far.free()
		map.finish_batches(_regroup(details, 160.0), 75.0, false)
		source.free()
	map.set_meta("afghan_density_stage2_layout", records)
	map.set_meta("afghan_density_stage2", {"enabled":true, "physical":records.size(), "counts":counts, "foliage":counts.foliage, "details":counts.details, "foliage_cells":plants.size(), "far_foliage_cells":_regroup(plants, 640.0).size(), "earth_render_cells":_regroup(earth, 640.0).size(), "detail_cells":details.size(), "detail_render_cells":_regroup(details, 160.0).size(), "cover_reach_m":REACH_COVER, "no_heightmap_change":true})
	STAGE3.populate(map, earlier, records)
