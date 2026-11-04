extends "res://modes/battle_royale/library/build_library_v2.gd"
## New standalone prefab, authored once and never overwriting user scenes.
func run() -> void:
	prepare_materials()
	var id := "rural_shade_shed_v13"
	var path := DIR + id + ".tscn"
	if FileAccess.file_exists(path):
		print("AFGHAN_V13_LIB preserved=" + path)
		quit()
		return
	var n := root_for(id, Vector2(6.6, 5.4), 3.1, "dirt")
	n.set_meta("loot_kind", "outbuilding")
	n.set_meta("resistance", "timber_adobe")
	n.set_meta("collision_persistent", true)
	n.set_meta("lod_profile", "physical_cover")
	n.set_meta("lod_near_end", 2300.0)
	n.set_meta("lod_far_end", 2300.0)
	n.set_meta("individual_shadows", false)
	n.set_meta("destructible", false)
	# The front (+Z) is completely open, so the approach stays walkable.
	for x in [-2.9, 2.9]:
		for z in [-2.3, 2.3]:
			box(n, Vector3(x, 1.40, z), Vector3(.20, 2.8, .20), "wood")
	box(n, Vector3(0, 2.91, 0), Vector3(6.55, .16, 5.35), "reed")
	for x in [-2.1, 0.0, 2.1]:
		box(n, Vector3(x, 2.72, 0), Vector3(.15, .18, 5.0), "wood", false)
	# Rear partial wall and side returns, never a closed obstacle ring.
	box(n, Vector3(0, .80, -2.48), Vector3(5.7, 1.60, .42), "adobe")
	for x in [-3.05, 3.05]:
		box(n, Vector3(x, .60, -1.18), Vector3(.36, 1.20, 1.85), "adobe")
	# Hay storage and small rope trims are only decorative.
	box(n, Vector3(-1.7, .28, -.9), Vector3(1.55, .55, 1.15), "reed", false)
	box(n, Vector3(.8, .17, -1.0), Vector3(1.3, .34, .9), "wood", false)
	for j in 3:
		box(n, Vector3(-1.5+j*1.5, 2.57, -1.6), Vector3(.08, .08, 1.1), "wood", false)
	marker(n, "LootStorage", Vector3(.8, .40, -1.0))
	marker(n, "Entrance", Vector3(0, .1, 3.5))
	marker(n, "Inside", Vector3(0, .2, .4))
	marker(n, "ClearApproach", Vector3(0, .2, 7.0))
	sockets(n, Vector3(-3.3, 0, -1.2), Vector3(3.3, 0, -1.2), "rural_yard", 5.4, true)
	save_piece(n, id)
	print("AFGHAN_V13_LIB ", JSON.stringify({"written":written,"preserved":skipped}))
	quit()
