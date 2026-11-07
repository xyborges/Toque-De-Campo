extends SceneTree

# Isolated in-process authoritative WarGame for 28 bots/60s per run.
# This is NOT a graphical ENet client or remote dedicated server.
var operation: String="favela"
var run_label: String="pilot"
var duration_sec: float=60.0
var physics_samples: Array[float]=[]
var frame_samples: Array[float]=[]
var multi_tick_frames:=0
var max_ticks:=0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--operation="):operation=arg.trim_prefix("--operation=")
		if arg.begins_with("--label="):run_label=arg.trim_prefix("--label=")
		if arg.begins_with("--seconds="):duration_sec=float(arg.trim_prefix("--seconds="))
	_measure.call_deferred()

func _summarize(values: Array[float]) -> Dictionary:
	if values.is_empty():return {}
	var ordered: Array[float]=values.duplicate()
	ordered.sort()
	var total:=0.0
	for value: float in values:total+=value
	var n:=ordered.size()
	return {"mean":total/n,"p95":ordered[mini(n-1,ceili(n*.95)-1)],
		"p99":ordered[mini(n-1,ceili(n*.99)-1)],"max":ordered[-1],
		"count":n}

func _measure() -> void:
	if operation not in ["favela","afghan"]:quit(2);return
	Engine.max_fps=60
	Engine.physics_ticks_per_second=60
	var begun:=Time.get_ticks_usec()
	var game:=WarGame.new()
	game.operation_id=operation
	game.offline_operation=true
	game.offline_participants=29
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:
		print("IA2_COMBINED_ERROR join_ready_timeout ",operation);quit(3);return
	var join_ms: float=(Time.get_ticks_usec()-begun)*.001
	var join_unix_ms:=int(Time.get_unix_time_from_system()*1000.0)
	game.request_deploy(0,"soldier","fal","stinger","base")
	deadline=Time.get_ticks_msec()+45000
	while (not is_instance_valid(game.bot_director) or game.bot_director.bots.size()<28) and Time.get_ticks_msec()<deadline:await process_frame
	if not is_instance_valid(game.bot_director) or game.bot_director.bots.size()!=28:
		print("IA2_COMBINED_ERROR bot_count_not_28 ",operation);quit(4);return
	var deployed:=0
	for bot_id: int in game.bot_director.bots:
		var actor: WarPlayer=game.players.get(bot_id) as WarPlayer
		if is_instance_valid(actor) and actor.deployed:deployed+=1
	if deployed!=28:
		print("IA2_COMBINED_ERROR deployed ",deployed);quit(5);return
	var start_usec:=Time.get_ticks_usec()
	var sample_start_unix_ms:=int(Time.get_unix_time_from_system()*1000.0)
	var prev_usec:=start_usec
	var prev_ticks:=Engine.get_physics_frames()
	while (Time.get_ticks_usec()-start_usec)<duration_sec*1000000.0:
		await process_frame
		var now:=Time.get_ticks_usec()
		frame_samples.append((now-prev_usec)*.001)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		var delta_ticks:=Engine.get_physics_frames()-prev_ticks
		if delta_ticks>1:multi_tick_frames+=1
		max_ticks=maxi(max_ticks,delta_ticks)
		prev_ticks=Engine.get_physics_frames()
		prev_usec=now
	var sample_end_unix_ms:=int(Time.get_unix_time_from_system()*1000.0)
	var deployed_final:=0
	for bot_id: int in game.bot_director.bots:
		var final_actor: WarPlayer=game.players.get(bot_id) as WarPlayer
		if is_instance_valid(final_actor) and final_actor.deployed:deployed_final+=1
	var result: Dictionary={
		"operation":operation,"label":run_label,
		"flags":{"housing":OS.get_environment("TDC_IA2_HOUSING_CACHE"),
			"terrain":OS.get_environment("TDC_IA2_TERRAIN_FACES")},
		"game_world_ms":game.world_build_ms,"join_ready_ms":join_ms,
		"join_unix_ms":join_unix_ms,"sample_start_unix_ms":sample_start_unix_ms,"sample_end_unix_ms":sample_end_unix_ms,
		"bot_count":game.bot_director.bots.size(),
		"bots_deployed_initial":deployed,
		"bots_deployed_final":deployed_final,
		"frames":_summarize(frame_samples),"physics_ms":_summarize(physics_samples),
		"max_ticks_frame":max_ticks,"multi_tick_frames":multi_tick_frames,
		"duration_measured_sec":(Time.get_ticks_usec()-start_usec)/1000000.0,
		"bot_diagnostics":game.bot_director.diagnostics,
		"engine_version":Engine.get_version_info()
	}
	print("IA2_COMBINED_60S ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0)
