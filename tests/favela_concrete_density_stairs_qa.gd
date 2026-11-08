extends SceneTree
## Headless audit of close-set buildings, concrete town floor and stairs.
const CELL := 28.0
const MIN_GAP := 1.5
var failures: Array[String] = []
var checks := 0

func expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok: failures.append(what)

func _initialize() -> void:
	_run.call_deferred()

func _grid(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy := maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return Vector2(dx, dy).length()

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var lots: Array[Dictionary] = WarFavelaMap.housing_plan()
	expect(lots.size() >= 3950, "Too many houses lost while tightening the grid")
	var occupied: Dictionary = {}
	var rectangles: Array[Rect2] = []
	var closest := INF
	var close_pairs := 0
	var compared := 0
	for lot: Dictionary in lots:
		var p: Vector2 = lot.position
		var size: Vector2 = lot.size
		var rect := Rect2(p - size * .5, size)
		var cell := _grid(p)
		var nearby: Dictionary = {}
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				for other: int in occupied.get(cell + Vector2i(dx, dz), []):
					nearby[other] = true
		for key in nearby:
			var distance := _rect_gap(rect, rectangles[int(key)])
			compared += 1
			closest = minf(closest, distance)
			if distance < 2.6: close_pairs += 1
			if distance < MIN_GAP - .035:
				failures.append("House spacing violation: " + str(distance) + " m")
				if failures.size() > 15: break
		rectangles.append(rect)
		if not occupied.has(cell): occupied[cell] = []
		occupied[cell].append(rectangles.size()-1)
	expect(closest >= MIN_GAP - .035, "Less than 1.5m between house footprints")
	expect(close_pairs >= 500, "Houses are still too spaced apart")
	var middle: Color = WarFavelaMap.new()._ground_color(0, -20)
	var outer: Color = WarFavelaMap.new()._ground_color(735, 40)
	expect(absf(middle.r - middle.g) < .07, "Town ground still appears brown")
	expect(outer.r > outer.g, "Exposed natural soil was lost from the rim")
	expect(WarFavelaMap.STREET_ART.TERRAIN_SHADER.contains("cement_amount"),
		"Concrete shader not available")
	expect(WarFavelaMap.STREET_ART.TERRAIN_SHADER.contains("grit_fine"),
		"Concrete grit and aggregate detail missing")
	expect(WarFavelaMap.STREET_ART.TERRAIN_SHADER.contains("old_repairs"),
		"Concrete wear texture detail missing")
	expect(WarFavelaMap.STREET_ART.TERRAIN_SHADER.contains("grit_tex"),
		"Concrete roughness noise sampler missing")
	var scene: Node3D = WarPrefabFactory.create("favela_degrau_beco")
	expect(scene != null, "Reusable step prefab missing")
	if scene != null:
		expect(scene.get_meta("library_id", "") == "favela_degrau_beco",
			"Step library registration missing")
		expect(scene.find_children("*", "CollisionShape3D", true, false).size() == 1,
			"Modular step missing physical collision")
		scene.free()
	var stairs: Array[Dictionary] = WarFavelaPedestrianStairs.plan(
		WarFavelaMap.MINI_STREETS, WarFavelaMap.BASES_2D,
		WarFavelaMap.OBJECTIVES_2D,
		func(x: float,z: float) -> float: return WarFavelaMap.height_at(x,z))
	expect(stairs.size() >= 6, "Pedestrian descents have insufficient stair flights")
	for flight: Dictionary in stairs:
		expect(flight.treads.size() == 7, "Incomplete stair flight")
		for b: Vector2 in WarFavelaMap.BASES_2D:
			expect((flight.center as Vector2).distance_to(b) >= 51.0,
				"Stairs overlap military base")
		for o: Vector2 in WarFavelaMap.OBJECTIVES_2D:
			expect((flight.center as Vector2).distance_to(o) >= 36.0,
				"Stairs block a capture point")
	print("FAVELA_CONCRETE_DENSITY_QA ", JSON.stringify({
		"houses": lots.size(), "min_gap_m": closest,
		"neighbor_pairs_1_5_to_2_6m": close_pairs, "pairs_checked": compared,
		"stair_flights": stairs.size(), "stair_treads": stairs.size() * 7,
		"town_color": str(middle), "rim_color": str(outer),
		"checks": checks, "failures": failures.slice(0, 20)
	}))
	if failures.is_empty():
		print("FAVELA_CONCRETE_DENSITY_QA PASS")
		quit(0)
	else:
		for issue: String in failures: printerr("FAVELA_CONCRETE_DENSITY_QA FAIL " + issue)
		quit(1)
