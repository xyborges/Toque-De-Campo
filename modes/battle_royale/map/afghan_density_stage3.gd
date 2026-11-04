extends RefCounted
## V13: coherent small agricultural compounds on village outskirts.
## Deterministic on dedicated server and client; never alter original lots,
## settlement doors, roads, farm parcels, loot, or authored scene hierarchy.
const LAND = preload("res://modes/battle_royale/map/afghan_landform.gd")
const CONTEXT = preload("res://modes/battle_royale/map/afghan_context.gd")
const ENV = preload("res://modes/battle_royale/map/afghan_environment.gd")
const SEED := 713356
const SHED := "rural_shade_shed_v13"
const WALL := "courtyard_wall_v2"
const COVER_REACH := 2300.0

static func _available(map: Node3D, p: Vector3, radius: float, existing: Array[Vector3]) -> bool:
	if absf(p.x) > 895.0 or absf(p.z) > 895.0: return false
	if not map.accessible(p) or map.is_water(p): return false
	if absf(p.x - LAND.stream_center(p.z)) < radius + 29.0: return false
	var planar := Vector2(p.x, p.z)
	if LAND.in_farmland(planar, radius + 4.0): return false
	var near: Dictionary = LAND._near_road(planar)
	if float(near.distance) < float(near.width) * .5 + radius + 6.0: return false
	for house: Dictionary in LAND.building_layout():
		if planar.distance_to(Vector2(house.position.x, house.position.z)) < float(house.radius) + radius + 7.0:
			return false
	for garden: Dictionary in LAND.garden_layout():
		if planar.distance_to(Vector2(garden.position.x, garden.position.z)) < maxf(float(garden.size.x), float(garden.size.y)) * .57 + radius + 3.0:
			return false
	for previous: Vector3 in existing:
		if planar.distance_squared_to(Vector2(previous.x, previous.z)) < pow(radius + 13.0, 2.0):
			return false
	if CONTEXT.gradient(map, p).length() > .24: return false
	return true

static func _site(map: Node3D, p: Vector3, existing: Array[Vector3], loot: Array[Vector3], spawn: Array[Vector3]) -> Dictionary:
	var planar := Vector2(p.x, p.z)
	var road: Dictionary = LAND._near_road(planar)
	if float(road.distance) > 155.0 or not is_finite(float(road.distance)): return {}
	var nearest_house := INF
	for house: Dictionary in LAND.building_layout():
		nearest_house = minf(nearest_house, planar.distance_to(Vector2(house.position.x, house.position.z)))
	if nearest_house > 175.0 or not _available(map, p, 9.5, existing): return {}
	for loot_point: Vector3 in loot:
		if planar.distance_to(Vector2(loot_point.x, loot_point.z)) < 16.0: return {}
	for spawn_point: Vector3 in spawn:
		if planar.distance_to(Vector2(spawn_point.x, spawn_point.z)) < 24.0: return {}
	var towards: Vector2 = Vector2(road.point) - planar
	if towards.length() < 15.0: return {}
	var yaw := atan2(towards.x, towards.y)
	var basis := Basis(Vector3.UP, yaw)
	# Rear wall and two side returns shape an open rural courtyard. No front wall.
	var checks: Array[Vector3] = [
		Vector3.ZERO, Vector3(-7.4, 0, -3.6), Vector3(7.4, 0, -3.6),
		Vector3(0, 0, -9.5), Vector3(0, 0, 5.5), Vector3(0, 0, 10.0),
		Vector3(-3.4, 0, 0.0), Vector3(3.4, 0, 0.0)
	]
	var ground_y: float = map.height_at(p.x, p.z)
	for offset: Vector3 in checks:
		var q: Vector3 = map.point(p.x + (basis * offset).x, p.z + (basis * offset).z)
		# No yard, wall or open approach over fields, roads or pre-existing cover.
		if not _available(map, q, 3.3 if offset.z < 0.0 else 2.6, existing): return {}
		if absf(q.y - ground_y) > 1.65: return {}
	var front: Vector3 = map.point(p.x + (basis * Vector3(0, 0, 6.0)).x, p.z + (basis * Vector3(0, 0, 6.0)).z)
	var roof_drop := absf(map.height_at(p.x - 3.3, p.z - 2.6) - ground_y)
	if roof_drop > .65: return {}
	# Additional separation from previously authored compounds.
	return {"position": p, "yaw": yaw, "road_distance":float(road.distance), "entrance":front}

static func layout(map: Node3D, stage1: Array[Dictionary], stage2: Array[Dictionary]) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var occupied: Array[Vector3] = []
	for records in [stage1, stage2, map.get_meta("afghan_cover_layout", [])]:
		for record: Dictionary in records:
			occupied.append(record.position)
	var loot: Array[Vector3] = map.loot_points()
	var spawn: Array[Vector3] = map.spawn_candidates()
	var result: Array[Dictionary] = []
	for region in LAND.CENTRES.size():
		var centre: Vector2 = LAND.CENTRES[region]
		var in_region := 0
		var target := 3 if region in [0, 1, 2, 3] else 2
		for attempt in 156:
			if in_region >= target: break
			var theta := float(attempt) * 2.399963 + float(region) * .71 + rng.randf_range(-.18, .18)
			var distance := 76.0 + float(attempt % 13) * 10.0 + rng.randf_range(-5.0, 5.0)
			var x := centre.x + cos(theta) * distance
			var z := centre.y + sin(theta) * distance
			var candidate: Vector3 = map.point(x, z)
			var site := _site(map, candidate, occupied, loot, spawn)
			if site.is_empty(): continue
			site.region = region
			site.add_wall = (attempt + region) % 3 != 0
			result.append(site)
			occupied.append(candidate)
			in_region += 1
	return result

static func _decorate(map: Node3D, record: Dictionary, details: Dictionary, visual_counts: Dictionary) -> void:
	var p: Vector3 = record.position
	var transform: Transform3D = CONTEXT.on_ground(map, p, float(record.yaw))
	for i in 7:
		var local := Vector3(-10.0 + float(i) * 3.4, 0, -11.5 if i % 2 == 0 else -8.4)
		var world: Vector3 = transform * local
		if not CONTEXT.clear(world, 5.0, 7.0): continue
		world.y = map.height_at(world.x, world.z)
		var id := "dry_scrub_patch_v8" if i % 2 == 0 else "pebble_patch_v3"
		ENV._detail(details, id, CONTEXT.on_ground(map, world, float(record.yaw) + float(i) * .4).scaled_local(Vector3.ONE * (.7 + .08 * float(i % 3))), Color(.89, .86, .73))
		visual_counts.details += 1

static func loot_points(map: Node3D) -> Array[Vector3]:
	# The server only: new authored storage markers on the 12 static sheds.
	var points: Array[Vector3] = []
	for record: Dictionary in map.get_meta("afghan_density_stage3_layout", []):
		var tr: Transform3D = CONTEXT.on_ground(map, record.position, float(record.yaw))
		points.append(tr * Vector3(.8, .40, -1.0))
	return points

static func populate(map: Node3D, stage1: Array[Dictionary], stage2: Array[Dictionary]) -> void:
	if "--afghan-density-stage3-before" in OS.get_cmdline_user_args():
		map.set_meta("afghan_density_stage3", {"enabled":false,"compounds":0,"physical":0})
		return
	var records := layout(map, stage1, stage2)
	var sheds: Dictionary = {}
	var walls: Dictionary = {}
	var details: Dictionary = {}
	var counts := {"compounds":records.size(),"shed":0,"wall":0,"details":0}
	for item: Dictionary in records:
		var tr: Transform3D = CONTEXT.on_ground(map, item.position, float(item.yaw))
		map.add_piece(SHED, tr, sheds)
		counts.shed += 1
		# Walls are aligned with the side of the yard, never across its entrance.
		var offsets := [Vector3(-7.4, 0, -3.6), Vector3(7.4, 0, -3.6)]
		if item.add_wall: offsets.append(Vector3(0, 0, -9.5))
		for index in offsets.size():
			var off: Vector3 = offsets[index]
			var point: Vector3 = tr * off
			var angle: float = float(item.yaw) + (PI * .5 if index < 2 else 0.0)
			map.add_piece(WALL, CONTEXT.on_ground(map, point, angle), walls)
			counts.wall += 1
		if map.render_visuals:
			_decorate(map, item, details, counts)
	map.finish_static_batches(sheds, COVER_REACH, false)
	map.finish_batches(walls, COVER_REACH, false)
	if map.render_visuals:
		map.finish_batches(details, 85.0, false)
	map.set_meta("afghan_density_stage3_layout", records)
	map.set_meta("afghan_density_stage3", {"enabled":true,"compounds":counts.compounds,"physical":counts.shed+counts.wall,"counts":counts,"cover_reach_m":COVER_REACH,"loot_and_spawn_unchanged":true})
