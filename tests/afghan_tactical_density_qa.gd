extends SceneTree
const Afghan = preload("res://modes/battle_royale/map/afghan_map.gd")
const Density = preload("res://modes/battle_royale/map/afghan_tactical_density.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := Afghan.new()
	map.render_visuals = false
	root.add_child(map)
	var pilot_start := Time.get_ticks_msec()
	var a := Density.layout(map)
	var b := Density.layout(map)
	if a.size() != b.size():
		push_error("Nondeterministic density")
		quit(2)
		return
	for i in a.size():
		if a[i].position != b[i].position:
			push_error("Position mismatch %d" % i)
			quit(3)
			return
	map.build()
	await physics_frame
	var blocked := 0
	for entry: Dictionary in a:
		var basis: Transform3D = preload("res://modes/battle_royale/map/afghan_context.gd").on_ground(map, entry.position, entry.yaw)
		var lateral: bool = str(entry.kind) == "annex"
		var start: Vector3 = basis * (Vector3(-5, 1.2, 0) if lateral else Vector3(0, .6, -2))
		var finish: Vector3 = basis * (Vector3(5, 1.2, 0) if lateral else Vector3(0, .6, 2))
		var hit: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish, 1))
		if not hit.is_empty() and hit.collider.get_meta("library_id", "") in ["rural_annex_v11", "field_bank_v10", "field_wall_v10"]:
			blocked += 1
	var metrics: Dictionary = map.get_meta("afghan_density", {})
	var counts: Dictionary = metrics.get("counts", {})
	var scene_asset: PackedScene = load("res://modes/battle_royale/library/rural_annex_v11.tscn")
	var result := {"counts":counts,"pieces":metrics.get("pieces",-1),"pilot":counts.get("pilot",0),"generated_ms":Time.get_ticks_msec()-pilot_start,"annex_valid":scene_asset != null, "physical_blocked":blocked}
	print("AFGHAN_DENSITY_QA ", JSON.stringify(result))
	var success := int(result.pieces) > 0 and int(result.pilot) > 0 and bool(result.annex_valid) and blocked == a.size()
	map.free()
	quit(0 if success else 1)
