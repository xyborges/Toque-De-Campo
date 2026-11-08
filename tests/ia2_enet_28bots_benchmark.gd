extends SceneTree

# Native ENet/DTLS authority with 28 live online bots and one GTX 1650 client.
# Five alternating A/B pairs per IA2 flag, in a single uninterrupted match.
# Visual events are injected client-side; do not claim authoritative kills.
var game: WarGame
var role := "client"
var server_ip := "127.0.0.1"
var failures: Array[String] = []
var results: Array[Dictionary] = []
var dropped_focus := 0
var min_remote_actors := 100
var server_min_bots := 100
var server_samples := 0
var server_bots_at_completion := 0
var started_usec := 0
var window_seconds := 12.0
var requested_pairs := 5
var requested_profiles: Array[String] = ["reuse","defer","cap"]
const SEGMENT_WARMUP_SECONDS := 2.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--server-ip="): server_ip = arg.trim_prefix("--server-ip=")
		if arg.begins_with("--pairs="): requested_pairs = clampi(int(arg.trim_prefix("--pairs=")),1,5)
		if arg.begins_with("--segment-seconds="): window_seconds = clampf(float(arg.trim_prefix("--segment-seconds=")),5.0,30.0)
		if arg.begins_with("--profiles="):
			requested_profiles.clear()
			for item: String in arg.trim_prefix("--profiles=").split(","):
				if item in ["reuse","defer","cap"]:requested_profiles.append(item)
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60 if role == "server" else 0
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("IA2_ENET_FAIL ", role, " ", message)

func _wait_for(condition: Callable, label_text: String, seconds := 130.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if condition.call(): return true
	_check(false, "timeout: " + label_text + " role=" + role + " status=" + str(game.status_label.text) + " online=" + str(game.online) + " ready=" + str(game.join_ready) + " host=" + game.address_input.text + " peers=" + str(game.multiplayer.get_peers()))
	return false

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for v in ordered: total += v
	var n := ordered.size()
	var tail := maxi(1, ceili(n * 0.01))
	var slow_sum := 0.0
	for j in range(n - tail, n): slow_sum += ordered[j]
	return {"count": n, "mean_ms": total / n,
		"fps": float(n) * 1000.0 / total,
		"one_percent_low_fps": float(tail) * 1000.0 / slow_sum,
		"p95_ms": ordered[mini(n-1, ceili(n*0.95)-1)],
		"p99_ms": ordered[mini(n-1, ceili(n*0.99)-1)],
		"max_ms": ordered.back(),
		"over33": ordered.filter(func(v: float)->bool:return v > 33.333).size()}

func _remote_actors() -> Array[WarPlayer]:
	var actors: Array[WarPlayer] = []
	for peer_id in game.players:
		var actor := game.players[peer_id] as WarPlayer
		if is_instance_valid(actor) and not actor.is_local and bool(game.members.get(peer_id,{}).get("bot",false)):
			actors.append(actor)
	actors.sort_custom(func(a: WarPlayer,b: WarPlayer)->bool:return a.peer_id < b.peer_id)
	return actors

func _run() -> void:
	if role == "client":
		GameOptions.ensure()
		GameOptions.values.merge(GameOptions.PRESETS["Médio"], true)
		GameOptions.values["scale"] = 1.0
		GameOptions.values["fps"] = 0
		GameOptions.values["vsync"] = false
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(1920,1080)
		root.scaling_3d_scale = 1.0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://tests/war_frame_pacing_game.gd").new()
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	game.set_meta("war_host",role == "server")
	if role == "server": game.set_meta("online_bots_test",true)
	else: game.set_meta("war_visual_preview",true)
	root.add_child(game)
	game.nickname_input.text = role
	game.address_input.text = server_ip
	if role == "server": await _server()
	else: await _client()
	var result := {
		"role": role, "failures": failures, "results": results,
		"server_min_bots": server_min_bots, "server_samples": server_samples,
		"min_remote_actors": min_remote_actors, "dropped_focus_frames": dropped_focus,
		"elapsed_sec": float(Time.get_ticks_usec() - started_usec)*0.000001 if started_usec > 0 else 0.0,
		"gpu": RenderingServer.get_video_adapter_name() if role == "client" else "headless",
		"renderer": RenderingServer.get_current_rendering_method(),
		"physics_hz": Engine.physics_ticks_per_second,
	}
	if role == "server" and is_instance_valid(game.bot_director):
		result["bot_diagnostics"] = game.bot_director.diagnostics.duplicate()
		result["final_bots"] = game.bot_director.bots.size()
		result["bots_at_completion"] = server_bots_at_completion
	if role == "client":
		result["render_texture"] = root.get_texture().get_size()
		result["render_scale"] = root.scaling_3d_scale
		result["replicated_players"] = game.players.size()
	NavalStorage.write_json("res://work/ia2-enet-20261108/" + role + ".json",result)
	print("IA2_ENET_28BOTS_RESULT ",JSON.stringify(result))
	game.show_menu()
	game.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)

func _server() -> void:
	if not await _wait_for(func()->bool:return game.multiplayer.get_peers().size()==1, "ENet connection",270):return
	var peer_id: int = game.multiplayer.get_peers()[0]
	if not await _wait_for(func()->bool:return game.players.has(peer_id) and game.loading_baselines.is_empty() and game.reports.has("baseline-ready"),"DTLS admission and baseline",240):return
	_check(game._deploy(peer_id,0,"soldier","fal","rpg","base"),"authority deploy")
	if not await _wait_for(func()->bool:return is_instance_valid(game.bot_director) and game.bot_director.bots.size()==28 and game.reports.has("client-ready"),"28 live bots and client",130):return
	# Put two opposing authority bots on a genuinely clear lane, so real
	# targeting and gunfire exercise the network while all 28 keep moving.
	var opponents: Array = [null,null]
	for bot_id in game.bot_director.bots:
		var record: Dictionary = game.bot_director.bots[bot_id]
		var team: int = int(record.get("team",-1))
		if team in [0,1] and opponents[team]==null:
			var candidate: WarPlayer=game.players[bot_id] as WarPlayer
			if is_instance_valid(candidate) and candidate.vehicle_id.is_empty() and candidate.deployed and candidate.hp>0:
				opponents[team]=candidate
	_check(opponents[0]!=null and opponents[1]!=null,"opposing bots selected")
	var clear_point: Vector3 = WarTerrain.point(-120,0)
	for x in range(-120,121,20):
		var a: Vector3 = WarTerrain.point(x,0)
		var b: Vector3 = WarTerrain.point(x+10,0)
		if game.npc_line_clear(a+Vector3.UP*1.5,b+Vector3.UP*1.5):clear_point=a;break
	for team in [0,1]:
		var bot: WarPlayer = opponents[team] as WarPlayer
		if not is_instance_valid(bot):continue
		bot.global_position=WarTerrain.point(clear_point.x+team*10,clear_point.z)+Vector3.UP*.15
		bot.velocity=Vector3.ZERO
		bot.yaw=PI*.5 if team==0 else -PI*.5
		bot.rotation.y=bot.yaw
		game.bot_director.bots[bot.peer_id].next_shot=0.0
		game.bot_director.bots[bot.peer_id].target=(opponents[1-team] as WarPlayer).peer_id
		game.bot_director.bots[bot.peer_id].reaction_until=game.war_clock
		game.members[bot.peer_id].shield=0.0
	await create_timer(.7).timeout
	var combat_debug: Array=[]
	for team in [0,1]:
		var bot:WarPlayer=opponents[team] as WarPlayer
		var foe:WarPlayer=opponents[1-team] as WarPlayer
		combat_debug.append({"id":bot.peer_id,"team":bot.war_team,"role":bot.war_class,"hp":bot.hp,"deployed":bot.deployed,"vehicle":bot.vehicle_id,"position":bot.global_position,"target_position":foe.global_position,"los":game.bot_director._has_clear_shot(bot,foe),"visible_enemy":game.bot_director._visible_enemy(bot)!=null})
	print("IA2_COMBAT_SETUP ",JSON.stringify(combat_debug))
	started_usec = Time.get_ticks_usec()
	game.bot_director.measuring = true
	game.measuring = true
	game.phase = "start"
	game._broadcast("qa_phase",["start"])
	var last_sample := 0
	var deadline := Time.get_ticks_msec()+700000
	while not game.reports.has("done") and Time.get_ticks_msec()<deadline:
		await process_frame
		var now := Time.get_ticks_usec()
		if now-last_sample >= 500000:
			last_sample = now
			server_samples += 1
			server_min_bots = mini(server_min_bots,game.bot_director.bots.size())
			if game.bot_director.bots.size()!=28:
				_check(false,"bot population dropped to "+str(game.bot_director.bots.size()))
				break
	if not game.reports.has("done"): _check(false,"client did not finish")
	server_bots_at_completion = game.bot_director.bots.size()
	game.measuring = false
	game.bot_director.measuring = false
	game.phase = "finish"
	game._broadcast("qa_phase",["finish"])
	_check(server_samples>=12,"server simulation observed")
	_check(int(game.bot_director.diagnostics.get("moves",0))>0,"bot movement executed")
	_check(int(game.bot_director.diagnostics.get("shot_attempts",0))>0,"bots attempted real combat")
	await create_timer(0.8).timeout

func _client() -> void:
	game.mode = "pvp"
	game.map_kind = "desert"
	game._enter_match_world()
	game.world_prebuilt = true
	await create_timer(1.0).timeout
	game.ui_focus.close_all()
	game.loading_screen.hide()
	await game.join_game("pvp")
	if not await _wait_for(func()->bool:return game.join_ready and is_instance_valid(game.local_player),"client ENet admission",220):return
	game.rpc_id(1,"qa_report","baseline-ready")
	if not await _wait_for(func()->bool:return game.local_player.deployed and game.players.size()==29,"28 bot presentations and local deployment",220):return
	game.ui_focus.close_all()
	game.third_person = true
	game.local_player._update_view()
	game.vehicle_system.set_process_input(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game.rpc_id(1,"qa_report","client-ready")
	if not await _wait_for(func()->bool:return game.phase=="start","server start",130):return
	started_usec = Time.get_ticks_usec()
	var texture: Vector2i = root.get_texture().get_size()
	var renderer := RenderingServer.get_current_rendering_method()
	_check(texture==Vector2i(1920,1080),"actual client resolution 1920x1080: "+str(texture))
	_check(is_equal_approx(root.scaling_3d_scale,1.0),"render scale 100%")
	_check(renderer!="gl_compatibility","Forward+ renderer")
	_check(RenderingServer.get_video_adapter_name().contains("GTX 1650"),"GPU GTX 1650")
	_check(game.members.size()==29,"one human plus 28 bots")
	for profile in requested_profiles:
		for pair in range(1,requested_pairs+1):
			var order: Array = [false,true] if pair%2==1 else [true,false]
			for optimized: bool in order:
				var record: Dictionary = await _segment(profile,pair,optimized)
				results.append(record)
				print("IA2_ENET_SEGMENT ",JSON.stringify(record))
				_check(bool(record.get("valid",false)),"valid segment "+profile+" pair "+str(pair)+" opt "+str(optimized))
				if not failures.is_empty(): break
			if not failures.is_empty(): break
		if not failures.is_empty():break
	game.rpc_id(1,"qa_report","done")
	await _wait_for(func()->bool:return game.phase=="finish","server done",15)

func _segment(profile: String,pair: int,optimized: bool) -> Dictionary:
	while game.ia2_remote_ragdoll_running:
		await process_frame
	for corpse: Node in get_nodes_in_group("death_ragdolls"):
		if is_instance_valid(corpse):corpse.queue_free()
	await process_frame
	var actors := _remote_actors()
	var all_flag_off := false
	game.ia2_remote_ragdoll_queue_enabled = optimized if profile=="defer" else all_flag_off
	game.ia2_ragdoll_strict_cap = optimized if profile=="cap" else all_flag_off
	for actor in actors:
		actor.ia2_respawn_weapon_reuse = optimized if profile=="reuse" else all_flag_off
	await create_timer(SEGMENT_WARMUP_SECONDS).timeout
	var frame_times: Array[float] = []
	var physics: Array[float] = []
	var callback_samples: Array[float] = []
	var focus_lost := 0
	var disconnected_frames := 0
	var min_actors := 100
	var worst_corpses := 0
	var events := 0
	var frame_last := Time.get_ticks_usec()
	var measurement_start := frame_last
	var event_due := 0.6
	while (Time.get_ticks_usec()-measurement_start)*0.000001 < window_seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now-frame_last)*0.001)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		frame_last = now
		if not DisplayServer.window_is_focused():focus_lost+=1
		if not game.online or not game.multiplayer.get_peers().has(1):disconnected_frames+=1
		var live_actors := _remote_actors()
		min_actors=mini(min_actors,live_actors.size())
		worst_corpses=maxi(worst_corpses,get_nodes_in_group("death_ragdolls").size())
		var elapsed := (now-measurement_start)*0.000001
		if elapsed>=event_due and live_actors.size()==28:
			event_due+=1.3
			var started := Time.get_ticks_usec()
			if profile=="reuse":
				for bot in live_actors:
					bot._refresh_weapon()
					bot._update_weapon_pose()
			else:
				var burst := 12 if profile=="cap" else 8
				for i in burst:
					var bot: WarPlayer = live_actors[(events*burst+i)%live_actors.size()]
					bot.death_presented=bot.life_id-1
					game.spawn_ragdoll(bot.global_position,1,bot)
			callback_samples.append((Time.get_ticks_usec()-started)*0.001)
			events+=1
	while game.ia2_remote_ragdoll_running:
		await process_frame
	min_remote_actors=mini(min_remote_actors,min_actors)
	dropped_focus+=focus_lost
	var ms := _stats(frame_times)
	var call_stats := _stats(callback_samples)
	var physics_stats := _stats(physics)
	var valid := min_actors==28 and events>=5 and focus_lost==0 and disconnected_frames==0 and not ms.is_empty()
	if profile=="cap" and optimized:
		valid=valid and worst_corpses<=10
	return {"profile":profile,"pair":pair,"optimized":optimized,
		"valid":valid,"min_remote_actors":min_actors,"events":events,
		"frames":ms,"callbacks":call_stats,"physics":physics_stats,
		"focus_lost":focus_lost,"disconnected_frames":disconnected_frames,"max_corpses":worst_corpses,
		"actual_resolution":root.get_texture().get_size(),
		"render_method":RenderingServer.get_current_rendering_method()}
