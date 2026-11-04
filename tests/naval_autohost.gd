extends SceneTree
var checks := 0
var failures: Array[String] = []
var child_pid := -1
var host: NavalMode
var guest: NavalMode
var late: NavalMode
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_until(test: Callable, seconds := 8.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call(): return true
		await create_timer(0.05).timeout
	return false
func make_mode(label: String) -> NavalMode:
	var mode := NavalMode.new()
	mode.nickname = label
	mode.set_meta("test_controls",true)
	root.add_child(mode)
	return mode
func run() -> void:
	check(NavalNetwork.parse_endpoint("192.168.101.227:54321").port==54321,"explicit IPv4 endpoint parsed")
	check(NavalNetwork.parse_endpoint("[::1]:54321").host=="::1","bracketed IPv6 parsed")
	check(NavalNetwork.parse_endpoint("192.168.1.2:99999").is_empty() and NavalNetwork.parse_endpoint("http://bad").is_empty(),"invalid endpoint rejected")
	host = make_mode("Anfitrião")
	host.room_name.text = "Sala automática"
	host._create_room()
	var ready := await wait_until(func(): return not host.network.room.is_empty(),15.0)
	check(ready,"create room launches native server and authenticates automatically")
	if not ready:
		print("HOST_STATUS ",host.status.text)
		finish(); return
	child_pid = int(host.hosting.info.pid)
	var port := host.network.port
	check(port>1024 and port!=3012 and OS.is_process_running(child_pid),"OS selects available ephemeral UDP port")
	check(host.network.room.state=="WAITING","room reaches waiting state")
	guest = make_mode("Convidado")
	guest.discovery.scan("127.0.0.1")
	var found := await wait_until(func(): return not guest.discovery.resolve("127.0.0.1").is_empty())
	check(found,"LAN discovery finds automatically hosted random port")
	var room_id: String = host.network.room.id
	guest.join_pending = {"id":room_id,"password":""}
	guest.address_field.text = "127.0.0.1"
	guest._connect()
	guest._resolution_update()
	guest.network.key = Crypto.new().generate_rsa(2048)
	check(await wait_until(func(): return not guest.network.room.is_empty()),"bare IP resolves random port and joins discovered room")
	check(host.network.room.members.size()==2,"host receives second player")
	host.network.request("start")
	check(await wait_until(func(): return host.ships.size()==2 and guest.ships.size()==2),"automatically hosted match replicates both ships")
	var ship := host._own_ship()
	if is_instance_valid(ship):
		var old := ship.global_position
		for i in range(45):
			host.network.send_control(1,0,ship.global_position+Vector3(0,0,-350),"lightMG",true)
			await create_timer(0.05).timeout
		check(ship.global_position.distance_to(old)>3.0,"hosted server validates movement")
		check(ship.ammo.lightMG<600,"hosted server validates firing and ammunition")
	host._close_mode()
	host.queue_free()
	host = null
	check(await wait_until(func(): return guest.network.room.members.size()==1 and guest.network.room.owner==guest.network.connection.get_unique_id()),"host leaves and ownership transfers to remaining guest")
	var tick := guest.latest_tick
	await create_timer(0.6).timeout
	check(OS.is_process_running(child_pid) and guest.latest_tick>tick,"independent automatic server continues after creator leaves")
	late = make_mode("Tardio")
	late._join_discovered("127.0.0.1:"+str(port),room_id)
	late.network.key = Crypto.new().generate_rsa(2048)
	check(await wait_until(func(): return late.ships.size()==2 and guest.ships.size()==2),"late join receives running automatically hosted match")
	guest._close_mode()
	guest.queue_free()
	guest = null
	late._close_mode()
	late.queue_free()
	late = null
	check(await wait_until(func(): return not OS.is_process_running(child_pid),12.0),"automatic server stops once final room and connection are gone")
	child_pid = -1
	finish()
func finish() -> void:
	for mode in [host,guest,late]:
		if is_instance_valid(mode): mode.queue_free()
	if child_pid>0 and not failures.is_empty() and OS.is_process_running(child_pid): OS.kill(child_pid)
	var report := {"checks":checks,"failures":failures}
	var report_path := "res://tests/naval-autohost-results.json" if OS.has_feature("editor") else NavalStorage.folder().path_join("autohost-test-results.json")
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
