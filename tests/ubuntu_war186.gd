extends SceneTree
var role:="host"
var port:=3014
var failures: Array[String]=[]
var checks:=0
var game: WarGame
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--war-port="): port=int(arg.trim_prefix("--war-port="))
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(condition: Callable,label: String,seconds:=40.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if condition.call(): return true
	if is_instance_valid(game): print("CENTRAL_DIAGNOSTIC ",{"label":label,"notice":game.last_notice,"status":game.status_label.text,"online":game.online,"ready":game.join_ready,"players":game.players.size(),"preparing":game.preparing_world,"peer":game.multiplayer.multiplayer_peer.get_connection_status(),"clock":game.war_clock})
	failures.append("timeout: "+label);return false
func run() -> void:
	var credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var accounts:=NavalAccounts.new();root.add_child(accounts)
	accounts.connection_state.connect(func(result,status): print("ACCOUNTS_TRANSPORT ",result," ",status))
	var authenticated: Dictionary=await accounts.sign_in("login",str(credentials[role].username),str(credentials[role].password))
	check(authenticated.get("ok",false) and accounts.validated_session,"login over verified TLS and signed account profile")
	if failures.is_empty():
		game=WarGame.new();game.accounts_service=accounts;root.add_child(game)
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.players.size()>=2,"central War join"):
			check(not game.testing and game._central_pvp(),"real account authority, without testing bypass")
			game.request_deploy(0 if role=="host" else 1,"soldier","fal" if role=="host" else "ak","stinger" if role=="host" else "rpg","base")
			if await wait_for(func():return game.local_player.deployed and game._battle_active(),"both teams deployed"):
				var actor:=game.local_player as WarPlayer
				check(actor.war_class=="soldier" and actor.weapon_id in actor.active_weapons(),"class rifle remains available regardless of account shop purchases")
				check(actor.global_position.y>=WarTerrain.height_at(actor.position.x,actor.position.z)-.10,"central deployment is above the physical terrain")
				game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
				await wait_for(func():return actor.weapon_id==("fal" if role=="host" else "ak") and actor.hp>0,"equipped class rifle")
				await create_timer(.3).timeout
				game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
				print("COMBAT_READY ",{"hp":actor.hp,"weapon":actor.weapon_id,"ammo":actor.ammo.get(actor.weapon_id,0),"deployed":actor.deployed,"allowed":game.gameplay_input_allowed(),"mouse":Input.mouse_mode,"blocked":game.ui_focus.blocked(),"life":actor.life_id})
				if role=="host":
					actor.fire_cooldown=0;actor.fire()
					check(await wait_for(func():return actor.ammo.fal==19,"FAL authoritative shot"),"central server validates and replicates FAL shot")
					actor.start_reload()
					check(await wait_for(func():return actor.reload_left>0,"FAL reload"),"central reload starts")
					await wait_for(func():return actor.reload_left==0,"reload completion",9.)
					actor.equip_quick_slot(3);game.prime_grenade(actor)
					if await wait_for(func():return not actor.grenade_held_id.is_empty(),"central War grenade prime"):
						await create_timer(.5).timeout;game.request_grenade(actor)
						check(await wait_for(func():return not game.grenades_system.events.is_empty(),"central War grenade explosion",8.),"central War uses the shared five-second grenade")
				else:
					check(await wait_for(func():return not game.seen_shots.is_empty(),"remote shot",12.),"other account receives the same shot")
					check(await wait_for(func():return not game.grenades_system.events.is_empty(),"remote grenade",18.),"other account receives the same grenade explosion")
				check(await wait_for(func():return game.match_stats.rows.size()>=2,"scoreboard authority"),"two authenticated accounts appear in the authoritative scoreboard")
				var other: GamePlayer
				for remote: GamePlayer in game.players.values():
					if not remote.is_local: other=remote
				check(is_instance_valid(other) and other.war_team!=actor.war_team and other.body_root.visible,"remote soldier has the opposing team identity and a visible body")
				actor.clear_weapon_aim()
	var result: Dictionary={"role":role,"checks":checks,"failures":failures,"port":port}
	NavalStorage.write_json("res://tests/ubuntu-war186-"+role+".json",result);print(JSON.stringify(result))
	if is_instance_valid(game): game.show_menu();game.queue_free()
	await create_timer(.4).timeout;accounts.queue_free();quit(0 if failures.is_empty() else 1)
