extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func wait_for(condition: Callable,seconds:=12.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	failures.append("timeout in "+role);return false
func actor_named(value: String) -> WarPlayer:
	for actor: WarPlayer in game.players.values():
		if str(actor.name)==value: return actor
	return null
func run() -> void:
	game=load("res://tests/war_friendly_network_fixture.gd").new();game.set_meta("war_host",role=="server");game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	elif await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed): await client_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/war-friendly-network-"+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==3): return
	var author:=actor_named("author");var victim:=actor_named("victim");var opponent:=actor_named("opponent")
	check(game._deploy(author.peer_id,0,"soldier","fal","rpg","base") and game._deploy(opponent.peer_id,1,"soldier","fal","rpg","base") and game._deploy(victim.peer_id,0,"soldier","fal","rpg","base"),"three actual ENet participants deploy with balanced team validation")
	await create_timer(.7).timeout
	var origin:=WarTerrain.point(-440,290)+Vector3.UP*.15
	for actor: WarPlayer in [author,victim,opponent]:
		var point:=origin+(Vector3(0,0,-18) if actor==victim else (Vector3(30,0,-18) if actor==opponent else Vector3.ZERO))
		var direction: Vector3=(origin+Vector3(0,1,-18)-point-Vector3.UP*1.65).normalized()
		game.qa_pose(actor.peer_id,point,atan2(-direction.x,-direction.z),asin(clampf(direction.y,-1,1)))
		game._broadcast("qa_pose",[actor.peer_id,point,actor.yaw,actor.pitch]);game.members[actor.peer_id].shield=0
	game._broadcast("qa_identities",[author.peer_id,victim.peer_id])
	game.phase="fire";game._broadcast("qa_phase",["fire"])
	if not await wait_for(func():return victim.hp==0):
		print("QA_FIRE_STATE ",{"hp":victim.hp,"author_pos":author.position,"victim_pos":victim.position,"ammo":author.ammo,"seen_shots":game.seen_shots.size()});return
	check(author.kills==0 and game.match_stats.rows[author.peer_id].kills==0,"friendly elimination grants no kill in either authoritative counter")
	check(game.match_stats.rows[author.peer_id].points==-100 and game.match_stats.rows[author.peer_id].damage==0,"authority deducts100 points and awards no friendly damage score")
	check(victim.deaths==1 and game.match_stats.rows[victim.peer_id].deaths==1,"one death is recorded for the teammate who was killed")
	check(game.reward_jobs.is_empty(),"friendly elimination never enters the account reward queue")
	if not await wait_for(func():return game.reports.has("author") and game.reports.has("victim") and game.reports.has("opponent")): return
	game.phase="finish";game._broadcast("qa_phase",["finish"]);await create_timer(.4).timeout
func client_flow() -> void:
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not await wait_for(func():return game.phase=="fire"): return
	var actor:=game.local_player as WarPlayer
	var author:=game.players.get(game.author_peer) as WarPlayer;var victim:=game.players.get(game.victim_peer) as WarPlayer
	check(is_instance_valid(author) and is_instance_valid(victim),"fixture resolves participants by their actual network identity")
	if not is_instance_valid(author) or not is_instance_valid(victim): return
	print("QA_READY ",role,{"phase":game.phase,"weapon":actor.weapon_id,"hp":actor.hp,"deployed":actor.deployed,"pos":actor.position,"yaw":actor.yaw,"pitch":actor.pitch,"enabled":game.gameplay_input_allowed()})
	if role=="author":
		for shot in 3:
			if victim.hp<=0: break
			actor.fire_cooldown=0;actor.fire();await create_timer(.25).timeout
	if not await wait_for(func():return victim.hp==0 and int(game.match_stats.rows.get(author.peer_id,{}).get("points",0))==-100): return
	check(victim.deaths==1 and author.kills==0,"remote damage and scoreboard keep death without a friendly kill")
	if role in ["author","victim"]:
		check(game.war_ui.combat_notice.visible and game.war_ui.combat_notice_text.text.contains("FOGO AMIGO"),"reliable server notice reaches "+role)
		check(game.war_ui.combat_notice_text.text.contains("−100") if role=="author" else game.war_ui.combat_notice_text.text.contains("morto por seu aliado"),"notice explains the correct role to "+role)
	else: check(not game.war_ui.combat_notice.visible,"uninvolved opponent receives no private friendly-fire alert")
	game.rpc_id(1,"qa_report",role)
	await wait_for(func():return game.phase=="finish")
