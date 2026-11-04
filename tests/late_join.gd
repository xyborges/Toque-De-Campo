extends SceneTree
var role: String="server"
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func run() -> void:
	var game=load("res://tests/late_join_fixture.gd").new()
	game.name="ToqueDeCampo"
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.nickname_input.text=role
	if role=="server": game.host_game("pvp")
	else:
		game.address_input.text="127.0.0.1"
		game.join_game("pvp")
	var start:=Time.get_ticks_msec()*.001
	var reset:=false
	var positions: Array[Vector3]=[]
	var remote_life:=0
	var shots:=0
	var fire_at:=0.0
	while Time.get_ticks_msec()*.001-start<9:
		await process_frame
		var elapsed:=Time.get_ticks_msec()*.001-start
		if role=="server" and not reset:
			for actor: GamePlayer in game.players.values():
				if actor.name=="existing":
					game._reset_server_player(actor)
					reset=true
					FileAccess.open("res://work/late-join-ready.txt",FileAccess.WRITE).store_string("respawned")
		if role=="existing" and is_instance_valid(game.local_player) and game.local_player.life_id>=2:
			var actor: GamePlayer=game.local_player
			actor.set_physics_process(false)
			actor.global_position=Vector3(22+sin(elapsed*1.5)*2,0,0)
			if elapsed>fire_at:
				fire_at=elapsed+.22
				actor.fire_cooldown=0
				actor.fire()
		if role=="late":
			for actor: GamePlayer in game.players.values():
				if actor.name=="existing":
					positions.append(actor.global_position)
					remote_life=actor.life_id
		shots=maxi(shots,game.seen_shots.size())
	var displacement:=0.0
	if not positions.is_empty():
		for p in positions: displacement=maxf(displacement,p.distance_to(positions[0]))
	if role=="server" and not reset: failures.append("existing client never respawned")
	if role=="late":
		if remote_life!=2: failures.append("late joiner did not receive life 2")
		if displacement<1: failures.append("late joiner sees a frozen avatar")
		if shots<3: failures.append("shots did not replicate alongside movement")
	var report: Dictionary={"role":role,"failures":failures,"life":remote_life,"movement":displacement,"shots":shots}
	NavalStorage.write_json("res://tests/late-join-"+role+".json",report)
	print(JSON.stringify(report))
	game.show_menu()
	await process_frame
	if not game.players.is_empty() or not game.projectiles.is_empty() or game.match_started or is_instance_valid(game.world_root): failures.append("match state survived exit")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
