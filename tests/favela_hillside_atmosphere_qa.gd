extends SceneTree
const Map = preload("res://modes/war/scripts/favela_map.gd")
const Woods = preload("res://modes/war/scripts/favela_hillside.gd")
const Atmosphere = preload("res://modes/war/scripts/favela_atmosphere.gd")
const IDS := ["favela_arbusto_encosta", "favela_rocha_encosta", "favela_nevoa_encosta"]
var checks := 0
var failures: Array[String] = []

func check(valid: bool, message: String) -> void:
	checks += 1
	if not valid:
		failures.append(message)
		print("FAVELA_NATURE_FAIL ", message)

func _initialize() -> void:
	_run.call_deferred()

func _signature(plans: Dictionary) -> PackedStringArray:
	var entries := PackedStringArray()
	for kind in ["trees", "shrubs", "grass", "rocks"]:
		for i in mini(80, plans[kind].size()):
			var p: Vector2 = plans[kind][i].p
			entries.append("%s:%.2f:%.2f:%.2f" % [
				kind,p.x,p.y,float(plans[kind][i].scale)])
	return entries

func _run() -> void:
	var roads := func(p: Vector2) -> float: return Map.road_distance(p)
	var first: Dictionary = Woods.plan(Map.housing_plan(), Map.BASES_2D,
		Map.OBJECTIVES_2D, roads)
	var repeat: Dictionary = Woods.plan(Map.housing_plan(), Map.BASES_2D,
		Map.OBJECTIVES_2D, roads)
	check(_signature(first) == _signature(repeat), "nature generator is nondeterministic")
	check(first.trees.size() >= 900, "insufficient wooded tree silhouettes")
	check(first.shrubs.size() >= 2200, "insufficient shrub coverage on slopes")
	check(first.grass.size() >= 7500, "insufficient grass tufts on slopes")
	check(first.rocks.size() >= 180, "insufficient rock outcrops on exposed hills")
	check(first.trees.size() <= Woods.TREE_BUDGET, "tree budget exceeded")
	check(first.shrubs.size() <= Woods.SHRUB_BUDGET, "shrub budget exceeded")
	check(first.grass.size() <= Woods.GRASS_BUDGET, "grass budget exceeded")
	check(first.rocks.size() <= Woods.ROCK_BUDGET, "rock budget exceeded")
	for kind in ["trees","shrubs","grass","rocks"]:
		var threshold := 13.0 if kind == "trees" else (
			10.0 if kind == "rocks" else (7.3 if kind == "shrubs" else 5.8))
		for site: Dictionary in first[kind]:
			var p: Vector2 = site.p
			check(Map.road_distance(p) >= threshold - .01,
				kind + " intersects road buffer")
			check(absf(p.x) <= 730 and absf(p.y) <= 730,
				kind + " beyond world bounds")
			if failures.size() >= 8: break
		if failures.size() >= 8:break
	for id in IDS:
		var resource: String = "res://modes/war/library/" + str(id) + ".tscn"
		check(ResourceLoader.exists(resource), "missing scene " + id)
		if ResourceLoader.exists(resource):
			var scene := load(resource) as PackedScene
			var node := scene.instantiate() as Node3D
			check(str(node.get_meta("library_id","")) == id, "invalid library ID " + id)
			check(node.find_children("*","CollisionShape3D",true,false).is_empty(),
				"unplanned physics collider " + id)
			node.free()
	var root3d := Node3D.new()
	root3d.name = "AtmosphericFixture"
	root.add_child(root3d)
	var summary: Dictionary = Atmosphere.build(root3d,
		func(x: float, z: float) -> float: return Map.height_at(x, z))
	check(bool(summary.cloud_sky), "sky cloud shader not initialized")
	check(int(summary.mist_veils) == 14, "wrong count of distant mist layers")
	check(root3d.get_node_or_null("AtmosferaFavela") is WorldEnvironment,
		"world environment not installed")
	var world := root3d.get_node("AtmosferaFavela") as WorldEnvironment
	check(world.environment.fog_enabled, "hillside humidity disabled")
	check(world.environment.fog_density <= .0005, "fog would obscure gameplay")
	check(world.environment.sky.sky_material is ShaderMaterial,
		"sky material is not procedural")
	var shader := (world.environment.sky.sky_material as ShaderMaterial).shader
	check("TIME" not in shader.code, "moving sky would force cubemap rebuilds")
	print("FAVELA_HILLSIDE_ATMOSPHERE ", JSON.stringify({
		"trees":first.trees.size(),"shrubs":first.shrubs.size(),
		"grass":first.grass.size(),"rocks":first.rocks.size(),
		"mist_layers":summary.mist_veils,"checks":checks,"failures":failures
	}))
	root3d.queue_free()
	if failures.is_empty():
		print("FAVELA_HILLSIDE_ATMOSPHERE PASS")
		quit(0)
	else:
		quit(1)
