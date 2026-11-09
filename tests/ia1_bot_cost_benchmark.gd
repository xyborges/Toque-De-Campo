extends SceneTree
# IA1 Fase 1: mesmo WarGame real, 0/6/12/28 bots. Somente medicao.
var operation := "afghan"
var count := 28
var label := "exploratory"
var duration := 30.0
var warmup := 8.0
var no_bot_bot_collision := false
var game: WarGame
var frames: Array[float] = []
var physics: Array[float] = []
var gpu_times: Array[float] = []
var frame_ticks: Array[float] = []
var scope_times: Dictionary = {}
var scope_calls: Dictionary = {}
var spikes := 0
var alive_at_end := 0
var unfocused_frames := 0
var population_min := 0
var max_tick := 0
var max_draws := 0.0
var vram_max := 0.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--operation="): operation = arg.trim_prefix("--operation=")
		if arg.begins_with("--bots="): count = int(arg.trim_prefix("--bots="))
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--duration="): duration = float(arg.trim_prefix("--duration="))
		if arg.begins_with("--warmup="): warmup = float(arg.trim_prefix("--warmup="))
		if arg == "--ia1-no-bot-bot-collision": no_bot_bot_collision = true
	for scope in BotCostProbe.SCOPES:
		scope_times[scope] = []
		scope_calls[scope] = []
	run.call_deferred()

func fail(message: String) -> void:
	push_error("IA1_INVALID: " + message)
	quit(2)

func describe(samples: Array) -> Dictionary:
	if samples.is_empty(): return {}
	var sorted := samples.duplicate()
	sorted.sort()
	var sum := 0.0
	for v in samples: sum += v
	var n := sorted.size()
	return {"n": n, "mean": sum / n, "p50": sorted[mini(n - 1, ceili(n * .50) - 1)],
		"p95": sorted[mini(n - 1, ceili(n * .95) - 1)],
		"p99": sorted[mini(n - 1, ceili(n * .99) - 1)], "max": sorted[-1]}

func run() -> void:
	if count not in [0,6,12,22,28]: fail("invalid bot count"); return
	if operation not in ["afghan","favela"]: fail("invalid map"); return
	if DisplayServer.get_name() == "headless": fail("visual Forward+ benchmark required"); return
	seed(712907)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(1920, 1080)
	root.scaling_3d_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure()
	var preset_key := str(GameOptions.PRESETS.keys()[1])
	GameOptions.values.merge(GameOptions.PRESETS[preset_key], true)
	GameOptions.values["scale"] = 1.0
	GameOptions.values["fps"] = 0
	GameOptions.values["vsync"] = false
	game = WarGame.new()
	game.operation_id = operation
	game.offline_operation = true
	game.offline_participants = count + 1
	game.set_meta("test_mode", true)
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 120000
	while not game.join_ready and Time.get_ticks_msec() < deadline: await process_frame
	if not game.join_ready: fail("game never ready"); return
	game.request_deploy(0, "soldier", "fal", WarRules.launcher_for_team(0), "base")
	deadline = Time.get_ticks_msec() + 45000
	var deployed := 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		deployed = 0
		if is_instance_valid(game.bot_director):
			for id in game.bot_director.bots:
				var bot := game.players.get(id) as WarPlayer
				if is_instance_valid(bot) and bot.deployed: deployed += 1
		if is_instance_valid(game.local_player) and game.local_player.deployed and is_instance_valid(game.bot_director) and game.bot_director.bots.size() == count and deployed == count: break
	if not is_instance_valid(game.bot_director) or game.bot_director.bots.size() != count or deployed != count:
		fail("incorrect bot population or deployment=" + str(deployed));return
	var teams := [0,0]
	for id in game.bot_director.bots:
		teams[int(game.bot_director.bots[id].team)] += 1
	if teams[0] != count / 2 or teams[1] != count / 2:
		fail("uneven teams " + str(teams));return
	# Diagnostic only. Collision exceptions are bot-to-bot only; retain normal
	# collision layers, human bodies, vehicles, hitboxes and projectile queries.
	if no_bot_bot_collision:
		for id in game.bot_director.bots:
			var bot := game.players.get(id) as WarPlayer
			for other_id in game.bot_director.bots:
				if id != other_id:
					bot.add_collision_exception_with(game.players[other_id])
	game.third_person = true
	game.local_player._update_view()
	game.ui_focus.close_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# Test harness only. Consecutive Windows launches can remain unfocused.
	if "--ia1-focus-window" in OS.get_cmdline_user_args():
		DisplayServer.window_move_to_foreground()
	await create_timer(warmup).timeout
	if "--ia1-focus-window" in OS.get_cmdline_user_args() and not DisplayServer.window_is_focused():
		DisplayServer.window_move_to_foreground()
		await create_timer(0.5).timeout
	if Vector2i(root.get_texture().get_size()) != Vector2i(1920,1080) or not is_equal_approx(root.scaling_3d_scale,1.0):
		fail("wrong rendered resolution " + str(root.get_texture().get_size()));return
	if RenderingServer.get_current_rendering_method() != "gl_compatibility" and RenderingServer.get_current_rendering_method() != "forward_plus":
		fail("unexpected renderer " + RenderingServer.get_current_rendering_method());return
	print("IA1_READY label=",label," operation=",operation," bots=",count," teams=",teams,
		" mask=",no_bot_bot_collision," renderer=",RenderingServer.get_current_rendering_method(),
		" probing=",BotCostProbe.enabled," resolution=",root.get_texture().get_size())
	BotCostProbe.clear()
	var previous := Time.get_ticks_usec()
	var start := previous
	var previous_physics := Engine.get_physics_frames()
	var window_start_unix_ms := int(Time.get_unix_time_from_system() * 1000)
	population_min = count
	while Time.get_ticks_usec() - start < int(duration * 1000000.0):
		await process_frame
		if not DisplayServer.window_is_focused(): unfocused_frames += 1
		population_min = mini(population_min, game.bot_director.bots.size())
		var now := Time.get_ticks_usec()
		var frame_ms := (now - previous) * .001
		previous = now
		frames.append(frame_ms)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		var ticks := Engine.get_physics_frames() - previous_physics
		previous_physics = Engine.get_physics_frames()
		frame_ticks.append(float(ticks))
		max_tick = maxi(max_tick,ticks)
		if frame_ms > 33.0: spikes += 1
		max_draws = maxf(max_draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		vram_max = maxf(vram_max,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		var sample := BotCostProbe.take()
		for scope: String in BotCostProbe.SCOPES:
			var measurement: Dictionary = sample[scope]
			(scope_times[scope] as Array).append(float(measurement.usec) * .001)
			(scope_calls[scope] as Array).append(float(measurement.calls))
	for id in game.bot_director.bots:
		var bot := game.players.get(id) as WarPlayer
		if is_instance_valid(bot) and bot.deployed and bot.hp > 0: alive_at_end += 1
	var report_scopes: Dictionary = {}
	for scope: String in BotCostProbe.SCOPES:
		report_scopes[scope] = {"ms": describe(scope_times[scope]),"calls_per_frame":describe(scope_calls[scope])}
	var accumulated := 0
	for ticks in frame_ticks:
		if ticks > 1: accumulated += 1
	var result := {
		"valid": not frames.is_empty() and unfocused_frames == 0 and population_min == count, "label":label,"operation":operation,"bots":count,
		"unfocused_frames":unfocused_frames,"population_min":population_min,
		"measurement_window_unix_ms":{"start":window_start_unix_ms,"end":int(Time.get_unix_time_from_system()*1000)},
		"bots_by_team":teams,"bots_alive_at_end":alive_at_end,
		"no_bot_bot_collision":no_bot_bot_collision,"probe_enabled":BotCostProbe.enabled,
		"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"resolution":"1920x1080", "preset":preset_key, "scale":root.scaling_3d_scale,
		"measured_s":duration,"warmup_s":warmup,"frame_ms":describe(frames),
		"fps_average":1000.0 / describe(frames).mean,"physics_ms":describe(physics),
		"gpu_render_ms":describe(gpu_times),"physics_ticks_per_frame":describe(frame_ticks),
		"frames_with_multiple_physics_ticks":accumulated,"max_ticks_per_frame":max_tick,
		"frames_over_33ms":spikes,"scopes":report_scopes,
		"draw_calls_max":max_draws,"reported_vram_mib_max":vram_max,
		"scope_note":"Per-frame accumulated GDScript wall clock; pose excludes deferred Jolt broadphase; perception includes LOS as subset; think_total includes perception/navigation. Do not sum overlapping scopes.",
		"fixture_note":"Real WarGame offline, stationary local 3rd person camera, unmodified AI. Pairwise bot collision exceptions diagnostic only, not a gameplay candidate."
	}
	var dir := "res://work/ia1-fisica-bots-20261106"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(ProjectSettings.globalize_path(dir.path_join(label+".json")),FileAccess.WRITE)
	if file == null: fail("failed to save data");return
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("IA1_RESULT " + JSON.stringify({"label":label,"operation":operation,"bots":count,"fps":result.fps_average,"p99":result.frame_ms.p99,"physics_ms":result.physics_ms.mean,"scope_ms":report_scopes,"accumulated_frames":accumulated}))
	game.queue_free()
	await process_frame
	quit(0 if bool(result.valid) else 2)
