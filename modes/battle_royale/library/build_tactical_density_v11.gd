extends "res://modes/battle_royale/library/build_library_v2.gd"
## Authoring-only generator. Existing user assets are never overwritten.
func run() -> void:
	prepare_materials()
	rural_annex()
	print("AFGHAN_DENSITY_LIBRARY_V11 ", JSON.stringify({"written":written,"preserved":skipped}))
	quit()

func rural_annex() -> void:
	var id := "rural_annex_v11"
	var n := root_for(id, Vector2(6.8, 5.2), 3.1, "dirt")
	n.set_meta("loot_kind", "outbuilding")
	n.set_meta("resistance", "masonry")
	n.set_meta("lod_profile", "physical_cover")
	n.set_meta("lod_near_end", 2300.0)
	n.set_meta("lod_far_end", 2300.0)
	n.set_meta("collision_persistent", true)
	n.set_meta("individual_shadows", false)
	# Door opens to +Z; interior is usable and the roof is partly collapsed.
	box(n, Vector3(0, .10, 0), Vector3(6.8, .20, 5.2), "stone")
	box(n, Vector3(-3.15, 1.45, 0), Vector3(.50, 2.9, 5.2), "adobe")
	box(n, Vector3(3.15, 1.45, -.6), Vector3(.50, 2.9, 4.0), "adobe")
	box(n, Vector3(0, 1.45, -2.35), Vector3(6.8, 2.9, .50), "adobe")
	for x in [-2.3, 2.3]:
		box(n, Vector3(x, 1.45, 2.35), Vector3(2.2, 2.9, .50), "adobe")
	box(n, Vector3(0, 2.65, 2.35), Vector3(2.4, .50, .50), "adobe")
	box(n, Vector3(-1.4, 3.0, -.75), Vector3(4.1, .17, 3.5), "wood")
	for x in [-2.5, -.7, 1.1]:
		box(n, Vector3(x, 2.8, -.8), Vector3(.13, .18, 3.5), "wood", false)
	box(n, Vector3(1.55, .48, -1.65), Vector3(1.15, .95, .72), "wood")
	box(n, Vector3(-3.35, 1.10, .8), Vector3(.24, 2.2, .95), "wood", false)
	marker(n, "Entrance", Vector3(0, .22, 3.05))
	marker(n, "CoverInside", Vector3(-.5, .2, -.4))
	sockets(n, Vector3(-3.4, 0, 0), Vector3(3.4, 0, 0), "rural_annex", 5.2, true)
	save_piece(n, id)
