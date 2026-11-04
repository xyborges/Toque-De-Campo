extends SceneTree
var mode: NavalMode
var role := "host"
var credentials_path := ""
var stage_path := ""
var report_path := ""
var screenshots := ""
var phase := "create"
var since := 0.0
var started := 0.0
var child_pid := -1
var moved := false
var maximum_speed:=0.0
var first_position:=Vector3.ZERO
var final_position:=Vector3.ZERO
var fired := false
var remote_shot := false
var remote_audio := false
var continued := false
var tick_before := -1
var failures: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--account-e2e="): credentials_path = arg.trim_prefix("--account-e2e=")
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--stage="): stage_path = arg.trim_prefix("--stage=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--screens="): screenshots = arg.trim_prefix("--screens=")
	run.call_deferred()
func now() -> float: return Time.get_ticks_msec()*0.001
func write_stage(stage: String,data: Dictionary = {}) -> void:
	data.stage = stage
	NavalStorage.write_json(stage_path,data)
func click(control: Control) -> void:
	if not is_instance_valid(control):
		failures.append("missing button in "+phase)
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
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		if pressed and phase == "browse_join":
			mode.browse_signature = ""
			mode._refresh_rooms()
			if control.get_parent() != mode.contents.browse: failures.append("discovery replaced room button during click")
	await process_frame
func find_button(node: Node,label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := find_button(child,label)
		if found: return found
	return null
func run() -> void:
	mode = NavalMode.new()
	mode.nickname = "Anfitrião" if role == "host" else "Convidado"
	mode.set_meta("test_controls",true)
	root.add_child(mode)
	mode.network.event_received.connect(func(kind: String,payload: Dictionary):
		if kind == "shot" and int(payload.owner)!=mode.network.connection.get_unique_id():
			remote_shot = true
	)
	if not credentials_path.is_empty(): await ensure_account()
	if role == "host":
		await process_frame
		await click(find_button(mode.pages.home,"CRIAR SALA" if mode._central_enabled() else "CRIAR SALA NESTE PC"))
		mode.room_name.text = "Hospedada pelo jogo"
		await process_frame
		await click(find_button(mode.pages.create,"CRIAR"))
	started = now()
	while now()-started<36.0:
		await process_frame
		var state := NavalStorage.read_json(stage_path)
		if role == "host": await _host_step(state)
		else: await _guest_step(state)
		if phase == "finished": finish(); return
	failures.append("timeout "+phase+" status="+mode.status.text if is_instance_valid(mode) else "timeout without mode")
	finish()
func _host_step(state: Dictionary) -> void:
	if phase == "create" and not mode.network.room.is_empty():
		var start := find_button(mode.pages.lobby,"INICIAR PARTIDA")
		if start == null or not start.disabled: failures.append("owner start was not disabled with one player")
		child_pid = -1 if mode._central_enabled() else int(mode.hosting.info.pid)
		write_stage("join",{"port":mode.network.port,"room":mode.network.room.id})
		capture.call_deferred("lobby")
		await click(find_button(mode.pages.lobby,"PRONTO"))
		phase = "join"
	if phase == "join" and mode.network.room.members.size()==2 and state.get("stage") == "ready":
		var start_button:=find_button(mode.pages.lobby,"INICIAR PARTIDA")
		if start_button==null or start_button.disabled: return
		phase = "start"
		await click(find_button(mode.pages.lobby,"INICIAR PARTIDA"))
	if phase == "start" and mode.ships.size()==2:
		first_position=mode._own_ship().global_position
		since = now()
		phase = "play"
		if not credentials_path.is_empty() and mode._own_ship().kind != "heavy": failures.append("purchased selected ship was replaced by light")
		write_stage("play")
	if phase == "play":
		var ship := mode._own_ship()
		if is_instance_valid(ship):
			maximum_speed=maxf(maximum_speed,ship.speed)
			final_position=ship.global_position
			mode.network.send_control(1.0,0.2,ship.global_position+Vector3(0,0,-300),"lightMG",true)
			moved = moved or ship.speed>2.0
			fired = fired or ship.ammo.lightMG<600
		if now()-since>3.5:
			if not moved or not fired: failures.append("no movement or server firing")
			phase = "leaving"
			leave_after_capture.call_deferred()
	if phase == "left" and state.get("stage") == "continued":
		continued = OS.is_process_running(child_pid)
		if not continued: failures.append("server died with creator")
		phase = "cleanup"
	if phase == "cleanup" and not OS.is_process_running(child_pid):
		phase = "finished"
func _guest_step(state: Dictionary) -> void:
	if phase == "create" and state.get("stage") == "join":
		var server := {"endpoint":mode._central_endpoint(),"port":mode.network.port} if mode._central_enabled() else mode.discovery.resolve("127.0.0.1")
		if server.is_empty() or int(server.port) != int(state.port): return
		# Exercise the same address-connect button and room button used by players.
		mode.address_field.text = str(server.endpoint)
		phase = "connect"
		await click(find_button(mode.pages.home,"JOGAR" if mode._central_enabled() else "CONECTAR"))
	if phase == "connect" and mode.network.authenticated:
		if mode.focus.stack.back() != mode.pages.browse:
			failures.append("connect button did not open room browser")
			phase = "finished"
			return
		phase = "choose_room"
		await process_frame
		await process_frame
	if phase == "choose_room":
		for child in mode.contents.browse.get_children():
			if child is Button and child.get_meta("room_id","") == state.room:
				phase = "browse_join"
				await click(child)
				break
	if phase == "browse_join" and not mode.network.room.is_empty():
		if mode.focus.stack.back() != mode.pages.lobby or mode.network.room.members.size()!=2:
			failures.append("room join did not display synchronized lobby")
		if find_button(mode.pages.lobby,"INICIAR PARTIDA") != null: failures.append("guest has start button")
		await capture("lobby")
		phase = "leave_for_code"
		await click(find_button(mode.pages.lobby,"SAIR DA SALA"))
	if phase == "leave_for_code" and mode.network.room.is_empty():
		phase = "code_join"
		mode._navigate("browse")
		await process_frame
		await click(find_button(mode.pages.browse,"ENTRAR POR CÓDIGO"))
		mode.room_code.text = str(state.room).to_upper() if mode._central_enabled() else "127.0.0.1:"+str(int(state.port))+"#"+str(state.room).to_upper()
		await process_frame
		print("QA_INVITE ",mode.room_code.text)
		await click(find_button(mode.pages.join,"ENTRAR"))
		print("QA_ENDPOINT ",mode.connection_endpoint," status=",mode.status.text)
	if phase == "code_join" and not mode.network.room.is_empty():
		if mode.focus.stack.back() != mode.pages.lobby: failures.append("code join did not open lobby")
		await click(find_button(mode.pages.lobby,"PRONTO"))
		write_stage("ready",state)
		phase = "joined"
	if phase == "joined" and state.get("stage") == "owner_left":
		if mode.network.room.members.size()==1 and mode.network.room.owner == mode.network.connection.get_unique_id():
			child_pid = int(state.pid)
			tick_before = mode.latest_tick
			since = now()
			phase = "continue"
	if phase == "continue" and now()-since>0.8:
		continued = mode.latest_tick>tick_before
		if DisplayServer.get_name()!="headless":
			remote_audio=is_instance_valid(mode.world.weapon_audio) and mode.world.weapon_audio.started_events>0
			if not remote_audio: failures.append("guest spatial sound missing")
		if not continued or not remote_shot: failures.append("guest replication or shots missing")
		write_stage("continued")
		var central := mode._central_enabled()
		mode._close_mode()
		mode.queue_free()
		mode = null
		phase = "finished" if central else "cleanup_guest"
	if phase == "cleanup_guest" and child_pid>0 and not OS.is_process_running(child_pid): phase = "finished"
func capture(label: String) -> void:
	if screenshots.is_empty(): return
	await create_timer(0.24).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshots.path_join("autohost-"+role+"-"+label+".png"))
func finish() -> void:
	if is_instance_valid(mode): mode.queue_free()
	if not failures.is_empty() and child_pid>0 and OS.is_process_running(child_pid): OS.kill(child_pid)
	var result := {"role":role,"failures":failures,"moved":moved,"fired":fired,"remote_shot":remote_shot,"remote_audio":remote_audio,"audio_tested":DisplayServer.get_name()!="headless","continued_after_creator":continued}
	NavalStorage.write_json(report_path,result)
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)

func leave_after_capture() -> void:
	await capture("combat")
	mode._close_mode()
	mode.queue_free()
	mode = null
	phase = "finished"
	write_stage("owner_left",{"pid":child_pid})

func ensure_account() -> void:
	var credentials := NavalStorage.read_json(credentials_path)
	var data: Dictionary = credentials[role]
	await process_frame
	var deadline := now()+12.0
	while now()<deadline:
		await process_frame
		if not mode.accounts_service.profile.is_empty() and not mode.focus.stack.is_empty() and mode.focus.stack.back()==mode.pages.home: break
		if mode.focus.stack.is_empty() or mode.focus.stack.back()!=mode.pages.account or mode.account_busy: continue
		mode.login_name.text = str(data.username)
		mode.login_password.text = str(data.password)
		await click(mode.login_screen.submit_button)
		while mode.account_busy: await process_frame
		if mode.accounts_service.token.is_empty():
			await click(mode.login_screen.switch_button)
			while mode.account_busy: await process_frame
			mode.login_password.text = str(data.password)
			mode.login_confirm.text = str(data.password)
			await click(mode.login_screen.submit_button)
			while mode.account_busy: await process_frame
		break
	if mode.accounts_service.token.is_empty(): failures.append("account login failed: "+mode.login_status.text)
	if role == "host":
		mode._navigate("shop")
		await process_frame
		if "heavy" not in mode._profile().get("owned",[]):
			await click(find_button(mode.pages.shop,"COMPRAR · 2600 MOEDAS"))
			await click(mode.confirm_button)
			while mode.account_busy: await process_frame
		await mode._persist_selection("heavy")
		if mode._profile().get("selected")!="heavy": failures.append("central selected heavy was not saved")
		mode.focus.close_all()
		mode._open("home")
