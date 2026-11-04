extends SceneTree
var role:="host"
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func wait_for(condition: Callable,label_text: String,seconds:=15.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	failures.append("timeout: "+label_text);return false
func run() -> void:
	var credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var accounts:=NavalAccounts.new();root.add_child(accounts)
	var response: Dictionary=await accounts.sign_in("login",str(credentials[role].username),str(credentials[role].password))
	check(response.get("ok",false) and accounts.validated_session,"QA login uses verified TLS and signed account profile")
	if failures.is_empty():
		game=WarGame.new();game.accounts_service=accounts;root.add_child(game)
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.players.size()==2,"two central accounts",30):
			check(not game.testing and game._central_pvp(),"production Ubuntu authority has no test bypass")
			if role=="guest": await wait_for(func():return game.members.values().any(func(member):return bool(member.get("deployed",false))),"first team deployed")
			var team:=0 if role=="host" else 1
			var weapon:=WarRules.launcher_for_team(team);var forbidden:="rpg" if team==0 else "stinger"
			game.request_deploy(team,"antitank","fal",weapon,"rally")
			if await wait_for(func():return game.local_player.deployed and game._battle_active(),"two opposing antitank players"):
				var actor:=game.local_player as WarPlayer
				actor.set_physics_process(false);game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
				game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
				check(actor.active_weapons().has(weapon) and not actor.active_weapons().has(forbidden),"central identity exposes only its team's launcher")
				game.select_gadget(weapon)
				if await wait_for(func():return actor.weapon_id==weapon and actor.gadget_equipped,"valid central launcher equip"):
					game.vehicle_system.rpc_id(1,"command","select",{"gadget":forbidden,"enabled":true})
					await create_timer(.35).timeout
					check(actor.weapon_id==weapon,"forged opposite-team command cannot replace the valid launcher")
					game.war_ui._refresh_equipment(game.infantry_hud);game.infantry_hud.refresh()
					check(game.infantry_hud.equipment_buttons[weapon].visible and not game.infantry_hud.equipment_buttons[forbidden].visible,"online HUD exposes one permitted launcher")
					if role=="guest":
						actor.pitch=.25;actor.yaw=0;actor.rotation.y=0;actor.camera_pivot.rotation.x=.25;actor._update_weapon_pose()
						game.rpc_id(1,"server_player_state",actor.position,0.,.25,weapon,false,0,actor.life_id)
						await create_timer(.25).timeout;game.request_gadget()
						check(await wait_for(func():return int(game.members[actor.peer_id].charges)==2 and not actor.launcher_events.is_empty(),"central RPG acceptance"),"central RPG consumes one charge and sends the accepted shot/recoil event")
					else:
						var charges:=int(game.members[actor.peer_id].charges);game.request_gadget();await create_timer(.3).timeout
						check(int(game.members[actor.peer_id].charges)==charges and actor.launcher_events.is_empty(),"Stinger without a target lock neither shoots nor spends a charge")
						check(await wait_for(func():return game.players.values().any(func(remote):return not remote.is_local and not remote.launcher_events.is_empty()),"remote launcher accepted event"),"other account receives the authoritative RPG presentation event")
					var remote: WarPlayer
					for candidate: WarPlayer in game.players.values():
						if not candidate.is_local: remote=candidate
					check(is_instance_valid(remote) and remote.weapon_id==forbidden and remote.launcher_model.get_meta("model_details").version==3,"remote avatar displays its own team launcher and revised model")
					NavalStorage.write_json("res://work/central165-launcher-"+role+".stage.json",{"done":true})
					var other:="guest" if role=="host" else "host"
					await wait_for(func():return NavalStorage.read_json("res://work/central165-launcher-"+other+".stage.json").get("done",false),"peer completed checks")
	var result: Dictionary={"role":role,"checks":checks,"failures":failures,"authority":"production Ubuntu, two real TLS accounts, normal deployment and RPCs"}
	NavalStorage.write_json("res://tests/ubuntu-war-launchers-"+role+".json",result);print(JSON.stringify(result))
	if is_instance_valid(game): game.show_menu();game.queue_free()
	await create_timer(.4).timeout;accounts.queue_free();quit(0 if failures.is_empty() else 1)
