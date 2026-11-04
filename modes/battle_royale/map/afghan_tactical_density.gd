extends RefCounted
## Deterministic tactical infill, additive to the existing Afghan map.
## Physical objects are instantiated identically on clients and authority.
const LAND = preload("res://modes/battle_royale/map/afghan_landform.gd")
const CONTEXT = preload("res://modes/battle_royale/map/afghan_context.gd")
const STAGE2 = preload("res://modes/battle_royale/map/afghan_density_stage2.gd")
const SEED := 712907 + 1103
const PILOT_CENTRE := Vector2(-260.0, 70.0)
const PILOT_RADIUS := 150.0

static func _candidate(map: Node3D, p: Vector3, radius: float, maximum_slope: float, placed: Array[Vector3]) -> bool:
	if absf(p.x) > 920.0 or absf(p.z) > 920.0:
		return false
	if not map.accessible(p) or map.is_water(p):
		return false
	if absf(p.x - LAND.stream_center(p.z)) < 27.0:
		return false
	if LAND.in_farmland(Vector2(p.x, p.z), radius + 2.0):
		return false
	var road: Dictionary = LAND._near_road(Vector2(p.x, p.z))
	if float(road.distance) < float(road.width) * .5 + radius + 5.0:
		return false
	for house: Dictionary in LAND.building_layout():
		if Vector2(p.x - house.position.x, p.z - house.position.z).length() < float(house.radius) + radius + 9.0:
			return false
	if CONTEXT.gradient(map, p).length() > maximum_slope:
		return false
	for previous: Vector3 in placed:
		if p.distance_squared_to(previous) < pow(radius + 17.0, 2.0):
			return false
	return true

static func layout(map: Node3D) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var result: Array[Dictionary] = []
	var occupied: Array[Vector3] = []
	# Pilot receives the highest initial density; distant cells receive
	# fewer landmarks, preserving open long-range sight corridors.
	for gz in range(-18, 19):
		for gx in range(-18, 19):
			var x := float(gx * 50) + rng.randf_range(-12.0, 12.0)
			var z := float(gz * 50) + rng.randf_range(-12.0, 12.0)
			var proximity := Vector2(x, z).distance_to(PILOT_CENTRE)
			var pilot := proximity < PILOT_RADIUS
			var chance := .92 if pilot else (.48 if proximity < 500.0 else .24)
			if rng.randf() > chance:
				continue
			var p: Vector3 = map.point(x, z)
			var kind := "bank" if (gx + gz) % 3 != 0 else "wall"
			var radius := 5.5
			var village_distance := INF
			for centre: Vector2 in LAND.CENTRES:
				village_distance = minf(village_distance, Vector2(x, z).distance_to(centre))
			if village_distance < 195.0 and (gx * 3 + gz) % 7 == 0:
				kind = "annex"
			if not _candidate(map, p, radius, .20 if kind == "annex" else .30, occupied):
				continue
			var angle := rng.randf_range(-PI, PI)
			var support := CONTEXT.on_ground(map, p, angle)
			var unstable := false
			var extent := 3.7 if kind == "annex" else 4.2
			for dx in [-extent, extent]:
				for dz in [-2.0, 2.0]:
					var q: Vector3 = support * Vector3(dx, 0, dz)
					if absf(map.height_at(q.x, q.z) - q.y) > (.22 if kind == "annex" else .34):
						unstable = true
			if unstable:
				continue
			occupied.append(p)
			result.append({"kind": kind, "position": p, "yaw": angle, "pilot": pilot})
	return result

static func populate(map: Node3D) -> void:
	if "--afghan-density-before" in OS.get_cmdline_user_args():
		map.set_meta("afghan_density", {"enabled": false, "pieces": 0})
		return
	var records := layout(map)
	var scenery: Dictionary = {}
	var cover: Dictionary = {}
	var counts := {"annex": 0, "wall": 0, "bank": 0, "pilot": 0}
	for record: Dictionary in records:
		var id := "rural_annex_v11" if record.kind == "annex" else ("field_wall_v10" if record.kind == "wall" else "field_bank_v10")
		var transform: Transform3D = CONTEXT.on_ground(map, record.position, record.yaw)
		var bucket: Dictionary = scenery if record.kind == "annex" else cover
		map.add_piece(id, transform, bucket)
		counts[record.kind] += 1
		if record.pilot:
			counts.pilot += 1
	# Important: physical cover and its distant silhouettes reach across the
	# entire playable map; collisions are always present, including headless.
	map.finish_static_batches(scenery, 2300.0, false)
	map.finish_batches(cover, 3000.0, false)
	map.set_meta("afghan_density_layout", records)
	map.set_meta("afghan_density", {"enabled": true, "pieces": records.size(), "counts": counts, "collision_persistent": true, "visual_reach_m": 2300})
	STAGE2.populate(map, records)
