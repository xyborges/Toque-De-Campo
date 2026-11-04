extends VBoxContainer
class_name GameVoiceSettingsPanel

var game: Node
var relay: BRVoiceRelay
var toggle: CheckBox
var device: OptionButton
var status_text: Label
var people: VBoxContainer
var voices: Dictionary={}
var monitor: GameVoiceClient
var test_button: Button
var test_meter: ProgressBar
var test_left:=0.
var test_result:=""
var poll:=0.
var sliders: Dictionary={}
var values: Dictionary={}

func _ready() -> void:
	add_theme_constant_override("separation",10)
	GameUI.label(self,"VOZ POR PROXIMIDADE",17,FieldTheme.ACCENT)
	toggle=CheckBox.new();toggle.text="Chat de voz";toggle.button_pressed=GameVoiceSettings.enabled();add_child(toggle)
	toggle.toggled.connect(func(value: bool):GameVoiceSettings.set_option("voice_enabled",value);_apply())
	GameUI.label(self,"Microfone",14,FieldTheme.MUTED)
	device=OptionButton.new();add_child(device)
	for name_text in AudioServer.get_input_device_list():
		device.add_item(name_text)
		if name_text==GameVoiceSettings.input_device():device.select(device.item_count-1)
	device.item_selected.connect(func(index: int):GameVoiceSettings.set_input_device(device.get_item_text(index));_apply())
	_slider("voice_volume","Volume",0.,100.,GameVoiceSettings.volume()*100.,1.)
	GameUI.label(self,"X · SEGURAR PARA FALAR",12,FieldTheme.MUTED)
	status_text=GameUI.label(self,"",13,FieldTheme.BAD)
	test_button=GameUI.button(self,"TESTAR MICROFONE",_toggle_test)
	test_meter=ProgressBar.new();test_meter.max_value=1.;test_meter.show_percentage=false;test_meter.custom_minimum_size.y=12;add_child(test_meter)
	if OS.get_name()=="Windows":GameUI.button(self,"PERMISSÃO DO MICROFONE",func():OS.shell_open("ms-settings:privacy-microphone"))
	people=VBoxContainer.new();people.add_theme_constant_override("separation",6);add_child(people)
	visibility_changed.connect(func():
		if is_visible_in_tree():_refresh()
		else:_stop_test()
	)
	_refresh()

func _slider(key: String,title: String,minimum: float,maximum: float,initial: float,step_value: float) -> void:
	var row:=HBoxContainer.new();add_child(row)
	GameUI.label(row,title,15).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var value:=GameUI.label(row,"",14,FieldTheme.MUTED);values[key]=value
	value.autowrap_mode=TextServer.AUTOWRAP_OFF;value.custom_minimum_size.x=55;value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var slider:=HSlider.new();slider.min_value=minimum;slider.max_value=maximum;slider.step=step_value;slider.value=initial;sliders[key]=slider;add_child(slider)
	_value_text(key,initial)
	slider.value_changed.connect(func(number: float):
		GameVoiceSettings.set_option(key,number/100.);_value_text(key,number);_apply()
	)

func _value_text(key: String,value: float) -> void:
	values[key].text="%d%%"%roundi(value)

func _apply() -> void:
	if is_instance_valid(monitor):monitor.set_input_device(GameVoiceSettings.input_device())
	if is_instance_valid(relay):relay.apply_preferences()

func _toggle_test() -> void:
	if test_left>0.:_stop_test();return
	test_result=""
	if not is_instance_valid(monitor):monitor=GameVoiceClient.new();add_child(monitor)
	if monitor.start_microphone_test():test_left=8.;test_button.text="PARAR TESTE"
	else:status_text.text=monitor.status()
func _stop_test() -> void:
	if is_instance_valid(monitor):
		if monitor.test_frames>0:test_result="Microfone detectado" if monitor.test_peak>.002 else "Sem sinal. Verifique o microfone e as permissões."
		monitor.stop_microphone_test()
	test_left=0.
	if is_instance_valid(test_button):test_button.text="TESTAR MICROFONE"
func _exit_tree() -> void:_stop_test()

func _process(delta: float) -> void:
	if not is_visible_in_tree():return
	if test_left>0.:
		if not monitor.microphone_testing:
			test_result=monitor.microphone_error if not monitor.microphone_error.is_empty() else "Teste encerrado";test_left=0.;test_button.text="TESTAR MICROFONE";return
		test_left=maxf(0.,test_left-delta);test_meter.value=minf(1.,monitor.meter*8.)
		status_text.text="Microfone detectado" if monitor.test_peak>.002 else "Fale no microfone. Selecione outro dispositivo se não houver sinal."
		if test_left<=0.:_stop_test()
		return
	poll+=delta
	if poll<.5:return
	poll=0.;_refresh()

func _refresh() -> void:
	if not is_instance_valid(relay) and is_instance_valid(game):relay=game.get("voice") as BRVoiceRelay
	if is_instance_valid(relay):
		status_text.text=test_result if not test_result.is_empty() else relay.status()
	else:status_text.text=test_result
	toggle.set_pressed_no_signal(GameVoiceSettings.enabled())
	for key in sliders:
		var number: float=GameVoiceSettings.volume()*100.
		sliders[key].set_value_no_signal(number);_value_text(key,number)
	var present: Dictionary={}
	if is_instance_valid(relay):
		for id in relay.roster:
			if game is NavalMode:
				if int(id)==game.network.local_id():continue
			elif is_instance_valid(game.local_player) and int(id)==game.local_player.peer_id:continue
			present[int(id)]=true
			if not voices.has(id):
				var row:=HBoxContainer.new();people.add_child(row)
				var title:=GameUI.label(row,"",15);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				var mute:=CheckBox.new();mute.text="Silenciar";row.add_child(mute)
				mute.toggled.connect(func(value: bool):relay.set_muted(int(id),value))
				voices[id]={"root":row,"name":title,"mute":mute}
			voices[id].name.text=str(relay.roster[id].name)
			voices[id].mute.set_pressed_no_signal(relay.voice_muted(int(id)))
	for id in voices.keys():
		if not present.has(id):voices[id].root.queue_free();voices.erase(id)
