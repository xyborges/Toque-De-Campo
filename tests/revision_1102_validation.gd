extends SceneTree
const FIXTURE=preload("res://tests/br_round_clock_fixture.gd")
var checks:=0
var failures: Array[String]=[]
var game: BattleRoyaleGame
var actor: BRPlayer
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func pickup(item: Dictionary,use:=false) -> bool:
	item.position=actor.global_position+Vector3(.5,.05,0)
	var id:=game.br_inventory.add_loot(item)
	return game._br_action(1,"ground_use" if use else "pickup",{"id":id},actor.life_id,game.br_generation)
func run() -> void:
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game);game.flat_world();game.br_generation=3
	for id in [1,2,3]:
		var player:=game._spawn_player(id,id==1,false,Vector3((id-1)*20,0,0)) as BRPlayer
		player.set_physics_process(false);player.set_process(false);player.hp=100.;player.life_id=7;player.set_meta("br_generation",3);game.br_inventory.add_player(id)
	actor=game.players[1];game.phase="active";game.br_round.begin([1,2,3],100.);game.br_zone.configure(42,[Vector3.ZERO]);game.br_zone.begin(100.)
	await physics_frame;await physics_frame
	actor.apply_body_proportions({"head":1.5,"arms":.65,"torso":NAN,"legs":1.4})
	for part in actor.avatar_parts.values():check(part.scale.is_equal_approx(Vector3.ONE),"legacy proportions cannot distort "+str(part.name))
	var colors:={"skin":"ac7951","shirt":"706249","pants":"313e37","boots":"202329"};actor.apply_body_colors(colors)
	check(actor.get_meta("body_colors")==colors,"four independent colors normalized")
	check(actor.avatar_parts.torso.material_override.albedo_color.is_equal_approx(Color(colors.shirt)),"shirt tint reaches shared human mesh")
	check(GameCharacterColors.normalize({"skin":"invalid"}).skin==GameCharacterColors.DEFAULTS.skin,"malformed color falls back")
	check(pickup({"kind":"weapon","weapon":"ak","magazine":17}),"first AK collected")
	check(pickup({"kind":"weapon","weapon":"ak","magazine":4},true),"second AK collected and equipped")
	var inv:=game.br_inventory.snapshot(1)
	check(inv.weapons==["ak","ak_br2"] and actor.weapon_id=="ak_br2","identical blueprints occupy independent slots")
	check(int(inv.magazines.ak)==17 and int(inv.magazines.ak_br2)==4,"magazines do not overwrite each other")
	check(actor.weapon_root.has_node("Imported_ak") and is_instance_valid(actor.muzzle_marker),"second AK uses actual AK rig and muzzle")
	check(pickup({"kind":"attachment","attachment":"pso4x","amount":1}),"scope collected")
	check(game._br_action(1,"optic",{"weapon":"ak_br2","optic":"pso4x"},7,3),"scope installed on second instance")
	inv=game.br_inventory.snapshot(1)
	check(inv.weapon_attachments.ak.is_empty() and inv.weapon_attachments.ak_br2.optic_top.id=="pso4x","attachments remain attached to the chosen instance")
	check(pickup({"kind":"ammo","calibre":"76239","amount":60}),"shared loose ammunition collected")
	game._server_reload(1,"ak_br2");check(actor.reload_left>0.,"second AK reload starts")
	actor.complete_reload();game._sync_backpack(actor);inv=game.br_inventory.snapshot(1)
	check(int(inv.magazines.ak)==17 and int(inv.magazines.ak_br2)==30 and int(inv.ammo["76239"])==34,"reload transfers 26 rounds once, preserving other gun")
	var dropped:=game.br_inventory.drop_weapon(1,"ak_br2",Vector3(.6,.05,0));check(dropped.ok,"second instance can be dropped")
	var dropped_item: Dictionary=game.br_inventory.world_loot[dropped.id]
	check(dropped_item.weapon=="ak" and dropped_item.magazine==30 and dropped_item.weapon_attachments.optic_top.id=="pso4x","drop preserves canonical model, magazine and optic")
	game._apply_backpack(actor)
	check(game._br_action(1,"pickup",{"id":dropped.id},7,3),"dropped duplicate can be collected again")
	check(pickup({"kind":"binoculars"},true),"binoculars can be looted and used")
	check(actor.weapon_id=="binoculars" and "binoculars" in actor.active_weapons() and actor.muzzle_marker==null,"binoculars are an owned utility, not a gun")
	var projectiles_before:=game.projectiles.size();actor.fire();check(game.projectiles.size()==projectiles_before,"binoculars never shoot")
	actor.hp=40.;check(pickup({"kind":"heal","amount":2},true),"ground curative starts timed application")
	game.test_clock=103.99;game._step_br_authority(.01)
	check(actor.hp==40. and game.br_inventory.snapshot(1).medkits==2,"no heal or consumption before timer")
	game.test_clock=104.;game._step_br_authority(.01)
	check(actor.hp>40. and actor.hp<=42. and game.br_inventory.snapshot(1).medkits==1 and game.heal_restore.has(1),"completion consumes one and begins gradual recovery")
	for step in 10:game.test_clock+=.4;game._step_br_authority(.4)
	check(actor.hp>42. and actor.hp<70.,"healing increases over time rather than jumping fifty HP")
	actor.hp-=8.;var hurt_hp:=actor.hp;game._step_br_authority(.01)
	check(not game.heal_restore.has(1) and actor.hp==hurt_hp,"new damage cancels remaining regeneration")
	actor.global_position=Vector3.ZERO;check(game._br_action(1,"heal",{},7,3),"second application starts")
	actor.global_position.x=2.;game._step_br_authority(.01)
	check(game.heal_pending.has(1) and actor.movement_input_locked() and game.br_inventory.snapshot(1).medkits==1,"application locks movement independently of backpack visibility")
	var logger:=GameDiagnostics.session();check(is_instance_valid(logger),"executable diagnostic autoload available")
	if logger:
		logger.record("validation",{"peer":42,"token":"never-share-this","nested":{"password":"also-secret","stage":"ready"}});logger.flush()
		var text:=FileAccess.get_file_as_string(logger.path)
		check(not text.contains("never-share-this") and not text.contains("also-secret") and text.contains("ready"),"logs redact secrets and retain useful stages")
		var archive:=GameDiagnostics.export_report();var zip:=ZIPReader.new();check(zip.open(archive)==OK and zip.get_files().size()>0,"one ZIP collects diagnostic files")
		for name_text in zip.get_files():check(name_text.ends_with(".jsonl") and not name_text.contains(".."),"report contains only bounded diagnostic logs")
		zip.close()
	game.free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Production authority on flat collision fixture: standard body/colors, independent identical gun instances, optic, reload/drop round conservation, binocular ownership/no firing, timed gradual healing/cancellation and sanitized executable report. No microphone recording or FPS claim."}
	NavalStorage.write_json("res://work/revision-1102-validation.json",report);print("REVISION_1102 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
