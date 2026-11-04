extends Control
class_name GameLoginScreen

signal authenticated
signal activity_changed(active: bool)
enum State { INITIALIZING, LOGIN_IDLE, REGISTER_IDLE, AUTHENTICATING, REGISTERING, SESSION_CHECK, AUTH_SUCCESS, AUTH_ERROR, CONNECTION_ERROR, TRANSITIONING }
var state := State.INITIALIZING
var service: NavalAccounts
var register_mode := false
var busy := false
var username: LineEdit
var password: LineEdit
var confirmation: LineEdit
var status: Label
var submit_button: Button
var switch_button: Button
var remember: CheckBox
var eye_button: Button
var user_error: Label
var password_error: Label
var confirm_error: Label
var confirm_group: VBoxContainer
var heading: Label
var subtitle: Label
var connection: Label
var form: VBoxContainer
var scroll: ScrollContainer
var brand: VBoxContainer
var scenery: LoginBackdrop
var shade: TextureRect
var curtain: ColorRect
var switch_tween: Tween
var show_tween: Tween
var probe: HTTPRequest
var probe_active := false
var probe_clock := 0.0
var last_result := HTTPRequest.RESULT_SUCCESS
var last_http := 0
var hover_at := -1.0
var ui_audio: AudioStreamPlayer
var sounds: Dictionary = {}
var loading_clock := 0.0
var cancel_intent := 0
const INK := FieldTheme.INK
const MUTED := FieldTheme.MUTED
const ACCENT := FieldTheme.ACCENT
const BAD := FieldTheme.BAD

func _ready() -> void:
	set_meta("fullscreen",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _theme()
	scenery = LoginBackdrop.new()
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scenery)
	shade = TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.30,0.48,0.75,1])
	gradient.colors = PackedColorArray([Color(0.025,0.05,0.06,1),Color(0.025,0.05,0.06,0.98),Color(0.025,0.05,0.06,0.86),Color(0.025,0.05,0.06,0.12),Color(0.025,0.05,0.06,0.16)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1024
	shade.texture = texture
	add_child(shade)
	brand = VBoxContainer.new()
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brand)
	var category := _label(brand,"MULTIPLAYER TÁTICO",11,MUTED)
	category.add_theme_constant_override("outline_size",0)
	_label(brand,"TOQUE DE CAMPO",25,INK)
	var line := ColorRect.new()
	line.color = ACCENT
	line.custom_minimum_size = Vector2(42,2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_child(line)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	form = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation",7)
	scroll.add_child(form)
	heading = _label(form,"BEM-VINDO\nAO CAMPO.",40,INK)
	heading.add_theme_constant_override("line_spacing",-4)
	subtitle = _label(form,"Entre na sua conta. Sua próxima partida começa aqui.",15,MUTED)
	subtitle.custom_minimum_size.y = 48
	username = _field(form,"USUÁRIO","Seu nome de usuário",24)
	user_error = _label(form,"",11,BAD)
	user_error.custom_minimum_size.y = 15
	_label(form,"SENHA",11,MUTED)
	var secret_row := HBoxContainer.new()
	secret_row.add_theme_constant_override("separation",0)
	form.add_child(secret_row)
	password = LineEdit.new()
	password.placeholder_text = "Sua senha"
	password.secret = true
	password.max_length = 128
	password.custom_minimum_size.y = 47
	password.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secret_row.add_child(password)
	eye_button = _button(secret_row,"",_toggle_password)
	eye_button.icon = _eye_icon(false)
	eye_button.custom_minimum_size = Vector2(54,47)
	eye_button.tooltip_text = "Mostrar ou ocultar senha"
	eye_button.accessibility_name = "Mostrar senha"
	password_error = _label(form,"",11,BAD)
	password_error.custom_minimum_size.y = 15
	confirm_group = VBoxContainer.new()
	confirm_group.add_theme_constant_override("separation",7)
	form.add_child(confirm_group)
	confirmation = _field(confirm_group,"CONFIRME A SENHA","Repita a senha",128)
	confirmation.secret = true
	confirm_error = _label(confirm_group,"",11,BAD)
	confirm_error.custom_minimum_size.y = 15
	confirm_group.hide()
	remember = CheckBox.new()
	remember.text = "Manter conectado neste computador"
	remember.button_pressed = service.persist_session
	remember.custom_minimum_size.y = 30
	remember.add_theme_font_size_override("font_size",13)
	form.add_child(remember)
	submit_button = _button(form,"ENTRAR",submit)
	submit_button.custom_minimum_size.y = 51
	submit_button.add_theme_color_override("font_color",Color("14231b"))
	submit_button.add_theme_color_override("font_hover_color",Color("14231b"))
	submit_button.add_theme_color_override("font_pressed_color",Color("14231b"))
	for variant in ["normal","hover","pressed"]:
		var style := _style(Color("b7cca1") if variant=="normal" else Color("cbdcba"),Color("cbdcba"))
		submit_button.add_theme_stylebox_override(variant,style)
	switch_button = _button(form,"CRIAR CONTA",func(): change_form(not register_mode))
	switch_button.custom_minimum_size.y = 40
	status = _label(self,"",13,MUTED)
	status.custom_minimum_size.y = 46
	status.max_lines_visible = 3
	var legal := _label(form,"Seu progresso fica vinculado à sua conta.\nNunca compartilhe sua senha.",11,Color("718886"))
	legal.name = "PrivacyNote"
	legal.custom_minimum_size.y = 36
	connection = Label.new()
	connection.text = "●  VERIFICANDO CONEXÃO"
	connection.add_theme_font_size_override("font_size",11)
	connection.add_theme_color_override("font_color",MUTED)
	connection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(connection)
	var exit_button := _button(self,"SAIR DO JOGO",func(): get_tree().quit())
	exit_button.name = "Exit"
	exit_button.add_theme_font_size_override("font_size",11)
	exit_button.custom_minimum_size = Vector2(125,32)
	var caption := Label.new()
	caption.name = "SceneCaption"
	caption.text = "PRONTO PARA A PRÓXIMA MISSÃO.\nUMA CONTA. TODAS AS SUAS PARTIDAS."
	caption.add_theme_font_size_override("font_size",12)
	caption.add_theme_color_override("font_color",Color("b8c7c4"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	curtain = ColorRect.new()
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color("071013")
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	ui_audio = AudioStreamPlayer.new()
	GameAudioSettings.ensure()
	ui_audio.bus = "Interface"
	ui_audio.volume_db = -26
	add_child(ui_audio)
	_make_sounds()
	probe = HTTPRequest.new()
	probe.timeout = 8
	probe.max_redirects = 0
	probe.body_size_limit = 4096
	add_child(probe)
	probe.request_completed.connect(_probe_done)
	service.connection_state.connect(_transport_state)
	for field in [username,password,confirmation]:
		field.text_submitted.connect(func(_text: String): submit())
		field.text_changed.connect(func(_text: String): _clear_field_errors())
	resized.connect(_layout)
	visibility_changed.connect(_visibility)
	_layout()
	_wire_focus()
	_set_state(State.LOGIN_IDLE)

func _label(parent: Node,text: String,pixels: int,color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",pixels)
	item.add_theme_color_override("font_color",color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func _field(parent: Node,title: String,hint: String,limit: int) -> LineEdit:
	_label(parent,title,11,MUTED)
	var item := LineEdit.new()
	item.placeholder_text = hint
	item.max_length = limit
	item.custom_minimum_size.y = 47
	parent.add_child(item)
	return item

func _button(parent: Node,text: String,action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(func(): _sound("click");action.call())
	item.mouse_entered.connect(func():
		if Time.get_ticks_msec()*0.001-hover_at>0.10 and not item.disabled:
			hover_at = Time.get_ticks_msec()*0.001
			_sound("hover")
	)
	parent.add_child(item)
	return item

func _style(bg: Color,border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _theme() -> Theme:
	return GameUI.THEME

func _eye_icon(revealed: bool) -> ImageTexture:
	var slash := '<path d="M4 4L20 20"/>' if revealed else ''
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24"><g fill="none" stroke="#b0c1ba" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12z"/><circle cx="12" cy="12" r="2.5"/>'+slash+'</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func _layout() -> void:
	if not is_instance_valid(brand): return
	var left := clampf(size.x*0.048,28,78)
	var width := clampf(size.x*0.32,320,430)
	if size.x<900: width = minf(width,size.x-56)
	var top := clampf(size.y*0.065,28,65)
	var compact := size.y<720
	if compact: top = 24
	brand.position = Vector2(left,top)
	brand.size = Vector2(width,78)
	scroll.position = Vector2(left,top+(80 if compact else 106))
	scroll.size = Vector2(width,size.y-scroll.position.y-115)
	heading.add_theme_font_size_override("font_size",26 if compact else (34 if size.y<800 else 40))
	subtitle.visible = not compact
	form.get_node("PrivacyNote").visible = not compact
	form.add_theme_constant_override("separation",4 if compact else 7)
	confirm_group.add_theme_constant_override("separation",4 if compact else 7)
	for field in [username,password,confirmation]: field.custom_minimum_size.y = 40 if compact else 47
	eye_button.custom_minimum_size.y = 40 if compact else 47
	remember.custom_minimum_size.y = 24 if compact else 30
	submit_button.custom_minimum_size.y = 42 if compact else 51
	switch_button.custom_minimum_size.y = 34 if compact else 40
	status.position = Vector2(left,size.y-105)
	status.size = Vector2(width,54)
	connection.position = Vector2(left,size.y-40)
	connection.size = Vector2(width,23)
	get_node("Exit").position = Vector2(size.x-154,top)
	get_node("SceneCaption").position = Vector2(size.x*0.62,size.y-90)
	get_node("SceneCaption").size = Vector2(size.x*0.35,55)
	get_node("SceneCaption").visible = size.x>=1000

func _wire_focus() -> void:
	var order: Array[Control] = [username,password,eye_button]
	if register_mode: order.append(confirmation)
	order.append_array([remember,submit_button,switch_button])
	for i in order.size():
		order[i].focus_next = order[i].get_path_to(order[(i+1)%order.size()])
		order[i].focus_previous = order[i].get_path_to(order[posmod(i-1,order.size())])

func focus_initial() -> void:
	if not busy and is_visible_in_tree(): username.grab_focus()

func _visibility() -> void:
	if is_instance_valid(scenery): scenery._visibility()
	if not is_visible_in_tree():
		if is_instance_valid(probe): probe.cancel_request()
		probe_active = false
		return
	curtain.modulate.a = 1
	if show_tween: show_tween.kill()
	show_tween = create_tween()
	show_tween.tween_property(curtain,"modulate:a",0.0,0.32)
	focus_initial.call_deferred()
	_probe.call_deferred()

func _set_state(value: State) -> void:
	state = value
	busy = value in [State.INITIALIZING,State.AUTHENTICATING,State.REGISTERING,State.SESSION_CHECK,State.AUTH_SUCCESS,State.TRANSITIONING]
	for item in [submit_button,switch_button,eye_button,remember]: item.disabled = busy
	for field in [username,password,confirmation]: field.editable = not busy
	submit_button.text = "CRIAR CONTA" if register_mode else "ENTRAR"
	if value==State.SESSION_CHECK: submit_button.text = "VERIFICANDO SESSÃO..."
	elif value in [State.AUTHENTICATING,State.REGISTERING]: submit_button.text = "CONECTANDO..."
	elif value in [State.AUTH_SUCCESS,State.TRANSITIONING]: submit_button.text = "ACESSO CONFIRMADO"
	activity_changed.emit(busy)

func change_form(register: bool) -> void:
	if busy or register_mode==register: return
	_set_state(State.TRANSITIONING)
	register_mode = register
	if switch_tween: switch_tween.kill()
	switch_tween = create_tween()
	switch_tween.tween_property(form,"modulate:a",0.0,0.10)
	switch_tween.tween_callback(func():
		confirmation.clear()
		confirm_group.visible = register_mode
		heading.text = "SUA PRÓXIMA\nMISSÃO COMEÇA." if register_mode else "BEM-VINDO\nAO CAMPO."
		subtitle.text = "Crie sua conta para reunir seu progresso em um só lugar." if register_mode else "Entre na sua conta. Sua próxima partida começa aqui."
		switch_button.text = "JÁ TENHO CONTA" if register_mode else "CRIAR CONTA"
		password.placeholder_text = "Pelo menos 12 caracteres" if register_mode else "Sua senha"
		status.text = ""
		_clear_field_errors()
		scenery.target_shift = 0.18 if register_mode else 0.0
		_wire_focus()
	)
	switch_tween.tween_property(form,"modulate:a",1.0,0.15)
	switch_tween.tween_callback(func():
		_set_state(State.REGISTER_IDLE if register_mode else State.LOGIN_IDLE)
		focus_initial()
	)

func _toggle_password() -> void:
	if busy: return
	var caret := password.caret_column
	password.secret = not password.secret
	confirmation.secret = password.secret
	eye_button.icon = _eye_icon(not password.secret)
	eye_button.accessibility_name = "Mostrar senha" if password.secret else "Ocultar senha"
	password.grab_focus()
	password.caret_column = caret

func _clear_field_errors() -> void:
	user_error.text = ""
	password_error.text = ""
	confirm_error.text = ""
	for field in [username,password,confirmation]: field.remove_theme_stylebox_override("normal")

func _field_error(field: LineEdit,label: Label,message: String) -> void:
	label.text = message
	field.add_theme_stylebox_override("normal",_style(Color("221e1d"),BAD))

func submit() -> void:
	if busy or not is_visible_in_tree(): return
	_clear_field_errors()
	var invalid := false
	if username.text.strip_edges().is_empty():
		_field_error(username,user_error,"Informe seu nome de usuário.")
		invalid = true
	if password.text.is_empty():
		_field_error(password,password_error,"Informe sua senha.")
		invalid = true
	if register_mode and password.text.length()<12 and not password.text.is_empty():
		_field_error(password,password_error,"Use uma senha com pelo menos 12 caracteres.")
		invalid = true
	if register_mode and confirmation.text!=password.text:
		_field_error(confirmation,confirm_error,"As duas senhas precisam ser iguais.")
		invalid = true
	if invalid:
		status.text = "Preencha os campos indicados para continuar."
		status.modulate = BAD
		_set_state(State.AUTH_ERROR)
		_sound("error")
		return
	probe.cancel_request()
	probe_active = false
	_set_state(State.REGISTERING if register_mode else State.AUTHENTICATING)
	status.modulate = MUTED
	status.text = "Criando sua conta..." if register_mode else "Confirmando suas credenciais..."
	connection.text = "●  CONECTANDO"
	connection.modulate = Color.WHITE
	last_result = HTTPRequest.RESULT_SUCCESS
	last_http = 0
	service.persist_session = remember.button_pressed
	var result := await service.sign_in("register" if register_mode else "login",username.text,password.text)
	# Preserve the existing security policy: clear secrets after a real authentication response.
	password.clear()
	confirmation.clear()
	password.secret = true
	confirmation.secret = true
	eye_button.icon = _eye_icon(false)
	if result.get("ok",false):
		await _success()
	else: _failure(result)

func restore() -> void:
	if service.token.is_empty():
		_set_state(State.LOGIN_IDLE)
		focus_initial.call_deferred()
		return
	_set_state(State.SESSION_CHECK)
	status.text = "Verificando sua sessão..."
	connection.text = "●  VERIFICANDO SESSÃO"
	var result := await service.call_api("profile")
	if result.get("ok",false): await _success()
	else: _failure(result)

func _success() -> void:
	_set_state(State.AUTH_SUCCESS)
	status.modulate = ACCENT
	status.text = "Tudo pronto, %s. Bem-vindo ao campo." % str(service.profile.username)
	connection.text = "●  CONECTADO"
	connection.modulate = ACCENT
	_sound("success")
	await get_tree().create_timer(0.25).timeout
	_set_state(State.TRANSITIONING)
	var fade := create_tween()
	fade.tween_property(curtain,"modulate:a",1.0,0.20)
	await fade.finished
	authenticated.emit()
	_set_state(State.LOGIN_IDLE)

func _failure(result: Dictionary) -> void:
	var message := str(result.get("error","Não foi possível entrar. Tente novamente."))
	if last_result==HTTPRequest.RESULT_TIMEOUT:
		message = "A conexão demorou mais que o esperado. Tente novamente."
	elif last_result!=HTTPRequest.RESULT_SUCCESS:
		message = "Não foi possível conectar ao servidor. Verifique sua rede/VPN."
	elif last_http>=500:
		message = "O serviço está temporariamente indisponível. Tente novamente."
	elif last_http==401 and state==State.SESSION_CHECK:
		message = "Sua sessão expirou. Entre novamente."
	_set_state(State.CONNECTION_ERROR if last_result!=HTTPRequest.RESULT_SUCCESS or last_http>=500 else State.AUTH_ERROR)
	status.text = message
	status.modulate = BAD
	connection.text = "●  SERVIDOR INDISPONÍVEL" if state==State.CONNECTION_ERROR else "●  SERVIDOR CONECTADO"
	connection.modulate = BAD if state==State.CONNECTION_ERROR else ACCENT
	_sound("error")
	username.grab_focus() if username.text.is_empty() else password.grab_focus()

func _transport_state(result: int,http_status: int) -> void:
	if busy:
		last_result = result
		last_http = http_status

func _probe() -> void:
	if busy or probe_active or not is_visible_in_tree(): return
	var cert := X509Certificate.new()
	if cert.load(service.ca_path)!=OK: return
	probe.set_tls_options(TLSOptions.client(cert))
	probe_active = probe.request(service.api_url)==OK
	if not probe_active:
		connection.text = "●  SERVIDOR INDISPONÍVEL"
		connection.modulate = BAD

func _probe_done(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	probe_active = false
	if busy: return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	var available: bool = result==HTTPRequest.RESULT_SUCCESS and code==200 and data is Dictionary and data.get("ok",false)
	connection.text = "●  SERVIDOR CONECTADO" if available else "●  SERVIDOR INDISPONÍVEL"
	connection.modulate = ACCENT if available else BAD

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if not busy:
			if register_mode: change_form(false)
			else: status.text = "";_clear_field_errors()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	probe_clock += delta
	if probe_clock>15:
		probe_clock = 0
		_probe()
	loading_clock += delta
	if state in [State.AUTHENTICATING,State.REGISTERING]:
		submit_button.text = "CONECTANDO"+".".repeat(1+int(loading_clock*3)%3)

func _make_sounds() -> void:
	for kind in ["hover","click","success","error"]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var duration := 0.045 if kind in ["hover","click"] else 0.14
		var data := PackedByteArray()
		data.resize(int(duration*22050)*2)
		for i in data.size()/2:
			var t := float(i)/22050
			var frequency := 620.0 if kind=="hover" else (440.0 if kind=="click" else (740.0+t*1800 if kind=="success" else 210.0-t*700))
			var sample := sin(t*TAU*frequency)*0.30*pow(1.0-t/duration,2.0)
			data.encode_s16(i*2,int(sample*32767))
		stream.data = data
		sounds[kind] = stream

func _sound(kind: String) -> void:
	if not is_instance_valid(ui_audio): return
	if kind=="hover" and ui_audio.playing: return
	ui_audio.stream = sounds.get(kind)
	ui_audio.play()

