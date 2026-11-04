extends RefCounted
class_name GameLoadouts

const PROTOCOL:=14
const ORDER:=["helmet","vest","sidearm","primary","optic","grenade","melee","equipment","drone"]
const TITLES:={"helmet":"Capacete","vest":"Colete","sidearm":"Pistola","primary":"Principal","optic":"Mira","grenade":"Granada","melee":"Arma branca","equipment":"Equipamento","drone":"Drone"}
const EQUIPMENT:={"medkit":"Kit médico","supply":"Munição","spot":"Observação","drone":"Drone"}
const OPTICS:={"scope4x":"Mira 4×"}
const OPTIC_WEAPONS:=["fal","ak","g3","sniper"]

static func allowed(mode: String,owned: Array,role:="soldier",team:=0) -> Dictionary:
	var weapons: Array=GameWeapons.INFANTRY_IDS + ["g3"] if mode=="war" else owned
	var choices: Dictionary={"sidearm":[],"primary":[],"melee":[]}
	if mode in ["war","desert","offline_training","offline_desert"]:
		choices.vest=["vest_2","vest_1","vest_3"];choices.helmet=["helmet_2","helmet_1","helmet_3"]
	if "glock" in weapons: choices.sidearm.append("glock")
	for id in (WarRules.primary_for(role,team) if mode=="war" else ["ak","fal","sniper"]):
		if id in weapons: choices.primary.append(id)
	for id in choices.primary:
		if id in OPTIC_WEAPONS:
			choices.optic=GameOpticCatalog.ids_for_weapon(id)
			if GameOpticCatalog.compatible("scope4x",id):choices.optic.append("scope4x")
			break
	for id in ["squeegee","broom","axe"]:
		if id in weapons: choices.melee.append(id)
	if mode!="war" or role=="soldier": choices.grenade=["grenade","smoke"]
	if mode=="war": choices.equipment=[WarRules.launcher_for_team(team) if role=="antitank" else {"medic":"medkit","soldier":"supply","marksman":"spot"}.get(role,"")]
	if mode=="war": choices.drone=["drone"]
	for slot in choices.keys():
		if choices[slot].is_empty(): choices.erase(slot)
	return choices

static func defaults(mode: String,owned: Array,role:="soldier",team:=0) -> Dictionary:
	var result: Dictionary={}
	var choices:=allowed(mode,owned,role,team)
	for slot in choices:
		# Attachments remain an explicit choice, including migrated loadouts.
		if slot!="optic": result[slot]=choices[slot][0]
	return result

static func validate(raw: Variant,mode: String,owned: Array,role:="soldier",team:=0,repair:=false) -> Dictionary:
	var permitted:=allowed(mode,owned,role,team)
	var result: Dictionary={};var adjusted:=false
	if not raw is Dictionary or var_to_bytes(raw).size()>700: return {"ok":false,"error":"Escolha o equipamento."}
	for slot in raw:
		if slot not in ORDER or not raw[slot] is String: return {"ok":false,"error":"Equipamento inválido."}
		var id:=str(raw[slot])
		if id.is_empty(): continue
		if not permitted.has(slot) or id not in permitted[slot]:
			if not repair: return {"ok":false,"error":"Equipamento indisponível."}
			adjusted=true
			if slot!="optic" and permitted.has(slot): result[slot]=permitted[slot][0]
		else: result[slot]=id
	if result.has("optic") and (str(result.get("primary","")) not in OPTIC_WEAPONS or not GameOpticCatalog.compatible(str(result.optic),str(result.get("primary",""))) or str(result.get("primary",""))!=str(raw.get("primary",""))):
		if not repair: return {"ok":false,"error":"Mira indisponível."}
		result.erase("optic");adjusted=true
	var choices: Array=[]
	for slot in ["sidearm","primary","melee"]:
		if result.has(slot): choices.append(result[slot])
	if choices.is_empty():
		if not repair: return {"ok":false,"error":"Escolha uma arma."}
		for slot in ["primary","sidearm","melee"]:
			if permitted.has(slot): result[slot]=permitted[slot][0];choices.append(result[slot]);adjusted=true;break
	if choices.is_empty(): return {"ok":false,"error":"Nenhuma arma disponível."}
	return {"ok":true,"slots":result,"choices":choices,"grenades":result.has("grenade"),"equipment":str(result.get("equipment","")),"equipped":str(result.get("primary",result.get("sidearm",result.get("melee","")))),"adjusted":adjusted}

static func title(id: String) -> String:
	if id.begins_with("vest_") or id.begins_with("helmet_"):
		return ("Colete" if id.begins_with("vest_") else "Capacete")+" · "+str(["","Leve","Padrão","Pesado"][clampi(int(id.get_slice("_",1)),0,3)])
	return ("Granada de fumaça (M18)" if id=="smoke" else "Granada explosiva") if id in ["grenade","smoke"] else (GameOpticCatalog.item_name(id) if GameOpticCatalog.valid(id) else str(EQUIPMENT.get(id,GameWeapons.ITEMS.get(id,{}).get("name",id))))

static func apply(actor: GamePlayer,approved: Dictionary,war:=false) -> void:
	actor.set_meta("approved_loadout",approved.slots.duplicate())
	if war: actor.owned=approved.choices.duplicate()
	actor.loadout=approved.choices.duplicate();actor.grenades_enabled=bool(approved.grenades)
	actor.set_meta("grenade_kind",str(approved.slots.get("grenade","grenade")))
	actor.set_meta("grenade_display_kind",str(approved.slots.get("grenade","grenade")))
	actor.grenades=2 if actor.grenades_enabled else 0
	actor.weapon_id=str(approved.equipped)
	actor.set_meta("class_equipment",not str(approved.equipment).is_empty())
	actor.set_meta("drone_enabled",approved.slots.has("drone"))
	var optics: Dictionary={}
	var primary:=str(approved.slots.get("primary",""))
	var chosen_optic:=str(approved.slots.get("optic",""))
	if primary in OPTIC_WEAPONS and GameOpticCatalog.compatible(chosen_optic,primary):optics[primary]=chosen_optic
	actor.set_meta("weapon_optics",optics)
	var attachments: Dictionary={}
	for weapon: String in optics:attachments[weapon]=GameAttachmentState.from_legacy(weapon,str(optics[weapon]))
	actor.set_meta("weapon_attachments",attachments)
	if actor.has_method("refresh_weapon_optics"): actor.call("refresh_weapon_optics")
	actor.remove_meta("quick_slots")
	trim_inventory(actor)

static func trim_inventory(actor: GamePlayer) -> void:
	if not actor.has_meta("approved_loadout"): return
	for id in actor.ammo.keys():
		if id not in actor.active_weapons(): actor.ammo.erase(id)
	for id in actor.reserves.keys():
		if id not in actor.active_weapons(): actor.reserves.erase(id)

static func identity(game: Node) -> String:
	var id:="local"
	if is_instance_valid(game.get("main_accounts")): id=str(game.main_accounts.profile.get("id",game.profile.get("appearance_account","local")))
	return id.sha256_text().substr(0,24)

static func saved(game: Node,mode: String,role:="soldier",team:=0) -> Dictionary:
	var file:=_saved_file()
	var key:=identity(game)+":"+mode+(":"+role+":"+str(team) if mode=="war" else "")
	var raw: Variant=file.get(key,defaults(mode,game.profile.owned,role,team))
	if raw is Dictionary:
		raw=raw.duplicate(true)
		var primary:=str(raw.get("primary",""))
		var explicit:=optic_id_preferences()
		if explicit.has(primary):
			var chosen:=str(explicit[primary])
			if chosen.is_empty():raw.erase("optic")
			elif GameOpticCatalog.compatible(chosen,primary):raw.optic=chosen
		else:
			var optic:=optic_preference(primary)
			if optic==4: raw.optic="scope4x"
			elif optic==0: raw.erase("optic")
	var restored:=validate(raw,mode,game.profile.owned,role,team,true)
	if not restored.ok:
		restored=validate(defaults(mode,game.profile.owned,role,team),mode,game.profile.owned,role,team)
		restored["adjusted"]=true
	return restored

static func save(game: Node,mode: String,slots: Dictionary,role:="soldier",team:=0) -> void:
	var approved:=validate(slots,mode,game.profile.owned,role,team)
	if not approved.ok: return
	var path:=NavalStorage.folder().path_join("loadouts-v1.json");var file:=_saved_file()
	var key:=identity(game)+":"+mode+(":"+role+":"+str(team) if mode=="war" else "")
	file[key]=approved.slots
	if mode=="war": file[identity(game)+":war:last"]={"role":role,"team":team}
	NavalStorage.write_json(path,file)
	var primary:=str(approved.slots.get("primary",""))
	if primary in OPTIC_WEAPONS:
		var chosen:=str(approved.slots.get("optic",""))
		var canonical:=GameOpticCatalog.resolve(chosen,primary) if not chosen.is_empty() else ""
		var optics:=optic_preferences()
		optics[primary]=4 if (chosen=="scope4x" or canonical in ["prism4x","pso4x","hensoldt4x"]) else 0
		var exact:=optic_id_preferences()
		exact[primary]=canonical
		GameOptions.set_value("weapon_optics",optics)
		GameOptions.set_value("weapon_optic_ids",exact)
		GameOptions.flush()

static func optic_preferences() -> Dictionary:
	GameOptions.ensure()
	var raw: Variant=GameOptions.values.get("weapon_optics",{})
	var result: Dictionary={}
	if not raw is Dictionary: return result
	for id: String in OPTIC_WEAPONS:
		var value: Variant=raw.get(id,null)
		if (value is int or value is float) and is_finite(float(value)) and float(value) in [0.,4.]: result[id]=int(value)
	return result

static func optic_preference(weapon: String) -> int:
	return int(optic_preferences().get(weapon,-1))

static func optic_id_preferences() -> Dictionary:
	GameOptions.ensure()
	var raw: Variant=GameOptions.values.get("weapon_optic_ids",{})
	var result: Dictionary={}
	if not raw is Dictionary:return result
	for weapon: String in OPTIC_WEAPONS:
		if not raw.has(weapon) or not raw[weapon] is String:continue
		var chosen:=str(raw[weapon])
		if chosen.is_empty() or GameOpticCatalog.compatible(chosen,weapon):result[weapon]=chosen
	return result

static func optic_choice(weapon: String) -> String:
	var exact:=optic_id_preferences()
	if exact.has(weapon):return str(exact[weapon])
	return "scope4x" if optic_preference(weapon)==4 else ""

static func war_last(game: Node) -> Dictionary:
	var file:=_saved_file()
	var raw: Variant=file.get(identity(game)+":war:last",{})
	if not raw is Dictionary: return {"role":"soldier","team":0}
	return {"role":str(raw.get("role","soldier")) if WarRules.CLASSES.has(str(raw.get("role",""))) else "soldier","team":clampi(int(raw.get("team",0)),0,1)}

static func _saved_file() -> Dictionary:
	var path:=NavalStorage.folder().path_join("loadouts-v1.json")
	var file:=NavalStorage.read_json(path)
	if int(file.get("_rifle_revision",0))<2:
		for key in file:
			if file[key] is Dictionary and file[key].get("primary","")=="fal": file[key].primary="ak"
		file["_rifle_revision"]=2
		NavalStorage.write_json(path,file)
	return file
