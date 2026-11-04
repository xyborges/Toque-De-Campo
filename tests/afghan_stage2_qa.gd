extends SceneTree
const Afghan = preload("res://modes/battle_royale/map/afghan_map.gd")
const Stage2 = preload("res://modes/battle_royale/map/afghan_density_stage2.gd")
const Context = preload("res://modes/battle_royale/map/afghan_context.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := Afghan.new()
	map.render_visuals = false
	root.add_child(map)
	map.build()
	await physics_frame
	var records: Array = map.get_meta("afghan_density_stage2_layout", [])
	var first: Array = map.get_meta("afghan_density_layout", [])
	var repeated: Array[Dictionary] = Stage2.layout(map, first)
	var stable := records.size() == repeated.size()
	var blocked := 0
	var access_ok := 0
	var road_ok := 0
	for i in records.size():
		var entry: Dictionary = records[i]
		if not stable or entry.position != repeated[i].position or entry.kind != repeated[i].kind: stable = false
		var transform: Transform3D = Context.on_ground(map, entry.position, entry.yaw)
		var is_annex: bool = str(entry.kind) == "annex"
		var start: Vector3 = transform * (Vector3(-5, 1.0, 0) if is_annex else Vector3(0, .55, -4.5))
		var finish: Vector3 = transform * (Vector3(5, 1.0, 0) if is_annex else Vector3(0, .55, 4.5))
		var hit: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish, 1))
		if not hit.is_empty() and str(hit.collider.get_meta("library_id", "")) in ["rural_annex_v11", "erosion_berm_v12", "wadi_bank_v12"]:
			blocked += 1
		if map.accessible(entry.position) and not map.is_water(entry.position): access_ok += 1
		var near: Dictionary = preload("res://modes/battle_royale/map/afghan_landform.gd")._near_road(Vector2(entry.position.x, entry.position.z))
		if float(near.distance) >= float(near.width) * .5 + 18.0: road_ok += 1
	var status: Dictionary = map.get_meta("afghan_density_stage2", {})
	var catalog_ok := load("res://modes/battle_royale/library/catalog_v2.tscn") is PackedScene
	var berm_ok := load("res://modes/battle_royale/library/erosion_berm_v12.tscn") is PackedScene
	var wadi_ok := load("res://modes/battle_royale/library/wadi_bank_v12.tscn") is PackedScene
	var result := {"ok":stable and blocked == records.size() and access_ok == records.size() and road_ok == records.size() and records.size() > 15 and catalog_ok and berm_ok and wadi_ok,"physical":records.size(),"blocked":blocked,"accessible":access_ok,"road_clearance":road_ok,"stable":stable,"catalog_ok":catalog_ok,"berm_ok":berm_ok,"wadi_ok":wadi_ok,"counts":status.get("counts", {})}
	print("AFGHAN_STAGE2_QA ", JSON.stringify(result))
	var f := FileAccess.open("res://work/afghan-stage2-qa.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(result, "\t")); f.close()
	map.free()
	quit(0 if result.ok else 1)
