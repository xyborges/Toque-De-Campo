extends Control
class_name GameLoadingScreen

var status: Label
var detail: Label
var progress: ProgressBar
var wait_label: Label
var elapsed := 0.0
var fade_tween: Tween

func _ready() -> void:
	theme = GameUI.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = FieldTheme.BASE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 440
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var kicker := GameUI.label(column,"TOQUE DE CAMPO / OPERAÇÃO",13,FieldTheme.ACCENT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status = GameUI.label(column,"PREPARANDO PARTIDA",30)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail = GameUI.label(column,"Preparando o campo de batalha...",15,FieldTheme.MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.indeterminate = true
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	column.add_child(progress)
	wait_label = GameUI.label(column,"CARREGANDO",12,FieldTheme.MUTED)
	wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _process(delta: float) -> void:
	if not visible: return
	elapsed += delta
	# Tempo real, sem apresentar percentual de carregamento fictício.
	var dots := ".".repeat(1 + int(elapsed * 2.5) % 3)
	wait_label.text = ("AGUARDANDO · %d s" % int(elapsed)) if elapsed >= 5.0 else ("CARREGANDO" + dots)

func present(title: String, description: String) -> void:
	if fade_tween and fade_tween.is_valid(): fade_tween.kill()
	elapsed = 0.0
	status.text = title
	detail.text = description
	modulate.a = 1.0
	show()

func fade_away() -> void:
	if not visible: return
	if fade_tween and fade_tween.is_valid(): fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(self,"modulate:a",0.0,0.24)
	fade_tween.tween_callback(func(): hide(); modulate.a = 1.0)
