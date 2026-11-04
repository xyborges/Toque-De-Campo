extends Control
class_name GameLoadingScreen
var status: Label
var detail: Label
var progress: ProgressBar
var elapsed := 0.0
func _ready() -> void:
	theme = GameUI.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = FieldTheme.BASE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	column.add_theme_constant_override("separation",18)
	center.add_child(column)
	GameUI.label(column,"TOQUE DE CAMPO",13,FieldTheme.ACCENT)
	status = GameUI.label(column,"PREPARANDO PARTIDA",30)
	detail = GameUI.label(column,"Aguardando o servidor...",14,FieldTheme.MUTED)
	progress = ProgressBar.new()
	progress.indeterminate = true
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	column.add_child(progress)
