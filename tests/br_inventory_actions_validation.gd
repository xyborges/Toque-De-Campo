extends SceneTree
const FIXTURE=preload("res://tests/br_round_clock_fixture.gd")
var game: BattleRoyaleGame
var actor: BRPlayer
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func reset() -> void:
	game.br_inventory.clear();game.br_generation=3;game.phase="active";game.test_clock=100.;game.heal_pending.clear();game.heal_restore.clear();game.zone_clock=0.
	game.br_round=BRRound.new();game.br_round.begin([1,2,3],100.);game.br_zone.configure(42,[Vector3.ZERO]);game.br_zone.begin(100.)
	for player: BRPlayer in game.players.values():
		player.hp=100.;player.life_id=7;player.position=Vector3.ZERO if player.peer_id==1 else Vector3(20+player.peer_id,0,20)
		player.loadout=[];player.owned=["fists"];player.weapon_id="fists";player.ammo.clear();player.reserves.clear();player.cancel_reload();player.fire_cooldown=0.;player.set_meta("br_generation",3)
		player.set_meta("weapon_attachments",{});player.set_meta("weapon_optics",{});game.br_inventory.add_player(player.peer_id);player._refresh_weapon()
func loot(item: Dictionary) -> int:
	var copy:=item.duplicate(true);copy.position=Vector3(.5,.02,0)
	return game.br_inventory.add_loot(copy)
func action(name: String,data: Dictionary,life:=7,generation:=3) -> bool:return game._br_action(1,name,data,life,generation)
func pickup(item: Dictionary) -> void:
	var id:=loot(item);check(id>0 and action("pickup",{"id":id}),"setup pickup "+str(item.get("kind","")))
func run() -> void:
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game);await process_frame;game.flat_world()
	for id in [1,2,3]:
		var player:=game._spawn_player(id,id==1,false,Vector3.ZERO) as BRPlayer;player.set_process(false);player.set_physics_process(false)
	actor=game.players[1];reset();await physics_frame;await physics_frame
	actor.hp=55.;var heal:=loot({"kind":"heal","amount":2})
	check(action("ground_use",{"id":heal}),"ground curative starts use")
	check(game.heal_pending.has(1) and game.br_inventory.snapshot(1).medkits==2 and actor.hp==55.,"curative moves into inventory without immediate consumption or healing")
	game.test_clock=103.99;game._step_br_authority(.01)
	check(actor.hp==55. and game.br_inventory.snapshot(1).medkits==2,"curative is not consumed before four seconds")
	game.test_clock=104.;game._step_br_authority(.01)
	check(actor.hp>55. and actor.hp<=100. and game.br_inventory.snapshot(1).medkits==1 and not game.heal_pending.has(1),"four-second completion starts gradual healing and consumes exactly one")
	game.heal_restore.clear();actor.hp=100.;var full_heal:=loot({"kind":"heal","amount":1});var medkits_before: int=game.br_inventory.snapshot(1).medkits
	check(not action("ground_use",{"id":full_heal}) and game.br_inventory.world_loot.has(full_heal) and game.br_inventory.snapshot(1).medkits==medkits_before,"full health leaves ground curative untouched")
	actor.hp=40.;action("heal",{});actor.hp-=1.;game.test_clock=104.1;game._step_br_authority(.01)
	check(not game.heal_pending.has(1) and game.br_inventory.snapshot(1).medkits==1 and actor.hp==39.,"damage interrupts application and preserves unconsumed curative")
	reset();pickup({"kind":"weapon","weapon":"fal","magazine":0});var ammo:=loot({"kind":"ammo","calibre":"76251","amount":20})
	check(action("ground_use",{"id":ammo}) and actor.weapon_id=="fal" and actor.reload_left>0.,"ground compatible ammunition equips and starts reload")
	check(int(actor.ammo.get("fal",0))==0 and int(actor.reserves.get("fal",0))==20,"reload does not grant magazine immediately")
	actor.complete_reload();game._sync_backpack(actor)
	check(int(actor.ammo.get("fal",0))==20 and int(actor.reserves.get("fal",0))==0,"reload completion preserves total ammunition")
	reset();pickup({"kind":"weapon","weapon":"fal","magazine":9,"weapon_attachments":{"optic_top":{"id":"pso4x","state":{},"position":0.}}});pickup({"kind":"weapon","weapon":"ak","magazine":12})
	var new_gun:=loot({"kind":"weapon","weapon":"glock","magazine":7})
	check(action("ground_use",{"id":new_gun}) and actor.weapon_id=="glock","using third ground weapon replaces held firearm")
	var inv:=game.br_inventory.snapshot(1);check(inv.weapons.size()==2 and "glock" in inv.weapons and "ak" in inv.weapons and "fal" not in inv.weapons,"weapon replacement maintains two slots")
	var old_gun: Dictionary={}
	for item: Dictionary in game.br_inventory.world_loot.values():
		if item.kind=="weapon" and item.weapon=="fal":old_gun=item
	check(not old_gun.is_empty() and int(old_gun.magazine)==9 and old_gun.weapon_attachments.optic_top.id=="pso4x","replaced firearm on ground preserves magazine and complete module state")
	var duplicate:=loot({"kind":"weapon","weapon":"ak","magazine":4});var before:=JSON.stringify(game.br_inventory.snapshot(1))
	check(action("ground_use",{"id":duplicate}) and not game.br_inventory.world_loot.has(duplicate) and game.br_inventory.snapshot(1).weapons.size()==2,"same-blueprint replacement succeeds and maintains two independent slots")
	reset();pickup({"kind":"weapon","weapon":"fal","magazine":4});pickup({"kind":"weapon","weapon":"ak","magazine":5});game._equip_server(actor,"ak")
	var optic:=loot({"kind":"attachment","attachment":"pso4x","amount":1})
	check(action("ground_use",{"id":optic}),"ground module use succeeds")
	inv=game.br_inventory.snapshot(1)
	check(inv.weapon_attachments.get("ak",{}).get("optic_top",{}).get("id","")=="pso4x" and inv.weapon_attachments.get("fal",{}).is_empty() and inv.accessory_items.is_empty(),"ground accessory prefers held compatible firearm and is not duplicated in bag")
	reset();pickup({"kind":"weapon","weapon":"fal","magazine":4})
	var instance_definition:=GameAttachmentRegistry.definition("pso4x").duplicate(true) as GameAttachmentDefinition
	instance_definition.id="qa_ground_individual";instance_definition.production=false
	instance_definition.state_schema={"charges":{"type":"int","min":0,"max":100,"default":0}}
	check(GameAttachmentRegistry.register_definition(instance_definition),"test-only stateful accessory registered")
	pickup({"kind":"attachment","attachment":instance_definition.id,"state":{"charges":7},"amount":1})
	var earlier_item: Dictionary=game.br_inventory.snapshot(1).accessory_items[0].duplicate(true)
	var individual:=loot({"kind":"attachment","attachment":instance_definition.id,"state":{"charges":91},"amount":1})
	check(action("ground_use",{"id":individual}),"ground use accepts a second instance of an existing accessory ID")
	inv=game.br_inventory.snapshot(1)
	check(inv.weapon_attachments.fal.optic_top.id==instance_definition.id and int(inv.weapon_attachments.fal.optic_top.state.charges)==91,"newly acquired accessory instance installs with its individual state")
	check(inv.accessory_items.size()==1 and int(inv.accessory_items[0].uid)==int(earlier_item.uid) and int(inv.accessory_items[0].state.charges)==7,"earlier same-ID accessory remains in bag with original UID and state")
	reset();GameAttachmentRegistry.unregister_definition(instance_definition.id)
	reset();var corpse:=loot({"kind":"container","contents":[{"kind":"helmet","level":2,"durability":70.,"position":Vector3(.5,.02,0)},{"kind":"vest","level":3,"durability":120.,"position":Vector3(.5,.02,0)},{"kind":"pack","level":2,"position":Vector3(.5,.02,0)}]})
	check(action("ground_use",{"id":corpse,"part":2}),"corpse vest part use succeeds")
	inv=game.br_inventory.snapshot(1)
	check(inv.protection.vest.level==3 and inv.protection.vest.durability==120. and inv.protection.helmet.level==0,"specific corpse part equips only selected protection preserving durability")
	var remainder: Array=game.br_inventory.world_loot[corpse].contents
	check(remainder.size()==2 and int(remainder[0].part_id)==1 and int(remainder[1].part_id)==3,"corpse part identifiers survive removal without renumbering")
	check(not action("ground_use",{"id":corpse,"part":2}) and game.br_inventory.world_loot[corpse].contents.size()==2,"used corpse part cannot duplicate equipment")
	check(action("ground_use",{"id":corpse,"part":1}) and int(actor.get_meta("br_helmet",0))==2,"corpse helmet updates equipped visual metadata")
	check(action("ground_use",{"id":corpse,"part":3}) and int(actor.get_meta("br_backpack",0))==2 and not game.br_inventory.world_loot.has(corpse),"last corpse part equips backpack and removes exhausted container")
	reset();game.br_inventory.members[1].medkits=15;actor.hp=50.;var capacity_item:=loot({"kind":"heal","amount":1});before=JSON.stringify(game.br_inventory.snapshot(1))
	check(not action("ground_use",{"id":capacity_item}) and game.br_inventory.world_loot.has(capacity_item) and JSON.stringify(game.br_inventory.snapshot(1))==before,"full capacity leaves ground item and inventory unchanged")
	check(not game.heal_pending.has(1),"failed capacity pickup never schedules healing")
	reset()
	for reason in ["dead","old_life","old_generation","far"]:
		var guarded:=loot({"kind":"heal","amount":1});actor.hp=0. if reason=="dead" else 50.
		if reason=="far":game.br_inventory.world_loot[guarded].position=Vector3(10,0,0)
		before=JSON.stringify(game.br_inventory.snapshot(1))
		check(not action("ground_use",{"id":guarded},6 if reason=="old_life" else 7,2 if reason=="old_generation" else 3) and game.br_inventory.world_loot.has(guarded) and JSON.stringify(game.br_inventory.snapshot(1))==before,"ground use rejects "+reason+" without consuming loot")
	actor.hp=100.
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Production BR authority inventory actions on real actor/flat collision fixture: contextual ground use, timed heal/cancellation/full health, ammo reload, two-slot atomic replacement with configured firearm preservation, current-weapon attachment priority, corpse stable part IDs/gear metadata, capacity and life/generation/death/range guards. Deterministic clock; no FPS benchmark."}
	var file:=FileAccess.open("res://work/br-inventory-actions-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BR_INVENTORY_ACTIONS_VALIDATION ",JSON.stringify(report));game.free();await process_frame;quit(0 if failures.is_empty() else 1)
