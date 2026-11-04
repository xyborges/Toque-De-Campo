@tool
extends Theme
class_name FieldTheme

# Palette extracted from the existing login. Keep its identity authoritative.
const INK := Color("e7ede8")
const MUTED := Color("97aaa9")
const ACCENT := Color("b7cca1")
const BAD := Color("ecaa98")
const BASE := Color("071013")
const PANEL := Color(0.06,0.10,0.11,0.96)
const FIELD := Color(0.06,0.10,0.11,0.88)
const BORDER := Color("364746")
const HOVER := Color("1e302f")
const PRESSED := Color("2e443d")
const ON_ACCENT := Color("14231b")
const DISABLED := Color("667976")
const RADIUS := 2
const SPACE := 8

static func box(bg: Color = PANEL, border: Color = BORDER, padding: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(RADIUS)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _init() -> void:
	default_font_size = 15
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift","Segoe UI","DejaVu Sans"])
	default_font = font
	for kind in ["Button","OptionButton","MenuButton","LineEdit","SpinBox","TextEdit"]:
		set_color("font_color",kind,INK)
		set_color("font_hover_color",kind,INK)
		set_color("font_pressed_color",kind,INK)
		set_color("font_disabled_color",kind,DISABLED)
		for state in ["normal","hover","pressed","disabled","focus","read_only"]:
			var bg := FIELD
			var edge := BORDER
			if state=="hover": bg = HOVER;edge = Color("70867b")
			if state=="pressed": bg = PRESSED
			if state=="focus": bg = Color.TRANSPARENT;edge = ACCENT
			var style := box(bg,edge,13)
			set_stylebox(state,kind,style)
	set_color("font_placeholder_color","LineEdit",Color("738784"))
	set_color("caret_color","LineEdit",ACCENT)
	set_color("selection_color","LineEdit",Color("3b574b"))
	set_color("font_color","Label",INK)
	set_stylebox("panel","PanelContainer",box())
	set_stylebox("panel","PopupMenu",box())
	set_color("font_color","PopupMenu",INK)
	set_stylebox("hover","PopupMenu",box(HOVER))
	set_stylebox("background","ProgressBar",box(Color("14221f"),Color.TRANSPARENT,0))
	set_stylebox("fill","ProgressBar",box(ACCENT,Color.TRANSPARENT,0))
	set_stylebox("slider","HSlider",box(Color("263833"),Color.TRANSPARENT,0))
	set_stylebox("grabber_area","HSlider",box(ACCENT,Color.TRANSPARENT,0))
	set_stylebox("grabber_area_highlight","HSlider",box(Color("cbdcba"),Color.TRANSPARENT,0))
	for state in ["normal","hover","pressed","disabled"]:
		var clear := box(Color.TRANSPARENT,Color.TRANSPARENT,0)
		clear.set_border_width_all(0)
		clear.set_content_margin_all(0)
		set_stylebox(state,"CheckBox",clear)
	set_color("font_color","CheckBox",INK)
	set_color("font_color","CheckButton",INK)
	set_color("font_color","TooltipLabel",INK)
	set_stylebox("panel","TooltipPanel",box())
	set_stylebox("scroll","VScrollBar",box(Color("14221f"),Color.TRANSPARENT,0))
	set_stylebox("grabber","VScrollBar",box(Color("536b5d"),Color.TRANSPARENT,0))

	for kind in ["ProgressBar","HSlider","VScrollBar"]:
		for style_name in get_stylebox_list(kind):
			var style := get_stylebox(style_name,kind) as StyleBoxFlat
			if style: style.set_content_margin_all(0)
	# HSlider draws its track using the style's minimum height. Zero margins
	# make the entire track disappear, leaving only the grabber visible.
	for style_name in ["slider","grabber_area","grabber_area_highlight"]:
		var track:=get_stylebox(style_name,"HSlider") as StyleBoxFlat
		track.content_margin_top=3;track.content_margin_bottom=3
