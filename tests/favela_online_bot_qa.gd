extends SceneTree
## ENet stress test: two remote humans, server-owned bots, live poses.
## Uses war_network_fixture and the same DTLS harness as favela_network_qa.gd.
var game: WarGame
var role := "server"
var failures: Array[String] = []
var checks := 0
var tracked: Dictionary = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="): role=argument.trim_prefix("--role=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("FAVELA_BOT_NET_FAIL ",role," ",label)

func wait_for(test: Callable, label: String, seconds := 65.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call(): return true
		await process_frame
	failures.append("timeout: "+label)
	print("FAVELA_BOT_NET_TIMEOUT ",role," ",label)
	return false

func humans() -> int:
	var n:=0
	for state: Dictionary in game.members.values():
		if not bool(state.get("bot",false)): n+=1
	return n

func bots() -> int:
	var n:=0
	for state: Dictionary in game.members.values():
		if bool(state.get("bot",false)): n+=1
	return n

func _run() -> void:
	game=load("res://tests/war_network_fixture.gd").new()
	game.operation_id=WarOperation.FAVELA
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	if role=="server":
		game.set_meta("war_host",true)
		game.set_meta("online_bots_test",true)
	root.add_child(game)
	game.nickname_input.text=role
	game.address_input.text="127.0.0.1"
	if role=="server":await _server()
	else:await _client()
	var payload := {"role":role,"checks":checks,"failures":failures,
		"humans":humans(),"bots":bots(),"actors":game.players.size(),
		"operation":game.operation_id}
	var output := OS.get_environment("FAVELA_NET_QA_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join(role+".json"),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))
		file.close()
	print("FAVELA_ONLINE_BOT_RESULT ",JSON.stringify(payload))
	game.show_menu()
	game.queue_free()
	await create_timer(.4).timeout
	quit(0 if failures.is_empty() else 1)

func _phase(next: String) -> void:
	game.phase=next
	game._broadcast("qa_phase",[next])

func _server() -> void:
	if not await wait_for(func(): return humans()==2 and game.loading_baselines.is_empty(),"two humans baseline",110.0):return
	var alpha: WarPlayer
	var bravo: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="alpha":alpha=actor
		elif str(actor.name)=="bravo":bravo=actor
	if not is_instance_valid(alpha) or not is_instance_valid(bravo):
		failures.append("client actors missing")
		return
	check(game._deploy(alpha.peer_id,0,"soldier","fal","","base"),"online police deploys")
	check(game._deploy(bravo.peer_id,1,"antitank","g3","rpg","base"),"online bandit RPG deploys")
	if not await wait_for(func():return bots()>=20,"server bots online",65.0):return
	if not await wait_for(func():return game.reports.has("alpha-ready") and game.reports.has("bravo-ready"),"both clients see NPCs",80.0):return
	check(game.vehicle_system.vehicles.size()==8,"all Favela vehicles remain authoritative")
	check(game._battle_active(),"online bot match active")
	check(bots()>=20,"twenty or more active NPC memberships")
	for id in game.bot_director.bots:
		var actor := game.players.get(id) as WarPlayer
		if is_instance_valid(actor) and actor.deployed and actor.hp>0:
			tracked[id]=actor.global_position
	_phase("observe")
	await create_timer(12.0).timeout
	var moving:=0
	var alive:=0
	for id in tracked:
		var actor := game.players.get(id) as WarPlayer
		if not is_instance_valid(actor) or actor.hp<=0:continue
		alive+=1
		if actor.global_position.distance_to(tracked[id])>1.5:moving+=1
	check(alive>=15,"most bots still alive and deployed")
	check(moving>=5,"at least five bots moved over 1.5 m in 12 seconds")
	check(int(game.bot_director.diagnostics.get("moves",0))>=500,"NPC director recorded movement")
	_phase("done")
	if not await wait_for(func():return game.reports.has("alpha-observed") and game.reports.has("bravo-observed"),"both clients finished observing",20.0):return
	await create_timer(.7).timeout

func _client() -> void:
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"ENet baseline join",115.0):return
	var own := game.local_player as WarPlayer
	if not await wait_for(func():return own.deployed,"deployed class",45.0):return
	if not await wait_for(func():return bots()>=20 and game.players.size()>=22,"NPC roster replicated",90.0):return
	check(game.operation_id==WarOperation.FAVELA,"Favela content selected")
	check(own.war_team==(0 if role=="alpha" else 1),"correct team replicated")
	check(game.vehicle_system.vehicles.size()==8,"eight vehicles mirrored")
	check(bots()>=20,"NPC memberships available")
	game.rpc_id(1,"qa_report",role+"-ready")
	if not await wait_for(func():return str(game.phase)=="observe","start observation",35.0):return
	var positions: Dictionary={}
	for id in game.members:
		if bool(game.members[id].get("bot",false)) and game.players.has(id):
			positions[id]=game.players[id].global_position
	if not await wait_for(func():return str(game.phase)=="done","observation completed",38.0):return
	var movement:=0
	for id in positions:
		if game.players.has(id) and game.players[id].global_position.distance_to(positions[id])>1.5:movement+=1
	check(movement>=3,"client received moving NPC states")
	game.rpc_id(1,"qa_report",role+"-observed")
	await create_timer(.3).timeout
