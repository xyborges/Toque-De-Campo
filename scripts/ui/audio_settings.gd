extends VBoxContainer
class_name GameAudioSettingsPanel
var save_timer: Timer
var sliders: Dictionary={}
var labels: Dictionary={}
func _ready() -> void:
	GameAudioSettings.ensure()
	save_timer=Timer.new();save_timer.wait_time=.35;save_timer.one_shot=true;add_child(save_timer);save_timer.timeout.connect(GameAudioSettings.flush)
	for category in GameAudioSettings.LABELS:
		var row:=HBoxContainer.new();add_child(row)
		GameUI.label(row,GameAudioSettings.LABELS[category],15).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var value:=GameUI.label(row,"%d%%"%roundi(GameAudioSettings.get_volume(category)*100),14,FieldTheme.MUTED)
		value.autowrap_mode=TextServer.AUTOWRAP_OFF;value.custom_minimum_size.x=55;value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		labels[category]=value
		var slider:=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=GameAudioSettings.get_volume(category)*100;add_child(slider);sliders[category]=slider
		slider.value_changed.connect(func(percent: float):
			GameAudioSettings.set_volume(category,percent/100);value.text="%d%%"%roundi(percent);save_timer.start()
		)
	visibility_changed.connect(func():
		if not visible: GameAudioSettings.flush()
		else: refresh_values()
	)
func refresh_values() -> void:
	GameAudioSettings.ensure()
	for category in sliders:
		var percent:=GameAudioSettings.get_volume(category)*100
		sliders[category].set_value_no_signal(percent);labels[category].text="%d%%"%roundi(percent)
func _exit_tree() -> void: GameAudioSettings.flush()
