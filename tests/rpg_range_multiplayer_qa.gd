extends SceneTree

# Two real Godot processes: a client sends the native "gadget" command;
# the server executes WarVehicles.use_gadget and broadcasts projectile_event.
# No manual projectile_event injection and no bypass of server checks.
const OUT := "res://work/rpg-range-qa/"
var game: WarGame
var role := "server"
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	run.call_deferred()

func verify(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", role, " ", label)
	else:
		failures.append(label)
		print("FAIL ", role, " ", label)

func wait_for(predicate: Callable, label: String, seconds := 14.0) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		if predicate.call(): return true
		await process_frame
	failures.append("timeout: " + label)
	print("FAIL ", role, " timeout ", label)
	return false

func flight_samples(shot: Dictionary) -> Dictionary:
	var result := {}
	for tick in 1200:
		if not bool(shot.active) or float(shot.distance) >= 605.0: break
		game.war_fx._step(shot, 1.0 / 120.0)
		for metres in [100,200,400,600]:
			if not result.has(str(metres)) and float(shot.distance) >= metres:
				result[str(metres)] = Vector3(shot.velocity).length()
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://tests/rpg_range_multiplayer_fixture.gd").new() as WarGame
	root.add_child(game)
	await process_frame
	game.vehicle_system.set_process(false)
	game.war_fx.set_physics_process(false)
	var peer := ENetMultiplayerPeer.new()
	var status := peer.create_server(39612, 4) if role == "server" else peer.create_client("127.0.0.1", 39612)
	if status == OK:
		status = GameSecureTransport.server(peer) if role == "server" else GameSecureTransport.client(peer, "127.0.0.1")
	verify(status == OK, "real Godot process opens encrypted ENet/DTLS")
	if status == OK:
		game.multiplayer.multiplayer_peer = peer
		game.online = true
		game.offline_operation = false
		if role == "server": await server_flow()
		else: await client_flow()
	var report := {"role":role,"checks":passed,"failures":failures}
	var file := FileAccess.open(OUT + "gameplay-" + role + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report))
		file.close()
	print("RPG_GAMEPLAY_MULTIPLAYER ", JSON.stringify(report))
	game.vehicle_system.set_process(false)
	game.war_fx.set_physics_process(false)
	game.online = false
	if status == OK: peer.close()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func server_flow() -> void:
	if not await wait_for(func(): return game.multiplayer.get_peers().size() == 1, "a remote player connects", 18.0): return
	var id: int = int(game.multiplayer.get_peers()[0])
	var actor := game.call("prepare_network_shooter", id) as WarPlayer
	verify(is_instance_valid(actor) and actor.gadget_equipped and actor.weapon_id == "rpg", "server equips an authorized antitank actor")
	verify(game._eligible(id), "gameplay server considers this living actor eligible")
	var counter: int = game.war_fx.counter
	game.rpc_id(id,"qa_fire")
	if not await wait_for(func(): return game.war_fx.counter > counter, "server accepts genuine client command gadget", 15.0): return
	verify(game.war_fx.counter == counter + 1, "exactly one rocket is spawned on the authority")
	verify(int(game.members[id].charges) == 3, "server consumes exactly one RPG charge")
	var shot: Dictionary = {}
	for slot in game.war_fx.active_slots:
		var candidate: Dictionary = game.war_fx.rounds[slot]
		if str(candidate.weapon) == "rpg" and str(candidate.shot_id).begins_with("gadget:"):
			shot = candidate
			break
	verify(not shot.is_empty() and bool(shot.get("server",false)), "WarProjectiles holds authoritative RPG")
	if shot.is_empty(): return
	verify(absf(Vector3(shot.velocity).length()-WarRpgBallistics.SPEED) < .01, "native command launches at 160 m/s")
	verify(is_equal_approx(float(shot.gravity), WarRpgBallistics.GRAVITY) and is_equal_approx(float(shot.drag), .016), "authority uses calibrated gravity and drag")
	verify(is_equal_approx(float(shot.range), 650.0), "authority enforces RPG 650 m range")
	if not await wait_for(func(): return not Dictionary(game.get("client_receipt")).is_empty(), "client confirms projectile_event", 12.0): return
	var remote: Dictionary = game.get("client_receipt")
	verify(bool(remote.get("received",false)) and not bool(remote.get("authority",true)), "client creates nonauthoritative RPG from actual RPC")
	verify(absf(float(remote.get("launch_speed",0.0))-WarRpgBallistics.SPEED) < .01, "client receives same 160 m/s speed")
	verify(is_equal_approx(float(remote.get("gravity",0.0)),WarRpgBallistics.GRAVITY) and is_equal_approx(float(remote.get("range",0.0)),650.0), "client receives same gravity and max range")
	var server_speeds := flight_samples(shot)
	var client_speeds: Dictionary = remote.get("speed_marks",{})
	for metres in [100,200,400,600]:
		var mark := str(metres)
		verify(server_speeds.has(mark) and client_speeds.has(mark) and absf(float(server_speeds.get(mark,0.0))-float(client_speeds.get(mark,99.0))) < 1.5, "%d m client and server flight speeds stay synchronized" % metres)
	verify(float(server_speeds.get("200",999)) < float(server_speeds.get("100",0)), "server RPG drag increases after 100 m")
	game.rpc_id(id,"qa_done")
	await create_timer(.35).timeout

func client_flow() -> void:
	if not await wait_for(func(): return game.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "genuine remote DTLS connection",18.0): return
	if not await wait_for(func(): return bool(game.get("fire_requested")), "server requests native client gadget fire",12.0): return
	verify(bool(game.get("fire_requested")), "WarVehicles.request_command sent gadget RPC")
	if not await wait_for(func(): return game.vehicle_system.shot_events.keys().any(func(key): return str(key).begins_with("gadget:")), "client receives projectile_event RPC",12.0): return
	var shot: Dictionary = {}
	for slot in game.war_fx.active_slots:
		var candidate: Dictionary = game.war_fx.rounds[slot]
		if str(candidate.weapon) == "rpg":
			shot = candidate
			break
	verify(not shot.is_empty() and not bool(shot.get("server",true)), "RPC creates RPG in the client visual projectile pool")
	if shot.is_empty(): return
	var data := {"received":true,"authority":bool(shot.server),"launch_speed":Vector3(shot.velocity).length(),"gravity":float(shot.gravity),"range":float(shot.range),"speed_marks":flight_samples(shot)}
	game.rpc_id(1,"qa_receipt",data)
	verify(data.speed_marks.size() == 4, "client evaluates 100/200/400/600 m with real integrator")
	await wait_for(func(): return bool(game.get("test_done")), "server confirms parity at four distances",16.0)
