extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node3D = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.start_offline("training")
	game.set_physics_process(false)
	var nav: OfflineDirector = game.offline_director
	var counts := [0,0,0,0]
	var target := nav.nearest(game.local_player.global_position)
	for x in range(nav.grid.region.size.x):
		for y in range(nav.grid.region.size.y):
			var id := Vector2i(x,y)
			if not nav.walkable(id): continue
			counts[0] += 1
			var pos := nav.world_point(id)
			var distance := pos.distance_to(game.local_player.global_position)
			if distance < 6.5 or distance > 25: continue
			counts[1] += 1
			if nav.grid.get_id_path(id,target).is_empty(): continue
			counts[2] += 1
			var camera: Camera3D = game.local_player.camera
			if (pos+Vector3.UP-camera.global_position).normalized().dot(-camera.global_basis.z) > 0.65 and game.npc_line_clear(camera.global_position-Vector3.UP,pos): continue
			counts[3] += 1
	print("SPAWN ",game.npcs.size()," counts=",counts," target=",target," world=",nav.world_point(target)," grid=",nav.grid.region)
	for i in range(15):
		game._spawn_npc(i)
		print("NEW COUNT ",game.npcs.size())
	game.queue_free()
	await process_frame
	quit()
