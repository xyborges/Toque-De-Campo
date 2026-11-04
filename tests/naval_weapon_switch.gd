extends SceneTree
var failures: Array[String] = []
var checks := 0
var target := Vector3(450,0,250)
var mode: NavalMode
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var server := NavalMode.new()
	server.dedicated = true
	root.add_child(server)
	mode = NavalMode.new()
	# Test owns the input clock; desktop focus changes must not generate test
	# controls. The production selection/release handlers are exercised below.
	mode.set_meta("test_controls",true)
	root.add_child(mode)
	mode.set_process_input(false)
	mode.set_process_unhandled_input(false)
	for binding: Dictionary in root.focus_exited.get_connections():
		if binding.callable.get_object()==mode: root.focus_exited.disconnect(binding.callable)
	var branch := Node.new()
	root.add_child(branch)
	var guest := NavalNetwork.new()
	branch.add_child(guest)
	var endpoint := NavalNetwork.format_endpoint("127.0.0.1",server.network.port)
	mode.network.connect_server(endpoint,"Troca de armas")
	guest.connect_server(endpoint,"Observador")
	guest.key = Crypto.new().generate_rsa(2048)
	await create_timer(0.7).timeout
	check(mode.network.authenticated and guest.authenticated,"two real ENet clients authenticate")
	var peer := mode.network.connection.get_unique_id()
	server.network.accounts[server.network.users[peer].identity].owned = ["light","heavy"]
	mode.network.request("select",{"ship":"heavy"})
	await create_timer(0.15).timeout
	mode.network.request("create",{"name":"Weapon switching regression"})
	await create_timer(0.2).timeout
	guest.request("join",{"id":mode.network.room.id})
	await create_timer(0.2).timeout
	mode.network.request("start")
	await create_timer(0.8).timeout
	var battle: NavalMatch = server.network.rooms[mode.network.room.id].simulation
	var authority: NavalShip = battle.ships[peer]
	var local := mode._own_ship()
	check(local!=null and local.kind=="heavy" and mode.ships.size()==2,"heavy ship spawns with four weapons in synchronized match")
	# Open water and forward horizontal aim, avoiding legitimate cabin/limit blocks.
	authority.global_position = Vector3(700,0,700)
	authority.heading = 0.0
	authority.rotation = Vector3.ZERO
	mode.camera.orbit_yaw = 0.0
	mode.camera.orbit_pitch = -0.04
	mode.focus.close_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Initial spawn headings are random. Let every turret finish turning to
	# the new test bearing before timing the first burst.
	await control_for(2.0,false)
	mode.fire_held = true
	await control_for(0.6,true)
	check(authority.ammo.lightMG<600,"initial held fire consumes authoritative ammunition")
	mode._select_weapon("heavyMG")
	check(mode.fire_held,"weapon selection preserves an existing held trigger")
	await control_for(0.7,true)
	check(authority.selected=="heavyMG" and authority.ammo.heavyMG<240,"heavy gun fires after switching while held")
	mode.fire_held = false
	mode.network.stop_fire()
	await create_timer(0.15).timeout
	var stale := mode.network.input_sequence
	mode.fire_held = true
	mode.network.send_control(0.0,0.0,target,mode.selected,true)
	await create_timer(0.12).timeout
	mode.network.cease_fire.rpc_id(1,str(mode.network.room.id),str(mode.network.room.match),stale)
	await create_timer(0.02).timeout
	check(authority.firing,"late stop packet cannot cancel newer held fire")
	mode.fire_held = false
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	mode.fire_held = true
	mode._input(release)
	check(not mode.fire_held,"release is observed before a GUI control can consume it")
	await create_timer(0.2).timeout
	var remaining: int = authority.ammo.heavyMG
	await create_timer(0.5).timeout
	check(authority.ammo.heavyMG==remaining and not authority.firing,"release reliably stops fire without endless shooting")
	for weapon: String in ["missile","torpedo","lightMG","heavyMG","lightMG"]:
		mode._select_weapon(weapon)
		mode.fire_held = true
		var before: int = authority.ammo[weapon]
		await control_for(0.7,true)
		if authority.ammo[weapon]>=before:
			print("FIRE_STATE ",weapon," blocked=",authority.turrets[weapon].blocked," reachable=",authority.turrets[weapon].reachable," selected=",authority.selected," cooldown=",authority.waits[weapon])
		check(authority.ammo[weapon]<before,"switch and fire "+weapon)
		mode.fire_held = false
		mode.network.stop_fire()
	# A weapon switch must not bypass the existing missile cadence.
	var missile_ammo: int = authority.ammo.missile
	mode._select_weapon("missile")
	await control_for(0.3,true)
	check(authority.ammo.missile==missile_ammo and authority.waits.missile>0,"switching back preserves missile cooldown")
	check(float(mode._own_ship().waits.get("missile",0))>0,"authoritative cooldown is replicated to the HUD")
	mode._select_weapon("lightMG")
	authority.ammo.lightMG = 0
	var counter := battle.counter
	await control_for(0.25,true)
	check(battle.counter==counter,"empty weapon produces no projectile or shot event")
	mode.fire_held = false
	mode.network.stop_fire()
	mode.network.request("reload")
	await create_timer(0.15).timeout
	check(authority.reload_left>0,"reload still starts after repeated weapon changes")
	counter = battle.counter
	await control_for(0.25,true)
	check(battle.counter==counter,"reloading weapon cannot fire")
	mode._open("pause")
	await create_timer(0.2).timeout
	check(not authority.firing and not mode.fire_held,"pause clears held fire")
	if DisplayServer.get_name()!="headless":
		mode.focus.close_all()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/screens/weapon-switch-match.png"))
	guest.close_connection()
	mode.network.close_connection()
	branch.queue_free()
	mode.queue_free()
	server.queue_free()
	await process_frame
	NavalStorage.write_json("res://tests/naval-weapon-switch-results.json",{"checks":checks,"failures":failures})
	quit(0 if failures.is_empty() else 1)

func control_for(duration: float, trigger: bool) -> void:
	var until := Time.get_ticks_msec()+int(duration*1000.0)
	while Time.get_ticks_msec()<until:
		mode.network.send_control(0.0,0.0,target,mode.selected,trigger)
		await create_timer(0.04).timeout
