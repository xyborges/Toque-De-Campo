extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.start_offline("training")
	game.offline_elapsed = 180.0
	game.local_player.hp = 100000.0
	game.local_player.limbs = {"head":100000.0,"torso":100000.0,"armL":100000.0,"armR":100000.0,"legL":100000.0,"legR":100000.0}
	# Look behind to allow the full director population without spawning in view.
	game.local_player.yaw = PI
	game.local_player.rotation.y = PI
	for i in range(20):
		game._spawn_npc(i)
		if game.npcs.size() >= 16: break
	var samples: Array[float] = []
	var cpu_samples: Array[float] = []
	var max_npcs: int = game.npcs.size()
	var initial: Dictionary = {}
	for npc in game.npcs: initial[npc.peer_id] = npc.global_position
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 9000:
		await process_frame
		max_npcs = maxi(max_npcs,game.npcs.size())
		if Time.get_ticks_msec()-start > 1500:
			samples.append(root.get_process_delta_time()*1000.0)
			cpu_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		game.local_player.hp = 100000.0
		if game.npcs.size() >= 16 and game.local_player.weapon_id != "broom":
			game.local_player.weapon_id = "broom"
			game.local_player._refresh_weapon()
		if game.local_player.fire_cooldown <= 0.0:
			game.local_player.shot_sequence += 1
			game._server_accept_shot(1,game.local_player.shot_sequence,game.local_player.life_id,game.local_player.camera.global_position,-game.local_player.camera.global_basis.z,game.local_player.weapon_id)
	samples.sort()
	cpu_samples.sort()
	var report := {"max_npcs":max_npcs,"frames":samples.size(),"median_frame_ms":samples[samples.size()/2],"p95_frame_ms":samples[int(samples.size()*0.95)],"p95_physics_ms":cpu_samples[int(cpu_samples.size()*0.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var moved := 0
	var in_reach := 0
	for npc in game.npcs:
		if initial.has(npc.peer_id) and npc.global_position.distance_to(initial[npc.peer_id]) > 1.5: moved += 1
		if npc.global_position.distance_to(game.local_player.global_position) < 2.0: in_reach += 1
	report["moving_npcs"] = moved
	report["npcs_reached_player"] = in_reach
	FileAccess.open("res://tests/offline-performance-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	game._stop_world_audio()
	game.queue_free()
	await process_frame
	quit()
