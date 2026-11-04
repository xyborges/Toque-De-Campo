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
func wait_for(test: Callable,label: String,seconds:=25.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	print("NETWORK_DIAGNOSTIC ",{"role":role,"port":game._network_port(),"online":game.online,"preparing":game.preparing_world,"testing":game.testing,"address":game.address_input.text,"status":game.status_label.text,"notice":game.last_notice,"players":game.players.size(),"members":game.members.size(),"peer":game.multiplayer.multiplayer_peer.get_connection_status()})
	failures.append("timeout "+label);return false
func click(actor: GamePlayer,down: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;actor._unhandled_input(event)
func run() -> void:
	game=load("res://tests/rifles185_network_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
	if role=="server": game.set_meta("war_host",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server()
	else:
		await game.join_game("pvp")
		var team:=0 if role=="alpha" else 1;var rifle: String=WarRules.primary_for("soldier",team)[0]
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join"):
			game.request_deploy(team,"soldier",rifle,WarRules.launcher_for_team(team),"base")
			if await wait_for(func():return game.local_player.deployed,"deploy"): await client(rifle)
	NavalStorage.write_json("res://tests/rifles185-network-"+role+".json",{"role":role,"checks":checks,"failures":failures});print(JSON.stringify({"role":role,"checks":checks,"failures":failures}))
	game.show_menu();game.queue_free();await create_timer(.5).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
	if not await wait_for(func():return game.members.size()==2 and game.members.values().all(func(m):return m.deployed),"both teams",50): return
	for actor: WarPlayer in game.players.values():
		var rifle: String=WarRules.primary_for(actor.war_class,actor.war_team)[0]
		check(actor.weapon_id==rifle and actor.loadout.has(rifle),"authority assigns "+rifle+" to team "+str(actor.war_team+1))
		var wrong:="ak" if rifle=="fal" else "fal"
		check(not game._deploy(actor.peer_id,actor.war_team,"soldier",wrong,WarRules.launcher_for_team(actor.war_team),"base",{"primary":wrong}),"server rejects opposing rifle "+wrong)
	game._broadcast("qa_phase",["exercise"])
	if not await wait_for(func():return game.reports.has("alpha") and game.reports.has("bravo"),"fire and reload",35): return
	for actor: WarPlayer in game.players.values():
		check(int(actor.ammo[actor.weapon_id])<int(GameWeapons.ITEMS[actor.weapon_id].mag) and int(actor.reserves[actor.weapon_id])<int(CombatRules.weapon(actor.weapon_id).reserve),"authority accepted reload, reserve transfer and resumed "+actor.weapon_id+" fire")
	game._broadcast("qa_phase",["done"]);await create_timer(.8).timeout
func client(rifle: String) -> void:
	var actor:=game.local_player as WarPlayer
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not await wait_for(func():return game.phase=="exercise","exercise"): return
	await create_timer(.3).timeout
	var other: WarPlayer
	for candidate: WarPlayer in game.players.values():
		if not candidate.is_local: other=candidate
	var expected:="ak" if rifle=="fal" else "fal"
	check(is_instance_valid(other) and other.weapon_id==expected and other.weapon_root.has_node("Imported_"+expected),"remote player has matching weapon identity and "+expected+" model")
	for tpp in [false,true]:
		game.third_person=tpp;actor._update_view();actor.fire_cooldown=0
		var before:=actor.shot_sequence;var ammo:=int(actor.ammo[rifle])
		click(actor,true);await create_timer(.7).timeout;click(actor,false);await create_timer(.25).timeout
		check(actor.shot_sequence>=before+4 and int(actor.ammo[rifle])<=ammo-4,rifle+" sustained fire in "+("TPP" if tpp else "FPP"))
	actor.equip_grenade();await physics_frame;actor.equip_quick_slot(2);await create_timer(.2).timeout
	check(actor.weapon_id==rifle and not actor.grenade_selected,rifle+" returns from grenade via its primary slot")
	actor.start_reload()
	check(await wait_for(func():return actor.reload_left>0,"reload starts",3),rifle+" authoritative reload starts")
	check(await wait_for(func():return actor.reload_left<=0,"reload ends",9),rifle+" authoritative reload completes")
	actor.fire_cooldown=0;var before:=actor.shot_sequence;click(actor,true);await create_timer(.3).timeout;click(actor,false)
	check(actor.shot_sequence>before,rifle+" can fire after reload")
	game.rpc_id(1,"qa_report",role)
	await wait_for(func():return game.phase=="done","done",12)
