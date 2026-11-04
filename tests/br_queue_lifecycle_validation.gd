extends SceneTree
const FIXTURE=preload("res://tests/br_round_clock_fixture.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func freeze(game: BattleRoyaleGame) -> void:
	for actor: BRPlayer in game.players.values():actor.set_physics_process(false);actor.set_process(false)
func human(game: BattleRoyaleGame,id: int,local: bool) -> BRPlayer:
	var actor:=game._spawn_player(id,local,false,Vector3(id*2,0,0)) as BRPlayer
	actor.name="Pessoa %d"%id;actor.set_physics_process(false);actor.set_process(false);game._stage_infantry(actor)
	game.br_inventory.add_player(id);return actor
func create_game(offline: bool) -> BattleRoyaleGame:
	var game: BattleRoyaleGame=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	game.offline_operation=offline;game.flat_world();return game
func run() -> void:
	var game:=create_game(false);var owner:=human(game,1,true)
	game._begin_queue();freeze(game)
	check(game.phase=="waiting" and game.players.size()==12 and game._human_ids()==[1],"first online human gets eleven server bots")
	check(is_equal_approx(game.round_start_clock,130.),"first human opens fixed30second pairing window")
	check(owner.hp==0. and game.br_round.alive_ids().is_empty(),"waiting roster has no active combat avatars")
	check(game._queue_admission_open(),"unsealed waiting room accepts humans before deadline")
	var state:=game._state_for(1);var bots:=0;var locals:=0
	for row: Dictionary in state.roster:
		if row.bot:bots+=1
		if row.local:locals+=1
	check(state.roster.size()==12 and bots==11 and locals==1 and int(state.capacity)==12,"private queue snapshot has correct human/bot/local roster")
	var deadline:=game.round_start_clock
	game.test_clock=110.;game._remove_queue_bot();human(game,2,false);game._begin_queue();freeze(game)
	check(game.players.size()==12 and game._human_ids().size()==2 and game.round_start_clock==deadline,"joining human replaces one bot without extending countdown")
	game._peer_disconnected(2);freeze(game)
	check(game.players.size()==12 and game._human_ids()==[1] and game.round_start_clock==deadline,"nonfinal departure refills bot without restarting countdown")
	game.test_clock=129.99;game._step_br_authority(.01)
	check(game.phase=="waiting" and game.br_generation==0,"no early start while one human waits with bots")
	game.test_clock=130.
	check(not game._queue_admission_open(),"admission closes at exactdeadline before round start callback")
	game._step_br_authority(.01);freeze(game)
	check(game.phase=="active" and game.br_generation==1 and game.br_round.alive_ids().size()==12,"deadline starts twelve participants with one human")
	check(game.room_sealed and not game._queue_admission_open(),"started room cannot admit a late human")
	for actor: BRPlayer in game.players.values():
		check(actor.hp==100. and actor.weapon_id=="fists" and actor.ammo.is_empty() and actor.reserves.is_empty(),"queue participant starts clean and unarmed")
	# A rifle/sniper or two launchers use the same generic weapon slots.
	for pair in [["fal","sniper"],["rpg","stinger"]]:
		game.br_inventory.add_player(1)
		for weapon: String in pair:
			var item:=game.br_inventory.add_loot({"kind":"weapon","weapon":weapon,"magazine":1,"position":Vector3.ZERO})
			check(game.br_inventory.pickup(1,item,Vector3.ZERO).ok,"generic slot accepts "+weapon)
		game._apply_backpack(owner);game.request_br_select_slot(1)
		check(owner.weapon_id==pair[1],"second generic slot equips "+str(pair[1]))
	var old_weapon:=owner.weapon_id;game.request_br_select_slot(2)
	check(owner.weapon_id==old_weapon,"invalid slot cannot equip an unowned weapon")
	# Finish every bot in one authority batch; winner remains this human.
	game.br_round.defer_end=true
	for id in game.players.keys():
		if id==1:continue
		var actor: BRPlayer=game.players[id];actor.last_impact_weapon="fal";actor.hp=0.;game._on_player_died(actor,1)
	game.br_round.defer_end=false;game.br_round.resolve_end(game._now());game._finish_br_round()
	check(game.phase=="finished" and game.br_round.winner==1 and is_equal_approx(game.restart_at,190.),"winner receives exactly60second results intermission")
	game.test_clock=189.99;game._step_br_authority(.01)
	check(game.phase=="finished","results remain until60second deadline")
	game.test_clock=190.;game._step_br_authority(.01);freeze(game)
	check(game.phase=="waiting" and is_equal_approx(game.round_start_clock,220.) and game.br_generation==1,"intermission returns cohort to a fresh30second queue")
	check(not game._queue_admission_open() and game.room_sealed,"rematch cohort stays sealed to newcomers")
	game.test_clock=219.99;game._step_br_authority(.01)
	check(game.phase=="waiting" and owner.hp==0.,"rematch countdown keeps previous winner staged")
	game.test_clock=220.;game._step_br_authority(.01);freeze(game)
	check(game.phase=="active" and game.br_generation==2 and owner.hp==100. and owner.weapon_id=="fists" and owner.loadout.is_empty(),"rematch starts fresh only after its own30seconds")
	game._peer_disconnected(1)
	check(game.phase=="cancelled" and game.players.is_empty() and game.round_start_clock<0. and game.restart_at<0.,"final human departure cancels room and removes every bot")
	game.leave_match();await create_timer(.05).timeout;game.free();await process_frame
	var offline:=create_game(true);human(offline,1,true);offline._begin_queue();freeze(offline)
	check(offline.players.size()==8 and offline._human_ids()==[1] and is_equal_approx(offline.round_start_clock,130.),"offline uses eight participants and same30second staging")
	offline._peer_disconnected(1)
	check(offline.phase=="cancelled" and offline.players.is_empty(),"empty offline queue also removes bots")
	offline.leave_match();await create_timer(.05).timeout;offline.free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Production queue authority with deterministic clock and flat collision fixture: firsthuman+serverbots, fixed30seconds, joining/leaving, sealedroom, rosterprivacy, genericweaponslots,60secondresults then30secondrematch, finaldeparture cancellation. No broker/process/network or FPS claim."}
	NavalStorage.write_json("res://work/br-queue-lifecycle-validation.json",report);print("BR_QUEUE_LIFECYCLE_VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
