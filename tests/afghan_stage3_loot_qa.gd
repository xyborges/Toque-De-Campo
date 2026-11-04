extends SceneTree
const Afghan = preload("res://modes/battle_royale/map/afghan_map.gd")
const Stage3 = preload("res://modes/battle_royale/map/afghan_density_stage3.gd")
const Game = preload("res://modes/battle_royale/scripts/game.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := Afghan.new()
	map.render_visuals = false
	root.add_child(map)
	map.build()
	var base: Array = Afghan.loot_points()
	var added: Array[Vector3] = Stage3.loot_points(map)
	var combined: Array = base.duplicate()
	combined.append_array(added)
	var contexts: Dictionary = {}
	for point: Vector3 in added: contexts[point] = "storage"
	var table: BRLootTable = load("res://modes/battle_royale/state/default_loot.tres")
	var drops := table.generate(192831, combined, [], contexts)
	var verified := 0
	var in_bounds := 0
	for anchor: Vector3 in added:
		var found := false
		for drop: Dictionary in drops:
			var position: Vector3 = drop.position
			if position.distance_to(anchor) <= 1.25:
				found = true
				break
		if found: verified += 1
		if Afghan.accessible(anchor) and not Afghan.is_water(anchor): in_bounds += 1
	var result := {"old_anchors":base.size(),"new_anchors":added.size(),"generated_drops":drops.size(),"new_anchors_with_drops":verified,"new_anchors_on_safe_terrain":in_bounds,"pass":added.size()==12 and verified==12 and in_bounds==12}
	print("AFGHAN_STAGE3_LOOT_QA ", JSON.stringify(result))
	map.free()
	quit(0 if result.pass else 1)
