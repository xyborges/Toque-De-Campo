extends SceneTree
# Rendered WarGame with 28 live bots; one flag at a time, never publishes.
# Usage: --mode=weapons|ragdolls|cap --optimized=0|1 --map=afghan|favela --tag=label
var mode := "weapons"
var optimized := false
var operation := "afghan"
var label := "test"
var warmup := 6.0
var duration := 14.0
var game: WarGame
var camera: Camera3D
var frame_ms: Array[float] = []
var frame_ticks: Array[int] = []
var callbacks: Array[float] = []
var failures: Array[String] = []
var events := 0
var missing_focus := 0
var minimum_bots := 28
var max_bodies := 0
var reused := 0
var builds := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="): mode = a.trim_prefix("--mode=")
		if a.begins_with("--optimized="): optimized = a.trim_prefix("--optimized=") == "1"
		if a.begins_with("--map="): operation = a.trim_prefix("--map=")
		if a.begins_with("--tag="): label = a.trim_prefix("--tag=")
		if a.begins_with("--duration="): duration = clampf(float(a.trim_prefix("--duration=")),10.0,30.0)
	_run.call_deferred()

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		push_error("IA2_REAL_WAR_FAIL: " + msg)

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var seq := values.duplicate()
	seq.sort()
	var total := 0.0
	for n in seq: total += n
	var count := seq.size()
	return {"mean_ms":total/count,"p95_ms":seq[mini(count-1,ceili(count*.95)-1)],
		"p99_ms":seq[mini(count-1,ceili(count*.99)-1)],
		"max_ms":seq[-1],"samples":count}

func _run() -> void:
	if DisplayServer.get_name() == "headless" or mode not in ["weapons","ragdolls","cap"] or operation not in ["afghan","favela"]:
		check(false,"invalid renderer, mode, or map")
		quit(3)
		return
	seed(712907)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(1920,1080)
	root.scaling_3d_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure()
	GameOptions.values.merge(GameOptions.PRESETS[GameOptions.PRESETS.keys()[1]],true)
	GameOptions.values["scale"] = 1.0
	GameOptions.values["fps"] = 0
	GameOptions.values["vsync"] = false
	game = WarGame.new()
	game.operation_id = operation
	game.offline_operation = true
	game.offline_participants = 29
	game.set_meta("test_mode",true)
	game.set_meta("war_mode",true)
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 120000
	while not game.join_ready and Time.get_ticks_msec() < deadline: await process_frame
	if not game.join_ready:
		check(false,"join_ready timeout")
		quit(3)
		return
	game.request_deploy(0,"soldier","fal",WarRules.launcher_for_team(0),"base")
	deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not is_instance_valid(game.bot_director) or game.bot_director.bots.size() != 28: continue
		var deployed := 0
		for id in game.bot_director.bots:
			var bot: WarPlayer = game.players.get(id) as WarPlayer
			if is_instance_valid(bot) and bot.deployed: deployed += 1
		if deployed == 28 and is_instance_valid(game.local_player) and game.local_player.deployed: break
	if not is_instance_valid(game.bot_director) or game.bot_director.bots.size() != 28:
		check(false,"28 bots not deployed")
		quit(3)
		return
	var actors: Array[WarPlayer] = []
	var teams := [0,0]
	for id in game.bot_director.bots:
		var actor: WarPlayer = game.players.get(id) as WarPlayer
		if is_instance_valid(actor) and actor.deployed and not actor.is_local:
			actors.append(actor)
			teams[int(game.bot_director.bots[id].team)] += 1
	check(actors.size()==28 and teams==[14,14],"28 remote actors, 14/14 teams")
	if not failures.is_empty():quit(3);return
	game.ia2_remote_ragdoll_queue_enabled = mode == "ragdolls" and optimized
	game.ia2_ragdoll_strict_cap = mode == "cap" and optimized
	for actor in actors:
		actor.ia2_respawn_weapon_reuse = mode == "weapons" and optimized
		actor.ia2_weapon_reuse_hits = 0
		actor.ia2_weapon_full_builds = 0
	game.ui_focus.close_all()
	camera = Camera3D.new()
	camera.far = 2200.0
	camera.fov = 70.0
	game.world_root.add_child(camera)
	var origin := Vector2(-85,-20) if operation=="favela" else Vector2(-260,70)
	var point := WarTerrain.point(origin.x,origin.y)
	camera.global_position=point+Vector3(-58,27,78)
	camera.look_at(point+Vector3.UP*1.5)
	camera.make_current()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	DisplayServer.window_move_to_foreground()
	await create_timer(warmup).timeout
	if not DisplayServer.window_is_focused():
		DisplayServer.window_move_to_foreground()
		await create_timer(.75).timeout
	check(Vector2i(root.get_texture().get_size())==Vector2i(1920,1080),"native 1080p window")
	check(is_equal_approx(root.scaling_3d_scale,1.0),"100% internal resolution")
	check(RenderingServer.get_current_rendering_method()=="forward_plus","Forward+ renderer")
	if not failures.is_empty():quit(3);return
	var start := Time.get_ticks_usec()
	var last := start
	var prev_phys := Engine.get_physics_frames()
	var next_event := 3.0
	var max_events := 5 if mode == "weapons" else 1
	var event_finished := false
	var gpu_max := 0.0
	var physics_max := 0.0
	while (Time.get_ticks_usec()-start)*.000001 < duration:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := (now-start)*.000001
		frame_ms.append((now-last)*.001)
		last=now
		frame_ticks.append(Engine.get_physics_frames()-prev_phys)
		prev_phys=Engine.get_physics_frames()
		if not DisplayServer.window_is_focused(): missing_focus += 1
		minimum_bots = mini(minimum_bots,game.bot_director.bots.size())
		gpu_max=maxf(gpu_max,RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		physics_max=maxf(physics_max,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		max_bodies=maxi(max_bodies,get_nodes_in_group("death_ragdolls").size())
		if elapsed >= next_event and events < max_events:
			var tick := Time.get_ticks_usec()
			if mode == "weapons":
				for actor in actors:
					actor._refresh_weapon()
					actor._update_weapon_pose()
			else:
				var deaths := 12 if mode=="cap" else 8
				for i in deaths:
					var actor: WarPlayer = actors[i]
					actor.death_presented = actor.life_id - 1
					game.spawn_ragdoll(actor.global_position,1,actor)
			callbacks.append((Time.get_ticks_usec()-tick)*.001)
			events += 1
			next_event += 2.0
			print("IA2_REAL_EVENT tag=",label," event=",events," callback_ms=",callbacks[-1])
		if mode == "ragdolls" and events > 0 and elapsed > 5.0 and not event_finished:
			event_finished=true
			if optimized: check(game.ia2_remote_ragdoll_created==8 and game.ia2_remote_ragdoll_jobs.is_empty(),"queued 8 remote ragdolls")
	if mode=="cap" and optimized: check(get_nodes_in_group("death_ragdolls").size()<=10,"strict cap after 12 deaths")
	if mode=="weapons":
		for actor in actors:
			reused += actor.ia2_weapon_reuse_hits
			builds += actor.ia2_weapon_full_builds
			check(is_instance_valid(actor.muzzle_marker),"weapon muzzle intact")
		if optimized: check(reused >= 28*events,"weapon reuse occurred for all refreshes")
	var multi := 0
	for tick in frame_ticks:
		if tick>1:multi+=1
	var result := {"label":label,"mode":mode,"optimized":optimized,"map":operation,"bots":minimum_bots,
		"teams":teams,"valid":failures.is_empty() and missing_focus==0 and minimum_bots==28 and events==max_events,
		"failures":failures,"unfocused_frames":missing_focus,"event_callbacks_ms":stats(callbacks),
		"events":events,"frame":stats(frame_ms),"fps":1000.0/stats(frame_ms).mean_ms,
		"frames_multi_tick":multi,"total_frames":frame_ms.size(),"max_ragdolls":max_bodies,
		"remote_ragdoll_created":game.ia2_remote_ragdoll_created,
		"reused_weapons":reused,"full_weapon_builds":builds,"gpu_max_ms":gpu_max,
		"physics_max_ms":physics_max,"renderer":RenderingServer.get_current_rendering_method(),
		"window_size":str(root.get_texture().get_size()),"git_note":"release branch descendant of main ee969af",
		"note":"Offline real WarGame, full bot AI, live renderer, synthetic event bursts; not an ENet client/server test."}
	var folder := ProjectSettings.globalize_path("res://work/ia2-real-28-bots-20261106")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join(label+".json"),FileAccess.WRITE)
	if file == null: check(false,"result file open")
	else:
		file.store_string(JSON.stringify(result,"  "))
		file.close()
	print("IA2_REAL_RESULT "+JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if bool(result.valid) else 2)
