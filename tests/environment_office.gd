extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.start_offline("training")
	game.set_physics_process(false)
	game.local_player.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(game.npcs.size()==8,"eight initial NPCs in enlarged office")
	var director: OfflineDirector = game.offline_director
	var origin := director.nearest(Vector3(0,0,1.5))
	for id in OfficeMap.ROOM_CENTERS:
		var destination := director.nearest(OfficeMap.ROOM_CENTERS[id])
		check(director.walkable(destination) and not director.grid.get_id_path(origin,destination).is_empty(),"NPC route connects warehouse to "+id)
	var world: World3D = game.get_world_3d()
	var door := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1.2,-27),Vector3(0,1.2,-31),1))
	check(door.is_empty(),"rear passage has a physical opening")
	var wall := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(4,1.2,-27),Vector3(4,1.2,-31),1))
	check(not wall.is_empty(),"adjacent rear wall still blocks projectiles")
	var valid := true
	for npc in game.npcs:
		valid = valid and OfficeMap.has_floor(npc.position.x,npc.position.z) and director.walkable(director.point_id(npc.position))
		for other in game.npcs:
			if other!=npc: valid = valid and npc.position.distance_to(other.position)>1.95
	check(valid,"NPC spawns remain on floor, clear and separated")
	check(not director.walkable(director.point_id(Vector3(13,0,-10))),"navigation excludes the empty area outside the warehouse")
	check(int(game.world_root.get_meta("environment_instances",0))>1500,"modular office furniture and architectural details are present")
	for npc in game.npcs: npc.queue_free()
	await physics_frame
	game.local_player.position = Vector3(0,.1,-27)
	for i in range(50):
		game.local_player.velocity = Vector3(0,-1,-3)
		game.local_player.move_and_slide()
		await physics_frame
	check(game.local_player.position.z< -29.0,"actual player capsule traverses rear doorway")
	game.queue_free()
	await process_frame
	NavalStorage.write_json("res://tests/environment-office-results.json",{"checks":checks,"failures":failures})
	quit(0 if failures.is_empty() else 1)
