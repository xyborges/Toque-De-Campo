extends Node3D
class_name NavalMode

signal closed
signal account_connected
var initial_page := "home"
var dedicated := false
var server_address := NavalCatalog.SERVER
var nickname := "Jogador"
var accounts_service: NavalAccounts
var login_name: LineEdit
var login_password: LineEdit
var login_confirm: LineEdit
var login_status: Label
var account_label: Label
var account_busy := false
var login_screen: GameLoginScreen
var menu_music: AudioStreamPlayer
var central_config: Dictionary = {}
var voice: BRVoiceRelay
var network: NavalNetwork
var world: NavalWorld
var damage_numbers: GameDamageNumbers
var damage_flash: GameDamageFlash
var camera: NavalCamera
var audio_listener: AudioListener3D
var death_view: GameDeathCamera
var ships: Dictionary = {}
var projectiles: Dictionary = {}
var projectile_pool: Array[NavalProjectileVisual] = []
var guide_mesh: ImmediateMesh
var guide_last_launch: Dictionary = {}
var seen: Dictionary = {}
var latest_snapshot: Dictionary = {}
var match_stats:=GameMatchStats.new()
var scoreboard: GameScoreboard
var score_signature:=""
var clock := 0.0
var clock_initialized := false
var received_at := 0.0
var latest_tick := -1
var current_match := ""
var fire_held := false
var selected := "lightMG"
var input_clock := 0.0
var guide_clock := 0.0
var wake_clock := 0.0
var connect_started := 0.0
var connect_pending := false
var own_life := 0
var prediction_line: MeshInstance3D
var impact_marker: MeshInstance3D
var ui: CanvasLayer
var focus: GameUIFocus
var pages: Dictionary = {}
var shared_settings: GameSettingsPanel
var naval_deploy_button: Button
var naval_deploy_clock:=0.0
var naval_death_menu_id:=""
var contents: Dictionary = {}
var status: Label
var hp_bar: ProgressBar
var telemetry: Label
var rank: Label
var weapon_row: HBoxContainer
var weapon_buttons: Dictionary = {}
var weapon_styles: Dictionary = {}
var aim_label: Label
var notification: Label
var reticle: ColorRect
var address_field: LineEdit
var room_name: LineEdit
var room_limit: SpinBox
var room_private: CheckBox
var room_password: LineEdit
var room_late: CheckBox
var room_code: LineEdit
var join_password: LineEdit
var confirm_button: Button
var confirm_text: Label
var pending_purchase: Dictionary = {}
var pending_navigation := ""
var room_signature := ""
var fleet_signature := ""
var guide_material: StandardMaterial3D
var preferences: Dictionary = {}
var feedback: Label
var feedback_left := 0.0
var discovery: NavalDiscovery
var hosting := NavalHosting.new()
var hosting_pending := false
var after_host := ""
var create_pending: Dictionary = {}
var join_pending: Dictionary = {}
var join_started := 0.0
var join_sent := false
var code_search := ""
var browse_signature := ""
var browse_dirty := false
var browse_press_active := false
var resolving: Dictionary = {}
var resolve_started := 0.0
var connection_endpoint := ""
var auto_service := false
var had_clients := false
var service_empty_since := 0.0
var service_started := 0.0
var service_idle_seconds := 10.0
var firewall_message := ""
var naval_loading: GameLoadingScreen
var naval_hud: GameNavalHUD
var network_status: Label
var service_ready_path := ""
var service_ready_data: Dictionary = {}
var service_heartbeat := 0.0
var status_heartbeat := 0.0
var closing := false
var navigation_generation := 0
var launch_subpage := ""

func _ready() -> void:
	name = "Naval"
	launch_subpage = initial_page if initial_page in ["shop","fleet","settings"] else ""
	GameAudioSettings.ensure()
	central_config = NavalStorage.read_json("res://assets/service-config.json")
	if accounts_service == null:
		accounts_service = NavalAccounts.new()
		add_child(accounts_service)
	network = NavalNetwork.new()
	network.name = "Network"
	add_child(network)
	var voice_context: Node3D=load("res://scripts/voice/naval_adapter.gd").new();voice_context.naval=self;network.add_child(voice_context)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--naval-port="): network.port = int(arg.trim_prefix("--naval-port="))
	if dedicated:
		var error := network.serve()
		print("NAVAL_SERVER port=",network.port," error=",error_string(error))
		if error != OK:
			get_tree().quit(1)
			return
		discovery = NavalDiscovery.new()
		add_child(discovery)
		var discovered := discovery.start(network)
		if discovered != OK: print("DISCOVERY_UNAVAILABLE ",error_string(discovered),"; direct IP:port remains available")
		_service_ready()
		return
	discovery = NavalDiscovery.new()
	add_child(discovery)
	if not _central_enabled(): discovery.start()
	discovery.changed.connect(func():
		if pages.has("browse"): _refresh_rooms()
	)
	network.event_received.connect(_event)
	network.disconnected.connect(_disconnected)
	preferences = NavalStorage.read_json(NavalStorage.settings_folder().path_join("settings.json"))
	_build_ui()
	get_window().focus_exited.connect(func():
		browse_press_active = false
		fire_held = false
		network.stop_fire()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)
	if NavalAccounts.testing(): _open_initial_page()
	elif accounts_service.validated_session and not accounts_service.token.is_empty() and not NavalAccounts.verify_ticket(accounts_service.ticket).is_empty() and not accounts_service.profile.is_empty():
		# The parent already authenticated this shared session. Reopening its
		# login screen here races navigation and flashes the login curtain.
		_account_ready.call_deferred()
	else: _restore_account.call_deferred()

func create_match(data: Dictionary) -> NavalMatch:
	var battle := NavalMatch.new()
	battle.name = "Match_"+str(data.id)
	add_child(battle)
	battle.build(network,data)
	return battle

func _new_page(id: String, title: String) -> VBoxContainer:
	var panel: PanelContainer
	var box: VBoxContainer
	if id in ["home","create","browse","lobby","fleet","shop","join"]:
		var screen := GameMenuPage.new()
		screen.mode = self
		screen.page_id = id
		screen.title = title
		focus.add_child(screen)
		panel = screen
		box = screen.content
	else:
		panel = PanelContainer.new()
		panel.theme = GameUI.THEME
		panel.add_theme_stylebox_override("panel",FieldTheme.box())
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		panel.add_child(scroll)
		box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation",12)
		scroll.add_child(box)
		GameUI.label(box,title,25,FieldTheme.ACCENT)
		focus.add_child(panel)
	panel.name = "Naval_"+id
	pages[id] = panel
	contents[id] = box
	panel.hide()
	return box

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if parent == contents.get("browse"):
		button.button_down.connect(func(): browse_press_active = true)
		button.button_up.connect(func(): browse_press_active = false)
	parent.add_child(button)
	if focus and focus.feedback: focus.feedback.watch(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _back(parent: Node) -> void:
	_button(parent,"VOLTAR",_go_back)

func _go_back() -> void:
	if closing: return
	if not focus.blocked():
		if is_instance_valid(world): _open("pause")
		else: _close_mode()
		return
	var top: Control=focus.stack.back()
	if top==pages.get("home") and focus.stack.size()==1 and not is_instance_valid(world):
		_close_mode()
	elif launch_subpage in ["shop","fleet"] and top==pages.get(launch_subpage) and focus.stack.size()==2 and focus.stack[0]==pages.home and not is_instance_valid(world):
		# Direct shortcuts from the main menu return to their launcher.
		_close_mode()
	elif focus.stack.size()>1 or is_instance_valid(world):
		focus.back()
	elif top==shared_settings:
		shared_settings.leave()
	else:
		focus.open_root(pages.home)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	focus = GameUIFocus.new()
	add_child(focus)
	focus.layer = 50
	focus.changed.connect(func():
		fire_held = false
		network.stop_fire()
		if not focus.blocked() and world != null: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	_install_naval_theme()
	_build_account_ui()
	var box := _new_page("home","MODO NAVAL")
	account_label = _label(box,"CONTA · conectando...")
	_label(box,"PVP · 2–6 jogadores")
	address_field = LineEdit.new()
	address_field.text = server_address
	address_field.placeholder_text = "Endereço do amigo: IP ou IP:porta"
	var connection_row := HBoxContainer.new()
	box.add_child(connection_row)
	address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection_row.add_child(address_field)
	_button(connection_row,"CONECTAR",_connect)
	connection_row.visible = not _central_enabled()
	status = _label(box,"Escolha Jogar para entrar numa sala ou crie uma nova." if _central_enabled() else "Crie uma sala para hospedar neste PC ou procure uma sala na rede local.")
	_button(box,"JOGAR",func(): _navigate("browse"))
	_button(box,"CRIAR SALA" if _central_enabled() else "CRIAR SALA NESTE PC",func(): _open("create"))
	var fleet_row := HBoxContainer.new()
	box.add_child(fleet_row)
	_button(fleet_row,"MINHA FROTA",func(): _navigate("fleet")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(fleet_row,"LOJA DE EMBARCAÇÕES",func(): _navigate("shop")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options_row := HBoxContainer.new()
	box.add_child(options_row)
	_button(options_row,"CONFIGURAÇÕES",func(): _open("settings")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(options_row,"TROCAR DE CONTA",_logout_account).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(box,"VOLTAR AO MENU PRINCIPAL",_close_mode)
	box = _new_page("create","CRIAR SALA")
	room_name = LineEdit.new()
	room_name.text = "Mar aberto"
	room_name.placeholder_text = "Nome da sala"
	room_name.max_length = 32
	box.add_child(room_name)
	if not _central_enabled(): _label(box,"Permita o acesso à rede se o Windows solicitar.")
	_label(box,"Número máximo de participantes")
	room_limit = SpinBox.new()
	room_limit.min_value = 2
	room_limit.max_value = 6
	room_limit.value = 6
	box.add_child(room_limit)
	room_private = CheckBox.new()
	room_private.text = "Sala privada"
	box.add_child(room_private)
	room_password = LineEdit.new()
	room_password.placeholder_text = "Senha (se privada)"
	room_password.secret = true
	room_password.max_length = 64
	box.add_child(room_password)
	room_late = CheckBox.new()
	room_late.text = "Permitir entrada durante a partida"
	room_late.button_pressed = true
	box.add_child(room_late)
	_button(box,"CRIAR",_create_room)
	_back(box)
	_new_page("browse","SALAS NAVAIS")
	_new_page("lobby","SALA")
	_new_page("fleet","MINHA FROTA")
	_new_page("shop","LOJA DE EMBARCAÇÕES")
	box = _new_page("join","ENTRAR POR CÓDIGO")
	room_code = LineEdit.new()
	room_code.placeholder_text = "Convite completo ou código da sala"
	_label(box,"Cole o convite copiado no lobby do amigo. Códigos simples são procurados na rede local.")
	box.add_child(room_code)
	join_password = LineEdit.new()
	join_password.placeholder_text = "Senha da sala privada"
	join_password.secret = true
	box.add_child(join_password)
	_button(box,"ENTRAR",_join_by_code)
	_back(box)
	box = _new_page("confirm","CONFIRMAR COMPRA")
	confirm_text = _label(box,"")
	confirm_button = _button(box,"CONFIRMAR",_confirm_purchase)
	_back(box)
	shared_settings=GameSettingsPanel.new();shared_settings.game=self;shared_settings.focus=focus;focus.add_child(shared_settings);pages["settings"]=shared_settings
	var pause:=GamePauseMenu.new();pause.game=self;pause.focus=focus;pause.settings=shared_settings;focus.add_child(pause);pages["pause"]=pause
	_build_hud()
	var toast := CanvasLayer.new()
	toast.layer = 70
	add_child(toast)
	feedback = Label.new()
	feedback.anchor_left = 0.15
	feedback.anchor_right = 0.85
	feedback.offset_top = 18
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.modulate = FieldTheme.BAD
	toast.add_child(feedback)
	naval_loading = GameLoadingScreen.new()
	toast.add_child(naval_loading)
	naval_loading.hide()


func _build_hud() -> void:
	scoreboard=GameScoreboard.new();scoreboard.game=self;scoreboard.source=match_stats
	scoreboard.active=func(): return not current_match.is_empty() and is_instance_valid(world)
	scoreboard.local_peer=func(): return network.local_id() if network.connection.has_multiplayer_peer() else 0
	ui.add_child(scoreboard)
	for active in [false,true]:
		weapon_styles[active] = FieldTheme.box(FieldTheme.PRESSED if active else FieldTheme.FIELD,FieldTheme.ACCENT if active else FieldTheme.BORDER,10)
	naval_hud = GameNavalHUD.new()
	naval_hud.mode = self
	ui.add_child(naval_hud)
	hp_bar = naval_hud.hp_bar
	telemetry = naval_hud.telemetry
	rank = naval_hud.rank
	reticle = naval_hud.reticle
	aim_label = naval_hud.aim_label
	weapon_row = naval_hud.weapon_row
	notification = naval_hud.notification
	damage_flash=GameDamageFlash.new();naval_hud.add_child(damage_flash)
	_set_hud(false)

func _set_hud(visible_state: bool) -> void:
	for child in ui.get_children():
		if child is Control: child.visible = visible_state and child!=scoreboard

func _open(id: String) -> void:
	if closing: return
	navigation_generation += 1
	if id=="settings" and is_instance_valid(shared_settings):
		if focus.stack.is_empty() and not is_instance_valid(world):
			focus.open_root(pages.home)
		shared_settings.present_naval()
		return
	if not pages.has(id): return
	if id in ["create","browse","lobby","fleet","shop","join"] and not is_instance_valid(world) and id!=launch_subpage:
		launch_subpage=""
	if id in ["home","create","browse","lobby","fleet","shop","join"] and not is_instance_valid(world):
		focus.open_route(pages[id],pages.home)
	else:
		focus.open(pages[id])

func request_main_menu() -> void:
	if is_instance_valid(world) and pages.has("pause") and pages.pause is GamePauseMenu:
		(pages.pause as GamePauseMenu).confirm_leave()
	else:
		_close_mode()

func _central_enabled() -> bool:
	if NavalAccounts.testing(): return false
	if "--naval-local-host-test" in OS.get_cmdline_user_args() and (OS.has_feature("editor") or OS.has_feature("qa")): return false
	return bool(central_config.get("central",true))

func _central_endpoint() -> String:
	return NavalNetwork.format_endpoint(str(central_config.get("host",NavalCatalog.SERVER)),int(central_config.get("port",NavalCatalog.PORT)))

func _navigate(id: String) -> void:
	if not NavalAccounts.testing() and accounts_service.token.is_empty():
		_open("account")
		return
	if id in ["fleet","shop"] and not NavalAccounts.testing():
		_refresh_fleet(id)
		_open(id)
		return
	if id == "create":
		_open("create")
		return
	if id == "browse":
		if _central_enabled() and not network.authenticated:
			pending_navigation = "browse"
			_connect_endpoint(NavalNetwork.parse_endpoint(_central_endpoint()))
			return
		discovery.scan()
		_refresh_rooms()
		if network.authenticated: network.request("list")
		_open("browse")
		return
	if not network.authenticated:
		_host_local(id)
		return
	if id in ["fleet","shop"]: _refresh_fleet(id)
	_open(id)

func _create_room() -> void:
	if hosting_pending or connect_pending: return
	if not network.room.is_empty():
		status.text = "Saia da sala atual antes de hospedar outra."
		return
	if room_private.button_pressed and room_password.text.length()<3:
		feedback.text = "Use uma senha com pelo menos três caracteres."
		feedback_left = 5.0
		return
	create_pending = {"name":room_name.text,"limit":int(room_limit.value),"private":room_private.button_pressed,"password":room_password.text,"late":room_late.button_pressed}
	_host_local("create_room")

func _host_local(next: String) -> void:
	if _central_enabled():
		after_host = next
		if network.authenticated: _after_connected()
		else: _connect_endpoint(NavalNetwork.parse_endpoint(_central_endpoint()))
		return
	if hosting_pending: return
	after_host = next
	var result := hosting.start()
	if result != OK:
		status.text = "Não foi possível iniciar a hospedagem local: "+error_string(result)
		feedback.text = status.text
		feedback_left = 8.0
		create_pending.clear()
		return
	hosting_pending = true
	status.text = "Iniciando hospedagem neste PC e escolhendo uma porta livre..."
	feedback.text = "Preparando hospedagem neste PC..."
	feedback_left = 20.0
	hosting.request_firewall()

func _host_update() -> void:
	if not hosting_pending: return
	var result := hosting.poll()
	if result == ERR_BUSY: return
	hosting_pending = false
	if result != OK:
		status.text = "A hospedagem local não iniciou: "+error_string(result)
		feedback.text = status.text
		feedback_left = 8.0
		create_pending.clear()
		return
	var port := int(hosting.info.port)
	address_field.text = "127.0.0.1:"+str(port)
	if network.authenticated and network.server_host == "127.0.0.1" and network.port == port:
		_after_connected()
		return
	_connect_endpoint({"host":"127.0.0.1","port":port})

func _after_connected() -> void:
	if after_host == "create_room" and not create_pending.is_empty():
		network.request("create",create_pending)
		create_pending.clear()
		after_host = ""
		return
	if not join_pending.is_empty():
		_send_join()
		return
	if not after_host.is_empty():
		var next := after_host
		after_host = ""
		_navigate(next)
	if not pending_navigation.is_empty():
		var next := pending_navigation
		pending_navigation = ""
		_navigate(next)

func _room_feedback(text: String) -> void:
	status.text = text
	feedback.text = text
	feedback_left = 9.0

func _connect() -> void:
	if not network.room.is_empty():
		_refresh_lobby()
		focus.close_all()
		_open("lobby")
		return
	if connect_pending or not resolving.is_empty(): return
	var address := address_field.text.strip_edges()
	var endpoint := NavalNetwork.parse_endpoint(address)
	if endpoint.is_empty():
		_room_feedback("Endereço inválido. Use IP:porta mostrado no lobby do amigo.")
		return
	if pending_navigation.is_empty() and join_pending.is_empty(): pending_navigation = "browse"
	if network.authenticated and address == connection_endpoint:
		_after_connected()
		return
	if not address.contains(":"):
		resolving = endpoint
		resolve_started = Time.get_ticks_msec()*0.001
		discovery.scan(str(endpoint.host))
		_room_feedback("Procurando o servidor em "+str(endpoint.host)+"...")
		return
	_connect_endpoint(endpoint)

func _connect_endpoint(endpoint: Dictionary) -> void:
	if _central_enabled(): endpoint = NavalNetwork.parse_endpoint(_central_endpoint())
	resolving.clear()
	if endpoint.is_empty():
		_room_feedback("Endereço do convite inválido. Copie novamente o convite no lobby.")
		return
	if network.authenticated: network.close_connection()
	connect_pending = true
	connect_started = Time.get_ticks_msec()*0.001
	network.port = int(endpoint.port)
	connection_endpoint = NavalNetwork.format_endpoint(str(endpoint.host),int(endpoint.port))
	_room_feedback("Conectando ao servidor principal..." if _central_enabled() else "Conectando ao servidor "+connection_endpoint+"...")
	if not NavalAccounts.testing():
		var response := await accounts_service.call_api("profile")
		if not response.get("ok",false):
			connect_pending = false
			_room_feedback(str(response.get("error","Entre novamente na sua conta.")))
			if accounts_service.token.is_empty(): _open("account")
			return
		network.account_ticket = accounts_service.ticket
		nickname = str(accounts_service.profile.username)
		connect_started = Time.get_ticks_msec()*0.001
	var error := network.connect_server(connection_endpoint,nickname)
	if error != OK:
		connect_pending = false
		join_pending.clear()
		_room_feedback("Falha ao conectar: "+error_string(error))

func _resolution_update() -> void:
	if not code_search.is_empty():
		var server := discovery.find_room(code_search)
		if not server.is_empty():
			code_search = ""
			discovery.lookup_room = ""
			_enter_room(str(server.endpoint),join_pending)
		elif Time.get_ticks_msec()*0.001-resolve_started>4.0:
			code_search = ""
			discovery.lookup_room = ""
			join_pending.clear()
			_room_feedback("Não localizei esse código na rede. Peça ao amigo para copiar o CONVITE COMPLETO no lobby e confirme que a sala continua aberta.")
		return
	if resolving.is_empty(): return
	var data := discovery.resolve(str(resolving.host))
	if not data.is_empty():
		_connect_endpoint({"host":resolving.host,"port":data.port})
	elif Time.get_ticks_msec()*0.001-resolve_started>1.4:
		_connect_endpoint(resolving.duplicate())

func _enter_room(endpoint: String, payload: Dictionary) -> void:
	if not network.room.is_empty():
		_refresh_lobby()
		focus.close_all()
		_open("lobby")
		return
	join_pending = payload.duplicate()
	join_sent = false
	pending_navigation = ""
	code_search = ""
	discovery.lookup_room = ""
	address_field.text = endpoint
	if network.authenticated and endpoint == connection_endpoint:
		_send_join()
	else:
		_connect_endpoint(NavalNetwork.parse_endpoint(endpoint))

func _send_join() -> void:
	if join_pending.is_empty() or join_sent: return
	join_sent = true
	join_started = Time.get_ticks_msec()*0.001
	_room_feedback("Entrando na sala...")
	network.request("join",join_pending)

func _join_discovered(endpoint: String, room_id: String) -> void:
	if connect_pending or join_sent: return
	_enter_room(endpoint,{"id":room_id,"password":""})

func _connect_for_code(endpoint: String) -> void:
	pending_navigation = "join"
	_connect_endpoint(NavalNetwork.parse_endpoint(endpoint))

func _clear_contents(id: String) -> VBoxContainer:
	var box: VBoxContainer = contents[id]
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	return box

func _refresh_rooms() -> void:
	# Keep controls alive between mouse-down and mouse-up, even if discovery changes.
	if browse_press_active or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		browse_dirty = true
		return
	browse_dirty = false
	var entries: Dictionary = {}
	var empty_servers: Array[String] = []
	if network.authenticated:
		for item: Dictionary in network.room_list:
			entries[str(item.id)] = {"room":item,"endpoint":connection_endpoint}
	for server: Dictionary in discovery.found.values():
		if server.rooms.is_empty(): empty_servers.append(str(server.endpoint))
		for item: Dictionary in server.rooms:
			if not entries.has(str(item.id)): entries[str(item.id)] = {"room":item,"endpoint":server.endpoint}
	var signature := JSON.stringify([entries,empty_servers,connection_endpoint,network.authenticated,join_sent,connect_pending])
	if signature == browse_signature: return
	browse_signature = signature
	var box := _clear_contents("browse")
	_label(box,"SALAS ONLINE" if _central_enabled() else "SALAS NA REDE LOCAL")
	if network.authenticated and not _central_enabled(): _label(box,connection_endpoint)
	for endpoint: String in empty_servers:
		_button(box,"Servidor em "+endpoint+" · entrar por código",_connect_for_code.bind(endpoint))
	if entries.is_empty(): _label(box,"Nenhuma sala disponível.")
	for entry: Dictionary in entries.values():
		var item: Dictionary = entry.room
		var state := "Aguardando jogadores" if item.state == "WAITING" else "Em partida"
		var button := _button(box,"%s · %d/%d · %s%s" % [item.name,item.players,item.limit,state,"" if _central_enabled() else "\n"+str(entry.endpoint)],_join_discovered.bind(str(entry.endpoint),str(item.id)))
		button.set_meta("room_id",str(item.id))
		button.disabled = connect_pending or join_sent or int(item.players)>=int(item.limit) or (item.state == "IN_PROGRESS" and not item.late)
	_button(box,"ATUALIZAR BUSCA",func():
		discovery.scan()
		if network.authenticated: network.request("list")
	)
	var manual_button := _button(box,"CONECTAR PELO ENDEREÇO",func():
		focus.close_all()
		_open("home")
		address_field.grab_focus()
	)
	manual_button.visible = not _central_enabled()
	_button(box,"ENTRAR POR CÓDIGO",func(): _open("join"))
	_back(box)

func _profile() -> Dictionary:
	return network.account if NavalAccounts.testing() else accounts_service.profile

func _refresh_fleet(page: String) -> void:
	var box := _clear_contents(page)
	var profile := _profile()
	_label(box,"MINHA FROTA" if page == "fleet" else "ESTALEIRO · EMBARCAÇÕES").add_theme_font_size_override("font_size",24)
	_label(box,"%s  ·  %s MOEDAS" % [str(profile.get("username",nickname)),str(int(profile.get("coins",0)))])
	if world != null:
		var own := _own_ship()
		if is_instance_valid(own):
			var remaining := maxf(0.0,10.0-(clock-own.last_damage_at))
			_label(box,"Troca disponível com vida completa e 10 s sem dano." if own.hp>=float(own.spec.hp) and remaining<=0.0 else "TROCA BLOQUEADA · vida completa e 10 s sem dano são necessários.")
	for id: String in NavalCatalog.SHIPS:
		var data: Dictionary = NavalCatalog.SHIPS[id]
		var owned: bool = id in profile.get("owned",[])
		if page == "fleet" and not owned: continue
		var card := GameUI.panel(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",14)
		card.add_child(row)
		var thumbnail := TextureRect.new()
		thumbnail.texture = GameUI.icon("naval")
		thumbnail.custom_minimum_size = Vector2(56,56)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(thumbnail)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		_label(detail,"%s   ·   %d HP" % [data.name,data.hp]).add_theme_font_size_override("font_size",19)
		var names: Array[String] = []
		for weapon in data.weapons: names.append(str(NavalCatalog.WEAPONS[weapon].name))
		_label(detail,"%.0f m/s   ·   %s" % [data.speed,", ".join(names)])
		if owned:
			var current := str(profile.get("selected","light")) == id
			var own := _own_ship()
			if world != null and is_instance_valid(own): current = own.kind == id
			var button := _button(detail,"EM USO" if current else ("TROCAR PARA ESTE NAVIO" if world != null else "SELECIONAR"),_select_ship.bind(id))
			button.disabled = current or account_busy
		else: _button(detail,"COMPRAR · %d MOEDAS" % data.price,_purchase.bind(id)).disabled = account_busy
	_back(box)

func _select_ship(id: String) -> void:
	if account_busy: return
	if NavalAccounts.testing() or network.authenticated:
		network.request("select",{"ship":id})
		return
	await _persist_selection(id)

func _persist_selection(id: String) -> void:
	if NavalAccounts.testing(): return
	account_busy = true
	var result := await accounts_service.call_api("select",{"ship":id})
	account_busy = false
	if not result.get("ok",false): _room_feedback(str(result.get("error","Não foi possível salvar a seleção.")))
	elif network.authenticated: network.request("profile",accounts_service.ticket)
	_refresh_fleet("fleet")
	_refresh_fleet("shop")

func _purchase(id: String) -> void:
	pending_purchase = {"ship":id,"transaction":NavalCatalog.uid()}
	confirm_text.text = "Comprar %s por %d moedas?" % [NavalCatalog.SHIPS[pending_purchase.ship].name,NavalCatalog.SHIPS[pending_purchase.ship].price]
	confirm_button.disabled = false
	confirm_button.text = "CONFIRMAR"
	_open("confirm")

func _confirm_purchase() -> void:
	if pending_purchase.is_empty(): return
	confirm_button.disabled = true
	confirm_button.text = "PROCESSANDO..."
	if NavalAccounts.testing():
		network.request("buy",pending_purchase)
		return
	if account_busy: return
	account_busy = true
	var result := await accounts_service.call_api("buy",pending_purchase)
	account_busy = false
	if result.get("ok",false):
		pending_purchase.clear()
		if not focus.stack.is_empty() and focus.stack.back() == pages.confirm: focus.close_top()
		if network.authenticated: network.request("profile",accounts_service.ticket)
		_refresh_fleet("shop")
		_refresh_fleet("fleet")
	else:
		confirm_text.text = str(result.get("error","Compra não concluída."))
		confirm_button.disabled = false
		confirm_button.text = "TENTAR NOVAMENTE"

func _refresh_lobby() -> void:
	var data := network.room
	if data.is_empty(): return
	var box := _clear_contents("lobby")
	_label(box,str(data.name)).modulate = FieldTheme.ACCENT
	_label(box,"%d / %d" % [data.members.size(),data.limit])
	for member: Dictionary in data.members:
		var member_card := GameUI.panel(box,12)
		var member_row := HBoxContainer.new()
		member_card.add_child(member_row)
		var icon := TextureRect.new()
		icon.texture = GameUI.icon("person")
		icon.custom_minimum_size = Vector2(32,32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		member_row.add_child(icon)
		GameUI.label(member_row,"%s · %s%s" % [member.name,NavalCatalog.SHIPS[member.ship].name,(" ✓" if bool(member.get("ready",false)) else "")],15).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var own_id:=network.local_id()
	var owned: Array=_profile().get("owned",["light"])
	var own: Dictionary={}
	for member: Dictionary in data.members:
		if int(member.peer)==own_id: own=member;break
	var selector:=OptionButton.new();box.add_child(selector)
	for id in owned:
		selector.add_item(str(NavalCatalog.SHIPS[id].name));selector.set_item_metadata(selector.item_count-1,id)
		if str(id)==str(own.get("ship","light")): selector.select(selector.item_count-1)
	selector.item_selected.connect(func(index): _select_ship(str(selector.get_item_metadata(index))))
	var chosen: String=str(own.get("ship","light"))
	var spec: Dictionary=NavalCatalog.SHIPS[chosen]
	_label(box,"%d HP · %.0f km/h"%[int(spec.hp),float(spec.speed)*3.6])
	var weapons: PackedStringArray=[]
	for weapon in spec.weapons: weapons.append("%s · %d"%[str(NavalCatalog.WEAPONS[weapon].name),int(NavalCatalog.WEAPONS[weapon].ammo)])
	_label(box," · ".join(weapons))
	naval_deploy_button=_button(box,"IMPLANTAR" if data.state=="IN_PROGRESS" else "PRONTO",func(): network.request("ready"))
	naval_deploy_button.disabled=bool(own.get("ready",false))
	_update_deploy_button()
	if data.state=="WAITING" and data.owner==own_id:
		var button:=_button(box,"INICIAR PARTIDA",func(): network.request("start"))
		button.disabled=data.members.size()<2
		for member: Dictionary in data.members:
			if not bool(member.get("ready",false)): button.disabled=true
	elif data.state=="WAITING": _label(box,"AGUARDANDO")
	var addresses := PackedStringArray()
	if network.server_host == "127.0.0.1":
		var local := NavalDiscovery.local_addresses()
		if NavalCatalog.SERVER in local:
			local.erase(NavalCatalog.SERVER)
			local.push_front(NavalCatalog.SERVER)
		for address in local: addresses.append(address+":"+str(network.port))
	else: addresses.append(connection_endpoint)
	if addresses.is_empty(): addresses.append("127.0.0.1:"+str(network.port))
	var code := LineEdit.new()
	code.text = str(data.id) if _central_enabled() else addresses[0]+"#"+str(data.id)
	code.editable = false
	code.tooltip_text = "Convite da sala"
	box.add_child(code)
	_button(box,"COPIAR CÓDIGO",func(): DisplayServer.clipboard_set(code.text))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	box.add_child(actions)
	_button(actions,"MINHA FROTA",func(): _navigate("fleet")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(actions,"SAIR DA SALA",func(): network.request("leave")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network_status = _label(box,_firewall_label())
	if addresses.size()>1 and not _central_enabled():
		var options := OptionButton.new()
		for address in addresses: options.add_item(address)
		options.tooltip_text = "Outras interfaces de rede deste PC. Escolha a mesma rede dos amigos."
		options.item_selected.connect(func(index: int): code.text = addresses[index]+"#"+str(data.id))
		box.add_child(options)

func _event(kind: String, payload: Dictionary) -> void:
	match kind:
		"authenticated":
			connect_pending = false
			status.text = "Conectado"
			if feedback.text.begins_with("Preparando hospedagem"): feedback_left = 0.0
			_after_connected()
		"error":
			join_pending.clear()
			join_sent = false
			code_search = ""
			_refresh_rooms()
			feedback.text = str(payload.text)
			feedback_left = 6.0
			status.text = str(payload.text)
			if connect_pending:
				connect_pending = false
				after_host = ""
				create_pending.clear()
				network.close_connection()
			if not pending_purchase.is_empty():
				confirm_text.text = str(payload.text)
				confirm_button.disabled = false
				confirm_button.text = "TENTAR NOVAMENTE"
			notification.text = str(payload.text)
		"rooms": _refresh_rooms()
		"refresh_account": _refresh_account.call_deferred()
		"wallet":
			if payload.has("selection") and not NavalAccounts.testing(): _persist_selection.call_deferred(str(payload.selection))
			if payload.has("transaction") and payload.transaction == pending_purchase.get("transaction",""):
				pending_purchase.clear()
				if not focus.stack.is_empty() and focus.stack.back() == pages.confirm: focus.close_top()
			_refresh_fleet("shop")
			_refresh_fleet("fleet")
		"room":
			join_pending.clear()
			join_sent = false
			pending_navigation = ""
			code_search = ""
			feedback_left = 0.0
			status.text = "Conectado à sala · "+str(payload.name)
			if payload.state == "WAITING":
				_clear_world()
				_refresh_lobby()
				focus.close_all()
				_open("lobby")
			elif payload.state == "STARTING": status.text = "Iniciando partida..."
			elif payload.state == "IN_PROGRESS":
				if _deployment_confirmed():
					if current_match!=str(payload.match): focus.close_all();_build_world(str(payload.match))
					elif not focus.stack.is_empty() and focus.stack.back()==pages.lobby: focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
				elif world==null: _refresh_lobby();_open("lobby")
				else: _offer_naval_deployment(str(payload.match))
			elif payload.state == "FINISHED": _clear_world()
		"snapshot": _snapshot(payload)
		"left":
			_clear_world()
			focus.close_all()
			_open("home")
		"shot","impact","destroyed","respawn","damage": _combat_event(kind,payload)

func _build_world(match_id: String) -> void:
	_clear_world()
	current_match = match_id
	world = NavalWorld.new()
	add_child(world)
	world.build(true,int(network.room.get("map_seed",0)))
	death_view=GameDeathCamera.new()
	world.add_child(death_view)
	camera = NavalCamera.new()
	damage_numbers=GameDamageNumbers.new();world.add_child(damage_numbers)
	world.add_child(camera)
	camera.position = Vector3(0,24,30)
	camera.look_at(Vector3(0,2,0))
	camera.current = true
	camera.fov = 70.0
	camera.sensitivity = float(preferences.get("sensitivity",0.0016))
	prediction_line = MeshInstance3D.new()
	guide_mesh = ImmediateMesh.new()
	prediction_line.mesh = guide_mesh
	guide_last_launch.clear()
	guide_material = StandardMaterial3D.new()
	guide_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide_material.albedo_color = Color("f7d27a")
	prediction_line.material_override = guide_material
	world.add_child(prediction_line)
	impact_marker = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.7
	ball.height = 1.4
	impact_marker.mesh = ball
	impact_marker.material_override = guide_material
	world.add_child(impact_marker)
	_set_hud(true)
	GameOptions.apply(get_viewport(),world)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _clear_world() -> void:
	fire_held = false
	if is_instance_valid(damage_flash): damage_flash.reset()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	death_view = null
	camera = null
	audio_listener = null
	ships.clear()
	projectiles.clear()
	projectile_pool.clear()
	guide_last_launch.clear()
	seen.clear()
	latest_snapshot.clear()
	match_stats.clear();score_signature=""
	if is_instance_valid(scoreboard): scoreboard.hide()
	current_match = ""
	clock_initialized = false
	latest_tick = -1
	own_life = 0
	if ui: _set_hud(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _snapshot(data: Dictionary) -> void:
	if network.room.is_empty() or network.room.state != "IN_PROGRESS": return
	if str(data.get("match","")) != current_match or int(data.get("tick",-1)) < latest_tick: return
	latest_snapshot = data
	var signature:=JSON.stringify(data.get("scores",{}))
	if signature!=score_signature:
		score_signature=signature
		match_stats.receive(data.get("scores",{}).values())
	latest_tick = int(data.tick)
	if not clock_initialized:
		clock = float(data.time)
		clock_initialized = true
	received_at = Time.get_ticks_msec()*0.001
	var present: Dictionary = {}
	for state: Dictionary in data.ships:
		var id := int(state.peer)
		present[id] = true
		var ship: NavalShip = ships.get(id)
		if is_instance_valid(ship) and ship.kind != str(state.kind):
			ship.collision_layer = 0
			ship.queue_free()
			ships.erase(id)
			ship = null
		if not is_instance_valid(ship):
			ship = NavalShip.new()
			world.add_child(ship)
			ship.build(str(state.kind),id,str(state.identity),str(state.name))
			ships[id] = ship
			_add_health_bar(ship)
			if id==network.local_id():
				audio_listener=AudioListener3D.new();ship.add_child(audio_listener)
				audio_listener.position=Vector3(0,float(ship.spec.height)+1.6,-float(ship.spec.length)*.1)
				audio_listener.make_current()
		state["clock"] = float(data.time)
		ship.receive(state)
		ship.collision_layer = 0 if ship.dead else 2
	for id in ships.keys():
		if not present.has(id):
			world.forget_owner(str(id))
			ships[id].queue_free()
			ships.erase(id)
	var active: Dictionary = {}
	for shot: Dictionary in data.projectiles:
		active[shot.id] = true
		_ensure_projectile(shot)
	for id in projectiles.keys():
		if not active.has(id) and float(projectiles[id].get("seen_at",0.0)) < clock-0.1:
			_release_projectile(id)
	_update_hud()

func _add_health_bar(ship: NavalShip) -> void:
	var bar := MeshInstance3D.new()
	bar.name = "HealthBar"
	var quad := QuadMesh.new()
	quad.size = Vector2(3.5,0.16)
	bar.mesh = quad
	bar.position.y = float(ship.spec.height)+5.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = FieldTheme.ACCENT
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar.material_override = material
	ship.add_child(bar)

func _update_hud() -> void:
	var ship := _own_ship()
	if not is_instance_valid(ship): return
	hp_bar.max_value = float(ship.spec.hp)
	hp_bar.value = ship.hp
	telemetry.text = "%s · %d/%d HP\n%.1f m/s · %s" % [ship.spec.name,ship.hp,ship.spec.hp,absf(ship.speed),"RECARREGANDO %.1f s" % ship.reload_left if ship.reload_left>0.0 else ""]
	if ship.dead:
		fire_held = false
		notification.text = "IMPLANTAÇÃO EM %.1f s" % maxf(0.0,ship.respawn_at-clock)
	elif notification.text.begins_with("NAVIO DESTRUÍDO"): notification.text = ""
	if weapon_buttons.size() != ship.spec.weapons.size():
		for child in weapon_row.get_children(): child.queue_free()
		weapon_buttons.clear()
		for index in range(ship.spec.weapons.size()):
			var weapon: String = ship.spec.weapons[index]
			var button := _button(weapon_row,"",_select_weapon.bind(weapon))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.icon = GameUI.icon(weapon)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width",36)
			button.add_theme_font_size_override("font_size",12)
			weapon_buttons[weapon] = button

	for weapon in weapon_buttons:
		weapon_buttons[weapon].text = "%s%s\n%d / %d" % ["▶ " if selected==weapon else "",NavalCatalog.WEAPONS[weapon].name,ship.ammo[weapon],NavalCatalog.WEAPONS[weapon].ammo]
		weapon_buttons[weapon].disabled = ship.dead
		weapon_buttons[weapon].add_theme_stylebox_override("normal",weapon_styles[selected==weapon])
	if naval_hud: naval_hud.refresh(ship)
	var rows: Array = latest_snapshot.get("scores",{}).values()
	rows.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("points",0))>int(b.get("points",0)))
	rank.text = "COMANDANTE · PONTOS · A / M / AS\n"
	for row: Dictionary in rows: rank.text += "%s  %d · %d / %d / %d\n" % [str(row.name).left(15),int(row.get("points",0)),row.kills,row.deaths,int(row.get("assists",0))]

func scoreboard_context() -> Dictionary:
	return {"mode":"PVP NAVAL · LIVRE","map":"MAR ABERTO","seconds":clock,"time_label":"DECORRIDO","network":true,"teams":false,"objectives":str(network.room.get("name",""))}

func _own_ship() -> NavalShip:
	return ships.get(network.local_id()) if network.connection.has_multiplayer_peer() else null

func _select_weapon(weapon: String) -> void:
	var ship := _own_ship()
	if not is_instance_valid(ship) or weapon not in ship.spec.weapons: return
	selected = weapon
	# Selection and trigger travel together in one sequenced control packet.
	# Keyboard/wheel switches retain an already held trigger; UI clicks never
	# create one, and their release is caught before GUI event consumption.
	_send_input()
	_update_hud()

func _input(event: InputEvent) -> void:
	if dedicated: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		fire_held = false
		network.stop_fire()

func _unhandled_input(event: InputEvent) -> void:
	if dedicated: return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE):
		if focus.blocked() and focus.stack.back()==login_screen: return
		_go_back()
		get_viewport().set_input_as_handled()
		return
	if focus.blocked() or camera == null: return
	var ship := _own_ship()
	if not is_instance_valid(ship) or ship.dead: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: camera.mouse(event.relative,ship.kind,ship.selected)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				if event.pressed: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			fire_held = event.pressed
			if not fire_held: network.stop_fire()
			_send_input()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: camera.zoom = not camera.zoom
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			_select_weapon(ship.spec.weapons[posmod(ship.spec.weapons.find(selected)+step,ship.spec.weapons.size())])
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			fire_held = false
			network.stop_fire()
			network.request("reload")
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
			var index := int(event.physical_keycode)-KEY_1
			if index < ship.spec.weapons.size(): _select_weapon(ship.spec.weapons[index])

func _send_input() -> void:
	if bool(get_meta("test_controls",false)): return
	var ship := _own_ship()
	if not is_instance_valid(ship) or camera == null: return
	var allowed := not focus.blocked() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not ship.dead
	var throttle := (1.0 if Input.is_physical_key_pressed(KEY_W) else 0.0)-(1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0)
	var steer := (1.0 if Input.is_physical_key_pressed(KEY_A) else 0.0)-(1.0 if Input.is_physical_key_pressed(KEY_D) else 0.0)
	network.send_control(throttle if allowed else 0.0,steer if allowed else 0.0,camera.aim_point(ship,clock),selected,fire_held and allowed)

func _process(delta: float) -> void:
	if naval_loading:
		naval_loading.visible = connect_pending or join_sent
		naval_loading.detail.text = status.text
	if dedicated:
		_service_update()
		return
	_update_menu_music(delta)
	naval_deploy_clock+=delta
	if naval_deploy_clock>=.1: naval_deploy_clock=0;_update_deploy_button()
	_host_update()
	_resolution_update()
	if browse_dirty and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _refresh_rooms()
	if join_sent and Time.get_ticks_msec()*0.001-join_started>7.0:
		join_sent = false
		join_pending.clear()
		_room_feedback("O servidor não confirmou a entrada na sala. Atualize a busca e tente novamente.")
		_refresh_rooms()
	var firewall := _firewall_label()
	if is_instance_valid(network_status): network_status.text = firewall
	feedback_left = maxf(0.0,feedback_left-delta)
	feedback.visible = feedback_left > 0.0
	if connect_pending and Time.get_ticks_msec()*0.001-connect_started>9.0:
		connect_pending = false
		network.close_connection()
		status.text = "Sem resposta de "+connection_endpoint+". Use a busca da rede ou copie IP:porta do lobby. No PC anfitrião, permita o jogo no Firewall."
		feedback.text = status.text
		feedback_left = 10.0
		create_pending.clear()
		after_host = ""
		join_pending.clear()
		join_sent = false
		_refresh_rooms()
	if world == null: return
	var synchronized := float(latest_snapshot.get("time",0.0))+maxf(0.0,Time.get_ticks_msec()*0.001-received_at)
	clock += delta
	clock += clampf(synchronized-clock,-delta*0.10,delta*0.10)
	world.update_time(clock)
	for ship: NavalShip in ships.values():
		ship.interpolate(delta,clock)
		var bar := ship.get_node("HealthBar") as MeshInstance3D
		bar.visible = not ship.dead and ship != _own_ship()
		bar.scale.x = maxf(0.01,ship.hp/float(ship.spec.hp))
	var own := _own_ship()
	if not is_instance_valid(own): return
	if own.life != own_life:
		own_life = own.life
		selected = own.selected
		fire_held = false
		camera.initialized = false
		camera.follow(own,0.0)
	if not is_instance_valid(death_view) or not death_view.active: camera.follow(own,delta)
	if is_instance_valid(audio_listener): audio_listener.global_basis=camera.global_basis
	input_clock += delta
	if input_clock >= 0.05:
		input_clock = 0.0
		_send_input()
	guide_clock += delta
	if guide_clock >= 1.0/30.0:
		guide_clock = 0.0
		_update_guide(own)
	_update_projectiles()
	wake_clock += delta
	if wake_clock >= 0.22:
		wake_clock = 0.0
		for ship: NavalShip in ships.values():
			if ship.dead:
				world.effect(ship.global_position+Vector3.UP*3,Color("3c4448"),1.4,3.0,false,true)
			elif absf(ship.speed)>2.0:
				var stern := ship.to_global(Vector3(0,0,float(ship.spec.length)*0.43))
				stern.y = NavalCatalog.wave(stern,clock)+0.05
				world.effect(stern,Color("c3e7e2"),float(ship.spec.width)*0.8,1.2,true)

func _update_guide(ship: NavalShip) -> void:
	if ship.dead or not ship.turrets.has(selected):
		prediction_line.hide()
		impact_marker.hide()
		return
	var turret: NavalTurret = ship.turrets[selected]
	var launch := turret.launch(ship.velocity,clock)
	guide_last_launch = launch
	var excludes: Array[RID] = [ship.get_rid()]
	var prediction := NavalBallistics.prediction(world.get_world_3d(),launch,excludes)
	var points: PackedVector3Array = prediction.points
	var mesh := guide_mesh
	mesh.clear_surfaces()
	if points.size() > 1:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for index in range(points.size()-1):
			mesh.surface_add_vertex(points[index])
			mesh.surface_add_vertex(points[index+1])
		mesh.surface_end()
	prediction_line.show()
	impact_marker.visible = bool(prediction.hit)
	impact_marker.position = prediction.impact
	guide_material.albedo_color = Color("f7d27a") if turret.reachable and not turret.blocked else Color("eb835f")
	var distance := ship.global_position.distance_to(camera.aim_point(ship,clock))
	aim_label.text = "%d m%s" % [distance," · BLOQUEADO PELO CASCO" if turret.blocked else (" · FORA DO ALCANCE/LIMITE" if not turret.reachable else "")]

func _ensure_projectile(shot: Dictionary) -> void:
	if not bool(shot.get("tracer",true)): return
	if world == null or projectiles.has(shot.id) or seen.has("impact:"+str(shot.id)): return
	var node: NavalProjectileVisual
	if not projectile_pool.is_empty(): node = projectile_pool.pop_back()
	else:
		node = NavalProjectileVisual.new()
		world.add_child(node)
		node.build()
	node.setup(str(shot.weapon))
	var data := shot.duplicate()
	data.node = node
	data.seen_at = clock
	projectiles[shot.id] = data

func _release_projectile(id: String) -> void:
	if not projectiles.has(id): return
	var node: NavalProjectileVisual = projectiles[id].node
	projectiles.erase(id)
	node.hide()
	if projectile_pool.size()<192: projectile_pool.append(node)
	else: node.queue_free()

func _update_projectiles() -> void:
	for id in projectiles.keys():
		var shot: Dictionary = projectiles[id]
		var age := maxf(0.0,clock-float(shot.time))
		if age > NavalBallistics.duration(shot.velocity.length(),float(shot.range),float(shot.life),str(shot.weapon))+0.3:
			_release_projectile(str(id))
			continue
		shot.node.update_shot(shot,age,camera.global_position)
		if not shot.get("near_played",false) and int(shot.owner)!=network.local_id():
			var previous_age:=float(shot.get("audio_age",maxf(0,age-.02)))
			var a:=NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,previous_age,shot.weapon,shot.time)
			var b:=NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,age,shot.weapon,shot.time)
			if world.combat_feedback.near_listener(a,b,GameWeaponAudio.listener_position(get_viewport()),NavalBallistics.instantaneous_velocity(shot.velocity,shot.gravity,age,shot.weapon),shot.weapon): shot.near_played=true
		shot.audio_age=age
		if shot.weapon == "missile" and fmod(age,0.14)<0.025:
			var point := NavalBallistics.position(shot.origin,shot.velocity,shot.gravity,age,shot.weapon,shot.time)
			world.effect(point,Color("bdb8a1"),0.4,0.8)

func _combat_event(kind: String, payload: Dictionary) -> void:
	if world == null: return
	var id := kind+":"+str(payload.id)
	if seen.has(id): return
	seen[id] = true
	if seen.size()>1024: seen.erase(seen.keys()[0])
	if kind == "shot":
		_ensure_projectile(payload)
		world.sound(str(payload.weapon),payload.origin,str(payload.owner),maxf(0,clock-float(payload.time)))
		world.combat_visuals.flash(payload.origin)
		var ship: NavalShip = ships.get(int(payload.owner))
		if is_instance_valid(ship): ship.turrets[payload.weapon].show_recoil()
	elif kind == "impact":
		world.combat_feedback.impact(str(payload.id),payload.position,"water" if payload.water else ("vehicle" if payload.get("hit_ship",false) else "concrete"))
		if bool(payload.get("hit_ship",false)) and is_instance_valid(world.metal_sparks): world.metal_sparks.burst(payload.position,Vector3.UP,str(payload.id))
		if payload.weapon in ["missile","torpedo"]: world.effect(payload.position+Vector3.UP,Color(.28,.29,.27,.45),2.4,4.5,false,true)
		if projectiles.has(payload.id):
			_release_projectile(str(payload.id))
		world.effect(payload.position,Color("c6ebeb") if payload.water else Color("ffb35f"),0.7 if payload.weapon in ["lightMG","heavyMG"] else 3.5,0.5)
		if payload.water: world.effect(payload.position+Vector3.UP*0.05,Color("d1f2ec"),2.0,1.0,true)
		if payload.weapon in ["missile","torpedo"]: world.play_explosion_sound(payload.position,str(payload.id)+":impact")
	elif kind == "destroyed":
		world.explosion(payload.position,str(payload.id))
		notification.text = "%s destruiu %s" % [payload.killer,payload.victim]
		var own:=_own_ship()
		if is_instance_valid(own) and own.ship_id==str(payload.get("ship","")) and death_view:
			fire_held=false
			death_view.follow(own,payload.position,-own.global_basis.z,1.2)
	elif kind=="damage":
		if int(payload.owner)==network.local_id() and is_instance_valid(damage_numbers): damage_numbers.show_damage(str(payload.id),payload.position,float(payload.amount),false,true)
		if int(payload.target)==network.local_id() and is_instance_valid(damage_flash): damage_flash.pulse(float(payload.amount),100*float(payload.get("hp",100))/maxf(1,float(payload.get("max_hp",100))))
	elif kind == "respawn":
		if int(payload.peer) == network.local_id():
			if is_instance_valid(damage_flash): damage_flash.reset()
			if death_view: death_view.stop()
			fire_held = false
			camera.initialized = false

func _disconnected() -> void:
	connect_pending = false
	join_pending.clear()
	join_sent = false
	code_search = ""
	pending_navigation = ""
	discovery.lookup_room = ""
	resolving.clear()
	_clear_world()
	focus.close_all()
	_open("home")
	status.text = "Conexão encerrada."

func _close_mode() -> void:
	if closing: return
	closing = true
	navigation_generation += 1
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	if not network.room.is_empty(): network.request("leave")
	network.close_connection()
	_clear_world()
	focus.close_all()
	# Never remove a whole Control/Viewport tree during its input dispatch.
	closed.emit.call_deferred()

func _firewall_label() -> String:
	if network.server_host != "127.0.0.1": return ""
	var result := hosting.firewall_status()
	if result.get("state") == "allowed": return "Acesso do aplicativo permitido pelo Firewall."
	if result.get("state") == "denied": return "Permissão de rede pendente: "+str(result.get("message",""))+" Abra Configurações para tentar novamente."
	return "Se o Windows pedir permissão de rede, permita o acesso para os amigos conectarem."

func _service_ready() -> void:
	service_started = Time.get_ticks_msec()*0.001
	auto_service = "--naval-auto-host" in OS.get_cmdline_user_args()
	var path := ""
	var token := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--naval-ready="): path = arg.trim_prefix("--naval-ready=")
		if arg.begins_with("--naval-token="): token = arg.trim_prefix("--naval-token=")
		if arg.begins_with("--naval-idle-seconds="): service_idle_seconds = clampf(float(arg.trim_prefix("--naval-idle-seconds=")),1.0,120.0)
	if not path.is_empty():
		var data := {"pid":OS.get_process_id(),"port":network.port,"protocol":NavalCatalog.PROTOCOL,"token":token,"addresses":NavalDiscovery.local_addresses(),"heartbeat":Time.get_unix_time_from_system()}
		service_ready_path = path
		service_ready_data = data
		if not NavalStorage.write_json(path,data): get_tree().quit(1)

func _service_update() -> void:
	if Time.get_unix_time_from_system()-status_heartbeat>2.0:
		status_heartbeat = Time.get_unix_time_from_system()
		NavalStorage.write_json(NavalStorage.folder().path_join("naval-status.json"),{"connections":network.users.size(),"rooms":network.rooms.size(),"updated":status_heartbeat})
	if not auto_service: return
	var now := Time.get_ticks_msec()*0.001
	if now-service_heartbeat>2.0 and not service_ready_data.is_empty():
		service_heartbeat = now
		service_ready_data.heartbeat = Time.get_unix_time_from_system()
		NavalStorage.write_json(service_ready_path,service_ready_data)
		NavalStorage.write_json(NavalStorage.folder().path_join("hosting/active.json"),service_ready_data)
	if not network.users.is_empty(): had_clients = true
	if network.rooms.is_empty() and network.users.is_empty():
		if service_empty_since == 0.0: service_empty_since = now
		if (had_clients and now-service_empty_since>service_idle_seconds) or (not had_clients and now-service_started>35.0): get_tree().quit()
	else: service_empty_since = 0.0

func _join_by_code() -> void:
	if connect_pending or join_sent or not code_search.is_empty(): return
	if not network.room.is_empty():
		_refresh_lobby()
		focus.close_all()
		_open("lobby")
		return
	var value := room_code.text.strip_edges()
	var parts := value.split("#",false)
	var room_id := str(parts[-1]).strip_edges().to_lower() if not parts.is_empty() else ""
	if room_id.length()!=32 or not room_id.is_valid_hex_number(false) or parts.size()>2:
		_room_feedback("Código inválido. Cole o convite completo ou os 32 caracteres do código da sala.")
		return
	var payload := {"id":room_id,"password":join_password.text}
	if _central_enabled():
		_enter_room(_central_endpoint(),payload)
		return
	if parts.size()==2:
		var endpoint := NavalNetwork.parse_endpoint(str(parts[0]).strip_edges())
		if endpoint.is_empty():
			_room_feedback("Endereço do convite inválido. Copie novamente no lobby do amigo.")
			return
		_enter_room(NavalNetwork.format_endpoint(str(endpoint.host),int(endpoint.port)),payload)
		return
	var server := discovery.find_room(room_id)
	if not server.is_empty():
		_enter_room(str(server.endpoint),payload)
		return
	# Never send a bare code to an unrelated authenticated server.
	join_pending = payload
	code_search = room_id
	discovery.lookup_room = room_id
	resolve_started = Time.get_ticks_msec()*0.001
	discovery.scan(network.server_host if network.authenticated else address_field.text.strip_edges().get_slice(":",0))
	_room_feedback("Procurando a sala pelo código na rede local...")

func _install_naval_theme() -> void:
	focus.shield.theme = GameUI.THEME

func _build_account_ui() -> void:
	login_screen = preload("res://scenes/ui/LoginScreen.tscn").instantiate()
	login_screen.service = accounts_service
	focus.add_child(login_screen)
	login_screen.hide()
	pages["account"] = login_screen
	login_name = login_screen.username
	login_password = login_screen.password
	login_confirm = login_screen.confirmation
	login_status = login_screen.status
	login_screen.authenticated.connect(_account_ready)
	login_screen.activity_changed.connect(func(active: bool): account_busy = active)
	if not is_instance_valid(menu_music):
		menu_music = GameMenuMusic.new()
		menu_music.volume_db = -60
		add_child(menu_music)
	login_screen.visibility_changed.connect(func():
		if menu_music is GameMenuMusic:
			menu_music.set_login_active(login_screen.is_visible_in_tree())
	)

func _restore_account() -> void:
	if closing: return
	_open("account")
	await login_screen.restore()

func _login_account(register: bool) -> void:
	if account_busy: return
	if login_screen.register_mode != register:
		login_screen.change_form(register)
		await get_tree().create_timer(0.28).timeout
	await login_screen.submit()

func _account_ready() -> void:
	if closing or not is_inside_tree(): return
	nickname = str(accounts_service.profile.username)
	account_label.text = "CONTA · %s   |   %d MOEDAS" % [nickname,int(accounts_service.profile.coins)]
	focus.close_all()
	_open_initial_page()
	account_connected.emit()

func _open_initial_page() -> void:
	# Consume the requested destination only after restoring the session.
	# Opening it earlier races the asynchronous login success transition.
	var destination := initial_page
	initial_page = "home"
	if destination in ["shop","fleet"]: _navigate(destination)
	else: _open(destination if pages.has(destination) else "home")

func _refresh_account() -> void:
	if NavalAccounts.testing(): return
	var result := await accounts_service.call_api("profile")
	if result.get("ok",false):
		if network.authenticated: network.request("profile",accounts_service.ticket)
		account_label.text = "CONTA · %s   |   %d MOEDAS" % [nickname,int(accounts_service.profile.coins)]

func _logout_account() -> void:
	if NavalAccounts.testing(): return
	if account_busy: return
	account_busy = true
	if not network.room.is_empty(): network.request("leave")
	network.close_connection()
	_clear_world()
	await accounts_service.logout()
	account_busy = false
	focus.close_all()
	_open("account")
	login_screen._set_state(GameLoginScreen.State.LOGIN_IDLE)
	if login_screen.register_mode: login_screen.change_form(false)
	login_status.text = "Conta desconectada."

func _update_menu_music(delta: float) -> void:
	if not is_instance_valid(menu_music) or menu_music.stream == null: return
	var in_menu := world == null
	if in_menu and not menu_music.playing: menu_music.play()
	menu_music.volume_db = move_toward(menu_music.volume_db,-10.0 if in_menu else -60.0,delta*55.0)
	if not in_menu and menu_music.volume_db<=-59.9: menu_music.stop()


func _deployment_confirmed() -> bool:
	if network.room.is_empty(): return false
	for member: Dictionary in network.room.get("members",[]):
		if int(member.peer)==network.local_id(): return bool(member.get("ready",false))
	return false

func _offer_naval_deployment(match_id: String) -> void:
	if naval_death_menu_id==match_id: return
	naval_death_menu_id=match_id
	await get_tree().create_timer(1.4).timeout
	if not is_inside_tree() or closing or current_match!=match_id: return
	if not _deployment_confirmed(): _refresh_lobby();_open("lobby")
	naval_death_menu_id=""

func _update_deploy_button() -> void:
	if not is_instance_valid(naval_deploy_button): return
	var ship:=_own_ship()
	var left:=maxf(0,ship.respawn_at-clock) if is_instance_valid(ship) and ship.dead else 0.0
	naval_deploy_button.disabled=_deployment_confirmed() or left>0
	naval_deploy_button.text=("%.0f s"%ceilf(left)) if left>0 else ("IMPLANTAR" if network.room.get("state","")=="IN_PROGRESS" else "PRONTO")

