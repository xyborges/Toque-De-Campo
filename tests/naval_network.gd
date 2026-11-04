extends SceneTree
var mode: NavalMode
var role := "server"
var stage := "connect"
var phase_started := 0.0
var failures: Array[String] = []
var saw_damage := false
var saw_destroyed := false
var saw_respawn := false
var saw_remote_shot := false
var saw_owner_transfer := false
var saw_late := false
var sent: Dictionary = {}
var a_id := 0
var b_id := 0
var old_b_id := 0
var shot_count := 0
var start := 0.0
var fire_started := 0.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	run.call_deferred()
func now() -> float: return Time.get_ticks_msec()*0.001
func write_stage(value: String, data: Dictionary = {}) -> void:
	data.stage = value
	NavalStorage.write_json(ProjectSettings.globalize_path("res://work/naval-net-stage.json"),data)
func read_stage() -> Dictionary:
	return NavalStorage.read_json(ProjectSettings.globalize_path("res://work/naval-net-stage.json"))
func fail(message: String) -> void:
	if message not in failures: failures.append(message)
func run() -> void:
	mode = NavalMode.new()
	mode.dedicated = role == "server"
	mode.nickname = role
	mode.set_meta("test_controls",true)
	root.add_child(mode)
	mode.network.event_received.connect(func(kind: String,payload: Dictionary):
		if kind == "shot" and int(payload.owner) != mode.network.connection.get_unique_id(): saw_remote_shot = true
		if kind == "destroyed": saw_destroyed = true
		if kind == "respawn": saw_respawn = true
	)
	if role == "server": write_stage("connect")
	else:
		mode.address_field.text = "127.0.0.1:"+str(mode.network.port)
		mode._connect()
	start = now()
	while now()-start < 45.0:
		await process_frame
		if role == "server": _server_step()
		else: _client_step()
		if stage == "finished":
			finish()
			return
	fail("timeout stage="+stage)
	finish()

func _server_step() -> void:
	var net := mode.network
	if stage == "connect" and net.rooms.size() == 1:
		var data: Dictionary = net.rooms.values()[0]
		write_stage("join",{"room":data.id})
		stage = "join"
	if stage == "join":
		var data: Dictionary = net.rooms.values()[0]
		if data.members.size() == 2:
			if data.simulation!=null: fail("match spawned before readiness")
			for peer in data.members:
				if net.users[peer].name == "a": a_id = peer
				if net.users[peer].name == "b": b_id = peer
			write_stage("start",{"room":data.id})
			stage = "start"
	if stage == "start":
		var data: Dictionary = net.rooms.values()[0]
		if data.state == "IN_PROGRESS":
			var battle: NavalMatch = data.simulation
			var a: NavalShip = battle.ships[a_id]
			var b: NavalShip = battle.ships[b_id]
			a.global_position = Vector3(0,0,35)
			a.heading = 0.0
			a.rotation = Vector3.ZERO
			b.global_position = Vector3(0,0,-35)
			b.heading = PI
			b.rotation = Vector3(0,PI,0)
			phase_started = now()
			write_stage("fire",{"room":data.id,"match":data.match,"target":b_id})
			stage = "fire"
	if stage == "fire":
		var data: Dictionary = net.rooms.values()[0]
		var battle: NavalMatch = data.simulation
		var b: NavalShip = battle.ships[b_id]
		if b.hp < 100.0: saw_damage = true
		if b.dead: saw_destroyed = true
		if b.life == 2:
			saw_respawn = true
			var a: NavalShip = battle.ships[a_id]
			shot_count = 600-int(a.ammo.lightMG)
			if not saw_damage or not saw_destroyed: fail("no physical damage/destruction")
			if int(data.stats[a.identity].kills) != 1 or int(data.stats[b.identity].deaths) != 1: fail("duplicate score")
			if b.hp != 100.0 or int(b.ammo.lightMG) != 600: fail("respawn did not restore health/ammo")
			if a.global_position.distance_to(b.global_position)<150: fail("unsafe respawn spacing")
			write_stage("owner_leave",{"room":data.id})
			stage = "owner_leave"
	if stage == "owner_leave":
		var data: Dictionary = net.rooms.values()[0]
		if data.members.size() == 1 and data.owner == b_id:
			saw_owner_transfer = true
			if data.state != "IN_PROGRESS" or data.simulation == null: fail("owner exit stopped match")
			write_stage("late_join",{"room":data.id})
			stage = "late_join"
	if stage == "late_join":
		var data: Dictionary = net.rooms.values()[0]
		if data.members.size() == 2 and data.simulation.ships.size()==2:
			saw_late = true
			if data.simulation.ships.size() != 2: fail("late join duplicated ships")
			old_b_id = b_id
			write_stage("reconnect",{"room":data.id})
			stage = "reconnect"
	if stage == "reconnect":
		var data: Dictionary = net.rooms.values()[0]
		for peer in data.members:
			if peer != old_b_id and net.users[peer].name == "b" and bool(net.users[peer].get("ready",false)):
				b_id = peer
				if data.simulation.ships.has(old_b_id): fail("ghost after reconnection")
				if data.simulation.ships.size() != 2: fail("reconnect duplicated ships")
				write_stage("leave_all",{"room":data.id})
				stage = "leave_all"
	if stage == "leave_all" and net.rooms.is_empty():
		write_stage("done")
		stage = "drain"
		phase_started = now()
	if stage == "drain" and now()-phase_started>0.6: stage = "finished"

func _client_step() -> void:
	var net := mode.network
	var state := read_stage()
	var command := str(state.get("stage","connect"))
	if role == "a" and command == "connect" and net.authenticated and not sent.has("create"):
		sent.create = true
		net.request("create",{"name":"Validação naval","limit":6,"late":true})
	if role == "b" and command == "join" and net.authenticated and not sent.has("join"):
		sent.join = true
		net.request("join",{"id":state.room})
	if command=="start" and not sent.has("ready") and net.room.get("state","")=="WAITING":
		sent.ready=true;net.request("ready")
	var all_ready:=not net.room.is_empty()
	for member: Dictionary in net.room.get("members",[]):
		if not bool(member.get("ready",false)): all_ready=false
	if role == "a" and command == "start" and all_ready and not sent.has("start"):
		sent.start = true
		net.request("start")
	if command == "fire" and not net.room.is_empty() and net.room.state == "IN_PROGRESS":
		if fire_started == 0.0: fire_started = now()
		if "--visual" in OS.get_cmdline_user_args() and mode.camera != null:
			mode.camera.orbit_yaw = 0.0 if role == "a" else PI
			if now()-fire_started>1.0 and not sent.has("screenshot"):
				sent.screenshot = true
				capture.call_deferred()
		if role == "a":
			var target: NavalShip = mode.ships.get(int(state.target))
			if is_instance_valid(target):
				net.send_control(0,0,target.global_position+Vector3.UP*0.9,"lightMG",not target.dead and target.life == 1)
		else:
			var own := mode._own_ship()
			if is_instance_valid(own) and own.hp < 100.0: saw_damage = true
			if is_instance_valid(own) and own.dead and mode.clock>=own.respawn_at+.1 and not sent.has("respawn-ready"):
				sent["respawn-ready"]=true;net.request("ready")
	if role == "a" and command == "owner_leave" and not sent.has("owner_leave"):
		sent.owner_leave = true
		net.request("leave")
	if role == "a" and command == "late_join" and not sent.has("late_join"):
		sent.late_join = true
		net.request("join",{"id":state.room})
	if role == "b" and command == "reconnect":
		if not sent.has("disconnect"):
			sent.disconnect = true
			phase_started = now()
			net.close_connection()
		elif now()-phase_started>0.5 and not sent.has("reconnect"):
			sent.reconnect = true
			mode._connect()
		elif net.authenticated and net.room.is_empty() and not sent.has("rejoin"):
			sent.rejoin = true
			net.request("join",{"id":state.room})
	if command in ["late_join","reconnect"] and net.room.get("state","")=="IN_PROGRESS" and not mode._deployment_confirmed() and not sent.has("deploy-"+command):
		sent["deploy-"+command]=true;net.request("ready")
	if command == "leave_all" and not sent.has("leave_all"):
		sent.leave_all = true
		net.request("leave")
	if command == "done":
		if role == "b" and not saw_damage: fail("no replicated damage")
		if not saw_destroyed or not saw_respawn: fail("missing destruction/respawn event")
		if role == "b" and not saw_remote_shot: fail("no remote shot")
		stage = "finished"

func finish() -> void:
	var report := {"role":role,"failures":failures,"damage":saw_damage,"destruction":saw_destroyed,"respawn":saw_respawn,"owner_transfer":saw_owner_transfer,"late_join":saw_late,"remote_shot":saw_remote_shot,"shots":shot_count}
	FileAccess.open("res://tests/naval-network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	mode.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)

func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/naval-online-"+role+".png")
