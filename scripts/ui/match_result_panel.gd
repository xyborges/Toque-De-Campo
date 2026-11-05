extends PanelContainer
class_name GameMatchResultPanel

# Reusable post-round ceremony. No death UI outside Battle Royale uses this.
var kicker: Label
var headline: Label
var description: Label
var note: Label
var timer: Label
var accent_line: ColorRect
var actions: HBoxContainer
var stat_titles: Array[Label] = []
var stat_values: Array[Label] = []
var stat_panels: Array[PanelContainer] = []
var intro_tween: Tween
var outcome_kind:="draw"
var cue: AudioStreamPlayer

func _ready() -> void:
	name = "MatchResult"
	theme = GameUI.THEME
	if DisplayServer.get_name()!="headless":
		GameAudioSettings.ensure()
		cue = AudioStreamPlayer.new()
		cue.bus = "Interface"
		cue.volume_db = -16.0
		add_child(cue)
	set_meta("ui_back_locked",true)
	set_meta("preferred_size",Vector2(760,480))
	add_theme_stylebox_override("panel",FieldTheme.box(FieldTheme.PANEL,FieldTheme.BORDER,30))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",17)
	add_child(body)
	kicker = GameUI.label(body,"TOQUE DE CAMPO / PÓS-PARTIDA",12,FieldTheme.MUTED)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	accent_line = ColorRect.new()
	accent_line.color = FieldTheme.ACCENT
	accent_line.custom_minimum_size.y = 4
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(accent_line)
	headline = GameUI.label(body,"RESULTADO",46,FieldTheme.ACCENT)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description = GameUI.label(body,"",17,FieldTheme.INK)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation",12)
	body.add_child(stats)
	for i in range(3):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel",FieldTheme.box(FieldTheme.FIELD,FieldTheme.BORDER,12))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.y = 83
		stats.add_child(panel)
		stat_panels.append(panel)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation",5)
		panel.add_child(column)
		var item_title := GameUI.label(column,"",11,FieldTheme.MUTED)
		item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_titles.append(item_title)
		var item_value := GameUI.label(column,"",24,FieldTheme.INK)
		item_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_values.append(item_value)
	note = GameUI.label(body,"",14,FieldTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer = GameUI.label(body,"",13,FieldTheme.ACCENT)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation",12)
	body.add_child(actions)
	hide()

func present(outcome: String, operation: String, explanation: String, detail: String, stats: Array) -> void:
	outcome_kind=outcome
	var tint := FieldTheme.ACCENT if outcome=="victory" else (FieldTheme.BAD if outcome=="defeat" else FieldTheme.MUTED)
	headline.text = "VITÓRIA" if outcome=="victory" else ("DERROTA" if outcome=="defeat" else ("EMPATE" if outcome=="draw" else "RESULTADO"))
	headline.add_theme_color_override("font_color",tint)
	accent_line.color = tint
	kicker.text = "TOQUE DE CAMPO  /  " + operation.to_upper()
	description.text = explanation
	note.text = detail
	note.visible = not detail.is_empty()
	for i in range(3):
		var valid := i < stats.size()
		stat_panels[i].visible = valid
		if valid:
			var item: Array = stats[i]
			stat_titles[i].text = str(item[0]).to_upper()
			stat_values[i].text = str(item[1])
	timer.text = ""
	timer.visible = false

func set_countdown(message: String) -> void:
	if timer.text==message: return
	timer.text = message
	timer.visible = not message.is_empty()

func intro() -> void:
	if is_instance_valid(cue) and outcome_kind in ["victory","defeat"]:
		cue.stream = _ceremony_tone(outcome_kind=="victory")
		cue.play()
	if intro_tween and intro_tween.is_valid(): intro_tween.kill()
	headline.modulate.a=0.0
	accent_line.modulate.a=0.0
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.set_trans(Tween.TRANS_CUBIC)
	intro_tween.set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(accent_line,"modulate:a",1.0,0.28)
	intro_tween.tween_property(headline,"modulate:a",1.0,0.42).set_delay(0.07)

# Lightweight original UI cue (not a combat sound or an imported recording).
func _ceremony_tone(victory: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.44 if victory else 0.36
	var samples := int(duration * stream.mix_rate)
	var raw := PackedByteArray()
	raw.resize(samples*2)
	var first := 392.0 if victory else 247.0
	var second := 587.0 if victory else 185.0
	for i in range(samples):
		var t := float(i)/stream.mix_rate
		var envelope := minf(1.0,t/0.035)*pow(maxf(0.0,1.0-t/duration),2.0)
		var value := (sin(t*TAU*first)+0.48*sin(t*TAU*second))*0.18*envelope
		raw.encode_s16(i*2,clampi(int(value*32767.0),-32767,32767))
	stream.data = raw
	return stream
