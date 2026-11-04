extends GameWeaponAudio
class_name WarAudio
var explosion_audio: GameExplosionAudio
var game: WarGame
var confirmations: Array[AudioStreamPlayer]=[]
var confirmation_cursor:=0
var confirmation_events: Dictionary={}

func confirm_elimination(event_id: String,friendly: bool) -> void:
	if confirmation_events.has(event_id) or confirmations.is_empty(): return
	confirmation_events[event_id]=true
	if confirmation_events.size()>128: confirmation_events.erase(confirmation_events.keys()[0])
	var voice:=confirmations[confirmation_cursor];confirmation_cursor=(confirmation_cursor+1)%confirmations.size()
	voice.stream=GameCombatAudioCatalog.stream("res://audio/war/"+("friendly-confirm" if friendly else "kill-confirm")+".wav")
	voice.play()

func occlusion_excludes() -> Array[RID]:
	if is_instance_valid(game) and is_instance_valid(game.local_player) and is_instance_valid(game.vehicle_system):
		return game.vehicle_system.owner_excludes(game.local_player.peer_id)
	return []

func _play_now(emitter: int,weapon: String,point: Vector3) -> AudioStreamPlayer3D:
	var voice:=super._play_now(emitter,weapon,point)
	if is_instance_valid(voice) and weapon=="tank":
		voice.stop();voice.stream=GameCombatAudioCatalog.stream("res://audio/war/tank-fire.wav")
		var tank_profile:=profile("tank")
		voice.set_meta("base_db",float(tank_profile.db));voice.unit_size=float(tank_profile.unit)
		apply_acoustics(voice,voice.global_position.distance_to(listener_position(get_viewport())),false,interior)
		voice.play()
	return voice

func _ready() -> void:
	# WarSoundscape already handles regional occlusion/interior buses.
	external_acoustics=true
	super._ready()
	if DisplayServer.get_name()=="headless": return
	explosion_audio=GameExplosionAudio.new()
	add_child(explosion_audio)
	for index in 4:
		var voice:=AudioStreamPlayer.new();voice.bus="Interface";voice.volume_db=-6;add_child(voice);confirmations.append(voice)
	for path in ["kill-confirm","friendly-confirm"]: GameCombatAudioCatalog.stream("res://audio/war/"+path+".wav")
	GameCombatAudioCatalog.stream("res://audio/war/tank-fire.wav")

func explosion(event_id: String,point: Vector3,kind:="standard") -> void:
	if is_instance_valid(explosion_audio): explosion_audio.play_event(event_id,point,kind)
