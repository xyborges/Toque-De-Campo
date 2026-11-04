extends RefCounted
class_name GameInventorySlots

static func resolve(actor: GamePlayer) -> Dictionary:
	if actor.has_meta("quick_slots") and actor.get_meta("quick_slots_owned")==actor.owned and actor.get_meta("quick_slots_loadout")==actor.loadout and bool(actor.get_meta("quick_slots_grenades",true))==actor.grenades_enabled:
		return actor.get_meta("quick_slots")
	var active:=actor.active_weapons()
	var result: Dictionary={3:"grenade"} if actor.grenades_enabled else {}
	var choices:=active.duplicate()
	choices.sort_custom(func(a,b): return int(GameWeapons.ITEMS[a].get("priority",10))<int(GameWeapons.ITEMS[b].get("priority",10)))
	for id in choices:
		if not GameWeapons.ITEMS.has(id): continue
		var slot:=int(GameWeapons.ITEMS[id].get("slot",4))
		if str(result.get(slot,"")).is_empty(): result[slot]=id
	var extra:=[5,6,9]
	var remaining:=choices.filter(func(id): return id not in result.values())
	remaining.sort_custom(func(a,b): return GameWeapons.ITEMS[a].kind=="firearm" and GameWeapons.ITEMS[b].kind!="firearm")
	for id in remaining:
		if extra.is_empty(): break
		result[extra.pop_front()]=id
	actor.set_meta("quick_slots_grenades",actor.grenades_enabled)
	actor.set_meta("quick_slots_owned",actor.owned.duplicate())
	actor.set_meta("quick_slots_loadout",actor.loadout.duplicate())
	actor.set_meta("quick_slots",result)
	return result
