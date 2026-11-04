extends PanelContainer
class_name GameMenuPage
var content: VBoxContainer
var preview: GameItemPreview
var mode: NavalMode
var page_id := ""
var title := ""
func _ready() -> void:
	theme = GameUI.THEME
	set_meta("fullscreen",true)
	add_theme_stylebox_override("panel",FieldTheme.box(FieldTheme.BASE,Color.TRANSPARENT,26))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	column.add_child(header)
	GameUI.label(header,"TOQUE DE CAMPO / NAVAL",16,FieldTheme.ACCENT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in [["browse","SALAS"],["fleet","FROTA"],["shop","LOJA"],["settings","OPÇÕES"]]:
		var b := GameUI.button(header,item[1],func(): mode._navigate(item[0]) if item[0]!="settings" else mode._open("settings"))
		b.add_theme_font_size_override("font_size",12)
		if item[0]==page_id: GameUI.accent(b)
	GameUI.label(column,title,30)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	if page_id in ["home","fleet","shop","create","lobby"]:
		var aside := VBoxContainer.new()
		aside.custom_minimum_size.x = 300
		row.add_child(aside)
		preview = GameItemPreview.new()
		preview.custom_minimum_size = Vector2(300,240)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		aside.add_child(preview)
		resized.connect(func(): aside.visible = size.x>=1000)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	GameUI.label(footer,"PVP NAVAL",11,FieldTheme.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUI.button(footer,"MENU PRINCIPAL",mode.request_main_menu)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			if preview: preview.show_item(str(mode._profile().get("selected","light")))
			GameUI.fade(self)
	)
