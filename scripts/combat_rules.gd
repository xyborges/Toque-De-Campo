extends RefCounted
class_name CombatRules

# Layers: 1 scenery, 2 combat regions, 4 movement capsules, 8 corpses.
const SHOT_MASK := 3
const DAMAGE := {"head":2.5, "chest":1.0, "abdomen":0.9, "armL":0.65, "armR":0.65, "forearmL":0.65, "forearmR":0.65, "handL":0.4, "handR":0.4, "legL":0.75, "legR":0.75, "footL":0.4, "footR":0.4}
const MODES := {"training":{"fatal_headshot":true,"limb_disability":true,"dismemberment":true}, "desert":{"fatal_headshot":true,"limb_disability":true,"dismemberment":true}, "pvp":{"fatal_headshot":true,"limb_disability":false,"dismemberment":false}}
const WEAPON_OPTIONS := {
	"broom":{"simulation":"melee","mode":"semi","reserve":0,"recoil":0.0,"spread":0.0,"sever":false},
	"squeegee":{"simulation":"melee","mode":"semi","reserve":0,"recoil":0.0,"spread":0.0,"sever":false},
	"axe":{"simulation":"melee","mode":"semi","reserve":0,"recoil":0.0,"spread":0.0,"sever":true},
	"glock":{"simulation":"projectile","mode":"semi","reserve":60,"recoil":0.024,"spread":0.001,"sever":false,"drag":0.20},
	"ak":{"simulation":"projectile","mode":"auto","reserve":180,"recoil":0.018,"spread":0.0013,"sever":false,"drag":0.09},
	"g3":{"simulation":"projectile","mode":"auto","reserve":120,"recoil":0.030,"spread":0.00115,"sever":false,"drag":0.08},
	"fal":{"simulation":"projectile","mode":"auto","reserve":120,"recoil":0.025,"spread":0.0011,"sever":false,"drag":0.08},
	"sniper":{"simulation":"projectile","mode":"semi","reserve":25,"recoil":0.062,"spread":0.0003,"sever":true,"drag":0.035},
	"rpg":{"simulation":"projectile","mode":"semi","reserve":0,"drag":0.016,"recoil":0.04,"spread":0.0,"sever":false},
	"stinger":{"simulation":"projectile","mode":"semi","reserve":0,"drag":0.008,"recoil":0.02,"spread":0.0,"sever":false}}

static func weapon(id: String) -> Dictionary:
	var instance_id:=id
	id=GameWeapons.canonical(id)
	var result: Dictionary = GameWeapons.ITEMS.get(id, GameWeapons.ITEMS.ak).duplicate(true)
	if id=="fists":
		result.merge({"simulation":"melee","mode":"semi","reserve":0,"drag":0.0,"recoil":0.0,"spread":0.0,"sever":false},true)
		result["id"]=id
		return result
	result.merge(WEAPON_OPTIONS.get(id, WEAPON_OPTIONS.ak), true)
	result["id"] = instance_id
	return result

static func region_group(region: String) -> String:
	if region in ["armL","forearmL","handL"]: return "armL"
	if region in ["armR","forearmR","handR"]: return "armR"
	if region in ["legL","footL"]: return "legL"
	if region in ["legR","footR"]: return "legR"
	if region in ["torso","chest","abdomen","abdomenPelvis"]: return "torso"
	return "head"

static func health_damage(base: float, region: String, mode: String) -> float:
	var multiplier := float(DAMAGE.get(region, 1.0))
	var amount := maxf(0.0, base) * multiplier
	if region == "head" and base > 0.0 and MODES.get(mode, MODES.pvp).fatal_headshot:
		amount = maxf(amount, 100.0)
	return amount

# Multiplayer damage keeps limb health for hit feedback/ragdolls, but may not
# permanently lock fire or movement on a still-living infantry character.
static func limb_disability_enabled(game: Node) -> bool:
	if not is_instance_valid(game):return false
	return bool(MODES.get(str(game.get("mode")),MODES.pvp).get("limb_disability",false))

static func fresh_limbs() -> Dictionary:
	return {"head":100.0,"torso":100.0,"armL":100.0,"armR":100.0,"legL":100.0,"legR":100.0}

static func transfer_ammo(magazine: int, reserve: int, capacity: int) -> Vector2i:
	var transferred := mini(maxi(0, capacity - magazine), maxi(0, reserve))
	return Vector2i(maxi(0, magazine) + transferred, maxi(0, reserve) - transferred)

static func finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

static func fresh_reserves() -> Dictionary:
	var result: Dictionary={}
	for id in GameWeapons.INFANTRY_IDS + ["g3"]:
		if GameWeapons.ITEMS[id].kind=="firearm": result[id]=int(weapon(id).reserve)
	return result
