extends RefCounted
class_name GameUI

const THEME: Theme = preload("res://themes/field_theme.tres")
static var icons: Dictionary = {}

static func label(parent: Node, text: String, pixels: int = 15, color: Color = FieldTheme.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",pixels)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func button(parent: Node, text: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	parent.add_child(b)
	if primary: accent(b)
	return b

static func accent(b: Button, active: bool = true) -> void:
	for state in ["normal","hover","pressed"]:
		b.add_theme_stylebox_override(state,FieldTheme.box((FieldTheme.ACCENT if state=="normal" else Color("cbdcba")) if active else (FieldTheme.FIELD if state=="normal" else FieldTheme.HOVER),FieldTheme.ACCENT if active else FieldTheme.BORDER,4 if b.text.is_empty() else 13))
		b.add_theme_color_override("icon_normal_color",FieldTheme.ON_ACCENT if active else Color.WHITE)
		b.add_theme_color_override("icon_hover_color",FieldTheme.ON_ACCENT if active else Color.WHITE)
		b.add_theme_color_override("font_"+("color" if state=="normal" else state+"_color"),FieldTheme.ON_ACCENT if active else FieldTheme.INK)

static func hud_menu_button(parent: Node, action: Callable) -> Button:
	# All gameplay HUDs share one placement, hit area and label.
	var button := GameUI.button(parent,"MENU",action)
	GameUI.rect(button,-112,20,-22,60,Vector2(1,0))
	return button

static func panel(parent: Node, padding: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",FieldTheme.box(FieldTheme.PANEL,FieldTheme.BORDER,padding))
	parent.add_child(p)
	return p

static func fade(control: Control) -> void:
	var old: Variant = control.get_meta("ui_fade") if control.has_meta("ui_fade") else null
	if old is Tween and old.is_valid(): old.kill()
	control.modulate.a = 0.0
	if control.has_meta("ui_process_before"):control.process_mode=int(control.get_meta("ui_process_before"))
	control.mouse_filter=Control.MOUSE_FILTER_STOP
	control.show();control.pivot_offset=control.size*.5;control.scale=Vector2(.985,.985)
	var tween := control.create_tween()
	control.set_meta("ui_fade",tween)
	tween.set_parallel(true);tween.set_trans(Tween.TRANS_QUAD);tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control,"modulate:a",1.0,0.16)
	tween.tween_property(control,"scale",Vector2.ONE,0.16)

static func dismiss(control: Control) -> void:
	var old: Variant=control.get_meta("ui_fade") if control.has_meta("ui_fade") else null
	if old is Tween and old.is_valid():old.kill()
	if not control.has_meta("ui_process_before"):control.set_meta("ui_process_before",control.process_mode)
	control.mouse_filter=Control.MOUSE_FILTER_IGNORE;control.process_mode=Node.PROCESS_MODE_DISABLED
	var tween:=control.create_tween();control.set_meta("ui_fade",tween)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);tween.tween_property(control,"modulate:a",0.,.10)
	tween.tween_callback(func():control.hide();control.scale=Vector2.ONE)

static func scene_fade(parent: Node) -> void:
	if DisplayServer.get_name()=="headless":return
	var veil:=ColorRect.new();veil.color=Color("081014");veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.z_index=100;parent.add_child(veil)
	var tween:=veil.create_tween();tween.tween_property(veil,"modulate:a",0.,.22);tween.tween_callback(veil.queue_free)

static func rect(control: Control, left: float, top: float, right: float, bottom: float, anchor: Vector2 = Vector2.ZERO) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

static func icon(kind: String) -> Texture2D:
	if icons.has(kind): return icons[kind]
	var path := "M3 12h18M12 3v18"
	match kind:
		"broom","squeegee": path = "M7 3l9 12M11 15l7-5 4 6-7 5z"
		"axe": path = "M6 3l13 18M7 7l7-5 6 6-7 5z"
		"glock": path = "M2 7h18v5h-8l-1 8H6l1-8H2z"
		"ak","fal","g3","lightMG","heavyMG": path = "M2 10h16v4H9l-1 5H5l1-5H2zM18 11h5M11 14v5h3v-5M15 8v2"
		"sniper": path = "M2 10h18v3H8l-3 6H2l2-6M20 11h4M10 6h7v3h-7z"
		"grenade": path = "M9 7h7l3 5v7l-3 3H8l-3-3v-7zM10 7V3h5v4M15 3l4 2 3 9M9 12h7M8 16h9M9 20h7"
		"rpg": path = "M2 12l5-3h5l2 2h8v2h-8l-2 2H7zM12 13v6h2v-6M18 11V7h3v4"
		"stinger": path = "M2 10h20v5H2zM4 8v9M20 8v9M10 15v5h3v-5M7 10V5h8v5"
		"medkit": path = "M3 7h18v14H3zM8 7V3h8v4M12 10v8M8 14h8"
		"supply": path = "M3 7h18v14H3zM3 11h18M7 4h10v3M7 14v4M12 14v4M17 14v4"
		"spot": path = "M2 10h8v9H2zM14 10h8v9h-8zM5 10V6h3v4M16 10V6h3v4M10 13h4"
		"drone": path = "M9 9h6v6H9zM3 3h5v5H3zM16 3h5v5h-5zM3 16h5v5H3zM16 16h5v5h-5zM8 8l2 2M14 10l2-2M8 16l2-2M14 14l2 2"
		"missile","torpedo": path = "M3 12l5-4h11l3 4-3 4H8zM7 8V4l4 4M7 16v4l4-4"
		"naval": path = "M2 15h20l-4 5H6zM8 15V8h9v7M12 8V3M2 23l4-1 4 1 4-1 4 1 4-1"
		"desert": path = "M1 20l7-10 5 6 4-9 6 13M4 20h17M7 5h4"
		"office": path = "M4 21V4h16v17M8 8h2M14 8h2M8 12h2M14 12h2M10 21v-5h4v5"
		"person": path = "M8 7a4 4 0 1 0 8 0a4 4 0 1 0-8 0M4 22v-5q8-6 16 0v5"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><path fill="none" stroke="#b7cca1" stroke-width="1.4" stroke-linecap="square" stroke-linejoin="miter" d="'+path+'"/></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	icons[kind] = ImageTexture.create_from_image(image)
	return icons[kind]
