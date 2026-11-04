extends SceneTree
var kind := "office"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-map="): kind = arg.trim_prefix("--perf-map=")
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.start_offline("training" if kind=="office" else "desert")
	game.local_player.hp = 100000.0
	game.offline_elapsed = 320.0
	await create_timer(4.5).timeout
	var samples: Array[float] = []
	var physics: Array[float] = []
	var since := Time.get_ticks_usec()
	var last := since
	while Time.get_ticks_usec()-since<5000000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last = now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	samples.sort()
	var mean := 0.0
	var physics_mean := 0.0
	for value in samples: mean += value/samples.size()
	for value in physics: physics_mean += value/physics.size()
	var result := {"map":kind,"npcs":game.npcs.size(),"fps":1000.0/mean,"frame_p95_ms":samples[int(samples.size()*.95)],"physics_ms":physics_mean,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"cap":60,"resolution":str(root.size)}
	NavalStorage.write_json("res://tests/environment-performance-"+kind+".json",result)
	print("ENVIRONMENT_ACTIVE_PERFORMANCE ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit()
