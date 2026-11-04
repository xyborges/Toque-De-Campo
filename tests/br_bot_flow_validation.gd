extends SceneTree
const FIXTURE=preload("res://tests/br_round_clock_fixture.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var game: BattleRoyaleGame=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	await process_frame;game.flat_world()
	var human:=game._spawn_player(1,true,false,Vector3(0,0,-18)) as BRPlayer
	var bot:=game._spawn_player(100000,false,false,Vector3.ZERO) as BRPlayer;bot.br_bot=true
	var third:=game._spawn_player(3,false,false,Vector3(30,0,-30)) as BRPlayer
	for actor in [human,bot,third]:actor.set_physics_process(false);actor.set_process(false);game.br_inventory.add_player(actor.peer_id)
	game.br_round.begin([1,100000,3],game._now());game.br_generation=1
	game.br_inventory.add_loot({"kind":"weapon","weapon":"glock","magazine":2,"position":Vector3(0,.05,-2.)})
	game.br_inventory.add_loot({"kind":"ammo","calibre":"9mm","amount":24,"position":Vector3(0,.05,-3.5)})
	await physics_frame;await physics_frame
	var picked:=false;var fired:=false;var hurt:=false;var reloaded:=false;var reserve_picked:=false
	for frame in 900:
		game.test_clock+=1./60.
		bot.fire_cooldown=maxf(0.,bot.fire_cooldown-1./60.)
		if bot.reload_left>0:
			bot.reload_left=maxf(0.,bot.reload_left-1./60.)
			if bot.reload_left==0.:bot.complete_reload();reloaded=true
		game.step_br_bot(bot,1./60.);game._step_projectiles(1./60.)
		if "glock" in bot.loadout:picked=true
		if int(game.br_round.participants[100000].shots)>0:fired=true
		if human.hp<100:hurt=true
		if int(bot.reserves.get("glock",0))>0:reserve_picked=true
		if frame%5==0:await physics_frame
		if game.phase=="finished":break
	check(picked,"bot acquires contextual weapon through authority pickup")
	check(fired,"bot fires accepted shots instead of visual-only attacks")
	check(reserve_picked,"bot seeks ammunition after magazine becomes empty")
	check(reloaded,"bot reloads from collected compatible reserve")
	check(hurt,"bot ballistic shots can injure an opponent")
	check(bot.global_position.is_finite() and bot.global_position.distance_to(Vector3.ZERO)>1.,"bot locomotion advances through collision controller")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"bot_position":str(bot.global_position),"shots":game.br_round.participants[100000].shots,"target_hp":human.hp,"scope":"Production BR bot decisions, pickups, physical motion, ballistic fire and reload in flat collision fixture; no FPS claim."}
	NavalStorage.write_json("res://work/br-bot-flow-validation.json",report);print("BR_BOT_FLOW_VALIDATION ",JSON.stringify(report))
	game.leave_match();await create_timer(.05).timeout
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
