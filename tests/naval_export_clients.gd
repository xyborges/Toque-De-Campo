extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var a := NavalMode.new()
	a.set_meta("test_controls",true)
	root.add_child(a)
	var b := NavalMode.new()
	b.set_meta("test_controls",true)
	root.add_child(b)
	for mode in [a,b]:
		mode.address_field.text = "127.0.0.1:"+str(mode.network.port)
		mode._connect()
	b.network.key = Crypto.new().generate_rsa(2048)
	await create_timer(1.0).timeout
	if not a.network.authenticated or not b.network.authenticated:
		failures.append("exported server authentication failed")
	else:
		a.network.request("create",{"name":"Executável distribuído","limit":2})
		await create_timer(0.3).timeout
		b.network.request("join",{"id":a.network.room.id})
		await create_timer(0.3).timeout
		a.network.request("start")
		await create_timer(0.6).timeout
		if a.ships.size()!=2 or b.ships.size()!=2: failures.append("exported server did not create two ships")
		else:
			var own := a._own_ship()
			var old := own.global_position
			for i in range(65):
				a.network.send_control(1,0,own.global_position+Vector3(0,0,-300),"lightMG",true)
				await create_timer(0.05).timeout
			if own.global_position.distance_to(old)<5: failures.append("exported server movement failed")
			if own.ammo.lightMG>=600: failures.append("exported server firing failed")
			if b.projectiles.is_empty() and b.seen.is_empty(): failures.append("exported server remote shot missing")
			print("EXPORTED_NAVAL distance=",own.global_position.distance_to(old)," ammo=",own.ammo.lightMG," received=",b.seen.size())
		a.network.request("leave")
		b.network.request("leave")
		await create_timer(0.2).timeout
	a.queue_free()
	b.queue_free()
	await process_frame
	FileAccess.open("res://tests/naval-export-results.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures}))
	print("EXPORTED_NAVAL failures=",failures)
	quit(0 if failures.is_empty() else 1)
