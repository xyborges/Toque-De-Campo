extends SceneTree
# Live ENet smoke test. Dedicated server, real WarGame, 28 online bots,
# one rendered client. Outputs only into ignored work/.
var game: WarGame
var role := "server"
var operation := "favela"
var failures: Array[String] = []
var frame_ms: Array[float] = []
var physics_ms: Array[float] = []
var unfocused := 0
var max_ticks := 0
var multi_ticks := 0
var label := "qa"
var bots_observed := 0
var cap_test := -1
var cap_observed := -1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--operation="): operation = arg.trim_prefix("--operation=")
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		if arg.begins_with("--cap="): cap_test = int(arg.trim_prefix("--cap="))
	run.call_deferred()

func wait_for(test: Callable, what: String, timeout_s := 105.0) -> bool:
	var limit := Time.get_ticks_msec() + int(timeout_s * 1000)
	while Time.get_ticks_msec() < limit:
		if test.call(): return true
		await process_frame
	failures.append("timeout:" + what)
	return false

func stats(source: Array[float]) -> Dictionary:
	if source.is_empty(): return {}
	var values := source.duplicate()
	values.sort()
	var total := 0.0
	for value in values: total += value
	var n := values.size()
	return {"n":n,"mean":total/n,"p95":values[mini(n-1,ceili(n*.95)-1)],"p99":values[mini(n-1,ceili(n*.99)-1)],"max":values[-1]}

func run() -> void:
	if role not in ["server","client"] or operation not in ["favela","afghan"]:
		push_error("IA2_NET_INVALID_PARAMETERS")
		quit(3)
		return
	game = WarGame.new()
	game.operation_id = operation
	game.set_meta("test_mode", true)
	game.set_meta("war_test", true)
	if role == "server":
		game.set_meta("war_host", true)
		game.set_meta("online_bots_test", true)
	else:
		game.set_meta("war_visual_preview", true)
	root.add_child(game)
	game.nickname_input.text = "qa-" + role
	game.address_input.text = "127.0.0.1"
	if role == "server":
		if await wait_for(func(): return game.online and game.multiplayer.is_server(), "server-listening", 120.0):
			if await wait_for(func(): return is_instance_valid(game.bot_director) and game.bot_director.bots.size()==28 and game.members.size()>=29, "online-28-bots-and-one-human", 120.0):
				bots_observed = game.bot_director.bots.size()
				if await wait_for(func(): return game.members.values().filter(func(x): return not bool(x.get("bot",false))).size()>=1 and game.players.values().any(func(x): return is_instance_valid(x) and x is WarPlayer and x.deployed and x.is_local==false), "client-connected-deployed", 30.0):
					await create_timer(26.0).timeout
	else:
		await game.join_game("pvp")
		if await wait_for(func(): return game.join_ready and is_instance_valid(game.local_player), "authenticated-joined", 120.0):
			game.request_deploy(0,"soldier","fal",WarRules.launcher_for_team(0),"base")
			if await wait_for(func(): return game.local_player.deployed, "local-deploy", 45.0):
				if await wait_for(func(): return game.players.size() >= 29, "28-remote-bots-received", 110.0):
					bots_observed = 28
					if cap_test in [0,1]:
						game.ia2_ragdoll_strict_cap = cap_test == 1
						var remote_actors: Array[WarPlayer] = []
						for candidate: WarPlayer in game.players.values():
							if is_instance_valid(candidate) and not candidate.is_local and candidate.deployed:
								remote_actors.append(candidate)
						if remote_actors.size()<12:
							failures.append("cap fixture needs 12 remote actors")
						else:
							for i in 12:
								var actor := remote_actors[i]
								actor.death_presented=actor.life_id-1
								game.spawn_ragdoll(actor.global_position,1,actor)
							await process_frame
							cap_observed = get_nodes_in_group("death_ragdolls").size()
							if cap_test==1 and cap_observed!=10:
								failures.append("strict cap failed: "+str(cap_observed))
					game.ui_focus.close_all()
					RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
					DisplayServer.window_move_to_foreground()
					await create_timer(4.0).timeout
					var prev := Time.get_ticks_usec()
					var prev_tick := Engine.get_physics_frames()
					var start := prev
					while Time.get_ticks_usec() - start < 15000000:
						await process_frame
						var now := Time.get_ticks_usec()
						frame_ms.append(float(now-prev)*.001)
						physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
						var ticks := Engine.get_physics_frames()-prev_tick
						prev_tick = Engine.get_physics_frames()
						max_ticks=maxi(max_ticks,ticks)
						if ticks>1:multi_ticks+=1
						if DisplayServer.get_name()!="headless" and not DisplayServer.window_is_focused():unfocused+=1
						prev=now
	var report: Dictionary = {"role":role,"operation":operation,"label":label,"failures":failures,"bots_observed":bots_observed,"cap_test":cap_test,"cap_observed":cap_observed,
		"remote_player_count":game.players.size(),"member_count":game.members.size(),"online":game.online,
		"join_ready":game.join_ready,"fps_average":1000.0/stats(frame_ms).get("mean",INF),"frame_ms":stats(frame_ms),
		"physics_ms":stats(physics_ms),"max_ticks":max_ticks,"multi_ticks":multi_ticks,"unfocused_frames":unfocused,
		"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"valid":failures.is_empty() and bots_observed==28 and (role=="server" or frame_ms.size()>0 and unfocused==0)}
	var directory := "res://work/ia2-qa-20261107"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var out := ProjectSettings.globalize_path(directory.path_join(label+"-"+role+".json"))
	var file := FileAccess.open(out,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print("IA2_QA_NETWORK_RESULT "+JSON.stringify(report))
	game.show_menu()
	game.queue_free()
	await create_timer(.3).timeout
	quit(0 if report.valid else 2)
