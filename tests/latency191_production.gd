extends SceneTree
var role := "host"
var credentials_path := ""
var report_path := ""
var measuring := false
var game
var frames: Array[float] = []
var rtt: Array[float] = []
var variation: Array[float] = []
var reliable_loss: Array[float] = []
var loss_epochs: Array[float] = []
var process_times: Array[float] = []
var next_peer_usec := 0
var last_frame_usec := 0
var failures: Array[String] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--latency-credentials="): credentials_path=arg.trim_prefix("--latency-credentials=")
		if arg.begins_with("--latency-report="): report_path=arg.trim_prefix("--latency-report=")
	run.call_deferred()

func _process(_delta: float) -> bool:
	if not measuring: return false
	var now := Time.get_ticks_usec()
	if last_frame_usec>0: frames.append((now-last_frame_usec)*.001)
	last_frame_usec=now
	process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
	if now>=next_peer_usec:
		next_peer_usec=now+500000
		var transport := game.multiplayer.multiplayer_peer as ENetMultiplayerPeer
		var peer := transport.get_peer(1) if transport else null
		if peer:
			var value := peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
			if value>0: rtt.append(value)
			variation.append(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE))
			reliable_loss.append(peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)/float(ENetPacketPeer.PACKET_LOSS_SCALE))
			loss_epochs.append(peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS_EPOCH))
	return false

func stat(values: Array) -> Dictionary:
	if values.is_empty(): return {"n":0}
	var sorted := values.duplicate();sorted.sort()
	var total := 0.
	for value in sorted: total+=float(value)
	return {"n":sorted.size(),"mean":total/sorted.size(),"p50":sorted[int(sorted.size()*.5)],"p95":sorted[maxi(0,ceili(sorted.size()*.95)-1)],"max":sorted[-1]}

func intervals(arrivals: Array) -> Dictionary:
	var gaps: Array[float] = []
	for i in range(1,arrivals.size()): gaps.append(float(arrivals[i])-float(arrivals[i-1]))
	return stat(gaps)

func run() -> void:
	var credentials := NavalStorage.read_json(credentials_path)
	var accounts := NavalAccounts.new();root.add_child(accounts)
	var auth: Dictionary = await accounts.sign_in("login",str(credentials[role].username),str(credentials[role].password))
	credentials.clear()
	if not auth.get("ok",false) or not accounts.validated_session: failures.append("QA account login failed")
	if failures.is_empty():
		game=load("res://tests/latency191_production_client.gd").new()
		game.accounts_service=accounts;root.add_child(game)
		var until := Time.get_ticks_msec()+60000
		while Time.get_ticks_msec()<until and not (game.join_ready and is_instance_valid(game.local_player)):
			await process_frame
		if not game.join_ready: failures.append("DTLS lobby join timed out")
		else:
			# Remain in staging: no deployment, movement, attacks, vehicle commands,
			# damage, forced deaths, or interaction with other players.
			await create_timer(5.).timeout
			game.tracking=true;measuring=true;last_frame_usec=0
			print("LATENCY191_READY "+role)
			await create_timer(25.).timeout
			measuring=false;game.tracking=false
	var pose_rows: Array = []
	if is_instance_valid(game):
		for id in game.pose_arrivals: pose_rows.append({"id":id,"interval_ms":intervals(game.pose_arrivals[id])})
	var result := {"role":role,"source_protocol":WarRules.PROTOCOL,"passive_lobby":true,"dtls":true,"headless":true,"measurement_seconds":25,"failures":failures,"enet_rtt_ms":stat(rtt),"enet_rtt_variation_ms":stat(variation),"enet_reliable_loss_ratio":stat(reliable_loss),"enet_loss_epoch_ms":stat(loss_epochs),"frame_interval_ms":stat(frames),"engine_process_ms":stat(process_times),"war_snapshot_interval_ms":intervals(game.snapshot_arrivals) if is_instance_valid(game) else {},"pose_streams":pose_rows,"players_seen":game.players.size() if is_instance_valid(game) else 0,"note":"Two QA clients remain in staging. This is not a combat or twelve-player load benchmark. RTT includes ENet polling; reliable loss is distinct from unreliable snapshot loss."}
	NavalStorage.write_json(report_path,result);print(JSON.stringify(result))
	if is_instance_valid(game): game.show_menu();game.queue_free()
	await create_timer(.4).timeout
	accounts.queue_free();quit(0 if failures.is_empty() else 1)
