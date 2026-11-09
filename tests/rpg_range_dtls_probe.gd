extends SceneTree
# Local DTLS integration of the RPG payload (single Godot process).
# Does NOT substitute the native two-process WarGame multiplayer QA.

var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func run() -> void:
	Engine.max_fps = 120
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var status := server.create_server(39612, 4)
	if status == OK:
		status = GameSecureTransport.server(server)
	check(status == OK, "DTLS server initialized with QA certificate")
	var client_status := client.create_client("127.0.0.1", 39612)
	if client_status == OK:
		client_status = GameSecureTransport.client(client, "127.0.0.1")
	check(client_status == OK, "DTLS client initialized with trusted QA CA")
	if status == OK and client_status == OK:
		for i in 400:
			server.poll()
			client.poll()
			if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				break
			await process_frame
		check(client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "encrypted loopback ENet handshake")
		if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			var payload := {"weapon":"rpg", "speed":WarRpgBallistics.SPEED, "gravity":WarRpgBallistics.GRAVITY, "drag":WarRpgBallistics.BASE_DRAG, "range":float(WarRules.SPECIAL.rpg.range)}
			client.set_target_peer(1)
			client.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
			client.put_packet(JSON.stringify(payload).to_utf8_buffer())
			for i in 400:
				server.poll()
				client.poll()
				if server.get_available_packet_count() > 0:
					break
				await process_frame
			check(server.get_available_packet_count() > 0, "encrypted RPG packet received by server")
			if server.get_available_packet_count() > 0:
				var value = JSON.parse_string(server.get_packet().get_string_from_utf8())
				check(value is Dictionary and str(value.get("weapon", "")) == "rpg", "RPG weapon identity preserved")
				check(absf(float(value.get("speed", 0.0)) - WarRpgBallistics.SPEED) < .001, "RPG 160 m/s speed preserved")
				check(absf(float(value.get("gravity", 0.0)) - WarRpgBallistics.GRAVITY) < .001, "RPG gravity preserved")
				check(absf(float(value.get("range", 0.0)) - 650.0) < .001, "RPG maximum range preserved")
	client.close()
	server.close()
	print("RPG_DTLS_PAYLOAD ", passed, " PASS / ", failures.size(), " FAIL")
	quit(0 if failures.is_empty() else 1)
