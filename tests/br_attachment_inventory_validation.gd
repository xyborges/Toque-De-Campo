extends SceneTree
const INV=preload("res://modes/battle_royale/state/inventory.gd")
const REGISTRY=preload("res://scripts/attachments/registry.gd")
const STATE=preload("res://scripts/attachments/state.gd")
const DEFINITION=preload("res://scripts/attachments/definition.gd")
const SOCKET=preload("res://scripts/attachments/socket.gd")
var checks:=0
var failures: Array[String]=[]
var registered: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func take(inv: BRInventory,id: int,item: Dictionary) -> bool:
	item.position=Vector3.ZERO
	var loot:=inv.add_loot(item)
	return loot>0 and bool(inv.pickup(id,loot,Vector3.ZERO).get("ok",false))
func socket(id: String,category: String,interface_id: String) -> Resource:
	var value:=SOCKET.new();value.id=id;value.categories=PackedStringArray([category]);value.interfaces=PackedStringArray([interface_id]);return value
func definition(id: String,category: String,interface_id: String,weight: float) -> Resource:
	var value:=DEFINITION.new();value.id=id;value.display_name=id;value.category=category;value.required_interfaces=PackedStringArray([interface_id]);value.weight=weight;value.production=false
	REGISTRY.register_definition(value);registered.append(id);return value
func accessory(inv: BRInventory,id: int,module: String,state: Dictionary={}) -> bool:
	return take(inv,id,{"kind":"attachment","attachment":module,"state":state,"amount":1})
func run() -> void:
	var original: Resource=REGISTRY.profile("fal")
	check(original!=null,"real firearm has registry profile")
	if not original:quit(1);return
	var profile: Resource=original.duplicate(true)
	profile.sockets.append(socket("qa_adapter","adapter","qa_base"));profile.sockets.append(socket("qa_mag","magazine","qa_fal_mag"));profile.sockets.append(socket("qa_side","light","qa_side"))
	REGISTRY.register_profile(profile)
	var adapter:=definition("qa_adapter","adapter","qa_base",1.)
	adapter.provided_sockets.append(socket("rail","light","qa_rail"))
	var light:=definition("qa_light","light","qa_rail",3.)
	light.state_schema={"on":{"type":"bool","default":false},"charge":{"type":"float","min":0.,"max":1.,"default":1.}}
	var magazine:=definition("qa_magazine","magazine","qa_fal_mag",2.);magazine.modifiers_flat={"mag":10.}
	var wrong:=definition("qa_wrong_interface","light","wrong",2.)
	var large:=definition("qa_large","light","qa_side",2.);large.required_space=Vector3(2,2,2)
	var conflict:=definition("qa_conflict","light","qa_side",2.);conflict.tags=PackedStringArray(["blocked"]);light.conflict_tags=PackedStringArray(["blocked"])
	var inv:=INV.new();inv.add_player(1);inv.add_player(2)
	check(take(inv,1,{"kind":"weapon","weapon":"fal","magazine":20}),"base FAL picked without modules")
	check(accessory(inv,1,"qa_adapter") and accessory(inv,1,"qa_light",{"on":true,"charge":.25}),"different categories share generic collectible flow")
	check(inv.snapshot(1).accessory_items.size()==2 and inv.snapshot(1).optics.is_empty() and inv.weight(1)==4.,"generic accessory bag owns individual state and weight")
	check(not accessory(inv,1,"qa_light",{"on":1}),"invalid typed module state rejected")
	check(not accessory(inv,1,"qa_light",{"on":true,"charge":INF}),"nonfinite module state rejected")
	check(not inv.equip_attachment(2,"fal","qa_adapter","qa_adapter").ok,"module installation enforces firearm ownership")
	check(not inv.equip_attachment(1,"fal","qa_adapter/rail","qa_light").ok,"child module cannot mount without parent adapter")
	check(inv.equip_attachment(1,"fal","qa_adapter","qa_adapter").ok and inv.equip_attachment(1,"fal","qa_adapter/rail","qa_light").ok,"adapter adds usable socket for nested independent light")
	check(inv.weight(1)==0. and inv.snapshot(1).weapon_attachments.fal["qa_adapter/rail"].state=={"on":true,"charge":.25},"installed state is individual and leaves bag")
	check(not inv.equip_attachment(1,"fal","unknown","").ok,"unknown socket cannot authorize a removal action")
	check(not inv.update_attachment_state(1,"fal","qa_adapter/rail",{"on":1}).ok,"generic state update rejects wrong schema type")
	check(inv.update_attachment_state(1,"fal","qa_adapter/rail",{"on":false,"charge":.5}).ok and inv.snapshot(1).weapon_attachments.fal["qa_adapter/rail"].state=={"on":false,"charge":.5},"generic state update changes only the installed instance")
	inv.update_attachment_state(1,"fal","qa_adapter/rail",{"on":true,"charge":.25})
	check(accessory(inv,1,"qa_wrong_interface") and not inv.equip_attachment(1,"fal","qa_side","qa_wrong_interface").ok,"wrong physical interface rejected by common flow")
	check(accessory(inv,1,"qa_large") and not inv.equip_attachment(1,"fal","qa_side","qa_large").ok,"physical module volume enforced")
	check(accessory(inv,1,"qa_conflict") and not inv.equip_attachment(1,"fal","qa_side","qa_conflict").ok,"cross-socket incompatible tags rejected")
	for item: Dictionary in inv.snapshot(1).accessory_items:inv.drop_attachment(1,str(item.id),Vector3.ZERO,int(item.uid))
	check(take(inv,1,{"kind":"heal","amount":15}),"fill bag to test nested removal transaction")
	var before:=inv.snapshot(1)
	check(not inv.equip_attachment(1,"fal","qa_adapter","").ok and inv.snapshot(1)==before,"full bag rejects cascade without orphaning or consuming any item")
	inv.drop_heal(1,1,Vector3.ZERO)
	var removal:=inv.equip_attachment(1,"fal","qa_adapter","")
	check(removal.ok and removal.returned.size()==2 and inv.snapshot(1).weapon_attachments.fal.is_empty() and inv.snapshot(1).accessory_items.size()==2 and inv.weight(1)==60.,"parent removal returns whole dependent subtree atomically")
	var uid:=-1
	for item: Dictionary in inv.snapshot(1).accessory_items:
		if item.id=="qa_light":uid=int(item.uid)
	var dropped:=inv.drop_attachment(1,"qa_light",Vector3.ZERO,uid)
	check(dropped.ok and inv.world_loot[dropped.id].state=={"on":true,"charge":.25},"discarded module preserves its runtime state")
	check(inv.pickup(2,dropped.id,Vector3.ZERO).ok and inv.snapshot(2).accessory_items[0].state=={"on":true,"charge":.25},"another owner recovers exact module state")
	var other_uid:=int(inv.snapshot(2).accessory_items[0].uid)
	check(not inv.drop_attachment(2,"qa_light",Vector3.ZERO,other_uid+999).ok,"instance selection rejects unknown bag UID")
	accessory(inv,1,"qa_light",{"on":false,"charge":.9})
	inv.drop_heal(1,1,Vector3.ZERO)
	inv.equip_attachment(1,"fal","qa_adapter","qa_adapter")
	var selected_uid:=-1
	for item: Dictionary in inv.snapshot(1).accessory_items:
		if item.id=="qa_light":selected_uid=int(item.uid)
	check(inv.equip_attachment(1,"fal","qa_adapter/rail","qa_light",selected_uid).ok and inv.snapshot(1).weapon_attachments.fal["qa_adapter/rail"].state.charge==.9,"UID selects the intended independently stateful accessory")
	inv.add_player(1)
	take(inv,1,{"kind":"weapon","weapon":"fal","magazine":20});take(inv,1,{"kind":"ammo","calibre":"76251","amount":40});accessory(inv,1,"qa_magazine")
	check(inv.equip_attachment(1,"fal","qa_mag","qa_magazine").ok and inv.effective_magazine_capacity(1,"fal")==30,"effective magazine capacity derives from module modifiers")
	check(inv.reload(1,"fal")==10 and inv.snapshot(1).magazines.fal==30 and inv.snapshot(1).ammo["76251"]==30,"extended magazine reload consumes reserve without creating rounds")
	take(inv,1,{"kind":"heal","amount":13})
	before=inv.snapshot(1)
	check(not inv.equip_attachment(1,"fal","qa_mag","").ok and inv.snapshot(1)==before,"capacity reduction cannot erase overflow or overflow full bag")
	inv.drop_heal(1,2,Vector3.ZERO)
	removal=inv.equip_attachment(1,"fal","qa_mag","")
	check(removal.ok and removal.ammo_returned==10 and inv.effective_magazine_capacity(1,"fal")==20 and inv.snapshot(1).magazines.fal==20 and inv.snapshot(1).ammo["76251"]==40,"removing extended capacity returns overflow to matching reserve")
	for cycle in 6:
		check(inv.equip_attachment(1,"fal","qa_mag","qa_magazine").ok,"repeat install keeps base stats cycle%d"%cycle)
		inv.reload(1,"fal")
		check(inv.equip_attachment(1,"fal","qa_mag","").ok and inv.snapshot(1).magazines.fal+inv.snapshot(1).ammo["76251"]==60,"repeat removal conserves every round cycle%d"%cycle)
	inv.add_player(1);take(inv,1,{"kind":"weapon","weapon":"fal","magazine":7});accessory(inv,1,"qa_adapter");accessory(inv,1,"qa_light",{"on":false,"charge":.75})
	inv.equip_attachment(1,"fal","qa_adapter","qa_adapter");inv.equip_attachment(1,"fal","qa_adapter/rail","qa_light")
	var discarded:=inv.drop_weapon(1,"fal",Vector3.ZERO)
	check(discarded.ok and inv.world_loot[discarded.id].weapon_attachments.size()==2 and inv.world_loot[discarded.id].magazine==7,"discarded weapon retains complete nested configuration and ammunition")
	check(inv.pickup(2,discarded.id,Vector3.ZERO).ok and inv.snapshot(2).weapon_attachments.fal["qa_adapter/rail"].state.charge==.75,"weapon transfer reconstructs nested state without extra loose module")
	var corpse:=inv.drop_all(2,Vector3.ZERO)
	check(corpse>0 and inv.drop_all(2,Vector3.ZERO)<0,"corpse transfer is idempotent")
	check(inv.pickup(1,corpse,Vector3.ZERO).ok and inv.snapshot(1).weapon_attachments.fal.size()==2 and inv.snapshot(1).accessory_items.size()==1,"corpse has installed subtree plus separately carried module exactly once")
	var copy:=inv.snapshot(1);copy.weapon_attachments.fal.clear();copy.accessory_items.clear()
	check(inv.snapshot(1).weapon_attachments.fal.size()==2 and inv.snapshot(1).accessory_items.size()==1,"private snapshot cannot mutate authoritative modules")
	var table:=BRLootTable.new();table.attachment_chance=1.;var generated:=table.generate(19,[Vector3.ZERO,Vector3(4,0,0)])
	check(generated.size()==2 and generated[0].kind=="attachment" and not str(generated[0].attachment).begins_with("qa_"),"editable loot table uses production registry without fixture definitions")
	REGISTRY.register_profile(original)
	for id: String in registered:REGISTRY.unregister_definition(id)
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Generic inventory transaction with test-only adapter, stateful light, conflicts, physical fit and magazine modifier; no new production items or FPS claim."}
	NavalStorage.write_json("res://work/br-attachment-inventory-validation.json",report);print("BR_ATTACHMENT_INVENTORY_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
