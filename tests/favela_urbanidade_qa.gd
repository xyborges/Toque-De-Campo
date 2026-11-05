extends SceneTree
## Godot: --headless --path . --script res://tests/favela_urbanidade_qa.gd
## This fixture uses the actual server-authoritative map and does not publish.
var failures: Array[String] = []

func require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var editor_scene := [
		"favela_lixeira_rua", "favela_pedras_entulho",
		"favela_caixa_fibra_optica",
	]
	for id in editor_scene:
		var path: String = "res://modes/war/library/" + str(id) + ".tscn"
		require(ResourceLoader.exists(path), "scene missing: " + id)
		if not ResourceLoader.exists(path):
			continue
		var part := WarPrefabFactory.create(id)
		require(part != null, "factory failed: " + id)
		if part == null:
			continue
		require(part.get_meta("library_id", "") == id, "library id missing: " + id)
		require(part.has_meta("footprint"), "footprint missing: " + id)
		var visual := part.find_children("*", "MeshInstance3D", true, false)
		require(visual.size() >= 3, "scene too plain: " + id)
		for mesh: MeshInstance3D in visual:
			require(mesh.mesh != null and mesh.visibility_range_end > 0,
				"scene without mesh or LOD: " + id)
		var collision := part.find_children("*", "CollisionShape3D", true, false)
		require(collision.size() == (1 if id == "favela_lixeira_rua" else 0),
			"unexpected physics on: " + id)
		part.free()
	var city := WarFavelaMap.new()._ground_color(10.0, -80.0)
	var outskirts := WarFavelaMap.new()._ground_color(690.0, -80.0)
	require(absf(city.r-city.g) < 0.055, "central terrain is still brown")
	require(outskirts.r > outskirts.g, "natural soil disappeared from outskirts")
	require(WarFavelaMap.STREET_ART.TERRAIN_SHADER.contains("cement_amount"),
		"concrete/soil shader mix not installed")
	var world := Node3D.new()
	root.add_child(world)
	WarWorld.build(world, false)
	var map := world.get_node_or_null("FavelaWar") as WarFavelaMap
	require(map != null, "Favela world not built")
	var metrics: Dictionary = map.build_metrics if map != null else {}
	require(int(metrics.get("houses", 0)) >= 4100, "housing density was lost")
	require(int(metrics.get("urban_parked_cars", 0)) >= 4, "new parked cars are missing")
	require(int(metrics.get("street_bins", 0)) >= 14, "not enough public trash bins")
	require(int(metrics.get("loose_rubble", 0)) >= 25, "rubble absent from street edges")
	require(int(metrics.get("fiber_boxes", 0)) >= 22, "optical splice boxes missing")
	require(int(metrics.get("fiber_spans", 0)) >= 22, "optical lines not connected")
	require(int(metrics.get("utility_poles", 0)) >= 120, "utility pole density too low")
	require(int(metrics.get("wire_spans", 0)) >= 150, "overhead wiring missing")
	require(int(metrics.get("collision_shapes", 0)) > 950, "physical coverage disappeared")
	print("FAVELA_URBANIDADE_QA ", JSON.stringify({
		"metrics": metrics,
		"city_color": str(city), "outskirts_color": str(outskirts),
		"failures": failures
	}))
	world.queue_free()
	if failures.is_empty():
		print("FAVELA_URBANIDADE_QA PASS")
		quit(0)
	else:
		for issue in failures:
			printerr("FAVELA_URBANIDADE_QA FAIL: " + issue)
		quit(1)
