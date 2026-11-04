extends SceneTree
# Two real ENet servers: the client must route invitations to the room's server,
# even when already authenticated elsewhere. All UI actions use mouse events.
var failures: Array[String] = []
var checks := 0
var guest: NavalMode
var branches: Array[Node] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(condition: Callable, seconds := 3.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if condition.call(): return true
	return false
func button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := button(child,label)
		if found: return found
	return null
func click(control: Control) -> void:
	await process_frame
	await process_frame
	if not is_instance_valid(control):
		check(false,"button exists")
		return
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			break
		parent = parent.get_parent()
	await process_frame
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
	await process_frame
func endpoint(label: String, server := false) -> NavalNetwork:
	var branch := Node.new()
	branch.name = label
	root.add_child(branch)
	branches.append(branch)
	var network := NavalNetwork.new()
	network.name = "Network"
	branch.add_child(network)
	if server:
		network.port = 0
		check(network.serve()==OK,label+" bound to an available UDP port")
	return network
func connect_identity(client: NavalNetwork, server: NavalNetwork) -> void:
	client.connect_server("127.0.0.1:"+str(server.port),"Dono")
	client.key = Crypto.new().generate_rsa(2048)
	await wait_for(func(): return client.authenticated)
func open_code(code: String, password := "") -> void:
	guest.focus.close_all()
	guest._open("join")
	guest.room_code.text = code
	guest.join_password.text = password
	await click(button(guest.pages.join,"ENTRAR"))
func leave() -> void:
	await click(button(guest.pages.lobby,"SAIR DA SALA"))
	check(await wait_for(func(): return guest.network.room.is_empty()),"leave acknowledged by server")
func run() -> void:
	var server_a := endpoint("ServerA",true)
	var server_b := endpoint("ServerB",true)
	var discovery := NavalDiscovery.new()
	root.add_child(discovery)
	check(discovery.start(server_a)==OK,"room server discovery bound")
	var owner_a := endpoint("OwnerA")
	await connect_identity(owner_a,server_a)
	owner_a.request("create",{"name":"Sala secreta","private":true,"password":"senha123"})
	check(await wait_for(func(): return not owner_a.room.is_empty()),"private room created")
	var room_id := str(owner_a.room.get("id",""))
	owner_a.request("start")
	await create_timer(0.15).timeout
	check(server_a.rooms[room_id].state=="WAITING" and server_a.rooms[room_id].simulation==null,"server rejects starting with one player")
	guest = NavalMode.new()
	root.add_child(guest)
	guest.address_field.text = "127.0.0.1:"+str(server_b.port)
	await click(button(guest.pages.home,"CONECTAR"))
	# Same process test clients require distinct device keys, like separate PCs.
	guest.network.key = Crypto.new().generate_rsa(2048)
	check(await wait_for(func(): return guest.network.authenticated),"connect button authenticates with unrelated server B")
	check(guest.focus.stack.back()==guest.pages.browse,"server connection opens room browser")
	var invite := "127.0.0.1:"+str(server_a.port)+"#"+room_id.to_upper()
	await open_code(invite,"senha123")
	check(await wait_for(func(): return guest.network.room.get("id","")==room_id),"full uppercase invite routes from server B to server A")
	check(guest.focus.stack.back()==guest.pages.lobby,"successful invitation opens lobby")
	check(guest.network.room.members.size()==2 and owner_a.room.members.size()==2,"both players receive same membership")
	check(button(guest.pages.lobby,"INICIAR PARTIDA")==null,"guest cannot start the room")
	check(button(guest.pages.lobby,"COPIAR CONVITE COMPLETO")!=null,"lobby provides complete share invitation")
	await leave()
	await open_code(room_id.to_upper(),"wrong")
	check(await wait_for(func(): return guest.feedback.text=="Senha incorreta."),"bare private code discovered and password checked on server")
	check(guest.network.room.is_empty() and not guest.join_sent,"rejected join permits retry")
	check(guest.discovery.found.values().all(func(data: Dictionary): return data.rooms.is_empty()),"private room not advertised in public browser")
	await open_code(room_id.to_upper(),"senha123")
	check(await wait_for(func(): return guest.network.room.get("id","")==room_id),"retry with correct password succeeds")
	await leave()
	await open_code("not-a-code")
	check("Código inválido" in guest.feedback.text and not guest.join_sent,"invalid code receives immediate feedback")
	await open_code("00000000000000000000000000000000")
	check(await wait_for(func(): return guest.code_search.is_empty(),5.0),"missing code search times out")
	check("CONVITE COMPLETO" in guest.feedback.text and guest.network.room.is_empty(),"missing code explains how to reconnect")
	guest._close_mode()
	guest.queue_free()
	discovery.queue_free()
	for branch in branches: branch.queue_free()
	await process_frame
	var result := {"checks":checks,"failures":failures}
	FileAccess.open("res://tests/naval-join-flow-results.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
