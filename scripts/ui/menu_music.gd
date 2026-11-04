extends AudioStreamPlayer
class_name GameMenuMusic

const LOGIN_TRACKS := [
	"res://audio/login/musica2.mp3",
	"res://audio/login/musica3.mp3",
	"res://audio/login/musica4.mp3",
	"res://audio/login/musica5.mp3",
	"res://audio/login/musica6.mp3"
]
const MENU_TRACK := "res://audio/naval-menu.mp3"
const PLAYLIST := LOGIN_TRACKS + [MENU_TRACK]
var login_active := false
var current_login_track := ""
var last_login_track := ""
var queue: Array[String] = []
var rng := RandomNumberGenerator.new()
var original: AudioStreamMP3
var envelope := 0.0
var channel := ""

func _ready() -> void:
	GameAudioSettings.ensure()
	rng.randomize()
	original = load("res://audio/naval-menu.mp3").duplicate() as AudioStreamMP3
	original.loop = false
	channel = "MenuMusic_"+str(get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,channel)
	AudioServer.set_bus_send(index,"Music")
	AudioServer.set_bus_volume_db(index,-60)
	bus = channel
	finished.connect(_advance)
	_advance()

func set_login_active(active: bool) -> void:
	login_active = active
	# Authentication is navigation, not a playback command. The same shuffled
	# playlist continues through login, logout, shops and room menus.

func next_login_track() -> String:
	if queue.is_empty():
		for path: String in PLAYLIST: queue.append(path)
		for i in range(queue.size()-1,0,-1):
			var j := rng.randi_range(0,i)
			var old := queue[i]
			queue[i] = queue[j]
			queue[j] = old
		if queue.back()==last_login_track and queue.size()>1:
			var old := queue[0]
			queue[0] = queue.back()
			queue[-1] = old
	last_login_track = queue.pop_back()
	return last_login_track

func _advance() -> void:
	envelope = 0.0
	current_login_track = next_login_track()
	var track := load(current_login_track) as AudioStreamMP3
	if track == null: stream = original
	else:
		track = track.duplicate()
		track.loop = false
		stream = track
	play()

func _process(delta: float) -> void:
	if playing:
		var remaining := stream.get_length()-get_playback_position()
		if not current_login_track.is_empty() and remaining<0.6:
			envelope = minf(envelope,maxf(0.0,remaining/0.6))
		else: envelope = move_toward(envelope,1.0,delta*1.8)
	var index := AudioServer.get_bus_index(channel)
	if index>=0: AudioServer.set_bus_volume_db(index,linear_to_db(envelope) if envelope>0.001 else -60.0)

func _exit_tree() -> void:
	stop()
	var index := AudioServer.get_bus_index(channel)
	if index>0: AudioServer.remove_bus(index)
