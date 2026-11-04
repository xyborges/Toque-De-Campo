extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func run() -> void:
	var inventory:=BRInventory.new()
	inventory.add_player(1)
	var loot_id:=inventory.add_loot({"kind":"grenade","amount":3,"position":Vector3.ZERO})
	var result:=inventory.pickup(1,loot_id)
	check(bool(result.get("ok",false)),"grenade pickup accepted")
	check(int(inventory.snapshot(1).get("grenades",0))==3,"grenades stored in backpack")
	inventory.members[1].grenades=2
	var dropped:=inventory.drop_all(1,Vector3(4,0,7))
	check(dropped>0,"corpse container created")
	var corpse: Dictionary=inventory.world_loot.get(dropped,{})
	var grenade_amount:=0
	for item: Dictionary in corpse.get("contents",[]):
		if str(item.get("kind",""))=="grenade":grenade_amount+=int(item.get("amount",0))
	check(grenade_amount==2,"corpse contains current grenade count, not stale pickup count")
	check(int(inventory.snapshot(1).get("grenades",0))==0,"dead inventory is cleared")
	print("BR_GRENADE_DROP_VALIDATION ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
