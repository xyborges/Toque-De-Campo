extends SceneTree
const Afghan = preload("res://modes/battle_royale/map/afghan_map.gd")
const Stage3 = preload("res://modes/battle_royale/map/afghan_density_stage3.gd")
const Context = preload("res://modes/battle_royale/map/afghan_context.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var map := Afghan.new()
	map.render_visuals = false
	root.add_child(map)
	map.build()
	await physics_frame
	var records: Array = map.get_meta("afghan_density_stage3_layout", [])
	var earlier: Array = map.get_meta("afghan_density_layout", [])
	var second: Array = map.get_meta("afghan_density_stage2_layout", [])
	var repeated: Array[Dictionary] = Stage3.layout(map, earlier, second)
	var stable: bool = records.size() == repeated.size()
	var hits := 0
	var yard_walls_hit := 0
	var yard_walls_checked := 0
	var usable_entries := 0
	var displaced_spawn := 0
	for i in records.size():
		var item: Dictionary = records[i]
		if not stable or item.position != repeated[i].position or item.yaw != repeated[i].yaw: stable = false
		var tr: Transform3D = Context.on_ground(map, item.position, float(item.yaw))
		var start: Vector3 = tr * Vector3(0, .9, -3.8)
		var finish: Vector3 = tr * Vector3(0, .9, -1.5)
		var ray: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish, 1))
		if not ray.is_empty() and ray.collider.get_meta("library_id","") == "rural_shade_shed_v13": hits += 1
		var entry: Vector3 = tr * Vector3(0, 1.2, 5)
		var front: Vector3 = tr * Vector3(0, 1.2, 8)
		var blocked: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(entry, front, 1))
		if blocked.is_empty(): usable_entries += 1
		for j in 3:
			if j == 2 and not bool(item.add_wall): continue
			var offset := Vector3(-7.4, 0, -3.6) if j == 0 else (Vector3(7.4, 0, -3.6) if j == 1 else Vector3(0, 0, -9.5))
			var wall_position: Vector3 = tr * offset
			var angle: float = float(item.yaw) + (PI * .5 if j < 2 else 0.0)
			var wall_transform: Transform3D = Context.on_ground(map, wall_position, angle)
			var wall_hit: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(wall_transform * Vector3(0, 1.0, -3.8), wall_transform * Vector3(0, 1.0, 3.8), 1))
			yard_walls_checked += 1
			if not wall_hit.is_empty() and str(wall_hit.collider.get_meta("library_id", "")) == "courtyard_wall_v2":
				yard_walls_hit += 1
		for spawn: Vector3 in map.spawn_candidates():
			if spawn.distance_to(item.position) < 20.0: displaced_spawn += 1
	var stats: Dictionary = map.get_meta("afghan_density_stage3", {})
	var res := {"compounds":records.size(), "physical":stats.get("physical",0), "stable":stable, "shed_hits":hits, "yard_walls_hit":yard_walls_hit, "yard_walls_checked":yard_walls_checked, "front_clear":usable_entries, "spawns_near":displaced_spawn, "metrics":stats}
	res["ok"] = stable and records.size() >= 10 and hits == records.size() and yard_walls_hit == yard_walls_checked and usable_entries == records.size() and displaced_spawn == 0
	print("AFGHAN_STAGE3_QA ", JSON.stringify(res))
	var file := FileAccess.open("res://work/afghan-stage3-qa.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(res, "\t")); file.close()
	map.free()
	quit(0 if res.ok else 1)
