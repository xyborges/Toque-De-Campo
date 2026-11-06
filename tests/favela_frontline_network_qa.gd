extends "res://tests/favela_network_qa.gd"
## Real ENet: Police capture C to unlock D, Bandits counterattack D to
## reopen C. Verify that the authoritative frontier reaches both clients.
## Run with the existing tests/run_favela_network.py harness.

func _server() -> void:
	if not await wait_for(func(): return game.players.size()==2 and game.loading_baselines.is_empty(),
		"both clients and baseline",90.0):return
	check(game.objective_states.size()==5,"five authoritative sectors")
	check(WarFavelaFrontline.active_id(game.objective_states)=="C","authority starts at C")
	check(game._valid_deployment_spawn(0,"B") and game._valid_deployment_spawn(1,"D"),
		"adjacent spawn authorization")
	check(not game._valid_deployment_spawn(0,"A") and not game._valid_deployment_spawn(1,"E"),
		"rear spawn forbidden during contest")
	var police: WarPlayer
	var bandit: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="alpha":police=actor
		elif str(actor.name)=="bravo":bandit=actor
	if not is_instance_valid(police) or not is_instance_valid(bandit):
		failures.append("client actor missing")
		return
	check(game._deploy(police.peer_id,0,"soldier","fal","","base"),"police deploy")
	check(game._deploy(bandit.peer_id,1,"antitank","g3","rpg","base"),"bandit deploy")
	if not await wait_for(func():return game.reports.has("alpha-ready") and game.reports.has("bravo-ready"),
		"clients join",30.0):return
	var center: Vector3=WarRules.OBJECTIVES["C"].position
	_pose(police,WarTerrain.point(center.x,center.z)+Vector3.UP*.35)
	_pose(bandit,WarRules.BASES[1]+Vector3.UP*.35)
	_phase("capture-C")
	if not await wait_for(func():return int(game.objective_states["C"].owner)==0 and WarFavelaFrontline.active_id(game.objective_states)=="D",
		"police capture C and unlock D",42.0):return
	check(not game._valid_deployment_spawn(0,"B") and game._valid_deployment_spawn(0,"C"),
		"forward respawn moved from B to C")
	_phase("captured-C")
	if not await wait_for(func():return game.reports.has("alpha-C") and game.reports.has("bravo-C"),
		"two client snapshots of D",15.0):return
	var ridge: Vector3=WarRules.OBJECTIVES["D"].position
	_pose(police,WarRules.BASES[0]+Vector3.UP*.35)
	_pose(bandit,WarTerrain.point(ridge.x,ridge.z)+Vector3.UP*.35)
	_phase("capture-D")
	if not await wait_for(func():return int(game.objective_states["D"].owner)==1 and WarFavelaFrontline.active_id(game.objective_states)=="C",
		"bandit counterattack D reopens C",42.0):return
	check(game._valid_deployment_spawn(0,"B") and game._valid_deployment_spawn(1,"D"),
		"respawn advances and retreats with front")
	_phase("captured-D")
	if not await wait_for(func():return game.reports.has("alpha-D") and game.reports.has("bravo-D"),
		"both clients see C again",16.0):return
	_phase("done")
	await create_timer(.5).timeout

func _client() -> void:
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),
		"Favela join",90.0):return
	var actor:=game.local_player as WarPlayer
	if not await wait_for(func():return actor.deployed and game.players.size()==2,
		"replicated deployment",45.0):return
	check(game.operation_id==WarOperation.FAVELA,"client uses Favela")
	check(WarFavelaFrontline.active_id(game.objective_states)=="C","client initial front C")
	game.ui_focus.close_all()
	game.rpc_id(1,"qa_report",role+"-ready")
	if not await wait_for(func():return game.phase=="captured-C","first capture phase",55.0):return
	if not await wait_for(func():return int(game.objective_states["C"].owner)==0 and WarFavelaFrontline.active_id(game.objective_states)=="D",
		"replicated police push",14.0):return
	check(true,"client sees D active")
	game.rpc_id(1,"qa_report",role+"-C")
	if not await wait_for(func():return game.phase=="captured-D","bandit counterattack phase",55.0):return
	if not await wait_for(func():return int(game.objective_states["D"].owner)==1 and WarFavelaFrontline.active_id(game.objective_states)=="C",
		"replicated bandit counterattack",14.0):return
	check(true,"client sees C active again")
	game.rpc_id(1,"qa_report",role+"-D")
	if not await wait_for(func():return game.phase=="done","final done",18.0):return
