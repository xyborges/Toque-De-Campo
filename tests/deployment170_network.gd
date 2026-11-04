extends SceneTree
var game: Node3D
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
func wait_for(condition: Callable,seconds:=12.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		if condition.call(): return true
	failures.append("timeout "+role);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func run() -> void:
	game=load("res://tests/deployment170_network_fixture.gd").new();root.add_child(game);game.nickname_input.text=role;game.profile.nickname=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	else:
		await game.join_game("pvp")
		if await wait_for(func():return game.players.size()==2 and game.deployment_panel.visible): await client_flow()
	var result:={"role":role,"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/deployment170-network-"+role+".json",result);print(JSON.stringify(result));game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2): return
	var named: Dictionary={}
	for player: GamePlayer in game.players.values(): named[str(player.name)]=player
	var alpha:=named.alpha as GamePlayer;var bravo:=named.bravo as GamePlayer
	check(alpha.hp==0 and bravo.hp==0 and alpha.ammo.is_empty() and bravo.ammo.is_empty(),"server joins keep both clients unspawned and without ammunition")
	check(not game._accept_infantry_deploy(alpha.peer_id,{"primary":"rpg"},"auto",alpha.life_id),"authority rejects a War launcher in Desert")
	check(not game._accept_infantry_deploy(alpha.peer_id,{"primary":"fal","ammo":999},"auto",alpha.life_id),"authority rejects client-authored ammunition fields")
	check(not game._accept_infantry_deploy(alpha.peer_id,{"primary":"fal"},"enemy-base",alpha.life_id),"authority rejects unavailable spawn points")
	phase("deploy")
	if not await wait_for(func():return alpha.hp==100 and bravo.hp==100): return
	check(alpha.loadout==["glock","fal"] and alpha.ammo.keys().size()==2 and not alpha.grenades_enabled,"Desert spawn grants alpha's selected gear only")
	check(bravo.loadout==["sniper"] and bravo.grenades_enabled and not bravo.ammo.has("fal"),"Desert spawn grants bravo's different validated loadout")
	var inventory:=alpha.loadout.duplicate();var life:=alpha.life_id
	check(not game._accept_infantry_deploy(alpha.peer_id,{"primary":"sniper"},"east",life) and alpha.loadout==inventory and alpha.life_id==life,"alive client cannot respawn or replace equipment")
	phase("pause")
	if not await wait_for(func():return game.reports.has("alpha-paused")): return
	game._apply_hit(bravo.peer_id,{"collider":alpha.hit_regions.chest},30,"chest","sniper")
	if not await wait_for(func():return game.reports.has("alpha-damaged-in-menu")): return
	check(alpha.hp==70,"multiplayer pause leaves authoritative damage running")
	phase("death")
	game._apply_hit(bravo.peer_id,{"collider":alpha.hit_regions.chest},1000,"chest","sniper")
	check(not game._accept_infantry_deploy(alpha.peer_id,{"sidearm":"glock"},"west",life),"death cooldown cannot be bypassed by a spawn RPC")
	if not await wait_for(func():return game.reports.has("alpha-awaiting"),8): return
	check(alpha.hp==0 and alpha.life_id==life,"dead player waits for explicit redeployment rather than automatically respawning")
	phase("respawn")
	if not await wait_for(func():return alpha.hp==100 and alpha.life_id==life+1): return
	check(alpha.loadout==["glock"] and alpha.ammo.keys()==["glock"] and alpha.global_position.x<0,"new life uses selected pistol and the chosen west spawn")
	phase("leave")
	if not await wait_for(func():return game.players.is_empty()): return
	check(game.match_stats.rows.is_empty(),"disconnect removes both players and their scoreboard records")
	phase("done")
func client_flow() -> void:
	var actor:=game.local_player as GamePlayer
	check(actor.hp==0 and not actor.body_root.visible and actor.body_collision.disabled,"client remains hidden and non-colliding until confirmation")
	if not await wait_for(func():return game.phase=="deploy"): return
	var panel:=game.deployment_panel as GameInfantryDeployment
	panel.editor.slots={"sidearm":"glock","primary":"fal"} if role=="alpha" else {"primary":"sniper","grenade":"grenade"};panel.editor._rebuild();panel.editor._changed();panel.confirm.pressed.emit()
	if not await wait_for(func():return actor.hp==100 and not game.ui_focus.blocked()): return
	check(actor.weapon_id==("fal" if role=="alpha" else "sniper"),"approved deployment equips the correct local weapon")
	if role=="alpha":
		if not await wait_for(func():return game.phase=="pause"): return
		game.ui_focus.open(game.pause_panel);game.rpc_id(1,"qa_report","alpha-paused")
		if not await wait_for(func():return actor.hp==70): return
		check(game.pause_panel.visible and not game.offline_frozen,"native multiplayer pause keeps the world active")
		game.rpc_id(1,"qa_report","alpha-damaged-in-menu")
		if not await wait_for(func():return actor.hp==0): return
		if not await wait_for(func():return game.deployment_panel.visible,8): return
		game.rpc_id(1,"qa_report","alpha-awaiting")
		if not await wait_for(func():return game.phase=="respawn"): return
		panel.editor.slots={"sidearm":"glock"};panel.editor._rebuild();panel.editor._changed();panel.spawn.select(1);panel.confirm.pressed.emit()
		if not await wait_for(func():return actor.hp==100 and actor.active_weapons()==["glock"] and not game.ui_focus.blocked() and actor.camera.current): return
		check(not game.ui_focus.blocked() and actor.camera.current,"replicated respawn restores the existing native camera and focus")
	if not await wait_for(func():return game.phase=="leave",30): return
	game.show_menu();check(game.players.is_empty() and game.world_root==null and not game.ui_focus.blocked(),"client exit cleans match state and menus")
