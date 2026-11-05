extends RefCounted
class_name GameCombatAudioCatalog

const PISTOL := "res://audio/pistol-109.wav"
# Production WAVs only. MP3 previews and demonstration burst are NOT played
# per shot, since that would double gunfire and detach impacts from projectiles.
const AUTOCANNON_SHOTS := [
	"res://audio/apc30mm/APC_30mm_disparo_01.wav",
	"res://audio/apc30mm/APC_30mm_disparo_02.wav",
	"res://audio/apc30mm/APC_30mm_disparo_03.wav"
]
const AUTOCANNON_SHOT_FAR := "res://audio/apc30mm/APC_30mm_disparo_distante.wav"
const AUTOCANNON_IMPACTS := [
	"res://audio/apc30mm/APC_30mm_impacto_solo.wav",
	"res://audio/apc30mm/APC_30mm_impacto_blindagem.wav",
	"res://audio/apc30mm/APC_30mm_impacto_distante.wav"
]
static func autocannon_impact_kind(surface: String) -> String:
	return "autocannon_metal" if surface in ["metal","vehicle","steel"] else "autocannon_ground"

static func autocannon_impact_path(kind: String,distant: bool) -> String:
	return AUTOCANNON_IMPACTS[2] if distant else (AUTOCANNON_IMPACTS[1] if kind=="autocannon_metal" else AUTOCANNON_IMPACTS[0])

const EXPLOSIONS := ["res://audio/explosions/grenade_near.wav","res://audio/explosions/tank_near.wav","res://audio/explosions/drone_near.wav"]
const EXPLOSIONS_FAR := ["res://audio/explosions/grenade_far.wav","res://audio/explosions/tank_far.wav","res://audio/explosions/drone_far.wav"]

static func explosion_type(kind: String) -> int:
	match kind:
		"tank","destroy": return 1
		"drone","tv","rpg","stinger","missile": return 2
		_: return 0 # grenade and default blasts; 30mm impact WAVs are selected separately
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
