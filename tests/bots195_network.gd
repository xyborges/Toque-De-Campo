extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(test: Callable,label: String,seconds:=50.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	failures.append("timeout "+label);print("FAIL timeout ",label);return false
func teams_balanced() -> bool:
	var teams:=[0,0]
	for member: Dictionary in game.members.values():
		if int(member.team) in [0,1]: teams[int(member.team)]+=1
	return teams==[6,6]
func run() -> void:
	game=load("res://tests/bots195_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
	if role=="server": game.set_meta("war_host",true);game.set_meta("online_bots_test",true)
	else: game.set_meta("war_visual_preview",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server()
	else: await client()
	var result: Dictionary={"role":role,"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/bots195-network-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.6).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
	if not await wait_for(func():return game.get("reports").has("alpha-alone"),"one human",80): return
	check(game._battle_active(),"one human can start the online battle")
	if not await wait_for(func():return is_instance_valid(game.bot_director) and game.bot_director.bots.size()==11 and game.players.size()==12,"solo bot fill",80): return
	check(game.bot_director.bots.size()==11,"bots fill both teams with one human")
	var signal_file:=FileAccess.open("res://work/bots195-bravo-go.json",FileAccess.WRITE);signal_file.store_string("ready");signal_file.close()
	game._broadcast("qa_phase",["join-bravo"])
	if not await wait_for(func():return game.get("reports").has("bravo-deployed") and is_instance_valid(game.bot_director) and game.bot_director.bots.size()==10 and game.players.size()==12 and teams_balanced(),"ten bots fill room",80):
		print("BOT_FILL_DIAGNOSTIC ",{"players":game.players.keys(),"members":game.members,"bots":game.bot_director.bots.keys() if is_instance_valid(game.bot_director) else [],"targets":game.bot_director._online_targets() if is_instance_valid(game.bot_director) else []});return
	check(game._battle_active(),"second human joins the running match")
	var teams:=[0,0]
	for member: Dictionary in game.members.values():
		if int(member.team) in [0,1]: teams[int(member.team)]+=1
	check(teams==[6,6],"humans and bots are balanced six against six")
	check(game.vehicle_system.vehicles.v_guarani.driver==0 and game.vehicle_system.vehicles.v_bmp2.driver==0,"team APCs remain available to human players")
	var charlie_file:=FileAccess.open("res://work/bots195-charlie-go.json",FileAccess.WRITE);charlie_file.store_string("ready");charlie_file.close()
	game._broadcast("qa_phase",["join-charlie"])
	if not await wait_for(func():return game.get("reports").has("charlie-deployed") and game.bot_director.bots.size()==9 and game.players.size()==12,"third human replaces bot",80):return
	teams=[0,0]
	for member: Dictionary in game.members.values():
		if int(member.team) in [0,1]: teams[int(member.team)]+=1
	check(teams==[6,6],"third player replaces a bot on the chosen team")
	game._broadcast("qa_phase",["charlie-leave"])
	if not await wait_for(func():return game.bot_director.bots.size()==10 and game.players.size()==12,"bot refills on disconnect",50):return
	check(true,"bot refills a vacated slot")
	var scout_id:=0
	for peer in game.members:
		if not bool(game.members[peer].get("bot",false)) and int(game.members[peer].team)==0: scout_id=int(peer);break
	game.members[scout_id].role="marksman";game.players[scout_id].apply_identity(0,"marksman")
	game._broadcast("war_identity",[scout_id,game.members[scout_id]])
	game.vehicle_system._set_utility(scout_id,"binoculars")
	var smoke_point: Vector3=game.players[scout_id].global_position+Vector3.UP
	game.vehicle_system.register_smoke("network-test",smoke_point,game.war_clock+25.)
	game.vehicle_system._broadcast("smoke_event",["network-test",smoke_point,game.war_clock+25.])
	game._broadcast("qa_phase",["utility"])
	if not await wait_for(func():return game.get("reports").has("alpha-utility") and game.get("reports").has("bravo-utility"),"utility replication",45):return
	check(true,"binoculars and tank smoke replicate to owner and other player")
	game.match_ended=true;game.round_restart_left=60.;game._broadcast("war_round_ended",[0,60.]);game._broadcast("qa_phase",["ended"])
	if not await wait_for(func():return game.get("reports").has("alpha-ended") and game.get("reports").has("bravo-ended"),"round end",45):return
	game.reset_operation()
	if not await wait_for(func():
		for id in game.bot_director.bots:
			if not game.players[id].deployed: return false
		return game.bot_director.bots.size()==10,"bot redeployment",45):return
	check(true,"round restart restores humans and bots")
	game._broadcast("qa_phase",["done"]);await create_timer(.8).timeout
func client() -> void:
	if role=="bravo":
		if not await wait_for(func():return FileAccess.file_exists("res://work/bots195-bravo-go.json"),"first player ready",130): return
	if role=="charlie":
		if not await wait_for(func():return FileAccess.file_exists("res://work/bots195-charlie-go.json"),"room full",130): return
	await game.join_game("pvp")
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join",100):return
	if role=="alpha":
		game.request_deploy(0,"soldier","fal","stinger","base")
		if not await wait_for(func():return game.local_player.deployed,"alpha deploy",30):return
		game.rpc_id(1,"qa_report","alpha-alone")
	elif role=="bravo":
		game.request_deploy(1,"soldier","ak","rpg","base")
		if not await wait_for(func():return game.local_player.deployed,"bravo deploy",30):return
		game.rpc_id(1,"qa_report","bravo-deployed")
	else:
		game.request_deploy(0,"soldier","fal","stinger","base")
		if not await wait_for(func():return game.local_player.deployed,"charlie deploy",30):return
		game.rpc_id(1,"qa_report","charlie-deployed")
		if await wait_for(func():return game.get("phase")=="charlie-leave","departure",30):
			check(true,"human joined full bot-filled server");return
	if role in ["alpha","bravo"]:
		check(await wait_for(func():return game.players.size()>=10,"replicated bots visible",90),"client receives bot actors")
		check(await wait_for(func():return int(game.get("bot_batches"))>=2,"bot pose packets",30),"client receives batched bot movement")
		check(int(game.get("max_bot_packet"))<1100,"batched bot payload stays under MTU budget")
		if not await wait_for(func():return game.get("phase")=="utility","utility phase",120):return
		var scout: WarPlayer=null
		for candidate: WarPlayer in game.players.values():
			if candidate.war_team==0 and candidate.war_class=="marksman" and candidate.utility_mode=="binoculars": scout=candidate;break
		check(is_instance_valid(scout),"binoculars visible in multiplayer")
		check(await wait_for(func():return game.vehicle_system.smoke_screens.has("network-test"),"smoke event",20),"smoke is synchronized")
		game.rpc_id(1,"qa_report",role+"-utility")
		if not await wait_for(func():return game.get("phase")=="ended","round ended",45):return
		check(game.match_ended and game.war_ui.round_panel.visible,"round-end screen appears")
		game.rpc_id(1,"qa_report",role+"-ended")
		await wait_for(func():return game.get("phase")=="done","test end",100)
		check(not game.match_ended and game.local_player.deployed,"player respawns after round restart")
