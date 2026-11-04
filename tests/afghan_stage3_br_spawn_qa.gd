extends SceneTree
const Afghan = preload("res://modes/battle_royale/map/afghan_map.gd")
const Nav = preload("res://modes/battle_royale/navigation/navigation.gd")
const Stage3 = preload("res://modes/battle_royale/map/afghan_density_stage3.gd")
const Game = preload("res://modes/battle_royale/scripts/game.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := Afghan.new()
	map.render_visuals = false
	root.add_child(map)
	map.build()
	await physics_frame
	var new_loot := Stage3.loot_points(map)
	var loot_ok := 0
	var prefab: PackedScene = load("res://modes/battle_royale/library/rural_shade_shed_v13.tscn")
	var has_marker := false
	if prefab != null:
		var instance: Node3D = prefab.instantiate()
		has_marker = instance.has_node("LootStorage")
		instance.free()
	for point: Vector3 in new_loot:
		if map.accessible(point) and not map.is_water(point):
			loot_ok += 1
	var nav := Nav.new()
	var nav_ready := nav.install(map, true)
	var ids: Array = []
	for i in range(1, 41): ids.append(i)
	var all_ok := nav_ready and has_marker and loot_ok == new_loot.size() and new_loot.size() == 12
	var rounds: Array[Dictionary] = []
	var first_positions: Dictionary = {}
	if nav_ready:
		for round_index in 8:
			var sample: Dictionary = nav.choose_spawns(ids, 144420 + round_index * 10039, 90.0)
			var minimum := INF
			for a: Variant in sample:
				for b: Variant in sample:
					if int(a) >= int(b):continue
					var pa: Vector3 = sample[a]
					var pb: Vector3 = sample[b]
					minimum = minf(minimum, Vector2(pa.x-pb.x,pa.z-pb.z).length())
			var passed := sample.size() == ids.size() and minimum >= 89.99
			all_ok = all_ok and passed
			if sample.has(1):
				var first: Vector3 = sample[1]
				first_positions[Vector2i(roundi(first.x/10.0), roundi(first.z/10.0))] = true
			rounds.append({"index":round_index,"assigned":sample.size(),"separation_m":minimum,"ok":passed})
	var result := {"nav_ready":nav_ready,"new_loot":new_loot.size(),"loot_walkable":loot_ok,"prefab_marker":has_marker,"rounds":rounds,"distinct_first_spawn_cells":first_positions.size(),"passes":all_ok and first_positions.size() >= 4}
	print("AFGHAN_STAGE3_BR_QA ", JSON.stringify(result))
	var f := FileAccess.open("res://work/afghan-stage3-br-qa.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(result,"\t"));f.close()
	nav.close()
	map.free()
	quit(0 if result.passes else 1)
