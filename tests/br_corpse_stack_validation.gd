extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func take(inv: BRInventory,id: int,item: Dictionary) -> bool:
	item.position=Vector3.ZERO;var loot:=inv.add_loot(item)
	return loot>0 and inv.pickup(id,loot,Vector3.ZERO).get("ok",false)
func run() -> void:
	var inv:=BRInventory.new()
	for id in [1,2,3,4,5]:inv.add_player(id)
	for id in [1,2,3,4]:take(inv,id,{"kind":"pack","level":3})
	for i in 3:check(take(inv,1,{"kind":"ammo","calibre":"9mm","amount":500}),"ammo stack fits large pack")
	check(inv.snapshot(1).ammo["9mm"]==1500 and is_equal_approx(inv.weight(1),180.),"large pack can hold1500rounds")
	var before:=inv.snapshot(1)
	check(not inv.drop_ammo(1,"9mm",501,Vector3.ZERO).ok and inv.snapshot(1)==before,"oversized individual ammo drop fails without mutating inventory")
	var body:=inv.drop_all(1,Vector3.ZERO);var stacks:=0;var total:=0
	for part: Dictionary in inv.world_loot[body].contents:
		if part.kind=="ammo":stacks+=1;total+=int(part.amount);check(int(part.amount)<=500,"corpse ammo stack meets validation bound")
	check(stacks==3 and total==1500,"death splits large reserve without deleting rounds")
	check(inv.pickup(2,body,Vector3.ZERO).ok and inv.snapshot(2).ammo["9mm"]==1500,"large corpse reserve is fully recoverable")
	check(inv.snapshot(1).ammo.is_empty() and inv.drop_all(1,Vector3.ZERO)<0,"death state clears exactly once")
	for i in 3:check(take(inv,3,{"kind":"heal","amount":15}),"healing stack fits large pack")
	check(inv.snapshot(3).medkits==45 and is_equal_approx(inv.weight(3),180.),"large pack can hold45curatives")
	before=inv.snapshot(3)
	check(not inv.drop_heal(3,16,Vector3.ZERO).ok and inv.snapshot(3)==before,"oversized individual healing drop fails without mutating inventory")
	body=inv.drop_all(3,Vector3.ZERO);stacks=0;total=0
	for part: Dictionary in inv.world_loot[body].contents:
		if part.kind=="heal":stacks+=1;total+=int(part.amount);check(int(part.amount)<=15,"corpse heal stack meets validation bound")
	check(stacks==3 and total==45,"death splits curatives without item loss")
	check(inv.pickup(4,body,Vector3.ZERO).ok and inv.snapshot(4).medkits==45,"large corpse healing stock is fully recoverable")
	var legacy:=inv.add_loot({"kind":"container","position":Vector3.ZERO,"contents":[{"kind":"ammo","calibre":"9mm","amount":501,"position":Vector3.ZERO},{"kind":"heal","amount":1,"position":Vector3.ZERO}]})
	check(inv.pickup(5,legacy,Vector3.ZERO,3.,2).ok,"valid item in mixed old container can be collected")
	check(inv.world_loot.has(legacy) and inv.world_loot[legacy].contents.size()==1 and inv.world_loot[legacy].contents[0].amount==501,"rejected legacy part remains instead of being silently destroyed")
	check(not inv.pickup(5,legacy,Vector3.ZERO).ok and inv.world_loot[legacy].contents[0].amount==501,"invalid part cannot be collected or vanish on retry")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Large-backpack death/drop conservation:1500rounds and45curatives split into valid world stacks; oversized manual drops are atomic and invalid legacy container parts are preserved. Pure inventory fixture, no network/FPS claim."}
	NavalStorage.write_json("res://work/br-corpse-stack-validation.json",report);print("BR_CORPSE_STACK_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
