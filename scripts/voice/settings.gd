extends RefCounted
class_name GameVoiceSettings

# Numeric options use the existing account preference transport. Device names
# stay on this computer; mute keys are salted server account hashes, not peers.
static var local_path:=""
static var local_values: Dictionary={}

static func enabled() -> bool:return GameOptions.flag("voice_enabled",true)
static func volume() -> float:return clampf(GameOptions.number("voice_volume",.8),0.,1.)
static func radius() -> float:return GameCombatAudioCatalog.PLAYER_VOICE_DISTANCE
static func set_option(key: String,value: Variant) -> void:
	if key not in ["voice_enabled","voice_volume"]:return
	if key=="voice_enabled":GameOptions.set_value(key,bool(value))
	elif (value is float or value is int) and is_finite(float(value)):
		GameOptions.set_value(key,clampf(float(value),0.,1.))
	GameOptions.flush()

static func _load_local() -> void:
	var current:=NavalStorage.folder().path_join("voice-device.json")
	if current!=local_path:local_path=current;local_values=NavalStorage.read_json(current)

static func input_device() -> String:
	_load_local()
	var desired:=str(local_values.get("input","Default"))
	return desired if desired in AudioServer.get_input_device_list() else "Default"
static func set_input_device(device: String) -> void:
	_load_local()
	if device not in AudioServer.get_input_device_list():device="Default"
	local_values.input=device;NavalStorage.write_json(local_path,local_values)

static func is_muted(identity: String) -> bool:
	GameOptions.ensure()
	var value: Variant=GameOptions.values.get("voice_muted",{})
	var muted: Dictionary=value if value is Dictionary else {}
	return bool(muted.get(identity,false)) if not identity.is_empty() else false
static func set_muted(identity: String,value: bool) -> void:
	if identity.length()!=64 or not identity.is_valid_hex_number(false):return
	GameOptions.ensure();var stored: Variant=GameOptions.values.get("voice_muted",{})
	var muted: Dictionary=stored.duplicate() if stored is Dictionary else {}
	if value:muted[identity]=true
	else:muted.erase(identity)
	# Bound local storage even across many rooms. Account hashes remain stable.
	while muted.size()>64:muted.erase(muted.keys()[0])
	GameOptions.set_value("voice_muted",muted);GameOptions.flush()
