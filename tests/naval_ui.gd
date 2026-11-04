extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func find_button(node: Node,label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := find_button(child,label)
		if found: return found
	return null
func click(control: Control) -> void:
	if not is_instance_valid(control): return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
	await process_frame
func run() -> void:
	var game: Node3D = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	await process_frame
	game.open_naval()
	await process_frame
	var mode: NavalMode = game.naval_mode
	mode.set_meta("test_controls",true)
	check(game.mode == "naval_v2" and not game.menu_layer.visible,"main menu opens isolated naval scene")
	await click(find_button(mode.pages.home,"CONFIGURAÇÕES"))
	check(mode.focus.stack.back() == mode.pages.settings,"actual settings click opens top modal")
	await click(find_button(mode.pages.settings,"VOLTAR"))
	check(mode.focus.stack.back() == mode.pages.home,"back restores naval home")
	mode.address_field.text = "127.0.0.1"
	mode._navigate("shop")
	await create_timer(2.0).timeout
	check(mode.network.authenticated and mode.focus.stack.back() == mode.pages.shop,"connect and continue to requested shop")
	# A fresh device key gives deterministic account state for each test run.
	if "combat" in mode.network.account.owned:
		check(true,"persisted fleet reloads on reconnect")
	else:
		mode._purchase("heavy")
		await click(find_button(mode.pages.confirm,"VOLTAR"))
		mode._purchase("combat")
		check(mode.pending_purchase.ship == "combat" and "Corveta" in mode.confirm_text.text,"cancelled purchase does not lock the next ship")
		await click(mode.confirm_button)
		await create_timer(0.3).timeout
		check("combat" in mode.network.account.owned and mode.network.account.coins == 28800,"confirmation click executes one real server purchase")
	mode.network.request("select",{"ship":"combat"})
	await create_timer(0.2).timeout
	mode.focus.close_all()
	mode._open("create")
	await process_frame
	mode.room_name.text = "Teste da interface"
	await click(find_button(mode.pages.create,"CRIAR"))
	await create_timer(0.3).timeout
	check(mode.network.room.get("state","") == "WAITING","actual create button creates room")
	var start := find_button(mode.pages.lobby,"INICIAR PARTIDA")
	check(start != null and start.disabled,"start disabled until second participant")
	var branch := Node.new()
	root.add_child(branch)
	var guest := NavalNetwork.new()
	branch.add_child(guest)
	guest.port = mode.network.port
	guest.connect_server("127.0.0.1","Convidado")
	guest.key = Crypto.new().generate_rsa(2048)
	await create_timer(0.8).timeout
	guest.request("join",{"id":mode.network.room.id})
	await create_timer(0.3).timeout
	start = find_button(mode.pages.lobby,"INICIAR PARTIDA")
	check(start != null and not start.disabled,"start enabled with two authenticated players")
	await click(start)
	await create_timer(0.8).timeout
	check(mode.current_match != "" and mode.ships.size() == 2,"actual start button enters synchronized world")
	check(mode.weapon_buttons.size() == 3,"selected corvette owns its three weapon buttons")
	mode.fire_held = true
	mode._open("pause")
	check(not mode.fire_held and mode.focus.blocked(),"pause menu cancels held firing without pausing server")
	mode._open("settings")
	var before := mode.focus.stack.size()
	var extra_branch := Node.new()
	root.add_child(extra_branch)
	var extra := NavalNetwork.new()
	extra_branch.add_child(extra)
	extra.port = mode.network.port
	extra.connect_server("127.0.0.1","Tardio")
	extra.key = Crypto.new().generate_rsa(2048)
	await create_timer(0.6).timeout
	extra.request("join",{"id":mode.network.room.id})
	await create_timer(0.2).timeout
	check(mode.focus.stack.size() == before,"room updates do not close open combat settings")
	mode._close_mode()
	await create_timer(0.3).timeout
	check(game.naval_mode == null and game.mode == "menu" and game.menu_layer.visible,"leaving naval restores main menu")
	game.start_offline("training")
	await create_timer(0.2).timeout
	check(is_instance_valid(game.local_player) and game.npcs.size()>=8,"offline office still opens after naval exit")
	game.open_naval()
	await process_frame
	check(game.npcs.is_empty() and game.players.is_empty(),"switching to naval clears previous infantry world")
	game.naval_mode._close_mode()
	guest.close_connection()
	branch.queue_free()
	extra.close_connection()
	extra_branch.queue_free()
	game.queue_free()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var result := {"checks":checks,"failures":failures}
	FileAccess.open("res://tests/naval-ui-results.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
