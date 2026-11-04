extends SceneTree

var role := "host"
const ROLES := ["host","guest","third"]
var observed_statuses: Dictionary={}
var third_admission_observed:=false
var game: BattleRoyaleGame
var accounts: NavalAccounts
var checks := 0
var failures: Array[String] = []
var started := 0
var phase_started := 0
var router_seen := false
var route_answer := {}
var observed_router := 0
var countdown: Array[Dictionary] = []
var phases: Array[String] = []
var last_countdown := -100.
var http_results: Array[Dictionary] = []
var metrics := {}
var clock := 0.
var finishing := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	started = Time.get_ticks_msec()
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func _process(delta: float) -> bool:
	if finishing or not is_instance_valid(game): return false
	if is_instance_valid(game.queue_router):
		router_seen = true
		var router = game.queue_router
		if int(router.get_instance_id()) != observed_router:
			observed_router = int(router.get_instance_id())
			router.completed.connect(func(answer: Dictionary):
				route_answer = {"ok": bool(answer.get("ok", false)), "port": int(answer.get("port", 0)),
					"protocol": int(answer.get("protocol", 0)), "room_id": str(answer.get("room_id", "")),
					"reservation_present": not str(answer.get("reservation", "")).is_empty(), "error": str(answer.get("error", ""))})
	if game.phase not in phases: phases.append(game.phase)
	if game.phase == "waiting" and not game.snapshot.is_empty():
		var remaining := float(game.snapshot.get("countdown", 0.))
		for entry: Dictionary in game.snapshot.get("roster",[]):
			if not bool(entry.get("bot",false)):observed_statuses[str(entry.get("status",""))]=true
		if remaining > 0. and absf(remaining - last_countdown) > .45:
			last_countdown = remaining
			countdown.append({"at_ms": Time.get_ticks_msec() - started, "remaining": remaining})
	clock += delta
	if clock > .5:
		clock = 0.
		write_stage("active" if game.phase == "active" else "joining")
	return false

func write_stage(value: String) -> void:
	if not is_instance_valid(game): return
	NavalStorage.write_json("res://work/ubuntu-br1102-" + role + ".stage.json", {
		"stage": value, "role": role, "port": game.assigned_port, "room_id": game.room_id,
		"phase": game.phase, "queue_status": game.queue_status, "route_pending": game.route_pending,
		"local_id": game.local_player.peer_id if is_instance_valid(game.local_player) else 0,
		"humans":human_count(),"countdown":game.snapshot.get("countdown",0.),"utc":Time.get_unix_time_from_system()})

func role_stage(peer_role: String) -> Dictionary:
	return NavalStorage.read_json("res://work/ubuntu-br1102-"+peer_role+".stage.json")
func human_count() -> int:
	var count:=0
	if not is_instance_valid(game):return count
	for entry: Dictionary in game.snapshot.get("roster",[]):
		if not bool(entry.get("bot",false)) and str(entry.get("status","")) not in ["Saiu","Erro"]:count+=1
	return count
func stages_match() -> bool:
	for other: String in ROLES:
		var stage:=role_stage(other)
		if str(stage.get("room_id",""))!=game.room_id or int(stage.get("port",0))!=game.assigned_port:return false
	return true

func wait_for(predicate: Callable, label: String, seconds := 140.) -> bool:
	var deadline := mini(started + 200000, Time.get_ticks_msec() + int(seconds * 1000.))
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if label == "broker route and room admission" and not route_answer.is_empty() and not bool(route_answer.get("ok", false)):
			failures.append("broker rejected route: " + str(route_answer.get("error", game.queue_status)))
			return false
		await process_frame
	failures.append(label)
	var detail: Dictionary={}
	if is_instance_valid(game):detail={"phase":game.phase,"queue_status":game.queue_status,"online":game.online,"players":game.players.size(),"assigned_port":game.assigned_port,"snapshot":not game.snapshot.is_empty()}
	print("TIMEOUT ", label, " ", JSON.stringify(detail))
	return false

func run() -> void:
	# Startup/import work belongs to the first frame delta; allow it to pass
	# before creating an HTTPRequest with an eight-second SceneTree timer.
	await process_frame
	await process_frame
	check(role in ROLES and not NavalAccounts.testing(), "real account mode; no account fixture switch")
	var credentials := NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	if role=="third":
		var third:=NavalStorage.read_json("res://work/ubuntu-war-passenger-credentials.json")
		credentials[role]={"username":str(third.get("username","")),"password":str(third.get("password",""))};third.clear()
	if not credentials.get(role) is Dictionary:
		check(false, "existing QA credential entry available"); await finish(); return
	accounts = NavalAccounts.new()
	root.add_child(accounts)
	accounts.connection_state.connect(func(result: int, status: int): http_results.append({"transport_result": result, "status": status}))
	var auth: Dictionary = await accounts.sign_in("login", str(credentials[role].username), str(credentials[role].password))
	check(bool(auth.get("ok", false)) and accounts.validated_session, "real account login over pinned HTTPS")
	credentials.clear()
	if not failures.is_empty(): await finish(); return
	if role=="third":
		if not await wait_for(func():
			var host:=role_stage("host");var guest:=role_stage("guest")
			return host.get("phase","")=="waiting" and guest.get("phase","")=="waiting" and int(host.get("humans",0))>=2 and str(host.get("room_id",""))==str(guest.get("room_id","")),"first two clients paired before third starts",100.):
			await finish();return
		metrics.third_requested_at=Time.get_unix_time_from_system()
		metrics.existing_countdown=role_stage("host").get("countdown",0.)
	game = BattleRoyaleGame.new()
	game.accounts_service = accounts
	game.offline_operation = false
	root.add_child(game)
	check(not game.has_meta("test_mode") and not game.has_meta("br_direct_connect") and game._central_pvp(), "production BR client; broker and central authority required")
	if not await wait_for(func(): return is_instance_valid(game.local_player) and game.snapshot.get("phase", "") == "waiting", "broker route and room admission"):
		await finish(); return
	check(router_seen and bool(route_answer.get("ok", false)) and int(route_answer.get("protocol", 0)) == BattleRoyaleGame.BR_PROTOCOL, "production DTLS broker3016 returned authenticated route")
	check(game.hud_layer.visible and game.br_hud.is_visible_in_tree(), "online waiting HUD and parent layer visible")
	check(game.assigned_port in [3020, 3021] and game.room_id.length() == 32 and not game.room_reservation.is_empty(), "assigned bounded child room and admission reservation")
	if not await wait_for(func():return human_count()==3 and stages_match(),"three real clients in same waiting roster",55.):
		await finish();return
	check(stages_match(),"third client joins the first two clients' existing room")
	var ready_humans:=0
	for entry: Dictionary in game.snapshot.get("roster",[]):
		if not bool(entry.get("bot",false)) and str(entry.get("status",""))=="Pronto":ready_humans+=1
	check(await wait_for(func():
		var ready:=0
		for entry: Dictionary in game.snapshot.get("roster",[]):
			if not bool(entry.get("bot",false)) and str(entry.get("status",""))=="Pronto":ready+=1
		return ready==3,"all three humans acknowledged preparation before active",15.),"server exposes three ready players")
	var roster: Array = game.snapshot.get("roster", [])
	var humans := 0
	var bots := 0
	var local_entry := false
	for entry: Dictionary in roster:
		if bool(entry.get("bot", false)): bots += 1
		else: humans += 1
		if int(entry.get("id", -1)) == game.local_player.peer_id and bool(entry.get("local", false)): local_entry = true
	check(roster.size() == BattleRoyaleGame.ONLINE_BOTS+3 and humans == 3 and bots == BattleRoyaleGame.ONLINE_BOTS and local_entry, "server roster includes28 authoritative bots plus3 humans and identifies local player")
	metrics.waiting = {"humans": humans, "bots": bots, "roster_size": roster.size(), "observed_countdown": game.snapshot.get("countdown", 0.)}
	# br_spawn arrives before the next complete authority snapshot; never read
	# the retained waiting snapshot as the new active match's state.
	if not await wait_for(func(): return game.phase == "active" and game.snapshot.get("phase", "") == "active" and int(game.zone_parameters.get("phase", 0)) >= 1 and not game.own_inventory.is_empty(), "real30second countdown reaches active with private inventory and zone", 45.):
		await finish(); return
	check(game.br_generation > 0 and game.local_player.deployed and game.local_player.hp > 0., "authority activates a new life and generation")
	check(game.own_inventory.has("weapons") and game.own_inventory.has("ammo") and game.own_inventory.has("protection") and game.own_inventory.has("backpack"), "private inventory includes weapon/ammo/protection/backpack state")
	check(game.zone_parameters.has("server_time") and game.zone_parameters.has("radius") and game.zone_parameters.has("target_radius") and float(game.zone_parameters.radius) > 0., "server replicates zone parameters")
	check(int(game.snapshot.get("total", 0)) == BattleRoyaleGame.ONLINE_BOTS+3 and int(game.snapshot.get("alive", 0)) > 0, "active round includes31 participants")
	check(countdown.size() >= (5 if role=="third" else 10) and float(countdown[0].remaining) > (4. if role=="third" else 20.) and float(countdown[0].remaining) <= 30.5 and float(countdown[-1].remaining) < 2., "observed fixed30second pairing countdown")
	var earliest := INF
	var latest := -INF
	for sample: Dictionary in countdown:
		var deadline := float(sample.at_ms) * .001 + float(sample.remaining)
		earliest = minf(earliest, deadline); latest = maxf(latest, deadline)
	check(latest - earliest < 2., "later player admissions never restart pairing countdown")
	var peer := game.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	metrics.active = {"generation": game.br_generation, "players": game.players.size(), "alive": game.snapshot.get("alive", 0),
		"local_id": game.local_player.peer_id, "local_hp": game.local_player.hp, "inventory_keys": game.own_inventory.keys(),
		"zone_phase": game.zone_parameters.get("phase", 0), "zone_radius": game.zone_parameters.get("radius", 0),
		"countdown_deadline_spread_seconds": latest - earliest, "room_id": game.room_id, "port": game.assigned_port,
		"rtt_ms": GameNetworkPeers.connected(peer,1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) if GameNetworkPeers.connected(peer,1) else -1}
	clock = -1000.
	write_stage("active_ready")
	await wait_for(func():return ROLES.all(func(other: String):return str(role_stage(other).get("stage","")) in ["active_ready","closed"]),"all three clients observe active state",12.)
	if role=="host":await wait_for(func():return role_stage("guest").get("stage","")=="closed" and role_stage("third").get("stage","")=="closed","other clients leave before final human",18.)
	await finish()

func finish() -> void:
	finishing = true
	if is_instance_valid(game):
		metrics.observed_sync_statuses=observed_statuses.keys()
		metrics.route_room=game.room_id
		metrics.local_peer=game.local_player.peer_id if is_instance_valid(game.local_player) else 0
		var voice := game.voice
		game.leave_match()
		check(game.closing and is_instance_valid(voice) and voice.closed and not voice.is_transmitting(), "leaving closes voice relay and transmission")
		check(voice.roster.is_empty() and voice.recipient_settings.is_empty() and voice.guards.is_empty() and voice.talking.is_empty(), "voice peer and pending state cleared")
		check(game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "game transport detached during graceful disconnect")
		await create_timer(2.5).timeout
		var orphan_router := false
		for child in root.get_children():
			if child is BRMatchRouter: orphan_router = true
		check(not orphan_router, "no root matchmaking router survives leave")
		write_stage("closed")
		game.queue_free()
		await process_frame
	if is_instance_valid(accounts):
		await accounts.logout()
		accounts.queue_free()
		await process_frame
	metrics.diagnostic_zip=GameDiagnostics.export_report()
	check(not str(metrics.diagnostic_zip).is_empty() and FileAccess.file_exists(str(metrics.diagnostic_zip)),"client exports persistent diagnostic ZIP")
	var report := {"ok": failures.is_empty(), "role": role, "checks": checks, "failures": failures, "metrics": metrics,
		"route": route_answer, "http_results": http_results, "countdown": countdown, "phases": phases,
		"elapsed_seconds": (Time.get_ticks_msec() - started) * .001,
		"scope": "Three actual independent headless production BR clients; the third starts only after the first two are paired, real pinnedHTTPS accounts, production DTLS broker and child server, live30second queue, three-client ready barrier and authority snapshots; per-client diagnostic ZIP export and ordered leave; broker/room cancellation verified by runner; no test metadata/direct routing, no microphone/audio decoding, firing or loot claim"}
	NavalStorage.write_json("res://work/ubuntu-br1102-" + role + ".json", report)
	print("UBUNTU_BR1102 ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
