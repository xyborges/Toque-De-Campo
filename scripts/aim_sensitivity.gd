extends RefCounted
class_name GameAimSensitivity
static var cache_path:=""
static var profiles: Dictionary={}
static var dirty:=false

static func groups() -> Dictionary:
	var infantry: Dictionary={}
	for id in GameWeapons.ITEMS: infantry["weapon:"+id]=str(GameWeapons.ITEMS[id].name)
	infantry["weapon:grenade"]="Granada"
	var ground: Dictionary={}
	for id in WarRules.VEHICLES: ground["war:"+id]=str(WarRules.VEHICLES[id].name)
	ground["war:drone"]="Drone"
	var ships: Dictionary={};var naval_guns: Dictionary={}
	for id in NavalCatalog.SHIPS: ships["naval:"+id]=str(NavalCatalog.SHIPS[id].name)
	for id in NavalCatalog.WEAPONS: naval_guns["navalweapon:"+id]=str(NavalCatalog.WEAPONS[id].name)
	return {"ARMAS DE INFANTARIA":infantry,"BLINDADOS E DRONE":ground,"ARMAS DOS BLINDADOS":{"mount:autocannon":"Autocanhão 30 mm","mount:tank":"Canhão de tanque","mount:coax":"Metralhadora coaxial","mount:tv":"Míssil TV"},"EMBARCAÇÕES":ships,"ARMAS NAVAIS":naval_guns}

static func _load() -> void:
	var path:=NavalStorage.settings_folder().path_join("aim-sensitivity.json")
	if cache_path==path: return
	cache_path=path;profiles={};dirty=false
	var document:=NavalStorage.read_json(path)
	var candidates: Variant=document.get("profiles",{})
	if not candidates is Dictionary: return
	if int(document.get("schema",1))<2 and candidates.has("weapon:fal"):
		candidates["weapon:ak"]=candidates["weapon:fal"];candidates.erase("weapon:fal")
		NavalStorage.write_json(path,{"schema":2,"profiles":candidates})
	for group: Dictionary in groups().values():
		for id in group:
			var raw: Variant=candidates.get(id,{})
			if not raw is Dictionary: continue
			var clean: Dictionary={}
			for field in ["normal","aim"]:
				var value: Variant=raw.get(field,1.0)
				clean[field]=clampf(float(value),.05,3) if (value is float or value is int) and is_finite(float(value)) else 1.0
			profiles[id]=clean

static func values(id: String) -> Dictionary:
	_load();return Dictionary(profiles.get(id,{"normal":1.0,"aim":1.0})).duplicate()

static func factor(id: String,aimed:=false) -> float:
	var current:=values(id)
	return float(current.normal)*(float(current.aim) if aimed else 1.0)

static func set_values(id: String,normal: float,aim: float) -> bool:
	if not is_finite(normal) or not is_finite(aim): return false
	_load()
	var allowed:=false
	for group: Dictionary in groups().values():
		if group.has(id): allowed=true;break
	if not allowed: return false
	profiles[id]={"normal":clampf(normal,.05,3),"aim":clampf(aim,.05,3)};dirty=true;NavalStorage.mark_setting("aim-sensitivity.json");return true

static func reset(id: String) -> void:
	_load();profiles.erase(id);dirty=true;NavalStorage.mark_setting("aim-sensitivity.json")

static func flush() -> void:
	if not dirty or cache_path.is_empty(): return
	if NavalStorage.write_json(cache_path,{"schema":2,"profiles":profiles}): dirty=false
