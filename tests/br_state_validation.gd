extends SceneTree

var checks:=0
var errors: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: errors.append(label);print("FAIL ",label)

func run() -> void:
	var inventory:=BRInventory.new()
	inventory.add_player(2);inventory.add_player(3)
	check(inventory.snapshot(2).weapons.is_empty() and inventory.snapshot(2).ammo.is_empty(),"spawn unarmed with no hidden ammunition")
	var gun:=inventory.add_loot({"kind":"weapon","weapon":"fal","magazine":3,"position":Vector3.ZERO})
	check(not inventory.pickup(2,gun,Vector3(8,0,0)).ok,"distant pickup rejected")
	check(inventory.pickup(2,gun,Vector3.ZERO).ok,"first survivor picks gun")
	check(not inventory.pickup(3,gun,Vector3.ZERO).ok,"contested loot cannot be duplicated")
	check(inventory.snapshot(2).magazines.fal==3,"partial magazine preserved")
	var wrong:=inventory.add_loot({"kind":"ammo","calibre":"76239","amount":30,"position":Vector3.ZERO})
	check(inventory.pickup(2,wrong,Vector3.ZERO).ok,"can carry another calibre for later")
	check(inventory.reload(2,"fal")==0,"AK ammunition never reloads FAL")
	var right:=inventory.add_loot({"kind":"ammo","calibre":"76251","amount":20,"position":Vector3.ZERO})
	check(inventory.pickup(2,right,Vector3.ZERO).ok,"correct calibre picked")
	check(inventory.reload(2,"fal")==17 and inventory.snapshot(2).magazines.fal==20 and inventory.snapshot(2).reserve_by_weapon.fal==3,"reload transfers only capacity and consumes correct reserve")
	for _i in 20: check(inventory.consume_shot(2,"fal"),"accepted shot consumes one loaded round")
	check(not inventory.consume_shot(2,"fal"),"empty weapon cannot shoot")
	var dropped:=inventory.drop_weapon(2,"fal",Vector3.ZERO)
	check(dropped.ok and inventory.pickup(3,int(dropped.id),Vector3.ZERO).ok,"dropped weapon transfers ownership")
	check(not inventory.consume_shot(2,"fal"),"dropped gun unavailable to previous owner")
	for weapon in ["glock","ak","sniper"]:
		var item:=inventory.add_loot({"kind":"weapon","weapon":weapon,"magazine":1,"position":Vector3.ZERO})
		var result:=inventory.pickup(2,item,Vector3.ZERO)
		check(bool(result.ok)==(weapon!="sniper"),"weapon slots capped at two")
	var heavy:=inventory.add_loot({"kind":"ammo","calibre":"javelin","amount":7,"position":Vector3.ZERO})
	check(inventory.pickup(2,heavy,Vector3.ZERO).ok and inventory.world_loot.has(heavy) and inventory.world_loot[heavy].amount==2,"partial pickup leaves excess ammunition in world")
	inventory.drop_ammo(2,"javelin",5,Vector3(10,0,0))
	var heal:=inventory.add_loot({"kind":"heal","amount":1,"position":Vector3.ZERO})
	check(inventory.pickup(2,heal,Vector3.ZERO).ok,"heal loot")
	check(inventory.use_medkit(2,100.0)==0.0 and inventory.snapshot(2).medkits==1,"full-health survivor does not waste medkit")
	check(inventory.use_medkit(2,75.0)==25.0 and inventory.snapshot(2).medkits==0,"heal caps at full health")
	check(inventory.use_medkit(2,0.0)==0.0,"no healing dead player")
	inventory.sync_from_actor(2,["ak"],{"ak":11},{"ak":29})
	check(inventory.snapshot(2).magazines.ak==11 and inventory.snapshot(2).reserve_by_weapon.ak==29,"shared combat ammo synchronizes into inventory")
	var corpse:=inventory.drop_all(2,Vector3(1,0,0))
	check(corpse>0 and inventory.world_loot[corpse].kind=="container","one container per corpse")
	check(inventory.drop_all(2,Vector3.ZERO)==-1,"duplicate death produces no duplicated contents")
	check(inventory.pickup(3,corpse,Vector3(1,0,0)).ok,"corpse resources can be recovered")
	var private_copy:=inventory.snapshot(3)
	private_copy.magazines.clear()
	check(not inventory.snapshot(3).magazines.is_empty(),"snapshot cannot mutate authoritative inventory")
	for record in inventory.nearby(Vector3.ZERO): check(not record.has("contents"),"loot visual stream never exposes corpse contents")
	var close_count:=inventory.world_loot.size()
	for i in 200: inventory.add_loot({"kind":"ammo","calibre":"9mm","amount":12,"position":Vector3(500+i*3,0,700)})
	inventory.nearby(Vector3.ZERO)
	check(inventory.last_query_candidates<=close_count,"loot proximity query touches only nearby grid cells")
	var stale_id:=inventory.add_loot({"kind":"ammo","calibre":"9mm","amount":1,"position":Vector3.ZERO})
	check(inventory.pickup(3,stale_id,Vector3.ZERO).ok,"near loot consumed")
	var stale_seen:=false
	for item in inventory.nearby(Vector3.ZERO):
		if item.id==stale_id: stale_seen=true
	check(not stale_seen,"consumed loot removed from spatial index")
	var candidates: Array[Vector3]=[]
	for x in range(-800,801,80):
		for z in range(-800,801,80): candidates.append(Vector3(x,0,z))
	var zone:=BRZone.new()
	for seed_value in 30:
		zone.configure(seed_value,candidates);zone.begin(1000.0)
		check(zone.stages.size()==8,"eight explicit zone phases")
		for stage: Dictionary in zone.stages:
			check(Vector2(stage.center).distance_to(stage.target_center)+float(stage.target_radius)<=float(stage.radius)+0.001,"next circle contained in current")
			check(candidates.has(Vector3(stage.target_center.x,0,stage.target_center.y)),"zone target chosen only from accessible candidates")
			check(absf(float(stage.target_center.x))+float(stage.target_radius)<=1000.001 and absf(float(stage.target_center.y))+float(stage.target_radius)<=1000.001,"target circle contained inside playable boundary")
		for elapsed in [0.0,149.0,151.0,239.0,240.0,500.0,900.0,925.0]:
			var now: float=1000.0+float(elapsed)
			var state:=zone.sample(now)
			var predicted:=BRZone.sample_snapshot(zone.snapshot(now),now)
			check(state.center.distance_to(predicted.center)<0.0001 and absf(float(state.radius)-float(predicted.radius))<0.0001,"client parameters reproduce exact server circle")
		check(zone.sample(1925.0).finished and zone.sample(1925.0).radius==0.0,"table closes in 925 seconds")
	var table:=load("res://modes/battle_royale/state/default_loot.tres") as BRLootTable
	var points: Array[Vector3]=[Vector3.ZERO,Vector3(20,0,10),Vector3(-20,0,-10)]
	var generated:=table.generate(42,points,points)
	check(generated==table.generate(42,points,points),"seeded loot deterministic")
	check(generated.size()==9,"each spawn gets separate sidearm and ammunition guarantee")
	for p in points:
		var has_gun:=false;var has_ammo:=false
		for record in generated:
			if Vector3(record.position).distance_to(p)<1.0:
				if record.kind=="weapon" and record.weapon=="glock": has_gun=true
				if record.kind=="ammo" and record.calibre=="9mm": has_ammo=true
		check(has_gun and has_ammo,"minimum reachable weapon and compatible ammo at spawn anchor")
	var round_state:=BRRound.new()
	round_state.begin([2,3,4],100.0)
	check(round_state.alive_ids().size()==3 and round_state.winner==-1,"three initial survivors without premature win")
	round_state.record_shot(2,"glock");round_state.record_damage(2,3,30.0)
	round_state.record_distance(2,150.0);round_state.record_pickup(2)
	var death:=round_state.eliminate(3,2,"glock",22.0,120.0)
	check(death.ok and death.placement==3 and not death.ended,"first death receives correct placement")
	check(not round_state.eliminate(3,2,"glock",22.0,121.0).ok,"dead survivor cannot be eliminated twice")
	check(not round_state.is_alive(3),"no implicit respawn")
	var final:=round_state.eliminate(4,-1,"zone",0.0,150.0)
	check(final.ended and final.winner==2 and round_state.result(2,150.0).victory,"last survivor wins on server")
	check(round_state.result(2,150.0).kills==1 and round_state.result(2,150.0).accuracy==100.0 and round_state.result(2,150.0).damage==30.0,"server stats retained independently from existing modes")
	check(not round_state.eliminate(2,4,"ak",0.0,151.0).ok,"finished round ignores stale damage/death")
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors,"scope":"Pure server BR inventory, seeded loot, circle replication and elimination state; does not certify client networking, navmesh or performance."}
	NavalStorage.write_json("res://work/br-state-validation.json",report);print("BR_STATE_VALIDATION ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
