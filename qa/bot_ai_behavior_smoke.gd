extends SceneTree
# Tests objective reallocation without starting the entire world/physics.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	WarRules.configure(WarOperation.UKRAINE)
	var director:=WarBotDirector.new()
	var test_game:=WarGame.new()
	var soldier:=WarPlayer.new()
	soldier.peer_id=10001
	soldier.war_team=0
	soldier.hp=100.
	soldier.deployed=true
	soldier.position=WarRules.OBJECTIVES["A"].position
	test_game.players[10001]=soldier
	test_game.objective_states=WarRules.fresh_objectives()
	var objective_a: Dictionary=test_game.objective_states["A"]
	objective_a.owner=0
	objective_a.side=1
	objective_a.count=[0,2]
	director.game=test_game
	director.squads={"0:0":{"team":0,"members":[10001],"objective":"B"}}
	director.bots={10001:{"team":0,"slot":0,"squad":"0:0","objective":"B"}}
	director._assign_objectives()
	var passed:=str(director.bots[10001].objective)=="A"
	test_game.players.clear()
	director.bots.clear()
	director.squads.clear()
	director.game=null
	soldier.free()
	director.free()
	test_game.free()
	if not passed:
		push_error("WAR_AI_DEFEND_OBJECTIVE_FAILED")
		quit(1)
		return
	print("WAR_AI_BEHAVIOR_OK: contested allied objective receives defense")
	quit(0)
