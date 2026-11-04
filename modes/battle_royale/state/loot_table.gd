extends Resource
class_name BRLootTable

@export var weapon_weights: Dictionary={"glock":40.0,"ak":26.0,"fal":23.0,"sniper":10.0,"stinger":1.0,"rpg":1.0}
@export var region_weapon_weights: Dictionary={
	"home":{"glock":50.,"ak":25.,"fal":18.,"sniper":6.,"stinger":1.,"rpg":0.5},
	"storage":{"glock":18.,"ak":34.,"fal":30.,"sniper":15.,"stinger":3.,"rpg":2.},
	"ruin":{"glock":30.,"ak":30.,"fal":25.,"sniper":14.,"stinger":1.,"rpg":1.},
	"farm_crate":{"glock":65.,"ak":20.,"fal":12.,"sniper":3.,"stinger":0.,"rpg":0.}}
@export_range(0.0,1.0) var heal_chance:=0.14
@export_range(0.0,1.0) var ammo_chance:=0.33
@export_range(0.0,1.0) var grenade_chance:=0.06
@export_range(0.0,1.0) var protection_chance:=0.17
@export_range(0.0,1.0) var backpack_chance:=0.09
@export_range(0.0,1.0) var attachment_chance:=0.08
@export var attachment_weights: Dictionary={}
# Older editable tables/tests used the optics-only name.
var optic_chance: float:
	get:return attachment_chance
	set(value):attachment_chance=value
@export_range(1,2000) var max_items:=900

func _weapon(rng: RandomNumberGenerator,region:="") -> String:
	var weights: Dictionary=region_weapon_weights.get(region,weapon_weights)
	var total:=0.0
	for weapon in weights:
		if str(weapon) in BRInventory.CALIBRES:total+=maxf(0.0,float(weights[weapon]))
	var value:=rng.randf()*total
	for weapon in weights:
		if str(weapon) not in BRInventory.CALIBRES:continue
		value-=maxf(0.0,float(weights[weapon]))
		if value<=0.0 and str(weapon) in BRInventory.CALIBRES: return str(weapon)
	return "glock"

func _attachment(rng: RandomNumberGenerator) -> String:
	var ids: Array=BRInventory.ATTACHMENTS.ids();ids.sort()
	var total:=0.
	for id: String in ids:total+=maxf(0.,float(attachment_weights.get(id,1.)))
	if total<=0.:return ""
	var choice:=rng.randf()*total
	for id: String in ids:
		var weight:=maxf(0.,float(attachment_weights.get(id,1.)))
		if weight<=0.:continue
		choice-=weight
		if choice<=0.:return id
	return ""

func generate(seed_value: int,points: Array,spawns: Array=[],regions: Dictionary={}) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for value in points:
		if result.size()>=max_items: break
		if not value is Vector3 or not value.is_finite(): continue
		var anchor: Vector3=value
		var cluster_count:=1+(1 if rng.randf()<.68 else 0)+(1 if rng.randf()<.22 else 0)
		for cluster_index in cluster_count:
			if result.size()>=max_items:break
			var angle:=rng.randf_range(0.,TAU);var radius:=0.0 if cluster_index==0 else rng.randf_range(.35,1.15)
			var point:=anchor+Vector3(cos(angle)*radius,0.,sin(angle)*radius)
			if rng.randf()<attachment_chance:
				var attachment:=_attachment(rng)
				if not attachment.is_empty():
					result.append({"kind":"attachment","attachment":attachment,"state":{},"amount":1,"position":point})
					continue
			if rng.randf()<.04:
				result.append({"kind":"binoculars","position":point});continue
			var roll:=rng.randf()
			if roll<heal_chance:
				result.append({"kind":"heal","amount":rng.randi_range(1,2),"position":point})
			elif roll<heal_chance+backpack_chance:
				var tier:=rng.randf();var level:=1 if tier<.55 else (2 if tier<.9 else 3)
				result.append({"kind":"pack","level":level,"position":point})
			elif roll<heal_chance+backpack_chance+protection_chance:
				var tier:=rng.randf();var level:=1 if tier<.55 else (2 if tier<.9 else 3)
				result.append({"kind":"vest" if rng.randf()<.55 else "helmet","level":level,"durability":BRInventory.PROTECTION_HP[level],"position":point})
			elif roll<heal_chance+backpack_chance+protection_chance+grenade_chance:
				result.append({"kind":"grenade","amount":1,"position":point})
			else:
				var weapon:=_weapon(rng,str(regions.get(anchor,"")))
				if roll<heal_chance+backpack_chance+protection_chance+grenade_chance+ammo_chance:
					result.append(_ammo(weapon,point,rng))
				else:
					result.append({"kind":"weapon","weapon":weapon,"magazine":rng.randi_range(maxi(1,int(BRInventory.MAGAZINES[weapon])/3),int(BRInventory.MAGAZINES[weapon])),"position":point})
	# Guarantee a modest sidearm + separate compatible ammunition near each
	# selected spawn. Using nearby authored loot anchors keeps it off walls.
	for value in spawns:
		if not value is Vector3: continue
		var spawn_point: Vector3=value
		# A resource guarantee must never create arbitrary loot in a crop field.
		# Missing authored anchors is a map error, not a reason to use spawn+2m.
		if points.is_empty(): continue
		var nearest: Vector3=points[0]
		var nearest_distance:=INF
		for candidate in points:
			if not candidate is Vector3: continue
			var d:=spawn_point.distance_squared_to(candidate)
			if d<nearest_distance: nearest_distance=d;nearest=candidate
		result.append({"kind":"weapon","weapon":"glock","magazine":6,"position":nearest})
		result.append({"kind":"ammo","calibre":"9mm","amount":24,"position":nearest+Vector3(0.4,0.0,0.0)})
	return result

func _ammo(weapon: String,point: Vector3,rng: RandomNumberGenerator=null) -> Dictionary:
	var magazines:=2
	if rng:magazines=rng.randi_range(2,4) if weapon in ["glock","ak","fal"] else rng.randi_range(1,2)
	var count:=int(BRInventory.MAGAZINES[weapon])*magazines
	return {"kind":"ammo","calibre":BRInventory.calibre_for(weapon),"amount":count,"position":point}
