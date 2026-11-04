extends Node
class_name GameUIFeedback
var ui_audio: AudioStreamPlayer
var sounds: Dictionary = {}
var hover_at := -1.0
func _ready() -> void:
	GameAudioSettings.ensure()
	ui_audio = AudioStreamPlayer.new()
	ui_audio.bus="Interface"
	ui_audio.volume_db = -26
	add_child(ui_audio)
	_make_sounds()
func watch(root: Node) -> void:
	if root is BaseButton and not root.get_meta("ui_feedback",false):
		root.set_meta("ui_feedback",true)
		root.pressed.connect(func(): _sound("click"))
		root.focus_entered.connect(func(): _hover(root))
		root.mouse_entered.connect(func(): _hover(root))
	for child in root.get_children(): watch(child)
func _hover(button: BaseButton) -> void:
	if not button.disabled and Time.get_ticks_msec()*0.001-hover_at>0.10:
		hover_at = Time.get_ticks_msec()*0.001
		_sound("hover")
func _make_sounds() -> void:
	for kind in ["hover","click","success","error"]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var duration := 0.045 if kind in ["hover","click"] else 0.14
		var data := PackedByteArray()
		data.resize(int(duration*22050)*2)
		for i in data.size()/2:
			var t := float(i)/22050
			var frequency := 620.0 if kind=="hover" else (440.0 if kind=="click" else (740.0+t*1800 if kind=="success" else 210.0-t*700))
			var sample := sin(t*TAU*frequency)*0.30*pow(1.0-t/duration,2.0)
			data.encode_s16(i*2,int(sample*32767))
		stream.data = data
		sounds[kind] = stream

func _sound(kind: String) -> void:
	if not is_instance_valid(ui_audio): return
	if kind=="hover" and ui_audio.playing: return
	ui_audio.stream = sounds.get(kind)
	ui_audio.play()

