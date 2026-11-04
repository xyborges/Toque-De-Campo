extends SceneTree
var mode: NavalMode
var role := 0
var start := 0.0
var failures: Array[String] = []
var sent: Dictionary = {}
var latest_tick := -1
var updates := 0
var max_ships := 0
var weapons: Dictionary = {}
var initial: Dictionary = {}
var moving: Dictionary = {}
var combat_started := 0.0
var total_shots := 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = int(arg.trim_prefix("--role="))
	run.call_deferred()
func now() -> float: return Time.get_ticks_msec()*0.001
func run() -> void:
	mode = NavalMode.new()
	mode.dedicated = role == 0
	mode.nickname = "Frota "+str(role)
	mode.set_meta("test_controls",true)
	root.add_child(mode)
	mode.network.event_received.connect(func(kind: String,payload: Dictionary):
		if kind == "snapshot":
			updates += 1
			max_ships = maxi(max_ships,payload.ships.size())
			if int(payload.tick)<latest_tick: failures.append("snapshot regression")
			latest_tick = int(payload.tick)
		elif kind == "shot": weapons[payload.weapon] = true
	)
	if role != 0:
		mode.address_field.text = "127.0.0.1:"+str(mode.network.port)
		mode._connect()
	start = now()
	while now()-start<32:
		await create_timer(0.05).timeout
		if role == 0:
			if mode.network.users.size() == 6 and mode.network.rooms.size() == 1:
				var data: Dictionary = mode.network.rooms.values()[0]
				if data.state == "IN_PROGRESS":
					if combat_started == 0.0: combat_started = now()
					total_shots = int(data.simulation.counter)
					for ship: NavalShip in data.simulation.ships.values():
						if not initial.has(ship.peer): initial[ship.peer] = ship.global_position
						if ship.global_position.distance_to(initial[ship.peer])>10.0: moving[ship.peer] = true
			if combat_started>0.0 and now()-combat_started>15.0:
				# Expanded maps take time to construct on each client. Keep the
				# server alive until every client records its full 14 s combat test.
				var complete := true
				for client in range(1,7): complete = complete and FileAccess.file_exists("res://tests/naval-six-"+str(client)+".json")
				if not complete: continue
				if moving.size()!=6: failures.append("not all six ships moved")
				if total_shots<40: failures.append("insufficient live projectiles")
				finish(); return
		else:
			var net := mode.network
			if not net.authenticated: continue
			var kind: String = ["light","combat","heavy","assault","submarine","heavy"][role-1]
			if kind not in net.account.owned:
				if not sent.has("buy"):
					sent.buy = true
					net.request("buy",{"ship":kind,"transaction":NavalCatalog.uid()})
				continue
			if net.account.selected != kind:
				if not sent.has("select"):
					sent.select = true
					net.request("select",{"ship":kind})
				continue
			if net.room.is_empty():
				if role == 1 and not sent.has("create"):
					sent.create = true
					net.request("create",{"name":"Seis jogadores","limit":6})
				elif role != 1:
					if not net.room_list.is_empty() and not sent.has("join"):
						sent.join = true
						net.request("join",{"id":net.room_list[0].id})
					elif fmod(now()-start,0.5)<0.06: net.request("list")
				continue
			if role == 1 and net.room.members.size() == 6 and net.room.state == "WAITING" and not sent.has("start"):
				sent.start = true
				net.request("start")
			if net.room.state == "IN_PROGRESS":
				if combat_started == 0.0: combat_started = now()
				var ship := mode._own_ship()
				if not is_instance_valid(ship): continue
				var list: Array = ship.spec.weapons
				var weapon: String = list[int((now()-combat_started)/3.0)%list.size()]
				var target: Vector3 = ship.global_position+Basis(Vector3.UP,ship.target_state.heading)*Vector3(20,0,350 if weapon == "heavyMG" else -350)
				net.send_control(1.0,0.15,target,weapon,true)
				if now()-combat_started>14.0:
					if max_ships != 6 or updates<35: failures.append("incomplete six-player replication")
					if weapons.size()<4: failures.append("not all four shot event types received")
					finish(); return
	failures.append("timeout")
	finish()
func finish() -> void:
	var report := {"role":role,"failures":failures,"updates":updates,"ships":max_ships,"weapons":weapons.keys(),"moving":moving.size()}
	FileAccess.open("res://tests/naval-six-"+str(role)+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	mode.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)
