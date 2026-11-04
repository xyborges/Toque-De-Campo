extends RefCounted
class_name BRInventory

# This object lives only on the authority. Clients receive a private snapshot,
# never another survivor's inventory. Loot IDs are consumed before replying.
const WEAPON_LIMIT := 2
const CAPACITY := 60.0
const PACK_CAPACITY:=[60.,100.,140.,180.]
static var CALIBRES := {"glock":"9mm", "ak":"76239", "fal":"76251", "sniper":"precision", "rpg":"rocket", "stinger":"javelin"}
const AMMO_WEIGHT := {"9mm":0.12, "76239":0.22, "76251":0.26, "precision":0.5, "rocket":8.0, "javelin":10.0}
static var MAGAZINES := {"glock":12, "ak":30, "fal":20, "sniper":5, "rpg":1, "stinger":1}
const CELL_SIZE := 64.0
const PROTECTION_HP:=[0.,60.,100.,150.]
const PROTECTION_RATIO:=[0.,.30,.40,.55]
const OPTICS=preload("res://scripts/optic_catalog.gd")
const ATTACHMENTS=preload("res://scripts/attachments/registry.gd")
const ATTACHMENT_STATE=preload("res://scripts/attachments/state.gd")
const OPTIC_WEIGHT:=4.
const MAX_ACCESSORY_ITEMS:=64
var members: Dictionary = {}
var world_loot: Dictionary = {}
var next_loot_id := 1
var spatial_cells: Dictionary = {}
var last_query_candidates := 0
var next_accessory_uid:=1

static func _static_init() -> void:
	for base in CALIBRES.keys():CALIBRES[base+"_br2"]=CALIBRES[base];MAGAZINES[base+"_br2"]=MAGAZINES[base]

static func calibre_for(weapon: String) -> String:
	return str(CALIBRES.get(weapon,""))

func sync_from_actor(id: int,weapons: Array,magazines: Dictionary,reserves_by_weapon: Dictionary) -> void:
	# Authority calls this before changing inventory. Shared combat remains the
	# owner of shot cadence and reloads; never call this with client claims.
	if not members.has(id): return
	var inv: Dictionary=members[id]
	var clean: Array=[]
	for value in weapons:
		var weapon:=str(value)
		if weapon in CALIBRES and weapon not in clean and clean.size()<WEAPON_LIMIT: clean.append(weapon)
	inv.weapons=clean
	for weapon in clean:
		var loaded:=maxi(0,int(magazines.get(weapon,0)))
		var capacity_value:=_effective_magazine_capacity(inv,weapon)
		inv.magazines[weapon]=mini(loaded,capacity_value)
		# A stale pre-change actor snapshot cannot delete excess rounds.
		var reserve:=maxi(0,int(reserves_by_weapon.get(weapon,0)))
		for other in clean:
			if CALIBRES[other]==CALIBRES[weapon]:reserve=mini(reserve,maxi(0,int(reserves_by_weapon.get(other,0))))
		inv.ammo[CALIBRES[weapon]]=reserve+maxi(0,loaded-capacity_value)
	for weapon in inv.magazines.keys():
		if weapon not in clean: inv.magazines.erase(weapon)
	for weapon in inv.weapon_attachments.keys():
		if weapon not in clean:inv.weapon_attachments.erase(weapon)

func add_player(id: int) -> void:
	members[id] = {"weapons":[], "magazines":{}, "ammo":{}, "medkits":0,"grenades":0,"binoculars":false, "items":0,"backpack":0,"accessory_items":[],"weapon_attachments":{},"protection":{"vest":{"level":0,"durability":0.},"helmet":{"level":0,"durability":0.}}}

func remove_player(id: int) -> void:
	members.erase(id)

func clear() -> void:
	members.clear(); world_loot.clear(); spatial_cells.clear(); next_loot_id=1;next_accessory_uid=1

func add_loot(item: Dictionary) -> int:
	if not _valid_item(item): return -1
	var copy := item.duplicate(true)
	var id := next_loot_id
	next_loot_id += 1
	copy.id=id; world_loot[id]=copy
	if copy.kind=="container":
		for i in copy.contents.size():
			if copy.contents[i] is Dictionary:copy.contents[i].part_id=i+1
		copy.next_part_id=copy.contents.size()+1
	var cell:=_cell(copy.position)
	if not spatial_cells.has(cell): spatial_cells[cell]={}
	spatial_cells[cell][id]=true
	return id

func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x/CELL_SIZE),floori(position.z/CELL_SIZE))

func _remove_loot(id: int) -> void:
	if not world_loot.has(id): return
	var cell:=_cell(world_loot[id].position)
	if spatial_cells.has(cell):
		spatial_cells[cell].erase(id)
		if spatial_cells[cell].is_empty(): spatial_cells.erase(cell)
	world_loot.erase(id)

func register_loot(items: Array) -> void:
	for item in items:
		if item is Dictionary: add_loot(item)

func _item_attachment(item: Dictionary) -> String:
	return str(item.get("attachment",item.get("optic","")))

func _weapon_configuration(item: Dictionary) -> Dictionary:
	var weapon:=str(item.get("weapon",""))
	var config: Variant=item.get("weapon_attachments",item.get("configuration",{}))
	if not config is Dictionary:return {}
	if config.is_empty() and not str(item.get("optic","")).is_empty():return ATTACHMENT_STATE.from_legacy(weapon,str(item.optic))
	return config.duplicate(true)

func _attachment_item_valid(item: Dictionary) -> bool:
	var definition: Resource=ATTACHMENTS.definition(_item_attachment(item))
	if not definition or not item.get("state",{}) is Dictionary:return false
	var state: Dictionary=item.get("state",{})
	if var_to_bytes(state).size()>512 or not ATTACHMENT_STATE.valid_state(_item_attachment(item),state):return false
	return int(item.get("amount",1))>0 and int(item.get("amount",1))<=45

func _valid_item(item: Dictionary) -> bool:
	var p: Variant=item.get("position")
	if not p is Vector3 or not p.is_finite(): return false
	match str(item.get("kind","")):
		"weapon":
			var weapon:=str(item.get("weapon",""));var optic:=str(item.get("optic",""))
			if not weapon in CALIBRES or (not optic.is_empty() and not OPTICS.compatible(optic,weapon)):return false
			if not item.get("weapon_attachments",item.get("configuration",{})) is Dictionary:return false
			var config:=_weapon_configuration(item);var validation: Dictionary=ATTACHMENT_STATE.validate(weapon,config)
			if not validation.get("ok",false):return false
			var temporary:={"weapon_attachments":{weapon:config}}
			return int(item.get("magazine",0))>=0 and int(item.get("magazine",0))<=_effective_magazine_capacity(temporary,weapon)
		"optic","attachment":return _attachment_item_valid(item)
		"ammo": return str(item.get("calibre","")) in AMMO_WEIGHT and int(item.get("amount",0))>0 and int(item.get("amount",0))<=500
		"grenade": return int(item.get("amount",1))>0 and int(item.get("amount",1))<=6
		"binoculars":return true
		"heal": return int(item.get("amount",1))>0 and int(item.get("amount",1))<=15
		"pack":return int(item.get("level",0)) in [1,2,3]
		"vest","helmet":
			var level:=int(item.get("level",0))
			return level in [1,2,3] and is_finite(float(item.get("durability",PROTECTION_HP[level]))) and float(item.get("durability",PROTECTION_HP[level]))>0 and float(item.get("durability",PROTECTION_HP[level]))<=PROTECTION_HP[level]
		"container": return item.get("contents") is Array
	return false

func weight(id: int) -> float:
	if not members.has(id): return 0.0
	return _weight(members[id])

func capacity(inv: Dictionary) -> float:
	return PACK_CAPACITY[clampi(int(inv.get("backpack",0)),0,3)]

func _weight(inv: Dictionary) -> float:
	var result:=float(inv.medkits)*4.0+float(inv.get("grenades",0))*1.2+(2. if inv.get("binoculars",false) else 0.)
	for calibre in inv.ammo: result+=float(inv.ammo[calibre])*float(AMMO_WEIGHT.get(calibre,1.0))
	for item: Dictionary in inv.accessory_items:
		var definition: Resource=ATTACHMENTS.definition(str(item.id))
		if definition:result+=maxf(0.,float(definition.weight))
	return result

func _effective_magazine_capacity(inv: Dictionary,weapon: String) -> int:
	if not weapon in MAGAZINES:return 0
	var config: Dictionary=inv.get("weapon_attachments",{}).get(weapon,{})
	var stats: Dictionary=ATTACHMENT_STATE.effective({"mag":int(MAGAZINES[weapon])},weapon,config)
	var value:=float(stats.get("mag",MAGAZINES[weapon]))
	return clampi(floori(value),1,200) if is_finite(value) else int(MAGAZINES[weapon])

func effective_magazine_capacity(id: int,weapon: String) -> int:
	return _effective_magazine_capacity(members[id],weapon) if members.has(id) else int(MAGAZINES.get(weapon,0))

func _accept(inv: Dictionary,item: Dictionary) -> Dictionary:
	var kind:=str(item.kind)
	if kind=="weapon":
		var weapon:=str(item.weapon)
		if weapon in inv.weapons:
			weapon=GameWeapons.canonical(weapon)+"_br2"
			if weapon in inv.weapons:return {"ok":false,"reason":"weapon_limit"}
		if inv.weapons.size()>=WEAPON_LIMIT: return {"ok":false,"reason":"weapon_limit"}
		var config:=_weapon_configuration(item)
		if not ATTACHMENT_STATE.validate(weapon,config).get("ok",false):return {"ok":false,"reason":"attachment"}
		inv.weapon_attachments[weapon]=config
		inv.weapons.append(weapon);inv.magazines[weapon]=clampi(int(item.get("magazine",0)),0,_effective_magazine_capacity(inv,weapon))
	elif kind in ["optic","attachment"]:
		var attachment:=_item_attachment(item);var amount:=int(item.get("amount",1))
		var definition: Resource=ATTACHMENTS.definition(attachment)
		if not definition:return {"ok":false,"reason":"missing"}
		var unit_weight:=maxf(0.,float(definition.weight))
		var room:=maxi(0,floori((capacity(inv)-_weight(inv)+.0001)/unit_weight)) if unit_weight>0. else MAX_ACCESSORY_ITEMS
		var accepted:=mini(MAX_ACCESSORY_ITEMS-inv.accessory_items.size(),mini(amount,room))
		if accepted<=0:return {"ok":false,"reason":"capacity"}
		for i in accepted:
			inv.accessory_items.append({"id":attachment,"state":ATTACHMENT_STATE.stateclean(attachment,item.get("state",{})),"uid":next_accessory_uid});next_accessory_uid+=1
		inv.items+=1
		return {"ok":true,"remaining":amount-accepted}
	elif kind=="ammo":
		var calibre:=str(item.calibre)
		var amount:=int(item.amount)
		var accepted:=mini(amount,maxi(0,floori((capacity(inv)-_weight(inv)+.0001)/float(AMMO_WEIGHT[calibre]))))
		if accepted<=0:return {"ok":false,"reason":"capacity"}
		inv.ammo[calibre]=int(inv.ammo.get(calibre,0))+accepted
		inv.items+=1
		return {"ok":true,"remaining":amount-accepted}
	elif kind=="grenade":
		var amount:=int(item.get("amount",1))
		var room_by_weight:=maxi(0,floori((capacity(inv)-_weight(inv)+.0001)/1.2))
		var accepted:=mini(amount,mini(6-int(inv.get("grenades",0)),room_by_weight))
		if accepted<=0:return {"ok":false,"reason":"capacity"}
		inv.grenades=int(inv.get("grenades",0))+accepted;inv.items+=1
		return {"ok":true,"remaining":amount-accepted}
	elif kind=="binoculars":
		if inv.get("binoculars",false):return {"ok":false,"reason":"already_owned"}
		if _weight(inv)+2.>capacity(inv):return {"ok":false,"reason":"capacity"}
		inv.binoculars=true
	elif kind=="heal":
		var amount:=int(item.get("amount",1))
		var accepted:=mini(amount,maxi(0,floori((capacity(inv)-_weight(inv)+.0001)/4.)))
		if accepted<=0:return {"ok":false,"reason":"capacity"}
		inv.medkits+=accepted;inv.items+=1
		return {"ok":true,"remaining":amount-accepted}
	elif kind=="pack":
		var level:=int(item.level);var previous:=int(inv.backpack)
		if level<=previous:return {"ok":false,"reason":"already_owned"}
		inv.backpack=level;inv.items+=1
		return {"ok":true,"replaced":{"kind":"pack","level":previous,"position":item.position} if previous>0 else {}}
	elif kind in ["vest","helmet"]:
		var old: Dictionary=inv.protection[kind]
		var level:=int(item.level);var durability:=float(item.get("durability",PROTECTION_HP[level]))
		if int(old.level)>level or (int(old.level)==level and float(old.durability)>=durability):return {"ok":false,"reason":"already_owned"}
		inv.protection[kind]={"level":level,"durability":durability};inv.items+=1
		var replaced: Dictionary={}
		if int(old.level)>0 and float(old.durability)>0:replaced={"kind":kind,"level":old.level,"durability":old.durability,"position":item.position}
		return {"ok":true,"replaced":replaced}
	else: return {"ok":false,"reason":"kind"}
	inv.items+=1
	return {"ok":true}

func pickup(id: int,loot_id: int,actor_pos: Vector3,max_distance:=3.0,part_id:=-1) -> Dictionary:
	if not members.has(id) or not world_loot.has(loot_id): return {"ok":false,"reason":"missing"}
	if not actor_pos.is_finite() or max_distance<=0.0 or max_distance>4.0: return {"ok":false,"reason":"distance"}
	var item: Dictionary=world_loot[loot_id]
	if actor_pos.distance_to(item.position)>max_distance: return {"ok":false,"reason":"distance"}
	var inv: Dictionary=members[id]
	if item.kind=="container":
		var remaining: Array=[]
		var collected:=0
		for part in item.contents:
			# Reject an invalid part without consuming it as a side effect of
			# looting a different valid item from the same container.
			if not part is Dictionary or not _valid_item(part):remaining.append(part);continue
			if part_id>=0 and int(part.get("part_id",-2))!=part_id:remaining.append(part);continue
			var accepted:=_accept(inv,part)
			if bool(accepted.ok):
				collected+=1
				if int(accepted.get("remaining",0))>0:
					part.amount=int(accepted.remaining);remaining.append(part)
				if not accepted.get("replaced",{}).is_empty():
					var replaced: Dictionary=accepted.replaced;replaced.part_id=int(item.get("next_part_id",1000));item.next_part_id=replaced.part_id+1;remaining.append(replaced)
			else: remaining.append(part)
		if collected==0: return {"ok":false,"reason":"capacity"}
		if remaining.is_empty(): _remove_loot(loot_id)
		else: item.contents=remaining
		return {"ok":true,"id":loot_id,"removed":remaining.is_empty(),"inventory":snapshot(id)}
	var previous_weapons: Array=inv.weapons.duplicate()
	var result:=_accept(inv,item)
	if not bool(result.ok): return result
	var removed:=int(result.get("remaining",0))<=0
	if removed:_remove_loot(loot_id)
	else:item.amount=int(result.remaining)
	if not result.get("replaced",{}).is_empty():add_loot(result.replaced)
	var added: Array=inv.weapons.filter(func(entry):return entry not in previous_weapons)
	return {"ok":true,"id":loot_id,"removed":removed,"inventory":snapshot(id),"weapon":str(added[0]) if not added.is_empty() else ""}

func drop_pack(id: int,position: Vector3) -> Dictionary:
	if not members.has(id) or not position.is_finite():return {"ok":false}
	var inv: Dictionary=members[id]
	if int(inv.backpack)<=0 or _weight(inv)>PACK_CAPACITY[0]+.0001:return {"ok":false,"reason":"capacity"}
	var loot:=add_loot({"kind":"pack","level":inv.backpack,"position":position})
	if loot<0:return {"ok":false}
	inv.backpack=0
	return {"ok":true,"id":loot,"inventory":snapshot(id)}

func drop_heal(id: int,amount: int,position: Vector3) -> Dictionary:
	if not members.has(id) or not position.is_finite() or amount<=0 or amount>int(members[id].medkits):return {"ok":false}
	var loot:=add_loot({"kind":"heal","amount":amount,"position":position})
	if loot<0:return {"ok":false}
	members[id].medkits-=amount
	return {"ok":true,"id":loot,"inventory":snapshot(id)}

func drop_weapon(id: int,weapon: String,position: Vector3) -> Dictionary:
	if not members.has(id) or not weapon in members[id].weapons or not position.is_finite(): return {"ok":false}
	var inv: Dictionary=members[id]
	var loot_id:=add_loot(_weapon_loot(inv,weapon,position))
	if loot_id<0: return {"ok":false}
	inv.weapons.erase(weapon);inv.magazines.erase(weapon);inv.weapon_attachments.erase(weapon)
	return {"ok":true,"id":loot_id,"inventory":snapshot(id)}

func equip_optic(id: int,weapon: String,optic: String) -> Dictionary:
	if not members.has(id) or weapon not in members[id].weapons:return {"ok":false,"reason":"ownership"}
	var config: Dictionary=members[id].weapon_attachments.get(weapon,{})
	var selected: String=OPTICS.resolve(optic,weapon) if not optic.is_empty() else ""
	if not optic.is_empty() and not OPTICS.compatible(optic,weapon):return {"ok":false,"reason":"compatibility"}
	for socket in config:
		var definition: Resource=ATTACHMENTS.definition(str(config[socket].id))
		if definition and str(definition.category)=="optic":return equip_attachment(id,weapon,str(socket),selected)
	if selected.is_empty():return {"ok":true,"inventory":snapshot(id)}
	for socket in ATTACHMENT_STATE.sockets(weapon,config):
		if ATTACHMENT_STATE.can_install(weapon,config,str(socket),selected).get("ok",false):return equip_attachment(id,weapon,str(socket),selected)
	return {"ok":false,"reason":"compatibility"}

func _accessory_index(inv: Dictionary,attachment: String,uid: int) -> int:
	for i in inv.accessory_items.size():
		var item: Dictionary=inv.accessory_items[i]
		if str(item.id)==attachment and (uid<0 or int(item.uid)==uid):return i
	return -1

func equip_attachment(id: int,weapon: String,socket: String,attachment: String,uid: int=-1,position: float=0.) -> Dictionary:
	if not members.has(id) or weapon not in members[id].weapons:return {"ok":false,"reason":"ownership"}
	if socket.is_empty() or socket.length()>128 or not is_finite(position):return {"ok":false,"reason":"socket"}
	var inv: Dictionary=members[id];var config: Dictionary=inv.weapon_attachments.get(weapon,{})
	var pieces:=socket.rsplit("/",true,1);var leaf:=str(pieces[-1]).split("@",true,1)[0]
	var socket_key:=str(pieces[0])+"/"+leaf if pieces.size()>1 else leaf
	if not ATTACHMENT_STATE.validate(weapon,config).get("ok",false) or not ATTACHMENT_STATE.sockets(weapon,config).has(socket_key):return {"ok":false,"reason":"socket"}
	var existing: Dictionary=config.get(socket,{})
	if str(existing.get("id",""))==attachment and not attachment.is_empty() and uid<0 and is_equal_approx(float(existing.get("position",0.)),position):return {"ok":true,"inventory":snapshot(id)}
	var bag_index:=-1;var plan: Dictionary
	if attachment.is_empty():plan=ATTACHMENT_STATE.remove(weapon,config,socket)
	else:
		bag_index=_accessory_index(inv,attachment,uid)
		if bag_index<0:return {"ok":false,"reason":"missing"}
		plan=ATTACHMENT_STATE.install(weapon,config,socket,attachment,inv.accessory_items[bag_index].state,position)
	if not plan.get("ok",false):return {"ok":false,"reason":str(plan.get("reason","compatibility"))}
	# Everything below is a candidate transaction. Failed capacity or magazine
	# conversion leaves the weapon, bag instances and ammunition untouched.
	var updated: Dictionary=inv.duplicate(true)
	if bag_index>=0:updated.accessory_items.remove_at(bag_index)
	var candidate_uid:=next_accessory_uid
	for entry: Dictionary in plan.get("removed",[]):
		updated.accessory_items.append({"id":str(entry.id),"state":entry.get("state",{}).duplicate(true),"uid":candidate_uid});candidate_uid+=1
	updated.weapon_attachments[weapon]=plan.state.duplicate(true)
	var maximum:=_effective_magazine_capacity(updated,weapon)
	var excess:=maxi(0,int(updated.magazines.get(weapon,0))-maximum)
	if excess>0:
		updated.magazines[weapon]=maximum
		var calibre:=calibre_for(weapon);updated.ammo[calibre]=int(updated.ammo.get(calibre,0))+excess
	if updated.accessory_items.size()>MAX_ACCESSORY_ITEMS or _weight(updated)>capacity(updated)+.0001:return {"ok":false,"reason":"capacity"}
	members[id]=updated;next_accessory_uid=candidate_uid
	return {"ok":true,"inventory":snapshot(id),"returned":plan.get("removed",[]).duplicate(true),"ammo_returned":excess}

func update_attachment_state(id: int,weapon: String,socket: String,state: Dictionary) -> Dictionary:
	if not members.has(id) or weapon not in members[id].weapons:return {"ok":false,"reason":"ownership"}
	var config: Dictionary=members[id].weapon_attachments.get(weapon,{})
	if not config.get(socket) is Dictionary:return {"ok":false,"reason":"socket"}
	var entry: Dictionary=config[socket]
	if not ATTACHMENT_STATE.valid_state(str(entry.id),state):return {"ok":false,"reason":"state"}
	var updated:=config.duplicate(true);updated[socket].state=ATTACHMENT_STATE.stateclean(str(entry.id),state)
	if not ATTACHMENT_STATE.validate(weapon,updated).get("ok",false):return {"ok":false,"reason":"compatibility"}
	members[id].weapon_attachments[weapon]=updated
	return {"ok":true,"inventory":snapshot(id)}

func drop_optic(id: int,optic: String,position: Vector3) -> Dictionary:
	return drop_attachment(id,optic,position,-1,true)

func drop_attachment(id: int,attachment: String,position: Vector3,uid: int=-1,legacy_optic:=false) -> Dictionary:
	if not members.has(id) or not position.is_finite():return {"ok":false}
	var index:=_accessory_index(members[id],attachment,uid)
	if index<0:return {"ok":false}
	var item: Dictionary=members[id].accessory_items[index]
	var record:={"kind":"attachment","attachment":attachment,"state":item.state.duplicate(true),"amount":1,"position":position}
	if legacy_optic:record.kind="optic";record.optic=attachment
	var loot:=add_loot(record)
	if loot<0:return {"ok":false}
	members[id].accessory_items.remove_at(index)
	return {"ok":true,"id":loot,"inventory":snapshot(id)}

func _weapon_loot(inv: Dictionary,weapon: String,position: Vector3) -> Dictionary:
	var config: Dictionary=inv.weapon_attachments.get(weapon,{})
	return {"kind":"weapon","weapon":GameWeapons.canonical(weapon),"magazine":int(inv.magazines.get(weapon,0)),"weapon_attachments":config.duplicate(true),"optic":ATTACHMENT_STATE.legacy_optic(weapon,config),"position":position}

func drop_ammo(id: int,calibre: String,amount: int,position: Vector3) -> Dictionary:
	if not members.has(id) or not calibre in AMMO_WEIGHT or amount<=0 or not position.is_finite(): return {"ok":false}
	var inv: Dictionary=members[id]
	if int(inv.ammo.get(calibre,0))<amount: return {"ok":false}
	var loot_id:=add_loot({"kind":"ammo","calibre":calibre,"amount":amount,"position":position})
	if loot_id<0: return {"ok":false}
	inv.ammo[calibre]-=amount
	return {"ok":true,"id":loot_id,"inventory":snapshot(id)}

func drop_protection(id: int,kind: String,position: Vector3) -> Dictionary:
	if not members.has(id) or kind not in ["vest","helmet"] or not position.is_finite():return {"ok":false}
	var old: Dictionary=members[id].protection[kind]
	if int(old.level)<=0 or float(old.durability)<=0:return {"ok":false}
	var item:=old.duplicate();item.kind=kind;item.position=position
	var loot:=add_loot(item)
	if loot<0:return {"ok":false}
	members[id].protection[kind]={"level":0,"durability":0.}
	return {"ok":true,"id":loot,"inventory":snapshot(id)}

func protected_damage(id: int,amount: float,region: String,consume:=true) -> float:
	if not members.has(id) or not is_finite(amount) or amount<=0:return maxf(0.,amount)
	var kind: String="helmet" if region=="head" else ("vest" if region in ["chest","abdomen","abdomenPelvis","torso"] else "")
	if kind.is_empty():return amount
	var item: Dictionary=members[id].protection[kind];var level:=clampi(int(item.level),0,3)
	var absorbed:=minf(float(item.durability),amount*PROTECTION_RATIO[level])
	if consume:
		item.durability=maxf(0.,float(item.durability)-absorbed)
		if float(item.durability)<=0:item.level=0
	return amount-absorbed

func consume_shot(id: int,weapon: String) -> bool:
	if not members.has(id) or not weapon in members[id].weapons: return false
	var inv: Dictionary=members[id]
	if int(inv.magazines.get(weapon,0))<=0: return false
	inv.magazines[weapon]-=1
	return true

func reload(id: int,weapon: String) -> int:
	# Call on reload COMPLETION, after the shared combat cadence/life checks.
	if not members.has(id) or not weapon in members[id].weapons: return 0
	var inv: Dictionary=members[id]
	var calibre:=str(CALIBRES[weapon])
	var amount:=mini(_effective_magazine_capacity(inv,weapon)-int(inv.magazines.get(weapon,0)),int(inv.ammo.get(calibre,0)))
	if amount<=0: return 0
	inv.magazines[weapon]=int(inv.magazines.get(weapon,0))+amount
	inv.ammo[calibre]=int(inv.ammo.get(calibre,0))-amount
	return amount

func use_medkit(id: int,current_hp: float) -> float:
	if not members.has(id) or current_hp<=0.0 or current_hp>=100.0 or not is_finite(current_hp): return 0.0
	if int(members[id].medkits)<=0: return 0.0
	members[id].medkits-=1
	return minf(50.0,100.0-current_hp)

func drop_all(id: int,position: Vector3) -> int:
	if not members.has(id) or not position.is_finite(): return -1
	var inv: Dictionary=members[id]
	var contents: Array=[]
	if inv.get("binoculars",false):contents.append({"kind":"binoculars","position":position})
	for weapon in inv.weapons:
		contents.append(_weapon_loot(inv,str(weapon),position))
	for item: Dictionary in inv.accessory_items:
		contents.append({"kind":"attachment","attachment":str(item.id),"state":item.state.duplicate(true),"amount":1,"position":position})
	if int(inv.get("grenades",0))>0:contents.append({"kind":"grenade","amount":int(inv.grenades),"position":position})
	for calibre in inv.ammo:
		var remaining:=maxi(0,int(inv.ammo[calibre]))
		while remaining>0:
			var amount:=mini(500,remaining);contents.append({"kind":"ammo","calibre":calibre,"amount":amount,"position":position});remaining-=amount
	var remaining_heals:=maxi(0,int(inv.medkits))
	while remaining_heals>0:
		var amount:=mini(15,remaining_heals);contents.append({"kind":"heal","amount":amount,"position":position});remaining_heals-=amount
	if int(inv.backpack)>0:contents.push_front({"kind":"pack","level":int(inv.backpack),"position":position})
	for kind in ["vest","helmet"]:
		var protection: Dictionary=inv.protection[kind]
		if int(protection.level)>0 and float(protection.durability)>0:contents.append({"kind":kind,"level":protection.level,"durability":protection.durability,"position":position})
	# Emptying immediately makes duplicate death callbacks harmless.
	add_player(id)
	if contents.is_empty(): return -1
	return add_loot({"kind":"container","contents":contents,"position":position})

func snapshot(id: int) -> Dictionary:
	if not members.has(id): return {}
	var copy: Dictionary=members[id].duplicate(true)
	copy.capacity=capacity(copy);copy.weight=_weight(copy);copy.reserves={}
	for weapon in copy.weapons: copy.reserves[weapon]=int(copy.ammo.get(CALIBRES[weapon],0))
	copy.reserve_by_weapon=copy.reserves.duplicate()
	copy.accessories={};copy.optics={};copy.attachments={};copy.bag_items=[]
	for item: Dictionary in copy.accessory_items:
		var attachment:=str(item.id);copy.accessories[attachment]=int(copy.accessories.get(attachment,0))+1
		var definition: Resource=ATTACHMENTS.definition(attachment)
		if definition and str(definition.category)=="optic":copy.optics[attachment]=int(copy.optics.get(attachment,0))+1
		copy.bag_items.append({"kind":"attachment","attachment":attachment,"state":item.state.duplicate(true),"uid":item.uid,"amount":1})
	for weapon in copy.weapon_attachments:
		var optic:=ATTACHMENT_STATE.legacy_optic(str(weapon),copy.weapon_attachments[weapon])
		if not optic.is_empty():copy.attachments[weapon]=optic
	for calibre in copy.ammo:
		if int(copy.ammo[calibre])>0:copy.bag_items.append({"kind":"ammo","calibre":str(calibre),"amount":int(copy.ammo[calibre])})
	if copy.get("binoculars",false):copy.bag_items.append({"kind":"binoculars"})
	if int(copy.medkits)>0:copy.bag_items.append({"kind":"heal","amount":int(copy.medkits)})
	return copy

func nearby(position: Vector3,radius:=80.0) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	last_query_candidates=0
	if not position.is_finite() or not is_finite(radius): return result
	var reach:=clampf(radius,0.0,100.0)
	var radius_sq:=reach*reach
	var low:=_cell(position-Vector3(reach,0.0,reach))
	var high:=_cell(position+Vector3(reach,0.0,reach))
	for x in range(low.x,high.x+1):
		for z in range(low.y,high.y+1):
			var cell:=Vector2i(x,z)
			if not spatial_cells.has(cell): continue
			for id in spatial_cells[cell]:
				last_query_candidates+=1
				var item: Dictionary=world_loot[id]
				if position.distance_squared_to(item.position)<=radius_sq:
					var copy:=item.duplicate(true)
					if position.distance_squared_to(item.position)>9.:copy.erase("contents")
					result.append(copy)
	return result

func move_loot(id: int,position: Vector3) -> void:
	if not world_loot.has(id) or not position.is_finite():return
	var item: Dictionary=world_loot[id];var old:=_cell(item.position);var next:=_cell(position)
	if old!=next:
		if spatial_cells.has(old):
			spatial_cells[old].erase(id)
			if spatial_cells[old].is_empty():spatial_cells.erase(old)
		if not spatial_cells.has(next):spatial_cells[next]={}
		spatial_cells[next][id]=true
	item.position=position
	for part: Dictionary in item.get("contents",[]):part.position=position

func pickup_replace(id: int,loot_id: int,position: Vector3,old_weapon: String,part_id: int=-1) -> Dictionary:
	if not members.has(id) or old_weapon not in members[id].weapons or not world_loot.has(loot_id):return {"ok":false,"reason":"ownership"}
	var world: Dictionary=world_loot[loot_id];var target: Dictionary=world
	if world.kind=="container":
		target={}
		for part: Dictionary in world.contents:
			if int(part.get("part_id",-2))==part_id:target=part;break
	if target.get("kind","")!="weapon":return {"ok":false,"reason":"kind"}
	var before: Dictionary=members[id].duplicate(true);var dropped:=_weapon_loot(before,old_weapon,position)
	members[id].weapons.erase(old_weapon);members[id].magazines.erase(old_weapon);members[id].weapon_attachments.erase(old_weapon)
	var result:=pickup(id,loot_id,position,3.,part_id)
	if not result.get("ok",false):members[id]=before;return result
	add_loot(dropped)
	return result
