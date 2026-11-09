extends SceneTree

# The temporary bot cap is a population policy, never a physics optimization.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok: failures.append(description)
	print(("PASS " if ok else "FAIL ")+description)

func run() -> void:
	check(GameBotPopulation.BOTS_PER_TEAM==11,"global cap is 11 bots per team")
	check(GameBotPopulation.TOTAL_BOTS==22,"global aggregate cap is 22 bots")
	check(WarRules.ONLINE_BOTS_PER_TEAM==11 and WarRules.ONLINE_BOTS==22,"Guerra shares the cap")
	check(BattleRoyaleGame.ONLINE_BOTS==22,"Battle Royale FFA has 22 bots")
	check(GameBotPopulation.war_online_targets([0,0])==[0,0],"no human means no online bots")
	check(GameBotPopulation.war_online_targets([1,0])==[10,11],"one human plus ten friendly bots balances eleven enemy bots")
	check(GameBotPopulation.war_online_targets([1,1])==[11,11],"two balanced humans have eleven bots on each side")
	check(GameBotPopulation.war_online_targets([3,1])==[9,11],"unbalanced humans preserve total-team balance without exceeding eleven bots")
	check(GameBotPopulation.war_online_targets([1,3])==[11,9],"mirrored imbalance preserves the cap")
	check(GameBotPopulation.war_online_targets([12,0])==[0,11],"human majority cannot force above-eleven bots")
	check(GameBotPopulation.war_online_targets([1,1],true)==[14,14],"explicit 28 bot stress test still works")
	check(GameBotPopulation.war_online_targets([3,1],true)==[13,15],"legacy 28 bot fixture balancing remains intact")
	check(WarRules.OFFLINE_PARTICIPANTS==18,"existing offline participant selection is unchanged")

	# Verify the real director's test-only guard; it cannot be enabled by
	# ordinary client counts or simply by running gameplay offline.
	var game: WarGame=WarGame.new()
	var director: WarBotDirector=WarBotDirector.new()
	director.game=game
	game.members[123]={"team":0,"bot":false}
	check(director._online_targets()==[10,11],"real director uses production limit and balances one human")
	game.set_meta("online_bots_test",true)
	check(director._online_targets()==[10,11],"test population flag alone cannot bypass the cap")
	game.set_meta("test_mode",true)
	check(director._online_targets()==[14,14],"both QA flags intentionally allow 28 bots")
	game.set_meta("online_bots_test",false)
	check(director._online_targets()==[10,11],"disabling QA flag restores production limit")
	director.free()
	game.free()
	print("BOT_POPULATION_11_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pass":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
