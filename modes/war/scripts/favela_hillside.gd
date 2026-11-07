extends RefCounted
class_name WarFavelaHillside

## Environmental grammar for the slopes and wooded rear belt.
## Deterministic site planning uses sparse lot-index cells and leaves the
## existing terrain, road mesh and navigation geometry completely untouched.
const SHRUB_SCENE := preload("res://modes/war/library/favela_arbusto_encosta.tscn")
const ROCK_SCENE := preload("res://modes/war/library/favela_rocha_encosta.tscn")
const CELL := 32.0
const SEED := 2411287
const TREE_BUDGET := 1850
const SHRUB_BUDGET := 4700
const GRASS_BUDGET := 14000
const ROCK_BUDGET := 480
const WOODS_LOD := {"sector": 195.0, "lod_distance": 165.0, "shadows": false, "optional": true}
const SHRUB_LOD := {"sector": 190.0, "lod_distance": 140.0, "shadows": false, "optional": true}
const GRASS_LOD := {"sector": 175.0, "lod_distance": 92.0, "shadows": false, "optional": true}
const ROCK_LOD := {"sector": 195.0, "lod_distance": 150.0, "shadows": false, "optional": true}

static func _region(p: Vector2) -> float:
	var rear := 1.0 - smoothstep(-695.0, -455.0, p.y)
	var flank := smoothstep(475.0, 660.0, absf(p.x))
	flank *= 1.0 - smoothstep(475.0, 680.0, p.y)
	var transition := (1.0 - smoothstep(-565.0, -365.0, p.y)) * .30
	var variation := .70 + .30 * sin(p.x * .032 + sin(p.y * .019)) * cos(p.y * .027)
	return clampf(maxf(rear, maxf(flank, transition)) * variation + .08, 0.0, 1.0)

static func _candidate(rng: RandomNumberGenerator, ordinal: int, kind: String) -> Vector2:
	var x: float
	var z: float
	var slot := ordinal % 12
	# Keep taller trees in the forest, but distribute scrub and grass toward
	# the small unbuilt pockets and cut slopes between the urban frontages.
	var urban_scrub := kind in ["shrubs", "grass"]
	var rear_limit := 6 if urban_scrub else 9
	var flank_limit := 9 if urban_scrub else 11
	if slot < rear_limit:
		x = rng.randf_range(-727.0, 727.0)
		z = rng.randf_range(-727.0, -425.0)
	elif slot < flank_limit:
		x = rng.randf_range(555.0, 727.0) * (-1.0 if ordinal % 2 else 1.0)
		z = rng.randf_range(-615.0, 620.0)
	else:
		x = rng.randf_range(-650.0, 650.0)
		z = rng.randf_range(-555.0, 540.0)
	return Vector2(x, z)

static func _indexed_lots(lots: Array) -> Dictionary:
	var cells: Dictionary = {}
	for lot: Dictionary in lots:
		var at: Vector2 = lot.position
		var size: Vector2 = lot.size
		var rect := Rect2(at - size * .5, size).grow(1.5)
		var from := Vector2i(floori(rect.position.x / CELL), floori(rect.position.y / CELL))
		var to := Vector2i(floori(rect.end.x / CELL), floori(rect.end.y / CELL))
		for z in range(from.y, to.y + 1):
			for x in range(from.x, to.x + 1):
				var key := Vector2i(x, z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(rect)
	return cells

static func _near_houses(p: Vector2, radius: float, cells: Dictionary) -> bool:
	var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for z in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			for rect: Rect2 in cells.get(Vector2i(x, z), []):
				if rect.grow(radius).has_point(p):
					return true
	return false

static func _clear_site(p: Vector2, clearance: float, house_gap: float,
		cells: Dictionary, bases: Array, objectives: Array, road_distance: Callable) -> bool:
	if maxf(absf(p.x), absf(p.y)) > 730.0:
		return false
	if float(road_distance.call(p)) < clearance:
		return false
	for base: Vector2 in bases:
		if p.distance_to(base) < 74.0:
			return false
	for objective: Vector2 in objectives:
		if p.distance_to(objective) < 37.0:
			return false
	return not _near_houses(p, house_gap, cells)

static func _points(kind: String, budget: int, attempts: int, seed_shift: int,
		cells: Dictionary, bases: Array, objectives: Array,
		road_distance: Callable) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + seed_shift
	var result: Array[Dictionary] = []
	var clearance := 13.0 if kind == "trees" else (10.0 if kind == "rocks" else (7.3 if kind == "shrubs" else 5.8))
	var buildings := 6.0 if kind == "trees" else (4.0 if kind == "rocks" else (2.8 if kind == "shrubs" else 1.8))
	for i in attempts:
		if result.size() >= budget:
			break
		var p := _candidate(rng, i + seed_shift, kind)
		var chance := _region(p)
		if kind in ["shrubs", "grass"] and p.y > -490.0 and absf(p.x) < 570.0:
			chance = minf(1.0, chance + .23)
		if rng.randf() > chance:
			continue
		# Clustered foliage density reflects intermittent exposed rock/soil.
		var group := .48 + .52 * (sin(p.x * .043 + sin(p.y * .017)) * cos(p.y * .041) * .5 + .5)
		if rng.randf() > group:
			continue
		if not _clear_site(p, clearance, buildings, cells, bases, objectives, road_distance):
			continue
		result.append({
			"p": p,
			"scale": rng.randf_range(.68, 1.35) if kind == "trees" else rng.randf_range(.70, 1.52),
			"yaw": rng.randf_range(-PI, PI),
			"variant": i % 3,
		})
	return result

static func plan(lots: Array, bases: Array, objectives: Array,
		road_distance: Callable,skip_visual_only:=false) -> Dictionary:
	var cells := _indexed_lots(lots)
	# Each category uses an independent fixed-seed RNG. Servers need only
	# the collision-bearing tree positions; they never instantiate or render
	# the decorative shrubs, grass and rocks. Do not change client plans.
	var trees:=_points("trees", TREE_BUDGET, 10500, 17, cells, bases, objectives, road_distance)
	if skip_visual_only:
		return {"trees":trees,"shrubs":[],"grass":[],"rocks":[]}
	return {
		"trees": trees,
		"shrubs": _points("shrubs", SHRUB_BUDGET, 19000, 93, cells, bases, objectives, road_distance),
		"grass": _points("grass", GRASS_BUDGET, 49000, 251, cells, bases, objectives, road_distance),
		"rocks": _points("rocks", ROCK_BUDGET, 2700, 367, cells, bases, objectives, road_distance)
	}

static func populate(kit: EnvironmentKit, lots: Array, bases: Array,
		objectives: Array, road_distance: Callable, terrain_height: Callable) -> Dictionary:
	var skip_visual_only:=not kit.visuals and OS.get_environment("TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE")=="1"
	var sites := plan(lots, bases, objectives, road_distance,skip_visual_only)
	var summary := {
		"hill_trees": sites.trees.size(),
		"hill_shrubs": sites.shrubs.size(),
		"hill_grass": sites.grass.size(),
		"hill_rocks": sites.rocks.size(),
		"hill_colliders": 0,
		"hill_visual_plan_skipped": skip_visual_only,
	}
	var shrub_root := SHRUB_SCENE.instantiate() as Node3D
	var rock_root := ROCK_SCENE.instantiate() as Node3D
	var shrub_view := shrub_root.get_node("Forma") as MeshInstance3D
	var rock_view := rock_root.get_node("Forma") as MeshInstance3D
	var shrub_mesh := shrub_view.mesh
	var rock_mesh := rock_view.mesh
	if kit.visuals:
		EnvironmentKit.materials["favela_hill_shrub"] = shrub_view.material_override
		EnvironmentKit.materials["favela_hill_rock"] = rock_view.material_override
		var foliage := StandardMaterial3D.new()
		foliage.vertex_color_use_as_albedo = true
		foliage.vertex_color_is_srgb = true
		foliage.roughness = 1.0
		foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
		EnvironmentKit.materials["favela_hill_leaf"] = foliage
	shrub_root.free()
	rock_root.free()
	for i in sites.trees.size():
		var site: Dictionary = sites.trees[i]
		var p: Vector2 = site.p
		var height: float = terrain_height.call(p.x, p.y)
		var scale: float = site.scale
		var pose := Transform3D(Basis(Vector3.UP, float(site.yaw)).scaled(Vector3.ONE * scale),
				Vector3(p.x, height - .11, p.y))
		if kit.visuals:
			var variant := int(site.variant)
			kit._instance(WarVegetation.tree_mesh(true, variant, false), "favela_hill_leaf",
				pose, false, WarVegetation.tree_mesh(true, variant, true), 780.0, WOODS_LOD)
		# Only occasional trunks are physical, never decorative grass or shrubs.
		if i % 24 == 0:
			var trunk := CylinderShape3D.new()
			trunk.radius = .26 * scale
			trunk.height = 5.2 * scale
			kit._collider("TroncoMata", trunk,
				Transform3D(Basis.IDENTITY, Vector3(p.x, height + trunk.height * .5, p.y)), "wood")
			summary.hill_colliders += 1
	if kit.visuals:
		var grass := WarVegetation.grass_mesh()
		var grass_low := WarVegetation.grass_low_mesh()
		for site: Dictionary in sites.shrubs:
			var p: Vector2 = site.p
			var y: float = terrain_height.call(p.x, p.y)
			var size: float = site.scale
			var pose := Transform3D(Basis(Vector3.UP, float(site.yaw)).scaled(
					Vector3(size * 1.16, size * .88, size)), Vector3(p.x, y + .37 * size, p.y))
			kit._instance(shrub_mesh, "favela_hill_shrub", pose, false, null, 520.0, SHRUB_LOD)
		for site: Dictionary in sites.grass:
			var p: Vector2 = site.p
			var y: float = terrain_height.call(p.x, p.y)
			var size: float = site.scale
			var pose := Transform3D(Basis(Vector3.UP, float(site.yaw)).scaled(
					Vector3(size * 2.4, size * 2.0, size * 2.4)), Vector3(p.x, y + .035, p.y))
			kit._instance(grass, "favela_hill_leaf", pose, false, grass_low, 335.0, GRASS_LOD)
		for site: Dictionary in sites.rocks:
			var p: Vector2 = site.p
			var y: float = terrain_height.call(p.x, p.y)
			var size: float = site.scale
			var pose := Transform3D(Basis(Vector3.UP, float(site.yaw)).scaled(
					Vector3(size * 1.6, size * .69, size * 1.13)), Vector3(p.x, y + .26 * size, p.y))
			kit._instance(rock_mesh, "favela_hill_rock", pose, false, null, 620.0, ROCK_LOD)
	return summary
