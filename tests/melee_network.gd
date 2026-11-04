extends SceneTree
var game: Node3D
var role := "server"
var failures: Array[String] = []
var saw_animation := false
var saw_damage := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--client": role = "client"
	run.call_deferred()

func run() -> void:
	game = load("res://tests/melee_network_fixture.gd").new()
	game.set_meta("test_mode",true)
	game.name = "ToqueDeCampo"
	root.add_child(game)
	game.nickname_input.text = role
	if role == "server": game.host_game("pvp")
	else:
		game.address_input.text = "127.0.0.1"
		game.join_game("pvp")
	var start := Time.get_ticks_msec()
	var fired := false
	var sent_at := 0
	while Time.get_ticks_msec()-start < 13000:
		await process_frame
		if role == "server" and game.players.size() == 2:
			var actor: GamePlayer = game.local_player
			if not fired:
				actor.weapon_id = "broom"
				actor._refresh_weapon()
				game.request_equip(actor,"broom")
				await create_timer(0.4).timeout
				actor.shot_sequence += 1
				game._server_accept_shot(1,actor.shot_sequence,actor.life_id,actor.camera.global_position,Vector3.FORWARD,"broom")
				fired = true
				sent_at = Time.get_ticks_msec()
			for id in game.players:
				if id != 1 and game.players[id].hp < 100.0: saw_damage = true
			if fired and Time.get_ticks_msec()-sent_at > 2500:
				if not saw_damage: failures.append("no authoritative melee damage")
				break
		elif role == "client" and is_instance_valid(game.local_player):
			var host: GamePlayer = game.players.get(1)
			if is_instance_valid(host) and is_instance_valid(host.melee_rig) and host.melee_rig.running: saw_animation = true
			if game.local_player.hp < 100.0: saw_damage = true
			if saw_damage and saw_animation and game.seen_impacts.size() > 0: break
	if not saw_damage: failures.append("no replicated melee contact")
	if role == "client" and not saw_animation: failures.append("no remote world animation")
	var report := {"role":role,"failures":failures,"saw_damage":saw_damage,"saw_animation":saw_animation,"impacts":game.seen_impacts.size()}
	FileAccess.open("res://tests/melee-network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	game.show_menu()
	game.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)
