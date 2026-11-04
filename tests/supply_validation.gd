extends SceneTree
class SupplyFixture:
	extends "res://tests/late_join_fixture.gd"
	func _build_audio() -> void:
		# This protocol/unit fixture does not exercise menu MP3 playback.
		music_player=AudioStreamPlayer.new();add_child(music_player)
		sound_player=AudioStreamPlayer3D.new();add_child(sound_player)
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var game:=SupplyFixture.new();game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="desert";game._enter_match_world();game.set_physics_process(false)
	var actor:=game._spawn_player(1,true,false,Vector3(-3.35,.16,-5.3)) as GamePlayer;actor.set_physics_process(false)
	var other:=game._spawn_player(2,false,false,Vector3(15,.16,8)) as GamePlayer;other.set_physics_process(false)
	var supply:=DesertDomination.new();game.world_root.add_child(supply);supply.build(game);game.domination=supply;supply.set_physics_process(false)
	await physics_frame;await physics_frame
	check(supply.name=="DesertDomination" and supply.supply_stock.size()==3,"supply RPC has a deterministic node and cached firearm capacities")
	actor.ammo={"fal":0,"glock":0,"sniper":0,"unknown":7};actor.reserves={"fal":0,"glock":0,"sniper":0,"unknown":9};actor.grenades=0
	actor.velocity=Vector3(2,0,0)
	var mesh:=actor.weapon_root.get_child(0).get_instance_id();var nodes:=get_node_count()
	check(supply.replenish(actor,actor.life_id).contains("COMPLETA"),"validated supply succeeds at the physical box")
	check(actor.ammo.fal==30 and actor.ammo.glock==12 and actor.ammo.sniper==5 and actor.reserves.fal==180 and actor.reserves.glock==60 and actor.reserves.sniper==25 and actor.grenades==2,"all finite magazines, reserves and grenades use exact configured capacities")
	check(actor.ammo.unknown==7 and actor.reserves.unknown==9,"unknown inventory entries are not refilled using a fallback rifle")
	check(actor.velocity==Vector3(2,0,0) and actor.hp==100 and actor.weapon_root.get_child(0).get_instance_id()==mesh and get_node_count()==nodes,"supply does not stop movement, change health or reconstruct meshes/nodes")
	var full_ammo:=actor.ammo.duplicate();var full_reserve:=actor.reserves.duplicate()
	check(supply.replenish(actor,actor.life_id).contains("20"),"the first cooldown denial still gives the existing feedback")
	var empty_replies:=0
	for i in 100:
		if supply.replenish(actor,actor.life_id).is_empty(): empty_replies+=1
	check(empty_replies==100 and actor.ammo==full_ammo and actor.reserves==full_reserve,"duplicate cooldown requests neither reapply inventory nor create repeated HUD feedback")
	supply.seconds+=.3;check(supply.replenish(actor,actor.life_id).contains("20"),"cooldown feedback becomes available again after its short presentation budget")
	supply.seconds+=20;actor.ammo.fal=0
	check(supply.replenish(actor,actor.life_id).contains("COMPLETA") and actor.ammo.fal==30,"the gameplay supply cooldown remains twenty seconds")
	supply.supplies.clear();actor.ammo.fal=0
	check(supply.replenish(actor,actor.life_id-1).is_empty() and actor.ammo.fal==0,"a previous life cannot request a refill")
	actor.hp=0;check(supply.replenish(actor,actor.life_id).is_empty() and actor.ammo.fal==0,"dead actors cannot request a refill");actor.hp=100
	actor.grenade_prime_pending=true;check(supply.replenish(actor,actor.life_id).contains("Guarde") and actor.ammo.fal==0,"preparing a grenade still blocks supply");actor.grenade_prime_pending=false
	actor.position=Vector3(30,.16,30);check(supply.replenish(actor,actor.life_id).contains("Aproxime") and actor.ammo.fal==0,"distant requests cannot bypass box range");actor.position=Vector3(-3.35,.16,-5.3)
	var packet: Array=game._inventory_packet(actor).duplicate(true);packet[1].fal=11;packet[2].fal=66
	var bad:=packet.duplicate(true);bad[0]=2;supply.supply_inventory(bad,1)
	check(actor.ammo.fal==0 and actor.grenades==2,"another player's supply packet cannot overwrite the local inventory")
	bad=packet.duplicate(true);bad[8]=actor.life_id-1;supply.supply_inventory(bad,1)
	check(actor.ammo.fal==0 and actor.grenades==2,"delayed supply from a previous life cannot overwrite stocks or grenades")
	actor.authoritative_reload_revision=10;bad=packet.duplicate(true);bad[9]=9;supply.supply_inventory(bad,1)
	check(actor.ammo.fal==0 and actor.grenades==2,"a stale reload/inventory revision is rejected before mutating grenade stock")
	packet[9]=10;actor.hp=0;supply.supply_inventory(packet,1)
	check(actor.ammo.fal==0 and actor.grenades==2,"supply arriving after death cannot re-enable the dead inventory");actor.hp=100
	supply.supply_inventory(packet,1)
	check(actor.ammo.fal==11 and actor.reserves.fal==66 and actor.grenades==1,"current owner/life/revision applies through the shared authoritative inventory handler")
	supply.supplies[2]=100;supply.supply_requests[2]=100;game.players.erase(2);supply.step(0)
	check(not supply.supplies.has(2) and not supply.supply_requests.has(2),"disconnect releases both supply cooldown and feedback-budget entries")
	other.queue_free();game.show_menu()
	if is_instance_valid(game.music_player): game.music_player.stop();game.music_player.stream=null
	game.queue_free();await create_timer(.2).timeout
	var result: Dictionary={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/supply-validation-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
