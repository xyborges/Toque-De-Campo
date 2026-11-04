extends RefCounted
class_name GameCombatAudioCatalog

const PISTOL := "res://audio/pistol-109.wav"
const EXPLOSIONS := ["res://audio/explosions/grenade_near.wav","res://audio/explosions/tank_near.wav","res://audio/explosions/drone_near.wav"]
const EXPLOSIONS_FAR := ["res://audio/explosions/grenade_far.wav","res://audio/explosions/tank_far.wav","res://audio/explosions/drone_far.wav"]

static func explosion_type(kind: String) -> int:
	match kind:
		"tank","destroy": return 1
		"drone","tv","rpg","stinger","missile": return 2
		_: return 0 # grenade, autocannon, standard infantry and other small blasts
# Death cries and proximity speech use one fixed spatial profile in every mode.
const PLAYER_VOICE_DISTANCE := 55.0
const PLAYER_VOICE_UNIT_SIZE := 4.0
const PLAYER_VOICE_VOLUME_DB := -6.0
static var streams: Dictionary={}

static func apply_player_voice_profile(player: AudioStreamPlayer3D) -> void:
	player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.max_distance=PLAYER_VOICE_DISTANCE
	player.unit_size=PLAYER_VOICE_UNIT_SIZE
	player.volume_db=PLAYER_VOICE_VOLUME_DB

static func stream(path: String) -> AudioStream:
	if not streams.has(path): streams[path]=load(path)
	return streams[path]
