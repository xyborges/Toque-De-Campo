extends SceneTree
var failures: Array[String] = []
var count := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	count += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func make_network(label: String) -> NavalNetwork:
	var branch := Node.new()
	branch.name = label
	root.add_child(branch)
	var network := NavalNetwork.new()
	network.name = "Network"
	branch.add_child(network)
	network.port = 39312
	return network
func run() -> void:
	var server := make_network("Server")
	check(server.serve() == OK,"dedicated naval endpoint")
	var a := make_network("ClientA")
	var b := make_network("ClientB")
	a.connect_server("127.0.0.1","Comandante A")
	a.key = Crypto.new().generate_rsa(2048)
	b.connect_server("127.0.0.1","Comandante B")
	b.key = Crypto.new().generate_rsa(2048)
	await create_timer(1.0).timeout
	check(a.authenticated and b.authenticated,"two separate authenticated device identities")
	check(a.account.id != b.account.id,"accounts do not use IP identity")
	a.request("create",{"name":"Sala A","limit":6,"private":false})
	await create_timer(0.2).timeout
	var room_id := str(a.room.get("id",""))
	check(not room_id.is_empty() and a.room.state == "WAITING","create waiting room")
	b.request("create",{"name":"Sala B","limit":2,"private":false})
	await create_timer(0.2).timeout
	check(server.rooms.size() == 2 and b.room.id != room_id,"rooms isolated by unique IDs")
	b.request("leave")
	await create_timer(0.2).timeout
	check(server.rooms.size() == 1,"empty room is deleted")
	b.request("join",{"id":room_id})
	await create_timer(0.2).timeout
	check(a.room.members.size() == 2 and b.room.members.size() == 2,"participant lists synchronized")
	b.request("start")
	await create_timer(0.1).timeout
	check(server.rooms[room_id].state == "WAITING","non-owner cannot start match")
	# Explicit fixture funding: production accounts now start at zero.
	server.accounts[a.account.id].coins = 30000
	NavalStorage.save_account(server.accounts[a.account.id])
	var transaction := NavalCatalog.uid()
	a.request("buy",{"ship":"combat","transaction":transaction})
	await create_timer(0.2).timeout
	var coins := int(a.account.coins)
	a.request("buy",{"ship":"combat","transaction":transaction})
	await create_timer(0.2).timeout
	check(coins == 28800 and int(a.account.coins) == coins,"purchase is authoritative and idempotent")
	check("combat" in a.account.owned,"fleet ownership saved")
	var saved := NavalStorage.load_account(str(a.account.id))
	check(int(saved.coins) == 28800 and "combat" in saved.owned,"server account persistence")
	a.request("leave")
	await create_timer(0.2).timeout
	check(server.rooms.has(room_id) and b.room.owner == b.connection.get_unique_id(),"owner leaves without destroying room")
	b.request("leave")
	await create_timer(0.2).timeout
	check(server.rooms.is_empty(),"last participant removes room")
	a.request("create",{"name":"Privada","limit":6,"private":true,"password":"naval123"})
	await create_timer(0.2).timeout
	room_id = str(a.room.get("id",""))
	b.request("list")
	await create_timer(0.1).timeout
	check(b.room_list.is_empty(),"private room not listed publicly")
	b.request("join",{"id":room_id,"password":"wrong"})
	await create_timer(0.1).timeout
	check(b.room.is_empty(),"wrong password rejected")
	b.request("join",{"id":room_id,"password":"naval123"})
	await create_timer(0.2).timeout
	check(b.room.get("id","") == room_id,"private room accepts correct password")
	a.close_connection()
	await create_timer(0.2).timeout
	check(server.rooms[room_id].owner == b.connection.get_unique_id(),"disconnect transfers room ownership")
	b.close_connection()
	await create_timer(0.2).timeout
	check(server.rooms.is_empty(),"disconnection cleans final room")
	for network in [a,b,server]: network.get_parent().queue_free()
	await process_frame
	var report := {"checks":count,"failures":failures}
	FileAccess.open("res://tests/naval-lobby-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
