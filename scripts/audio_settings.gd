extends RefCounted
class_name GameAudioSettings

const LABELS := {"Master":"Geral","Music":"Música","Efeitos":"Efeitos","Armas":"Armas","Ambiente":"Ambiente","Veiculos":"Veículos","Passos":"Passos","Interface":"Interface"}
const PARENTS := {"Music":"Master","Efeitos":"Master","Armas":"Efeitos","Ambiente":"Efeitos","Veiculos":"Efeitos","Passos":"Efeitos","Interface":"Master"}
static var values: Dictionary={}
static var loaded_path:=""
static var dirty:=false

static func ensure() -> void:
	var path:=NavalStorage.settings_folder().path_join("audio-settings.json")
	if loaded_path!=path:
		loaded_path=path;values=NavalStorage.read_json(path);dirty=false
		if values.is_empty():
			var old:=NavalStorage.read_json(NavalStorage.settings_folder().path_join("war-audio.json"))
			for category in old:
				if LABELS.has(category) and is_finite(float(old[category])): values[category]=clampf(db_to_linear(float(old[category])),0,1)
		for category in LABELS:
			var raw: Variant=values.get(category,1.0)
			if not (raw is float or raw is int) or not is_finite(float(raw)): values[category]=1.0
		if int(values.get("_schema",0))<2:
			var music_db:=float(NavalStorage.read_json(NavalStorage.settings_folder().path_join("settings.json")).get("music_db",-21.0))
			values["Music"]=clampf(float(values.get("Music",1.0))*(0.0 if music_db<=-60 else db_to_linear(clampf(music_db,-60,-10)+10)),0,1)
			values["_schema"]=2;dirty=true
	for category in PARENTS:
		var index:=AudioServer.get_bus_index(category)
		if index<0:
			AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,category)
		AudioServer.set_bus_send(index,PARENTS[category])
	for category in LABELS: _apply(category)
	_ensure_master_peak_ceiling()

static func _ensure_master_peak_ceiling() -> void:
	# Combat has multiple independent 3D voices. Keep the sum under digital
	# full scale without compressing each weapon or changing user sliders.
	var master:=AudioServer.get_bus_index("Master")
	if master<0: return
	for index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master,index) is AudioEffectLimiter: return
	var peak:=AudioEffectLimiter.new()
	peak.threshold_db=-1.0
	peak.ceiling_db=-1.0
	AudioServer.add_bus_effect(master,peak)

static func get_volume(category: String) -> float:
	return clampf(float(values.get(category,1.0)),0,1)

static func _apply(category: String) -> void:
	var index:=AudioServer.get_bus_index(category)
	if index<0: return
	var value:=get_volume(category)
	AudioServer.set_bus_mute(index,value<=.0001)
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.001,value)))

static func set_volume(category: String,value: float) -> void:
	if not LABELS.has(category) or not is_finite(value): return
	values[category]=clampf(value,0,1);dirty=true;NavalStorage.mark_setting("audio-settings.json");_apply(category)

static func flush() -> void:
	if dirty and not loaded_path.is_empty() and NavalStorage.write_json(loaded_path,values): dirty=false
