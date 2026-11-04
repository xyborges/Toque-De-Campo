extends SceneTree
const FIXTURE=preload("res://tests/br_completion_fixture.gd")
var checks:=0
var failures: Array[String]=[]
var game: BattleRoyaleGame

func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func pure_inventory() -> void:
	var inv:=BRInventory.new();inv.add_player(1);inv.add_player(2)
	check(inv.snapshot(1).capacity==60 and inv.snapshot(1).backpack==0,"unarmed survivor has base pockets")
	for level in [1,2,3]:
		var item:=inv.add_loot({"kind":"pack","level":level,"position":Vector3.ZERO})
		check(inv.pickup(1,item,Vector3.ZERO).ok,"equip backpack tier %d"%level)
		check(inv.snapshot(1).capacity==BRInventory.PACK_CAPACITY[level],"tier capacity %d"%level)
	var ammo:=inv.add_loot({"kind":"ammo","calibre":"javelin","amount":20,"position":Vector3.ZERO})
	check(inv.pickup(1,ammo,Vector3.ZERO).ok and inv.snapshot(1).ammo.javelin==18 and inv.world_loot[ammo].amount==2,"partial pickup preserves total and obeys level 3 capacity")
	check(not inv.drop_pack(1,Vector3.ZERO).ok,"cannot drop backpack while pockets would overflow")
	check(inv.drop_ammo(1,"javelin",12,Vector3.ZERO).ok and inv.drop_pack(1,Vector3.ZERO).ok,"discard ammunition then backpack safely")
	for kind in ["vest","helmet"]:
		for level in [1,2,3]:
			var item:=inv.add_loot({"kind":kind,"level":level,"position":Vector3.ZERO})
			check(inv.pickup(1,item,Vector3.ZERO).ok,"equip %s %d"%[kind,level])
			var region:="head" if kind=="helmet" else "chest"
			var expected: float=100.*(1.-BRInventory.PROTECTION_RATIO[level])
			check(is_equal_approx(inv.protected_damage(1,100.,region),expected),"region protection scales by tier")
	check(is_equal_approx(inv.protected_damage(1,40.,"legL"),40.),"limbs receive no torso protection")
	var saved: Dictionary=inv.snapshot(1).protection.helmet
	inv.protected_damage(1,1000.,"head")
	check(inv.snapshot(1).protection.helmet.level==0 and saved.level==3,"broken helmet removed and private snapshot isolated")
	var corpse:=inv.drop_all(1,Vector3.ZERO)
	var close:=inv.nearby(Vector3.ZERO);var far:=inv.nearby(Vector3(20,0,0))
	check(close.any(func(r):return r.id==corpse and r.has("contents")),"nearby corpse exposes selectable contents")
	check(far.all(func(r):return not r.has("contents")),"distant corpse contents are hidden")
	var parts: Array=inv.world_loot[corpse].contents
	var part: Dictionary=parts[0]
	check(inv.pickup(2,corpse,Vector3.ZERO,3.,int(part.part_id)).ok,"individual corpse item collected")
	check(not inv.pickup(2,corpse,Vector3.ZERO,3.,int(part.part_id)).ok,"stale item ID cannot collect a different corpse item")
	check(inv.drop_all(1,Vector3.ZERO)==-1,"duplicate death cannot duplicate bag")

func run() -> void:
	pure_inventory()
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	await process_frame
	game.flat_world()
	var actor:=game._spawn_player(1,true,false,Vector3.ZERO) as BRPlayer
	var target:=game._spawn_player(2,false,false,Vector3(0,0,-1)) as BRPlayer
	var third:=game._spawn_player(3,false,false,Vector3(5,0,0)) as BRPlayer
	for p in [actor,target,third]:p.set_physics_process(false);p.set_process(false);game.br_inventory.add_player(p.peer_id)
	game.br_round.begin([1,2,3],game._now());game.br_generation=1
	for p in [actor,target,third]:p.set_meta("br_generation",1)
	await physics_frame;await physics_frame
	check(actor.get_meta("human_war_mesh",false) and actor.get_meta("articulated_arms",false),"BR uses shared human body")
	check(not actor.avatar_parts.torso.get_node_or_null("BRProtectionvest") and not actor.avatar_parts.head.get_node_or_null("BRProtectionhelmet"),"BR starts without permanent vest or helmet")
	check(actor.view_root.visible and actor.view_root.get_node_or_null("ForearmLeft") and actor.view_root.get_node_or_null("ForearmRight"),"both fist forearms visible in FPP")
	var rest: Vector3=actor.view_root.get_node("Right").position
	actor.play_fire_animation("fists");actor.punch_clock=.20;actor._pose_fists()
	check(actor.view_root.get_node("Right").position.z<rest.z-.3,"punch extends arm forward")
	actor.punch_clock=0.;actor._pose_fists()
	check(actor.set_posture(1),"crouch clearance")
	actor.stance.advance(actor,1.);actor._animate_walk()
	check(actor.crouched and actor.camera_pivot.position.y<1.3,"crouch camera and articulated pose")
	check(actor.set_posture(2),"prone clearance")
	actor.stance.advance(actor,1.);actor._animate_walk()
	check(actor.prone and actor.camera_pivot.position.y<.6 and actor.clamp_aim_pitch(-1.)>=-.38,"prone posture and downward aim limit")
	actor.set_posture(0);actor.stance.advance(actor,1.)
	for kind in ["vest","helmet","pack"]:
		var item:=game.br_inventory.add_loot({"kind":kind,"level":3,"position":Vector3(.7,0,0)})
		check(game._br_action(1,"pickup",{"id":item},actor.life_id,1),"server pickup "+kind)
	check(actor.avatar_parts.torso.get_node_or_null("BRProtectionvest") and actor.avatar_parts.torso.get_node_or_null("BRProtectionpack") and actor.avatar_parts.head.get_node_or_null("BRProtectionhelmet"),"gear visually attached to shared rig")
	check(game.own_inventory.backpack==3 and game.own_inventory.capacity==180.,"private HUD backpack snapshot")
	actor.last_impact_weapon="glock";var before:=actor.hp;actor.take_damage(30.,"head",2)
	check(is_equal_approx(before-actor.hp,33.75),"tier 3 helmet mitigates headshot without forced fatal hit")
	actor.last_impact_weapon="zone";before=actor.hp;actor.take_damage(10.,"chest",0)
	check(is_equal_approx(before-actor.hp,10.),"zone bypasses armor")
	actor.hp=100.;actor.limbs=CombatRules.fresh_limbs()
	for item in [{"kind":"weapon","weapon":"fal","magazine":3},{"kind":"ammo","calibre":"76251","amount":20}]:
		item.position=Vector3(.7,0,0);var id:=game.br_inventory.add_loot(item);game._br_action(1,"pickup",{"id":id},actor.life_id,1)
	game._equip_server(actor,"fal");actor.start_reload()
	check(actor.reload_left>0.,"shared firearm reload begins")
	var total_before:=int(actor.ammo.fal)+int(actor.reserves.fal)
	check(game._br_action(1,"drop",{"weapon":"fal"},actor.life_id,1),"drop equipped weapon during reload")
	check(actor.weapon_id=="fists" and actor.reload_weapon.is_empty() and not actor.pending_shots.size(),"drop cancels reload and returns to fists")
	var dropped: Dictionary={}
	for item in game.br_inventory.nearby(Vector3.ZERO):
		if item.kind=="weapon" and item.weapon=="fal":dropped=item
	check(not dropped.is_empty() and int(dropped.magazine)+int(game.br_inventory.snapshot(1).ammo.get("76251",0))==total_before,"drop preserves rounds without duplication")
	if not dropped.is_empty():game._br_action(2,"pickup",{"id":dropped.id},target.life_id,1)
	# The rare launcher follows the ordinary shot/reload checks, with no lock.
	for item in [{"kind":"weapon","weapon":"stinger","magazine":1},{"kind":"ammo","calibre":"javelin","amount":1}]:
		item.position=Vector3(.7,0,0);var id:=game.br_inventory.add_loot(item);game._br_action(1,"pickup",{"id":id},actor.life_id,1)
	game._equip_server(actor,"stinger");actor.shot_sequence+=1
	game._server_accept_shot(1,actor.shot_sequence,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,"stinger",0)
	check(int(actor.ammo.get("stinger",-1))==0 and not game.projectiles.is_empty(),"Javelin fires unguided and consumes loaded round")
	actor.start_reload();actor.reload_left=0.;actor.complete_reload()
	check(actor.ammo.stinger==1 and actor.reserves.stinger==0,"Javelin reload consumes rare reserve")
	game._equip_server(actor,"fists");actor.punch_clock=0.;actor._pose_fists()
	actor.hp=100.;target.hp=100.;third.hp=100.
	game._send_br_states();game._refresh_br_ui()
	if "--br-captures" in OS.get_cmdline_user_args():await capture(actor,target)
	check(game._br_action(1,"drop_protection",{"kind":"helmet"},actor.life_id,1),"helmet can be dropped")
	check(not actor.avatar_parts.head.get_node_or_null("BRProtectionhelmet"),"dropped helmet disappears visually")
	game._apply_hit(2,{"collider":actor.hit_regions.chest,"position":actor.global_position},1000.,"chest","fal",Vector3.RIGHT)
	check(actor.hp==0 and actor.respawn_left==0 and not game.br_round.is_alive(1),"elimination has no respawn")
	game.sync_inventory(actor)
	check(game.br_inventory.snapshot(1).weapons.is_empty() and game.br_inventory.drop_all(1,actor.global_position)==-1,"late inventory acknowledgement cannot duplicate corpse loot")
	check(not game._br_action(1,"drop",{"weapon":"stinger"},actor.life_id,1),"dead survivor cannot change inventory")
	game._apply_hit(2,{"collider":third.hit_regions.chest,"position":third.global_position},1000.,"chest","fal",Vector3.RIGHT)
	check(game.phase=="finished" and game.br_round.winner==2 and game.restart_at>game._now()+59.,"last survivor wins and one-minute intermission starts")
	game._send_br_states();game._refresh_br_ui()
	check(game.br_hud.result_panel.is_visible_in_tree() and game.ui_focus.blocked(),"results menu releases controls")
	game.start_br_round()
	check(actor.hp==100. and actor.weapon_id=="fists" and game.br_inventory.snapshot(1).backpack==0 and not actor.prone,"next round resets survivor and equipment")
	check(int(actor.get_meta("br_vest",-1))==0 and int(actor.get_meta("br_backpack",-1))==0,"new round clears public equipment baseline for late joiners")
	check(game.projectiles.is_empty() and not game.ui_focus.blocked(),"new round clears projectiles and closes result menu")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Production inventory, human rig, fists, postures, gear damage, drop during reload, unguided launcher, death and round reset on flat physics fixture; no FPS claim."}
	NavalStorage.write_json("res://work/br-completion-validation.json",report);print("BR_COMPLETION_VALIDATION ",JSON.stringify(report))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)

func capture(actor: BRPlayer,target: BRPlayer) -> void:
	root.title="Toque de Campo · Battle Royale · revisão local"
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	actor._animate_walk();target.global_position=Vector3(1.5,0,-4);target._animate_walk()
	game._send_br_states();game._refresh_br_ui()
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/br-fists-hud.png")
	for item in [{"kind":"weapon","weapon":"glock","magazine":6},{"kind":"ammo","calibre":"9mm","amount":24},{"kind":"pack","level":2},{"kind":"heal","amount":1}]:
		item.position=Vector3(.7,0,0);game.br_inventory.add_loot(item)
	game._send_br_states();game._refresh_br_ui();game.ui_focus.open(game.br_hud.inventory_panel);game.br_hud._update_nearby()
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/br-backpack.png")
	game.ui_focus.close_all();game.third_person=true;actor._update_view();actor._animate_walk();target.global_position=Vector3(0,0,-3)
	BRProtectionAppearance.apply(target,2,2,2);target._animate_walk()
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/br-protection-human.png")
