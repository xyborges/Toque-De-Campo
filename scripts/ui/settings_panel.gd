extends PanelContainer
class_name GameSettingsPanel
var game: Node
var focus: GameUIFocus
var tabs: TabContainer
var resolution: OptionButton
var window_mode: OptionButton
var antialias: OptionButton
var renderer: OptionButton
var renderer_status: Label
var ui_values: Dictionary={}
var confirmation: PanelContainer
var confirm_label: Label
var video_before: Dictionary={}
var video_left:=0.0
var video_pending:=false
var listening:=""
var binding_buttons: Dictionary={}
var key_feedback: Label
var save_timer: Timer
var aim_panel: GameAimSettingsPanel
var naval_sensitivity: HSlider
var naval_sensitivity_label: Label
var pending_files: Dictionary={}

func _ready() -> void:
	name="GameSettings";theme=GameUI.THEME;set_meta("fullscreen",true)
	set_meta("ui_back_action",Callable(self,"leave"))
	add_theme_stylebox_override("panel",FieldTheme.box(FieldTheme.BASE,FieldTheme.BORDER,24))
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",14);add_child(content)
	aim_panel=game.get("aim_settings_panel") as GameAimSettingsPanel
	if not is_instance_valid(aim_panel): aim_panel=GameAimSettingsPanel.new();focus.add_child(aim_panel)
	GameUI.label(content,"CONFIGURAÇÕES",28)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(tabs)
	save_timer=Timer.new();save_timer.wait_time=.35;save_timer.one_shot=true;add_child(save_timer);save_timer.timeout.connect(_flush)
	_video(_page("Vídeo"))
	var audio_page:=_page("Áudio");audio_page.add_child(GameAudioSettingsPanel.new())
	var voice_panel:=GameVoiceSettingsPanel.new();voice_panel.game=game;audio_page.add_child(voice_panel)
	_controls(_page("Controles"))
	if not game is NavalMode: _gameplay(_page("Jogabilidade"))
	_interface(_page("Interface"))
	_naval(_page("Naval"))
	GameUI.button(content,"EXPORTAR DIAGNÓSTICO",func():
		var output:=GameDiagnostics.export_report()
		if not output.is_empty():OS.shell_show_in_file_manager(ProjectSettings.globalize_path(output))
	)
	GameUI.button(content,"VOLTAR",leave)
	visibility_changed.connect(func():
		if visible: _refresh_preferences()
	)
	confirmation=PanelContainer.new();confirmation.theme=GameUI.THEME;confirmation.add_theme_stylebox_override("panel",FieldTheme.box())
	confirmation.set_meta("ui_back_action",Callable(self,"_revert_video"))
	confirmation.set_meta("preferred_size",Vector2(520,220))
	var box:=VBoxContainer.new();confirmation.add_child(box);GameUI.label(box,"Manter estas configurações?",22)
	confirm_label=GameUI.label(box,"",16,FieldTheme.MUTED)
	GameUI.button(box,"MANTER",_confirm_video,true);GameUI.button(box,"REVERTER",_revert_video)
	focus.add_child(confirmation);confirmation.hide();hide()

func _page(title: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",12);scroll.add_child(column);return column

func present(index:=0) -> void:
	_refresh_preferences()
	tabs.current_tab=clampi(index,0,tabs.get_tab_count()-1);focus.open(self)

func present_naval() -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)=="Naval":
			present(index)
			return
	present()

func leave() -> void:
	_flush()
	listening=""
	if game is NavalMode and not is_instance_valid(game.world) and game.launch_subpage=="settings" and focus.stack.size()==2 and focus.stack[0]==game.pages.home:
		# A settings shortcut opened from the main menu returns to its launcher.
		game._close_mode()
	elif game is NavalMode and focus.stack.size()<=1 and not is_instance_valid(game.world):
		# Navigation falls back to Naval home, never to an empty stage.
		game._open("home")
	else:
		focus.close_top()

func _refresh_preferences() -> void:
	if is_instance_valid(antialias): antialias.select(clampi(int(GameOptions.number("aa",0)),0,3))
	if is_instance_valid(renderer):
		renderer.select(maxi(0,GameOptions.RENDERERS.find(GameOptions.renderer_preference())))
		_refresh_renderer_status()
	if ui_values.has("war_vegetation"):ui_values.war_vegetation.select(maxi(0,GameOptions.vegetation_level()-1))
	if ui_values.has("render_distance"):ui_values.render_distance.select(GameOptions.SCENARIO.DISTANCES.find(GameOptions.scenario_distance()))
	if ui_values.has("lod_quality"):ui_values.lod_quality.select(clampi(int(GameOptions.number("lod_quality",1)),0,2))
	if ui_values.has("fov"): ui_values.fov.set_value_no_signal(GameOptions.number("fov",70 if game.get_meta("war_mode",false) else 76))
	if ui_values.has("opacity"): ui_values.opacity.set_value_no_signal(GameOptions.number("hud_opacity",1)*100)
	if ui_values.has("damage"): ui_values.damage.set_pressed_no_signal(GameOptions.flag("damage_text"))
	if ui_values.has("vsync"): ui_values.vsync.set_pressed_no_signal(GameOptions.flag("vsync",true))
	if ui_values.has("fps"): ui_values.fps.select(maxi(0,[0,60,90,120,144,240].find(int(GameOptions.number("fps",0)))))
	for action in binding_buttons: binding_buttons[action].text=GameOptions.key_name(action)
	_refresh_naval_preferences()
	for panel in find_children("*","VBoxContainer",true,false):
		if panel is GameAudioSettingsPanel: panel.refresh_values()

func _choice(parent: Node,label: String,items: Array,callback: Callable) -> OptionButton:
	GameUI.label(parent,label,14,FieldTheme.MUTED);var option:=OptionButton.new();parent.add_child(option)
	for item in items: option.add_item(str(item))
	option.item_selected.connect(callback);return option

func _video(column: Node) -> void:
	window_mode=_choice(column,"Tela",["Janela","Tela cheia"],func(index): resolution.disabled=index==1)
	window_mode.select(0 if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED else 1)
	resolution=_choice(column,"Resolução",["960 × 640","1280 × 800","1440 × 900","1920 × 1080"],func(_index): pass)
	var sizes:=[Vector2i(960,640),Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080)]
	for index in sizes.size(): resolution.set_item_metadata(index,sizes[index]);if_size_select(index,sizes[index])
	resolution.disabled=window_mode.selected==1
	GameUI.button(column,"APLICAR TELA",_apply_video)
	var presets:=_choice(column,"Qualidade",["Personalizada","Baixo","Médio","Alto","Ultra"],func(index):
		if index==0: return
		var selected: Dictionary=GameOptions.PRESETS[GameOptions.PRESETS.keys()[index-1]]
		for field in selected: GameOptions.set_value(field,selected[field])
		if is_instance_valid(antialias): antialias.select(clampi(int(selected.aa),0,3))
		_apply();_refresh_preferences();save_timer.start()
	)
	presets.tooltip_text="Antisserrilhado, escala de renderização e sombras."
	renderer=_choice(column,"Renderizador",["Compatibility","Forward+ · experimental"],func(index):
		GameOptions.set_value("renderer",GameOptions.RENDERERS[clampi(index,0,GameOptions.RENDERERS.size()-1)])
		GameOptions.flush();_refresh_renderer_status()
	)
	renderer.name="Renderer";renderer.select(maxi(0,GameOptions.RENDERERS.find(GameOptions.renderer_preference())))
	renderer.tooltip_text="Forward+ usa Vulkan e habilita o caminho gráfico moderno. A mudança entra após reiniciar o jogo."
	renderer_status=GameUI.label(column,"",13,FieldTheme.MUTED);renderer_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	GameUI.button(column,"REINICIAR PARA APLICAR RENDERIZADOR",_restart_renderer)
	_refresh_renderer_status()
	antialias=_choice(column,"Antisserrilhamento",["Desligado","MSAA 2×","MSAA 4×","MSAA 8×"],func(index):
		GameOptions.set_value("aa",clampi(index,0,3));_apply();save_timer.start()
	)
	antialias.name="Antialiasing";antialias.select(clampi(int(GameOptions.number("aa",0)),0,3))
	if not game is NavalMode:
		var distance:=_choice(column,"Distância de cenário",["250 m","400 m","650 m","900 m"],func(index):
			GameOptions.set_value("render_distance",GameOptions.SCENARIO.DISTANCES[index]);_apply();save_timer.start()
		)
		distance.name="ScenarioDistance";ui_values.render_distance=distance
		distance.select(GameOptions.SCENARIO.DISTANCES.find(GameOptions.scenario_distance()))
		var lod:=_choice(column,"Qualidade de LOD",["Baixo","Médio","Alto"],func(index):
			GameOptions.set_value("lod_quality",index);_apply();save_timer.start()
		)
		lod.name="ScenarioLOD";ui_values.lod_quality=lod;lod.select(clampi(int(GameOptions.number("lod_quality",1)),0,2))
		var vegetation:=_choice(column,"Vegetação",["Baixo","Médio","Alto"],func(index):
			GameOptions.set_value("war_vegetation",index+1);_apply();save_timer.start()
		)
		vegetation.name="WarVegetationQuality";ui_values.war_vegetation=vegetation
		vegetation.select(maxi(0,GameOptions.vegetation_level()-1))
	var vsync:=CheckBox.new();vsync.text="V-Sync";vsync.button_pressed=DisplayServer.window_get_vsync_mode()!=DisplayServer.VSYNC_DISABLED;column.add_child(vsync)
	ui_values.vsync=vsync
	vsync.toggled.connect(func(value): GameOptions.set_value("vsync",value);_apply();save_timer.start())
	var fps_values:=[0,60,90,120,144,240]
	var fps:=_choice(column,"Limite de FPS",["Sem limite","60","90","120","144","240"],func(index): GameOptions.set_value("fps",fps_values[index]);_apply();save_timer.start())
	ui_values.fps=fps
	fps.select(maxi(0,fps_values.find(Engine.max_fps)))

func if_size_select(index: int,value: Vector2i) -> void:
	if DisplayServer.window_get_size()==value: resolution.select(index)

func _refresh_renderer_status() -> void:
	if not is_instance_valid(renderer_status):return
	var active:=GameOptions.active_renderer();var wanted:=GameOptions.renderer_preference()
	var message:="Ativo: "+GameOptions.renderer_label(active)+"."
	if wanted!=active:message+=" Selecionado: "+GameOptions.renderer_label(wanted)+" — reinicie para aplicar."
	if GameOptions.values.has("renderer_error"):
		message+=" A última tentativa de Forward+ falhou ou foi revertida; Compatibility foi mantido."
	renderer_status.text=message

func _restart_renderer() -> void:
	var wanted:=GameOptions.renderer_preference()
	if wanted==GameOptions.active_renderer():
		_refresh_renderer_status()
		return
	GameOptions.flush()
	if GameOptions.launch_renderer(wanted)>0:
		get_tree().quit()
	else:
		_refresh_renderer_status()

func _controls(column: Node) -> void:
	GameUI.button(column,"SENSIBILIDADE",func():
		aim_panel.present(focus,game.aim_settings_context() if game.has_method("aim_settings_context") else "naval:light")
	)
	for action in GameOptions.ACTIONS:
		if game is NavalMode and str(action).begins_with("lean_"): continue
		if not InputMap.has_action(action): continue
		var row:=HBoxContainer.new();column.add_child(row);GameUI.label(row,GameOptions.ACTIONS[action],15).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var button:=GameUI.button(row,GameOptions.key_name(action),func(): listening=action;key_feedback.text="Pressione uma tecla.")
		button.custom_minimum_size.x=160;binding_buttons[action]=button
	key_feedback=GameUI.label(column,"",14,FieldTheme.BAD)
	var rows:=GameUI.label(column,control_text(),15,FieldTheme.MUTED);rows.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func control_text() -> String:
	if game.get_meta("battle_royale",false):return "Mouse · olhar\nClique · disparar / soco\nBotão direito · mirar\n1 / 2 · armas    3 · punhos\nF · recolher    H · curativo\nR · recarregar    Backspace · largar arma\nCtrl · agachar    Z · deitar\nV · FPP / TPP\nTab / I · mochila    P · resultados\nX · segurar para falar\nEsc · menu"
	if game is NavalMode: return "Mouse · mirar\nClique · disparar\nBotão direito · zoom\n1–4 · armamento\nR · recarregar\nTab · placar\nEsc · menu"
	var result:="Mouse · olhar\nClique · disparar\nBotão direito · mirar\n1–9 · equipamento\nG · granada\nR · recarregar\nV · FPP / TPP\nTab · placar\nEsc · menu"
	result+="\nX · segurar para falar"
	if game.get_meta("war_mode",false): result+="\nF · veículo\nC · câmera do veículo\nT · térmica\n1–2 · armas do veículo\nM · implantação\nB · drone"
	return result

func _naval_settings() -> Dictionary:
	if pending_files.has("settings.json"):
		return pending_files["settings.json"].duplicate(true)
	if game is NavalMode:
		return game.preferences.duplicate(true)
	return NavalStorage.read_json(NavalStorage.settings_folder().path_join("settings.json"))

func _naval(column: Node) -> void:
	GameUI.label(column,"CÂMERA NAVAL",18,FieldTheme.ACCENT)
	GameUI.label(column,"Sensibilidade do mouse",15)
	naval_sensitivity=HSlider.new()
	naval_sensitivity.name="NavalMouseSensitivity"
	naval_sensitivity.min_value=25
	naval_sensitivity.max_value=250
	naval_sensitivity.step=1
	naval_sensitivity.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_child(naval_sensitivity)
	naval_sensitivity_label=GameUI.label(column,"",14,FieldTheme.MUTED)
	naval_sensitivity.value_changed.connect(func(value: float):
		var saved:=_naval_settings()
		saved["sensitivity"]=value*.0016/100.0
		if game is NavalMode:
			game.preferences=saved.duplicate(true)
			if is_instance_valid(game.camera):
				game.camera.sensitivity=float(saved["sensitivity"])
		_queue_file("settings.json",saved)
		_update_naval_sensitivity_label()
	)
	GameUI.label(column,"MIRA NAVAL",18,FieldTheme.ACCENT)
	GameUI.button(column,"SENSIBILIDADE POR EMBARCAÇÃO E ARMA",func():
		aim_panel.present(focus,game.aim_settings_context() if game is NavalMode else "naval:light")
	)
	_refresh_naval_preferences()

func _refresh_naval_preferences() -> void:
	if not is_instance_valid(naval_sensitivity):return
	var saved:=_naval_settings()
	var raw: Variant=saved.get("sensitivity",.0016)
	var sensitivity:=.0016
	if (raw is float or raw is int) and is_finite(float(raw)) and float(raw)>0:
		sensitivity=float(raw)
	naval_sensitivity.set_value_no_signal(clampf(sensitivity/.0016*100.0,25.0,250.0))
	_update_naval_sensitivity_label()

func _update_naval_sensitivity_label() -> void:
	if is_instance_valid(naval_sensitivity_label):
		naval_sensitivity_label.text="Sensibilidade · %d%%"%int(naval_sensitivity.value)

func _gameplay(column: Node) -> void:
	if not game is NavalMode:
		GameUI.label(column,"Campo de visão",15)
		var fov:=HSlider.new();fov.min_value=60;fov.max_value=100;fov.step=1;fov.value=GameOptions.number("fov",70 if game.get_meta("war_mode",false) else 76);column.add_child(fov)
		ui_values.fov=fov
		fov.value_changed.connect(func(value): GameOptions.set_value("fov",value);_apply();save_timer.start())
	if game.get_meta("war_mode",false):
		var saved:=NavalStorage.read_json(NavalStorage.settings_folder().path_join("war-camera.json"))
		for field in ["distance","side"]:
			GameUI.label(column,"Distância da câmera" if field=="distance" else "Ombro",15)
			var slider:=HSlider.new();slider.min_value=2 if field=="distance" else .4;slider.max_value=4 if field=="distance" else 1.05;slider.step=.05;slider.value=float(saved.get(field,3.25 if field=="distance" else .72));column.add_child(slider)
			slider.value_changed.connect(func(value):
				saved[field]=value;_queue_file("war-camera.json",saved)
				if is_instance_valid(game.local_player):
					if field=="distance": game.local_player.shoulder_distance=value
					else: game.local_player.shoulder_side=value
			)

func _interface(column: Node) -> void:
	GameUI.label(column,"Opacidade do HUD",15)
	var opacity:=HSlider.new();opacity.min_value=65;opacity.max_value=100;opacity.step=1;opacity.value=GameOptions.number("hud_opacity",1)*100;column.add_child(opacity)
	ui_values.opacity=opacity
	opacity.value_changed.connect(func(value): GameOptions.set_value("hud_opacity",value/100);_apply();save_timer.start())
	var numbers:=CheckBox.new();numbers.text="Indicadores de dano";numbers.button_pressed=GameOptions.flag("damage_text");column.add_child(numbers)
	ui_values.damage=numbers
	numbers.toggled.connect(func(value): GameOptions.set_value("damage_text",value);save_timer.start())

func _apply() -> void:
	var world: Node=game.get("world") if game is NavalMode else game.get("world_root")
	GameOptions.apply(get_viewport(),world)
	var actor: GamePlayer=game.get("local_player") if not game is NavalMode else null
	if is_instance_valid(actor): actor._update_view()

func _apply_video() -> void:
	if video_pending or DisplayServer.get_name()=="headless": return
	video_before={"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if window_mode.selected==0: DisplayServer.window_set_size(resolution.get_item_metadata(resolution.selected))
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	video_pending=true;video_left=10;focus.open(confirmation)

func _confirm_video() -> void:
	if not video_pending: return
	video_pending=false;GameOptions.set_value("window_mode",window_mode.selected)
	var size: Vector2i=resolution.get_item_metadata(resolution.selected);GameOptions.set_value("window_size",[size.x,size.y]);GameOptions.flush()
	if is_instance_valid(focus) and focus.is_inside_tree() and confirmation in focus.stack: focus.close_top()

func _revert_video() -> void:
	if not video_pending: return
	video_pending=false;DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(video_before.size);DisplayServer.window_set_position(video_before.position);DisplayServer.window_set_mode(video_before.mode)
	if is_instance_valid(focus) and focus.is_inside_tree() and confirmation in focus.stack: focus.close_top()

func _process(delta: float) -> void:
	if not video_pending: return
	video_left-=delta;confirm_label.text="Revertendo em %d s"%maxi(0,ceili(video_left))
	if video_left<=0 or not confirmation.visible: _revert_video()

func _input(event: InputEvent) -> void:
	if listening.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if event.keycode==KEY_ESCAPE: listening="";key_feedback.text="";return
	var error:=GameOptions.bind(listening,event.physical_keycode if event.physical_keycode>0 else event.keycode)
	key_feedback.text=error
	if error.is_empty(): binding_buttons[listening].text=GameOptions.key_name(listening);listening=""

func _queue_file(name_text: String,data: Dictionary) -> void:
	pending_files[name_text]=data.duplicate(true);NavalStorage.mark_setting(name_text);save_timer.start()

func _flush() -> void:
	GameOptions.flush();GameAudioSettings.flush()
	for file in pending_files: NavalStorage.write_json(NavalStorage.settings_folder().path_join(file),pending_files[file])
	pending_files.clear()

func _exit_tree() -> void:
	_revert_video();_flush()
