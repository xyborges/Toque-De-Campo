extends SceneTree
const FIXTURE=preload("res://tests/br_broker_network_fixture.gd")
const ACCOUNTS=preload("res://tests/br_broker_test_accounts.gd")
const ROUTER=preload("res://modes/battle_royale/matchmaking/router.gd")
const REGISTRY=preload("res://modes/battle_royale/matchmaking/room_registry.gd")
var checks:=0
var failures: Array[String]=[]
var broker: Node
var issuer: CryptoKey
var clients: Array[Node]=[]
var routes: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func wait_for(test: Callable,label: String,seconds:=110.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.05).timeout
	check(false,"timeout "+label);return false
func account(index: int) -> NavalAccounts:
	var service:=ACCOUNTS.new();root.add_child(service)
	service.client_key=Crypto.new().generate_rsa(2048)
	var id:="%032x"%index
	var payload:=Marshalls.utf8_to_base64(JSON.stringify({"id":id,"username":"Loopback%d"%index,"device":service.client_key.save_to_string(true).sha256_text(),"expires":Time.get_unix_time_from_system()+300.}))
	var signature:=Crypto.new().sign(HashingContext.HASH_SHA256,payload.sha256_buffer(),issuer)
	service.ticket={"payload":payload,"signature":Marshalls.raw_to_base64(signature)};service.profile={"id":id}
	clients.append(service);return service
func begin_route(index: int,invalid_proof:=false) -> void:
	var service:=account(index)
	if invalid_proof:service.client_key=Crypto.new().generate_rsa(2048)
	var router:=ROUTER.new();root.add_child(router);clients.append(router)
	routes[index]=await router.request_match(service,"127.0.0.1",BattleRoyaleGame.BR_PROTOCOL,39590)
func run() -> void:
	issuer=Crypto.new().generate_rsa(2048);broker=FIXTURE.new();root.add_child(broker)
	var public:=CryptoKey.new();public.load_from_string(issuer.save_to_string(true),true);broker.issuer_public=public
	check(broker.start_listening(39590,BattleRoyaleGame.BR_PROTOCOL,2)==OK,"loopback broker binds with DTLS")
	begin_route(1);begin_route(2)
	if await wait_for(func():return routes.has(1) and routes.has(2),"two authenticated routes"):
		check(bool(routes[1].get("ok",false)) and bool(routes[2].get("ok",false)),"signed test tickets and fresh device proofs accepted")
		if bool(routes[1].get("ok",false)):
			check(routes[1].room_id==routes[2].room_id and routes[1].port==routes[2].port,"two authenticated clients share waiting match")
			var first: Dictionary=broker.pool.rooms[routes[1].room_id]
			check(OS.is_process_running(int(first.pid)),"first real child process running")
			check(bool(first.status.get("ready",false)) and str(first.status.get("phase",""))=="waiting","real child completed full-map native navigation loading")
			for index in range(3,13):broker.pool.request("%032x"%index,Time.get_unix_time_from_system())
			begin_route(13)
			if await wait_for(func():return routes.has(13),"second physical match"):
				check(bool(routes[13].get("ok",false)),"bounded capacity allocates second child")
				if bool(routes[13].get("ok",false)):
					check(routes[13].room_id!=routes[1].room_id and routes[13].port!=routes[1].port,"simultaneous matches use independent rooms and ports")
					var second: Dictionary=broker.pool.rooms[routes[13].room_id]
					check(first.pid!=second.pid and OS.is_process_running(int(second.pid)),"second match is an independent running process")
					check(first.folder!=second.folder,"matches have isolated state folders")
					check(broker.pool.rooms.size()==2,"process count remains bounded at configured capacity")
	begin_route(14,true)
	if await wait_for(func():return routes.has(14),"invalid device key rejected",20.):check(not bool(routes[14].get("ok",false)),"wrong device proof rejected before allocation")
	var pids: Array[int]=[]
	for record: Dictionary in broker.pool.rooms.values():pids.append(int(record.pid))
	broker.pool.shutdown()
	for process_id in pids:check(not OS.is_process_running(process_id),"child process stopped on broker shutdown")
	for node in clients:
		if node.has_method("close"):node.close()
		if is_instance_valid(node):node.queue_free()
	broker.queue_free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"routes":routes,"child_pids":pids,"scope":"Local ENet/DTLS broker + real Windows Godot child game processes with physical Afghan map/navigation; test-only issuer trust anchor, fresh production device nonce proof, waiting-room sharing and bounded parallel-room allocation. No account service, VPN or publication."}
	var file:=FileAccess.open("res://work/br-broker-network.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BR_BROKER_NETWORK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
