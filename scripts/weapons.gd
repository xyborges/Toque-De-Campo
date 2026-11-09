extends RefCounted
class_name GameWeapons

# Account ownership and the ordinary arsenal remain common infantry items.
# Class launchers belong to a War deployment and share its validated charges.
const INFANTRY_IDS := ["broom","squeegee","axe","glock","ak","fal","sniper"]

static var ITEMS := {
    "binoculars":{"slot":4,"priority":0,"name":"Binóculos","kind":"utility","optic_fovs":[20.,10.],"damage":0.,"range":0.,"cooldown":1.,"power":0.,"mag":0,"reload":0.,"speed":0.,"gravity":0.,"color":Color("454c3a")},
    "fists": {"slot":4,"priority":0,"name":"Punhos","kind":"melee","damage":14.0,"range":1.45,"cooldown":0.48,"power":1.0,"mag":0,"reload":0.0,"speed":0.0,"gravity":0.0,"color":Color("#8c8064")},
    "broom": {"slot":4, "priority":1, "name":"Vassoura", "kind":"melee", "damage":16.0, "range":2.25, "cooldown":0.86, "power":3.0, "mag":0, "reload":0.0, "speed":0.0, "gravity":0.0, "color":Color("#a87a3d")},
    "squeegee": {"slot":4, "priority":0, "name":"Rodo", "kind":"melee", "damage":25.0, "range":2.20, "cooldown":1.0, "power":5.0, "mag":0, "reload":0.0, "speed":0.0, "gravity":0.0, "color":Color("#536979")},
    "axe": {"slot":4, "priority":2, "name":"Machado", "kind":"melee", "damage":52.0, "range":1.95, "cooldown":1.22, "power":9.0, "mag":0, "reload":0.0, "speed":0.0, "gravity":0.0, "color":Color("#644833")},
    "glock": {"slot":1, "priority":0, "name":"Glock", "kind":"firearm", "damage":30.0, "range":160.0, "cooldown":0.20, "power":4.0, "mag":12, "reload":4.0, "speed":350.0, "gravity":9.81, "color":Color("#22272b")},
    "ak": {"slot":2, "priority":0, "name":"AK", "kind":"firearm", "damage":55.0, "range":900.0, "cooldown":0.11, "power":7.0, "mag":30, "reload":6.0, "speed":715.0, "gravity":9.81, "color":Color("#20251e")},
    "g3": {"slot":2,"priority":1,"name":"G3","kind":"firearm","damage":60.0,"range":1050.0,"cooldown":0.13,"power":8.0,"mag":20,"reload":3.1,"speed":785.0,"gravity":9.81,"color":Color("#596b39")},
    "fal": {"slot":2, "priority":1, "name":"FAL", "kind":"firearm", "damage":62.0, "range":1100.0, "cooldown":0.13, "power":8.0, "mag":20, "reload":6.0, "speed":800.0, "gravity":9.81, "color":Color("#30362e")},
    "sniper": {"slot":2, "priority":2, "name":"Sniper", "kind":"firearm", "category":"precision", "damage":100.0, "range":2200.0, "cooldown":1.15, "power":12.0, "mag":5, "reload":4.5, "speed":900.0, "gravity":12.0, "color":Color("#171b1b")},
    "rpg": {"slot":7, "priority":0, "name":"RPG-7", "kind":"launcher", "category":"antiarmor", "war_only":true, "optic_fovs":[26.0], "damage":430.0, "range":650.0, "cooldown":5.5, "power":12.0, "mag":0, "reload":0.0, "speed":WarRpgBallistics.SPEED, "gravity":WarRpgBallistics.GRAVITY, "color":Color("#66764b")},
    "stinger": {"slot":8, "priority":0, "name":"FIM-92 Stinger", "kind":"launcher", "category":"antitank", "war_only":true, "optic_fovs":[35.0], "damage":280.0, "range":700.0, "cooldown":6.5, "power":12.0, "mag":0, "reload":0.0, "speed":125.0, "gravity":0.0, "color":Color("#727455")}
}

static func canonical(id: String) -> String:
	var base:=id.trim_suffix("_br2")
	return base if base in ["glock","ak","fal","sniper","rpg","stinger"] else id

static func _static_init() -> void:
	# Two inventory instances may share a blueprint without sharing magazines
	# or attachments. These IDs are never exposed in the ordinary arsenal.
	for base in ["glock","ak","fal","sniper","rpg","stinger"]:ITEMS[base+"_br2"]=ITEMS[base].duplicate(true)

static func is_launcher(id: String) -> bool:
	return str(ITEMS.get(id,{}).get("kind",""))=="launcher"

const NAVAL := {
    "light": {"name":"Patrulheiro leve", "hp":100.0, "speed":28.0, "turn":1.8, "length":9.0, "width":3.6, "price":0, "allowed":["lightMG"]},
    "combat": {"name":"Corveta de combate", "hp":160.0, "speed":22.0, "turn":1.35, "length":15.0, "width":4.6, "price":1200, "allowed":["lightMG","heavyMG","missile"]},
    "heavy": {"name":"Destróier pesado", "hp":240.0, "speed":16.0, "turn":0.92, "length":22.0, "width":5.8, "price":2600, "allowed":["lightMG","heavyMG","missile","torpedo"]},
    "assault": {"name":"Navio de assalto", "hp":320.0, "speed":12.0, "turn":0.68, "length":25.0, "width":7.2, "price":3900, "allowed":["lightMG","heavyMG","missile","torpedo"]},
    "submarine": {"name":"Submarino de ataque", "hp":210.0, "speed":18.0, "turn":1.05, "length":29.0, "width":5.4, "price":5200, "allowed":["lightMG","heavyMG","missile","torpedo"]}
}

const NAVAL_WEAPONS := {
    "lightMG": {"name":"Metralhadora leve", "damage":4.0, "cadence":0.105, "speed":620.0, "gravity":12.0, "ammo":600, "reload":3.0, "color":Color("#ffd66b")},
    "heavyMG": {"name":"Metralhadora pesada", "damage":9.0, "cadence":0.34, "speed":470.0, "gravity":16.0, "ammo":240, "reload":5.0, "color":Color("#ff9e52")},
    "missile": {"name":"Míssil", "damage":55.0, "cadence":10.0, "speed":90.846, "gravity":0.8, "ammo":6, "reload":10.0, "color":Color("#ffd34f")},
    "torpedo": {"name":"Torpedo", "damage":70.0, "cadence":8.0, "speed":44.1, "gravity":0.0, "ammo":8, "reload":8.0, "color":Color("#ff633f")}
}


static func fresh_ammo() -> Dictionary:
	var result: Dictionary={}
	for id in INFANTRY_IDS + ["g3"]:
		if ITEMS[id].kind=="firearm": result[id]=int(ITEMS[id].mag)
	return result

static func migrate_profile(profile: Dictionary,revision: int) -> void:
	if revision>=2: return
	var had_rifle: bool="fal" in profile.get("owned",[])
	for field in ["owned","loadout"]:
		var clean: Array=[]
		for id in profile.get(field,[]):
			var renamed: String="ak" if id=="fal" else str(id)
			if renamed in INFANTRY_IDS and renamed not in clean: clean.append(renamed)
		# Keep the previous FAL entitlement while correcting the old asset's name.
		if field=="owned" and had_rifle: clean.append("fal")
		profile[field]=clean
	if profile.get("equipped","")=="fal": profile.equipped="ak"
