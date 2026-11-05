extends Control
class_name GameMainMenu
var game: Node
var tabs: Dictionary = {}
var pages: Dictionary = {}
var body: MarginContainer
var play_cards: Container
var page_scroll: ScrollContainer
var account: Label
var status: Label
var nickname: LineEdit
var address: LineEdit
var page_title: Label
var hero_title: Label
var hero_detail: Label
var play_button: Button
var desert_training_button: Button
var war_offline_button: Button
var selected_mode := "office"
var mode_buttons: Dictionary = {}
var preview: GameItemPreview
var preview_info: Label
var weapon_selected := "ak"
var loadout_panel: GameLoadoutEditor
var loadout_mode: OptionButton
var credits_panel: PanelContainer
var character_skin: ColorPickerButton
var character_sliders: Dictionary = {}
var feedback: GameUIFeedback
var ranking_overlay: Control
var ranking_panel: PanelContainer
var ranking_widget: GameGlobalRanking
var preparation_preview: SubViewportContainer
var preparation_editor: GameLoadoutEditor
var preparation_team: OptionButton
var preparation_class: OptionButton
var preparation_roles: HBoxContainer
var preparation_slots: HBoxContainer
var preparation_panel: PanelContainer
var menu_shade: ColorRect
const MODES := {
	"office":["OFFLINE","ESCRITÓRIO","Treino contra NPCs. Combate e progresso no seu ritmo.","1 JOGADOR · NPCs"],
	"naval":["PVP NAVAL","MAR ABERTO","Salas online, navios e balística. Entre na frota.","2–6 JOGADORES · ONLINE"],
	"desert":["PVP DESERTO","DOMINAÇÃO · CASINHA","Cada jogador por si. Capture a casa, acumule pontos e reponha munição no interior.","2–6 JOGADORES · ONLINE"],
	"war":["GUERRA","LINHA DE FRENTE","Conquista, trincheiras, classes e blindados. Treine sozinho com bots ou dispute uma operação online.","OFFLINE COM BOTS · ONLINE 6v6"],
	"war_afghan":["GUERRA · AFEGÃO","DESERTO AFEGÃO","A mesma Conquista do modo Guerra no vale afegão. EUA contra Mujahidins, com bases, classes, blindados e bots.","OFFLINE COM BOTS · ONLINE 6v6"],
	"br":["BATTLE ROYALE","DESERTO AFEGÃO","Explore os vilarejos, encontre equipamento e sobreviva ao fechamento da zona.","INDIVIDUAL · 2 km × 2 km"]}
func _ready() -> void:
	name = "MainMenu"
	theme = GameUI.THEME
	weapon_selected = str(game.profile.get("equipped","ak"))
	if not GameWeapons.ITEMS.has(weapon_selected): weapon_selected = "ak"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preparation_preview=preload("res://scripts/ui/equipment_preview.gd").new();preparation_preview.name="PreparationBackground"
	preparation_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(preparation_preview)
	preparation_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu_shade=ColorRect.new();menu_shade.color=Color(.025,.05,.06,.12)
	menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(menu_shade)
	var header := PanelContainer.new()
	GameUI.rect(header,0,0,0,78)
	header.anchor_right = 1
	add_child(header)
	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation",22)
	header.add_child(header_box)
	GameUI.label(header_box,"TOQUE
DE CAMPO",19,FieldTheme.ACCENT).custom_minimum_size.x = 130
	var nav := HBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(nav)
	for item in [["play","JOGAR"],["arsenal","ARSENAL"],["person","PERSONAGEM"],["shop","LOJA"],["settings","CONFIGURAÇÕES"]]:
		var b := GameUI.button(nav,item[1],show_page.bind(item[0]))
		b.add_theme_font_size_override("font_size",13)
		b.custom_minimum_size.x = 85
		tabs[item[0]] = b
	account = GameUI.label(header_box,"",13,FieldTheme.ACCENT)
	account.custom_minimum_size.x = 130
	body = MarginContainer.new()
	body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 98
	body.offset_bottom = -92
	body.add_theme_constant_override("margin_left",36)
	body.add_theme_constant_override("margin_right",36)
	add_child(body)
	page_scroll = ScrollContainer.new()
	page_scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.follow_focus = true
	body.add_child(page_scroll)
	for id in ["play","arsenal","person","shop","settings"]:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation",18)
		page_scroll.add_child(page)
		pages[id] = page
		page.hide()
	_build_play()
	_build_arsenal()
	_build_person()
	_build_shop()
	_build_settings()
	_build_ranking()
	var footer := PanelContainer.new()
	footer.anchor_top = 1
	footer.anchor_bottom = 1
	footer.anchor_right = 1
	footer.offset_top = -78
	add_child(footer)
	var foot := HBoxContainer.new()
	footer.add_child(foot)
	status = GameUI.label(foot,"ESCOLHA SEU CAMPO DE BATALHA",13,FieldTheme.MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUI.button(foot,"SAIR DA CONTA",game._main_logout)
	GameUI.button(foot,"SAIR",func(): get_tree().quit())
	feedback = GameUIFeedback.new()
	add_child(feedback)
	feedback.watch(self)
	resized.connect(_layout)
	visibility_changed.connect(func():
		if is_visible_in_tree(): refresh();GameUI.fade(self)
	)
	_layout()
	show_page("play")
func _page_head(id: String, kicker: String, title: String, detail: String) -> void:
	GameUI.label(pages[id],kicker,12,FieldTheme.ACCENT)
	GameUI.label(pages[id],title,34)
	if not detail.is_empty(): GameUI.label(pages[id],detail,14,FieldTheme.MUTED)
func _build_play() -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);pages.play.add_child(row)
	pages.play.mouse_filter=Control.MOUSE_FILTER_IGNORE;pages.play.size_flags_vertical=Control.SIZE_EXPAND_FILL
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var operations:=GameUI.panel(row);operations.custom_minimum_size.x=230
	var sidebar:=VBoxContainer.new();sidebar.add_theme_constant_override("separation",10);operations.add_child(sidebar)
	GameUI.label(sidebar,"OPERAÇÕES",18,FieldTheme.ACCENT)
	play_cards=VBoxContainer.new();sidebar.add_child(play_cards)
	for id in MODES:
		if id in ["war","war_afghan"] and not ProjectSettings.get_setting("gameplay/war_enabled",false): continue
		var b := GameUI.button(play_cards,MODES[id][0],_select_mode.bind(id))
		b.name = "Mode_"+id
		b.custom_minimum_size.y = 42
		b.add_theme_font_size_override("font_size",14)
		mode_buttons[id] = b
	var portrait:=VBoxContainer.new();portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL;portrait.custom_minimum_size.x=290;row.add_child(portrait)
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	GameUI.label(portrait,"SEU PERSONAGEM",20,FieldTheme.ACCENT)
	preparation_roles=HBoxContainer.new();portrait.add_child(preparation_roles)
	preparation_team=OptionButton.new();preparation_roles.add_child(preparation_team)
	for team in ["Ucrânia","Rússia"]:preparation_team.add_item(team)
	preparation_class=OptionButton.new();preparation_roles.add_child(preparation_class)
	for role in WarRules.CLASSES:preparation_class.add_item(str(WarRules.CLASSES[role].name));preparation_class.set_item_metadata(preparation_class.item_count-1,role)
	var saved:=GameLoadouts.war_last(game);preparation_team.select(int(saved.team));preparation_class.select(WarRules.CLASSES.keys().find(str(saved.role)))
	var space:=Control.new();space.mouse_filter=Control.MOUSE_FILTER_IGNORE;space.custom_minimum_size.y=300;space.size_flags_vertical=Control.SIZE_EXPAND_FILL;portrait.add_child(space)
	preparation_preview.slot_clicked.connect(_preparation_slot)
	preparation_slots=HBoxContainer.new();portrait.add_child(preparation_slots)
	for slot in ["sidearm","grenade","melee"]:GameUI.button(preparation_slots,GameLoadouts.TITLES[slot],_preparation_slot.bind(slot)).add_theme_font_size_override("font_size",12)
	preparation_panel=GameUI.panel(row);preparation_panel.custom_minimum_size.x=270
	var equipment:=VBoxContainer.new();preparation_panel.add_child(equipment);GameUI.label(equipment,"EQUIPAMENTO",18,FieldTheme.ACCENT)
	preparation_editor=GameLoadoutEditor.new();preparation_editor.preview=preparation_preview;equipment.add_child(preparation_editor)
	preparation_editor.changed.connect(func():preparation_preview.available=preparation_editor.choices)
	preparation_team.item_selected.connect(func(_index):_preparation_context_changed())
	preparation_class.item_selected.connect(func(_index):_preparation_context_changed())
	hero_title=GameUI.label(sidebar,"",18)
	hero_detail=GameUI.label(sidebar,"",13,FieldTheme.MUTED);hero_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hero_detail.custom_minimum_size.x=200
	play_button = GameUI.button(sidebar,"JOGAR",_play,true)
	play_button.name = "Deploy"
	desert_training_button = GameUI.button(sidebar,"TREINO NO DESERTO",func(): game.launch_from_menu("desert",true))
	desert_training_button.add_theme_font_size_override("font_size",12)
	war_offline_button=GameUI.button(sidebar,"TREINO OFFLINE · BOTS",func():
		if selected_mode=="br": game.launch_from_menu("br",true)
		elif selected_mode=="war_afghan": game.launch_from_menu("war_afghan",true)
		else: game.launch_from_menu("war",true)
	)
	war_offline_button.name="WarOffline"
	war_offline_button.add_theme_font_size_override("font_size",13)
	_select_mode("office")

func _gui_input(event: InputEvent) -> void:
	if is_instance_valid(preparation_preview) and pages.play.visible:
		preparation_preview._pointer(event)

func _process(_delta: float) -> void:
	if is_instance_valid(preparation_preview) and not preparation_preview.hovered.is_empty() and get_viewport().gui_get_hovered_control()!=self:
		preparation_preview._highlight("")

func _configure_preparation() -> void:
	if not is_instance_valid(preparation_editor):return
	var applicable:=selected_mode in ["office","desert","war","war_afghan"]
	preparation_panel.visible=applicable;preparation_slots.visible=applicable;preparation_roles.visible=selected_mode in ["war","war_afghan"]
	if not applicable:preparation_preview.show_item("person",game.profile);preparation_preview.available={};return
	var kind: String={"office":"offline_training","desert":"desert","war":"war","war_afghan":"war"}[selected_mode]
	preparation_editor.configure(game,kind,str(preparation_class.get_item_metadata(preparation_class.selected)),preparation_team.selected)
	preparation_preview.available=preparation_editor.choices
	for button in preparation_slots.get_children():button.visible=preparation_editor.choices.has(str({"Pistola":"sidearm","Granada":"grenade","Arma branca":"melee"}.get(button.text,"")))

func _preparation_context_changed() -> void:
	_configure_preparation()
	GameLoadouts.save(game,preparation_editor.mode,preparation_editor.slots,preparation_editor.role,preparation_editor.team)

func _preparation_slot(slot: String) -> void:
	if not preparation_editor.choices.has(slot):return
	if preparation_editor.rows.has(slot):preparation_editor._select(slot)
	else:
		# Opening an empty slot offers a choice; it does not equip on hover.
		preparation_editor.add_option.grab_focus();preparation_editor.add_option.show_popup()
func _select_mode(id: String) -> void:
	selected_mode = id
	for key in mode_buttons: GameUI.accent(mode_buttons[key],key==id)
	hero_title.text = MODES[id][1]
	hero_detail.text = MODES[id][2]
	play_button.text = "INICIAR TREINO" if id=="office" else ("VER SALAS NAVAIS" if id=="naval" else ("CONECTAR ONLINE" if id in ["war","war_afghan"] else "ENTRAR NO PVP"))
	if id=="br":play_button.text="INICIAR"
	if id in ["war","war_afghan"]:
		preparation_team.set_item_text(0,"EUA" if id=="war_afghan" else "Ucrânia")
		preparation_team.set_item_text(1,"Mujahidins" if id=="war_afghan" else "Rússia")
	desert_training_button.visible=id=="office"
	war_offline_button.visible=id in ["war","war_afghan","br"]
	_configure_preparation()
func _play() -> void:
	game.launch_from_menu(selected_mode)
func _build_arsenal() -> void:
	_page_head("arsenal","COLEÇÃO / INFANTARIA","SEU ARMAMENTO.","Selecione seu equipamento inicial entre as armas adquiridas.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	pages.arsenal.add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 240
	row.add_child(list)
	for id in GameWeapons.INFANTRY_IDS:
		var b := GameUI.button(list,GameWeapons.ITEMS[id].name.to_upper(),_select_weapon.bind(id))
		b.icon = GameUI.icon(id)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",36)
		b.set_meta("weapon_id",id)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	preview = GameItemPreview.new()
	preview.custom_minimum_size = Vector2(260,240)
	detail.add_child(preview)
	preview_info = GameUI.label(detail,"",17,FieldTheme.ACCENT)
	GameUI.button(detail,"EQUIPAR",_equip,true)
	loadout_mode=OptionButton.new()
	for entry in [["Offline · Escritório","offline_training"],["Offline · Deserto","offline_desert"],["PVP Deserto","desert"]]:
		loadout_mode.add_item(entry[0]);loadout_mode.set_item_metadata(loadout_mode.item_count-1,entry[1])
	detail.add_child(loadout_mode)
	loadout_panel=GameLoadoutEditor.new();detail.add_child(loadout_panel);loadout_panel.configure(game,"offline_training")
	loadout_mode.item_selected.connect(func(index): loadout_panel.configure(game,str(loadout_mode.get_item_metadata(index))))
func _select_weapon(id: String) -> void:
	weapon_selected = id
	preview.show_item(id)
	var item: Dictionary = GameWeapons.ITEMS[id]
	preview_info.text = "%s\nDano %.0f · alcance %.0f m%s" % [item.name,item.damage,item.range," · %d por carregador" % item.mag if item.kind=="firearm" else ""]
	for b in pages.arsenal.find_children("*","Button",true,false):
		if b.has_meta("weapon_id"): GameUI.accent(b,b.get_meta("weapon_id")==id)
func _equip() -> void:
	if weapon_selected not in game.profile.owned:
		status.text = "Indisponível."
		return
	var slot:=str({1:"sidearm",2:"primary",4:"melee"}.get(int(GameWeapons.ITEMS[weapon_selected].slot),""))
	if slot.is_empty(): return
	loadout_panel.slots[slot]=weapon_selected;loadout_panel._rebuild();loadout_panel._changed()
	game.profile["equipped"]=weapon_selected;game._save_profile();status.text=""
func _build_person() -> void:
	_page_head("person","COLEÇÃO","PERSONAGEM","")
	var row := HBoxContainer.new()
	pages.person.add_child(row)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 300
	row.add_child(controls)
	GameUI.label(controls,"APELIDO",11,FieldTheme.MUTED)
	nickname = LineEdit.new()
	nickname.name = "Nickname"
	nickname.text = game.profile.nickname
	nickname.placeholder_text = "Seu apelido"
	nickname.max_length = 24
	controls.add_child(nickname)
	var person := GameItemPreview.new()
	person.name="PersonPreview";person.custom_minimum_size=Vector2(270,310)
	person.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(person)
	for part in GameCharacterColors.DEFAULTS:
		var picker := ColorPickerButton.new();picker.text={"skin":"PELE","shirt":"CAMISA","pants":"CALÇA","boots":"BOTAS"}[part]
		picker.color=Color(GameCharacterColors.normalize(game.profile.get("colors",{}))[part]);picker.edit_alpha=false;controls.add_child(picker)
		character_sliders[part]=picker
		picker.color_changed.connect(func(color: Color):
			game.profile.colors=GameCharacterColors.normalize(game.profile.get("colors",{}));game.profile.colors[part]=color.to_html(false)
			game._save_profile();game.queue_character_save();person.show_item("person",game.profile)
		)
	GameUI.button(controls,"SALVAR PERSONAGEM",func(): game._read_profile_ui();game.queue_character_save();status.text = "Personagem salvo.",true)
func _build_shop() -> void:
	_page_head("shop","SUPRIMENTOS","LOJA","")
	var ship := GameUI.panel(pages.shop)
	var content := VBoxContainer.new()
	ship.add_child(content)
	GameUI.label(content,"ESTALEIRO NAVAL",24,FieldTheme.ACCENT)
	GameUI.label(content,"Patrulheiros, corvetas, destróieres e submarinos.",15,FieldTheme.MUTED)
	GameUI.button(content,"VER EMBARCAÇÕES",func(): game.open_naval_page("shop"),true)
	var infantry := GameUI.panel(pages.shop)
	var description := VBoxContainer.new()
	infantry.add_child(description)
	GameUI.label(description,"ARSENAL DE INFANTARIA",24)
	GameUI.label(description,"As compras de armas continuam disponíveis no arsenal durante a partida. Consulte seu equipamento antes de entrar.",14,FieldTheme.MUTED)
	GameUI.button(description,"VER COLEÇÃO DE ARMAS",show_page.bind("arsenal"))
func _build_settings() -> void:
	_page_head("settings","SISTEMA","CONFIGURAÇÕES.","Áudio, vídeo e preferências de cada modo.")
	var settings_grid:=GridContainer.new()
	settings_grid.columns=2
	settings_grid.add_theme_constant_override("h_separation",12)
	settings_grid.add_theme_constant_override("v_separation",12)
	pages.settings.add_child(settings_grid)
	for entry in [["VÍDEO",0],["ÁUDIO",1],["CONTROLES",2],["JOGABILIDADE",3],["INTERFACE",4],["NAVAL",5]]:
		var button:=GameUI.button(settings_grid,str(entry[0]),func(): game.settings_panel.present(int(entry[1])))
		button.custom_minimum_size=Vector2(220,54)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	GameUI.label(pages.settings,"Configurações compartilhadas entre o menu e a partida. Preferências específicas ficam na categoria do respectivo modo.",14,FieldTheme.MUTED)
	GameUI.button(pages.settings,"CRÉDITOS",_credits)
	address = LineEdit.new()
	address.text = NavalCatalog.SERVER
	address.visible = not game._central_pvp()
	address.placeholder_text = "IP do anfitrião"
	pages.settings.add_child(address)
	var host := GameUI.button(pages.settings,"HOSPEDAR PVP LOCAL",func(): game.host_game("pvp"))
	host.visible = not game._central_pvp()
func _build_ranking() -> void:
	var toggle:=GameUI.button(self,"RANKING GLOBAL ▾",func():
		ranking_overlay.visible=not ranking_overlay.visible
		if ranking_overlay.visible: ranking_widget.refresh_remote();GameUI.fade(ranking_panel)
	)
	GameUI.rect(toggle,-380,20,-160,58,Vector2(1,0));toggle.z_index=15
	ranking_overlay=Control.new();ranking_overlay.name="RankingDropdown";ranking_overlay.z_index=30
	ranking_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ranking_overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(ranking_overlay);ranking_overlay.hide()
	ranking_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: ranking_overlay.hide()
	)
	ranking_panel=GameUI.panel(ranking_overlay,18)
	GameUI.rect(ranking_panel,-610,-290,-24,290,Vector2(1,.5))
	ranking_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var content:=VBoxContainer.new();ranking_panel.add_child(content)
	var top:=HBoxContainer.new();content.add_child(top)
	GameUI.label(top,"RANKING GLOBAL",15,FieldTheme.ACCENT).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	GameUI.button(top,"FECHAR",func(): ranking_overlay.hide()).custom_minimum_size.y=28
	var scrolling:=ScrollContainer.new();scrolling.size_flags_vertical=Control.SIZE_EXPAND_FILL;scrolling.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scrolling)
	ranking_widget=GameGlobalRanking.new();ranking_widget.accounts=game.main_accounts;ranking_widget.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scrolling.add_child(ranking_widget)

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and is_instance_valid(ranking_overlay) and ranking_overlay.visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		ranking_overlay.hide();get_viewport().set_input_as_handled()

func show_page(id: String) -> void:
	if is_instance_valid(ranking_overlay): ranking_overlay.hide()
	menu_shade.color.a=.12 if id=="play" else .82
	for key in pages: pages[key].visible = key==id
	for key in tabs: GameUI.accent(tabs[key],key==id)
	page_scroll.scroll_vertical = 0
	if id=="arsenal": _select_weapon(weapon_selected)
	if id=="person":
		var person := pages.person.find_child("PersonPreview",true,false) as GameItemPreview
		person.show_item("person",game.profile)
	GameUI.fade(pages[id])
	if id=="play":pages.play.mouse_filter=Control.MOUSE_FILTER_IGNORE
func refresh() -> void:
	account.text = "%s\n%d MOEDAS" % [game.profile.nickname,int(game.profile.coins)]
	_configure_preparation()
	if is_instance_valid(loadout_panel): loadout_panel.configure(game,str(loadout_mode.get_item_metadata(loadout_mode.selected)))
	if is_instance_valid(character_skin): character_skin.color=Color(str(game.profile.skin))
	for part in character_sliders: character_sliders[part].color=Color(GameCharacterColors.normalize(game.profile.get("colors",{}))[part])
func _layout() -> void:
	if is_instance_valid(ranking_panel):
		ranking_panel.offset_left=-minf(610,size.x-24);ranking_panel.offset_top=-minf(290,size.y*.39);ranking_panel.offset_bottom=minf(290,size.y*.39)
	var compact := size.x<1050
	if play_cards is GridContainer: play_cards.columns=2 if compact else mini(4,mode_buttons.size())
	body.add_theme_constant_override("margin_left",20 if compact else 36)
	body.add_theme_constant_override("margin_right",20 if compact else 36)
	for b in tabs.values():
		b.custom_minimum_size.x = 64 if compact else 85
		b.add_theme_font_size_override("font_size",11 if compact else 13)

func _credits() -> void:
	if is_instance_valid(credits_panel):
		game.ui_focus.open(credits_panel)
		return
	var panel: PanelContainer = game._modal_card("CRÉDITOS · FOTOGRAFIAS E ÁUDIO")
	credits_panel = panel
	var content := panel.find_child("Content",true,false) as VBoxContainer
	GameUI.label(content,"Fotografias ilustrativas. Os mapas utilizam os modelos do próprio jogo.",14,FieldTheme.MUTED)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/modes/credits.json"))
	if data is Dictionary:
		for id in data:
			GameUI.label(content,"%s · %s" % [MODES[id][0],data[id].author],15,FieldTheme.ACCENT)
			var url: String = data[id].source
			GameUI.button(content,"VER FOTOGRAFIA E AUTOR",func(): OS.shell_open(url))
	GameUI.button(content,"LICENÇA UNSPLASH",func(): OS.shell_open("https://unsplash.com/license"))
	GameUI.label(content,"GRAVAÇÕES DOS MOTORES",18,FieldTheme.ACCENT)
	var audio: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://audio/war/credits.json"))
	if audio is Array:
		for item: Dictionary in audio:
			GameUI.label(content,str(item.title)+" · "+str(item.authors)+" · "+str(item.license),14,FieldTheme.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			GameUI.button(content,"FONTE E AUTOR",OS.shell_open.bind(str(item.source)))
			GameUI.button(content,"LICENÇA "+str(item.license),OS.shell_open.bind(str(item.license_url)))
	GameUI.label(content,"Áudio adaptado: equalização, mistura, conversão mono e edição de loops. Sem endosso dos autores.",13,FieldTheme.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	GameUI.button(content,"VOLTAR",func(): game.ui_focus.close_top())
	game.ui_focus.open(panel)
