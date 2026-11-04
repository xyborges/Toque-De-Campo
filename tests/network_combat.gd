extends SceneTree

var game: Node3D
var role := "server"
var start := 0.0
var stage_time := 0.0
var stage := "connect"
var failures: Array[String] = []
var saw_damage := false
var saw_death := false
var saw_respawn := false
var max_corpses := 0
var death_audio_index := -1
var shots_sent := 0
var reload_sent := false
var reload_seen := false
var duplicate_sent := false
var movement_tick := 0
var settled_at := 0.0
var shot_times: Array[float] = []
var final_ready := false
var reconnect_started := false
var rejoin_sent := false
var damage_with_menu := false
var remote_aim_verified := false
var remote_motion_verified := false
var observe_pose_started := false
var old_victim_id := 0
var victim_id := 0
var shooter_id := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	call_deferred("run")

func now() -> float:
	return Time.get_ticks_msec() * 0.001

func write_control(value: String) -> void:
	FileAccess.open("res://tests/net-stage.txt",FileAccess.WRITE).store_string(value)

func read_control() -> String:
	if not FileAccess.file_exists("res://tests/net-stage.txt"): return "connect"
	return FileAccess.get_file_as_string("res://tests/net-stage.txt").strip_edges()

func fail(message: String) -> void:
	if not failures.has(message): failures.append(message)

func result() -> void:
	var local: GamePlayer = game.local_player
	var report := {"role":role,"failures":failures,"shots_seen":game.seen_shots.size(),"impacts_seen":game.seen_impacts.size(),"players":game.players.size(),"saw_damage":saw_damage,"saw_death":saw_death,"saw_respawn":saw_respawn,"max_corpses":max_corpses,"reload_seen":reload_seen,"death_audio_index":death_audio_index,"damage_with_menu":damage_with_menu,"remote_aim_verified":remote_aim_verified,"remote_motion_verified":remote_motion_verified,"ammo":local.ammo if local else {},"reserve":local.reserves if local else {}}
	FileAccess.open("res://tests/network-"+role+"-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	game.show_menu()
	game.queue_free()
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	game = load("res://tests/network_fixture.gd").new()
	game.name = "ToqueDeCampo"
	game.set_meta("test_mode",true)
	game.set_meta("role",role)
	root.add_child(game)
	game.nickname_input.text = {"server":"Servidor","shooter":"Atirador","target":"Alvo"}[role]
	game.third_person = false
	if role == "server":
		write_control("connect")
		game.host_game("pvp")
		game.local_player.global_position = Vector3(10,0,0)
	else:
		game.address_input.text = "127.0.0.1"
		game.join_game("pvp")
	start = now()
	while now() - start < 42.0:
		await process_frame
		max_corpses = maxi(max_corpses,get_nodes_in_group("death_ragdolls").size())
		if role == "server": server_step()
		else: client_step()
		if stage == "finished":
			result()
			return
	fail("timeout stage="+stage)
	result()

func server_step() -> void:
	if stage == "connect" and game.players.size() == 3:
		for id in game.players:
			var actor: GamePlayer = game.players[id]
			if actor.name == "Atirador": shooter_id = id
			elif actor.name == "Alvo": victim_id = id
		if shooter_id == 0 or victim_id == 0: return
		for id in [shooter_id,victim_id]:
			var actor: GamePlayer = game.players[id]
			actor.global_position = Vector3(0,0,15 if id == shooter_id else -15)
			actor.hp = 100.0
			actor.limbs = CombatRules.fresh_limbs()
			actor.has_network_state = false
			game.rpc("remote_player_respawn",id,actor.global_position,actor.life_id)
		stage = "fire"
		stage_time = now()
		write_control("fire")
	if stage == "fire":
		var victim: GamePlayer = game.players[victim_id]
		if victim.hp < 100: saw_damage = true
		if victim.hp <= 0:
			saw_death = true
			death_audio_index = victim.death_sound
		if victim.life_id == 2 and victim.hp == 100:
			saw_respawn = true
			var killer: GamePlayer = game.players[shooter_id]
			if killer.kills != 1 or victim.deaths != 1: fail("duplicate kill/death")
			if game.seen_shots.size() != 2: fail("duplicate or missing accepted shots")
			if not saw_damage or not saw_death: fail("no authoritative damage/death")
			stage = "reload"
			stage_time = now()
			write_control("reload")
	if stage == "reload":
		var actor: GamePlayer = game.players[shooter_id]
		if actor.reload_left > 0: reload_seen = true
		if reload_seen and actor.reload_left == 0.0 and actor.ammo.fal == 30:
			if actor.reserves.fal != 178: fail("reserve duplicated during reload")
			stage = "cancel"
			stage_time = now()
			write_control("cancel")
	if stage == "cancel":
		var actor: GamePlayer = game.players[shooter_id]
		if actor.weapon_id == "glock" and actor.reload_weapon.is_empty():
			stage = "observe"
			stage_time = now()
			write_control("observe")
	if stage == "observe" and now() - stage_time > 2.0:
		var actor: GamePlayer = game.players[shooter_id]
		if actor.ammo.fal != 29 or actor.reserves.fal != 178: fail("cancelled reload changed ammunition")
		if not actor.crouched or not actor.iron_sights or actor.pitch < 0.6: fail("aim/crouch not authoritative")
		if max_corpses != 1: fail("ragdoll count must be one")
		write_control("reconnect")
		old_victim_id = victim_id
		stage = "reconnect"
		stage_time = now()
	if stage == "reconnect":
		for id in game.players:
			if id != old_victim_id and game.players[id].name == "Alvo":
				if game.players.has(old_victim_id): fail("stale player after reconnect")
				if game.players.size() != 3: fail("reconnection duplicated avatar")
				FileAccess.open("res://tests/network-expected-ids.json",FileAccess.WRITE).store_string(JSON.stringify({"old":old_victim_id,"new":id}))
				write_control("finish")
				stage = "wait_clients"
				stage_time = now()
	if stage == "wait_clients" and FileAccess.file_exists("res://tests/network-ready-shooter.txt") and FileAccess.file_exists("res://tests/network-ready-target.txt"):
		write_control("shutdown")
		stage = "shutdown"
		stage_time = now()
	if stage == "shutdown" and now() - stage_time > 0.8: stage = "finished"

func client_step() -> void:
	var next_control := read_control()
	if role == "target" and next_control == "reconnect":
		if not reconnect_started:
			reconnect_started = true
			stage_time = now()
			game.ui_focus.open(game.settings_panel)
			game.show_menu()
		elif not rejoin_sent and now() - stage_time > 0.5:
			rejoin_sent = true
			game.join_game("pvp")
		return
	var actor: GamePlayer = game.local_player
	if not is_instance_valid(actor): return
	var control := read_control()
	if control != stage:
		stage = control
		stage_time = now()
		if not game.ui_focus.blocked():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			actor.mouse_captured = true
		if role == "target" and stage == "fire": game.ui_focus.open(game.settings_panel)
		get_root().gui_release_focus()
	if actor.hp < 100.0:
		saw_damage = true
		if game.ui_focus.blocked(): damage_with_menu = true
	if actor.hp <= 0.0:
		saw_death = true
		# Local clients cannot apply their own damage or continue firing after death.
		var before := actor.hp
		actor.take_damage(100,"head",1)
		if actor.hp != before: fail("client became damage authority")
	if actor.life_id == 2 and actor.hp == 100: saw_respawn = true
	for remote in game.players.values():
		if remote.reload_left > 0.0: reload_seen = true
		if remote.hp <= 0.0: death_audio_index = remote.death_sound
	if role == "shooter":
		if stage == "fire" and now()-stage_time > 0.7:
			actor.pitch = atan2((1.32 if shots_sent == 0 else 1.73) - 1.68,30.0)
			actor.yaw = 0
			actor.rotation.y = 0
			actor.camera_pivot.rotation.x = actor.pitch
			actor._update_view()
			if shots_sent == 0 or (shots_sent == 1 and now()-shot_times[0] > 1.1):
				actor.fire()
				shots_sent += 1
				shot_times.append(now())
				if shots_sent == 1:
					game.rpc_id(1,"server_shot_request",actor.shot_sequence,actor.life_id,actor.last_camera_origin,actor.last_view_direction,"fal",0)
		if stage == "reload" and not reload_sent:
			reload_sent = true
			actor.start_reload()
			game.rpc_id(1,"server_reload_request","fal")
		if stage == "cancel" and not duplicate_sent and actor.reload_weapon.is_empty() and int(actor.ammo.fal) == 30:
			duplicate_sent = true
			actor.fire()
			actor.start_reload()
			actor.equip_slot(4)
	if stage == "observe" and role == "shooter":
		actor.pitch = 0.65
		actor.aiming = true
		actor.iron_sights = true
		Input.action_press("crouch")
		if now() - stage_time < 0.7: Input.action_press("move_right")
		else: Input.action_release("move_right")
	if role == "target" and stage == "observe":
		for remote in game.players.values():
			if remote.name != "Atirador": continue
			if remote.global_position.x > 0.4: remote_motion_verified = true
			if remote.crouched and remote.iron_sights and remote.pitch > 0.6:
				var expected: Vector3 = remote.global_basis * (Basis(Vector3.RIGHT,remote.pitch) * Vector3.FORWARD)
				if (-remote.weapon_root.global_basis.z).dot(expected) > 0.99: remote_aim_verified = true
	if stage == "shutdown" and final_ready:
		stage = "finished"
		return
	if stage == "finish":
		if final_ready: return
		Input.action_release("crouch")
		Input.action_release("move_right")
		var expected_ids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/network-expected-ids.json"))
		if not game.players.has(int(expected_ids.new)) or game.players.size() < 3: return
		if game.players.size() != 3 or game.players.has(int(expected_ids.old)): fail("stale or duplicate avatar after peer reconnect")
		if not reload_seen: fail("reload animation not replicated")
		if role == "shooter" and game.seen_shots.size() != 3: fail("shot confirmation count")
		if role == "target" and (not rejoin_sent or game.ui_focus.blocked()): fail("reconnect focus not reset")
		if role == "target" and not damage_with_menu: fail("online menu prevented damage")
		if role == "target" and not (remote_aim_verified and remote_motion_verified): fail("remote moving crouched aiming pose not replicated")
		if max_corpses != 1: fail("client ragdoll duplicated/missing")
		if role == "target" and not (saw_damage and saw_death and saw_respawn): fail("damage death respawn not replicated")
		# A new local-host session starts with zero coins, not the removed
		# 30,000-coin grant. One accepted kill must award exactly 30.
		if role == "shooter" and int(game.profile.coins) != 30: fail("server kill reward not applied once")
		if role == "shooter" and (actor.ammo.fal != 29 or actor.reserves.fal != 178 or actor.weapon_id != "glock"): fail("inventory/equip not reconciled")
		final_ready = true
		FileAccess.open("res://tests/network-ready-" + role + ".txt",FileAccess.WRITE).store_string("ready")
