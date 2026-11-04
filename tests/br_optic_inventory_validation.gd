extends SceneTree
const FIXTURE=preload("res://tests/br_completion_fixture.gd")
const OPTICS=preload("res://scripts/optic_catalog.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func take(inv: BRInventory,id: int,item: Dictionary) -> bool:
	item.position=Vector3.ZERO
	return bool(inv.pickup(id,inv.add_loot(item),Vector3.ZERO).get("ok",false))
func run() -> void:
	var inv:=BRInventory.new();inv.add_player(1);inv.add_player(2)
	for weapon in ["fal","ak"]:
		for optic in ["prism4x","pso4x"]:check(OPTICS.compatible(optic,weapon),"both independent optics fit "+weapon+" "+optic)
	check(not OPTICS.compatible("prism4x","glock"),"pistol rejects telescope")
	check(inv.add_loot({"kind":"optic","optic":"made_up","position":Vector3.ZERO})<0,"unknown optic rejected")
	check(take(inv,1,{"kind":"weapon","weapon":"fal","magazine":7}),"FAL obtained")
	check(take(inv,1,{"kind":"weapon","weapon":"ak","magazine":11}),"AK obtained")
	check(take(inv,1,{"kind":"optic","optic":"pso4x","amount":2}),"optic stack obtained")
	check(inv.weight(1)==8. and inv.snapshot(1).optics.pso4x==2,"bag stack weighs four per item")
	check(inv.equip_optic(1,"fal","pso4x").ok and inv.snapshot(1).attachments.fal=="pso4x" and inv.snapshot(1).optics.pso4x==1 and inv.weight(1)==4.,"equip FAL consumes one bag item without weight")
	check(inv.equip_optic(1,"ak","pso4x").ok and inv.snapshot(1).optics.is_empty() and inv.weight(1)==0.,"same optic can be fitted to AK independently")
	check(not inv.equip_optic(1,"fal","prism4x").ok,"missing optic cannot be created by selection")
	check(not inv.equip_optic(2,"fal","pso4x").ok,"weapon ownership enforced")
	check(take(inv,1,{"kind":"optic","optic":"prism4x","amount":1}),"alternate optic obtained")
	check(take(inv,1,{"kind":"heal","amount":14}) and inv.weight(1)==60.,"fill bag to exact capacity")
	var before:=inv.snapshot(1)
	check(not inv.equip_optic(1,"fal","").ok and inv.snapshot(1)==before,"detach into full bag is rejected atomically")
	check(inv.equip_optic(1,"fal","prism4x").ok and inv.snapshot(1).attachments.fal=="prism4x" and inv.snapshot(1).optics.pso4x==1 and inv.weight(1)==60.,"full bag swaps optics transactionally")
	var optic_drop:=inv.drop_optic(1,"pso4x",Vector3.ZERO)
	check(optic_drop.ok and inv.snapshot(1).optics.is_empty() and inv.world_loot[optic_drop.id].optic=="pso4x","drop removes exactly one carried optic")
	check(inv.equip_optic(1,"fal","").ok and inv.snapshot(1).optics.prism4x==1 and not inv.snapshot(1).attachments.has("fal"),"detach uses free capacity and preserves item")
	check(inv.equip_optic(1,"fal","prism4x").ok,"optic can be fitted again")
	var gun_drop:=inv.drop_weapon(1,"fal",Vector3.ZERO)
	check(gun_drop.ok and inv.world_loot[gun_drop.id].optic=="prism4x" and not inv.snapshot(1).attachments.has("fal"),"discarded weapon carries its fitted optic")
	check(inv.pickup(2,gun_drop.id,Vector3.ZERO).ok and inv.snapshot(2).attachments.fal=="prism4x" and inv.snapshot(2).optics.is_empty(),"other survivor receives attached optic without a duplicate loose item")
	var corpse:=inv.drop_all(1,Vector3.ZERO)
	var attached:=0
	for item: Dictionary in inv.world_loot[corpse].contents:
		if item.kind=="weapon" and item.weapon=="ak" and item.optic=="pso4x":attached+=1
	check(attached==1 and inv.drop_all(1,Vector3.ZERO)<0,"corpse preserves attachment exactly once")
	check(inv.pickup(2,corpse,Vector3.ZERO).ok and inv.snapshot(2).attachments.ak=="pso4x","corpse weapon restores attached optic")
	var private_copy:=inv.snapshot(2);private_copy.attachments.clear()
	check(inv.snapshot(2).attachments.size()==2,"snapshot cannot mutate equipment authority")
	var table:=BRLootTable.new();table.optic_chance=1.
	var generated:=table.generate(17,[Vector3.ZERO,Vector3(8,0,0)])
	check(generated.size()>=2 and generated.all(func(item: Dictionary):return str(item.get("kind",""))=="attachment" and GameAttachmentRegistry.definition(str(item.get("attachment","")))!=null and minf(Vector3(item.position).distance_to(Vector3.ZERO),Vector3(item.position).distance_to(Vector3(8,0,0)))<=1.16),"registry accessory loot stays near authored anchors across spawn clusters")
	var game: BattleRoyaleGame=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	await process_frame;game.flat_world()
	var actor:=game._spawn_player(1,true,false,Vector3.ZERO) as BRPlayer
	var target:=game._spawn_player(2,false,false,Vector3(4,0,0)) as BRPlayer
	for player in [actor,target]:player.set_physics_process(false);player.set_process(false);game.br_inventory.add_player(player.peer_id)
	game.br_round.begin([1,2],game._now());game.br_generation=1
	await physics_frame;await physics_frame
	for item in [{"kind":"weapon","weapon":"fal","magazine":5},{"kind":"optic","optic":"pso4x","amount":1}]:
		item.position=Vector3(.4,.05,0)
		check(game._br_action(1,"pickup",{"id":game.br_inventory.add_loot(item)},actor.life_id,1),"production pickup "+str(item.kind))
	check(not game._br_action(1,"optic",{"weapon":"fal","optic":"pso4x"},actor.life_id,0),"old generation cannot attach optic")
	check(not game._br_action(1,"optic",{"weapon":"fal","optic":"pso4x"},actor.life_id-1,1),"old life cannot attach optic")
	check(game._br_action(1,"optic",{"weapon":"fal","optic":"pso4x"},actor.life_id,1) and actor.get_meta("weapon_optics",{}).get("fal","")=="pso4x","authority attaches optic to actual actor model metadata")
	actor.hp=0.
	check(not game._br_action(1,"optic",{"weapon":"fal","optic":""},actor.life_id,1),"dead player cannot modify attachments")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Independent 4x optics, bag capacity, atomic equip/swap/detach, weapon drop and corpse preservation, production actor metadata and life/generation/death checks; no FPS claim."}
	NavalStorage.write_json("res://work/br-optic-inventory-validation.json",report);print("BR_OPTIC_INVENTORY_VALIDATION ",JSON.stringify(report))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
