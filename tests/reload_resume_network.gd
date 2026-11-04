extends SceneTree
var game: Node3D
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
func wait_for(condition: Callable,label_text: String,seconds:=10.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if condition.call(): return true
	failures.append("timeout: "+label_text);print("FAIL timeout: "+label_text);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func capture(label_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/reload-resume-network-"+label_text+".png")
func run() -> void:
	game=load("res://tests/reload_resume_network_fixture.gd").new();game.name="ToqueDeCampo";game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server":
		game.dedicated_pvp=true;game.host_game("pvp");await server_flow()
	else:
		game.join_game("pvp")
		if await wait_for(func():return game.players.size()==2 and is_instance_valid(game.local_player),"initial two-player join"):
			game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			if role=="shooter": await shooter_flow()
			else: await observer_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/reload-resume-network-"+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2,"two clients"): return
	var actor: GamePlayer
	for player: GamePlayer in game.players.values():
		if str(player.name)=="shooter": actor=player
	actor.ammo.fal=12;actor.ammo.glock=4;actor.reserves.fal=180;actor.reserves.glock=60
	game._equip_server(actor,"fal");game.sync_inventory(actor)
	await create_timer(.5).timeout;phase("partial-fal")
	if not await wait_for(func():return game.reports.has("paused-fal"),"partial FAL reload paused"): return
	var saved: float=actor.paused_reloads.fal.left
	check(saved>4.3 and saved<5.1 and actor.reload_weapon.is_empty() and actor.ammo.fal==12,"server saves real elapsed FAL progress without replenishing")
	phase("observer-leave")
	if not await wait_for(func():return game.players.size()==1,"observer leaves"): return
	await create_timer(.6).timeout
	check(actor.paused_reloads.has("fal") and is_equal_approx(float(actor.paused_reloads.fal.left),saved),"disconnect does not erase or advance another player's holstered reload")
	if not await wait_for(func():return game.players.size()==2,"observer rejoins",15): return
	phase("late-baseline")
	if not await wait_for(func():return game.reports.has("late-baseline"),"late join receives paused state"): return
	phase("resume-fal")
	if not await wait_for(func():return actor.reload_weapon=="fal","server resumes FAL"): return
	check(actor.reload_total==6 and actor.reload_left<=saved+.02 and actor.reload_left>saved-.5,"server resumes remaining FAL time instead of starting six seconds again")
	var rounds: int=game.projectiles.size()
	game._server_accept_shot(actor.peer_id,777,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,"fal",0)
	check(actor.ammo.fal==12 and game.projectiles.size()==rounds,"server denies a shot during resumed reload")
	if not await wait_for(func():return actor.ammo.fal==30 and actor.reload_weapon.is_empty(),"FAL completes once",8): return
	check(actor.reserves.fal==162,"server transfers exactly the missing FAL rounds")
	if not await wait_for(func():return game.reports.has("fal-complete") and game.reports.has("remote-resume"),"both clients observe FAL completion"): return
	phase("grenade-pause")
	if not await wait_for(func():return game.reports.has("grenade-paused"),"Glock and grenade pause"): return
	check(actor.paused_reloads.has("glock") and not actor.grenade_held_id.is_empty() and actor.ammo.glock==4,"server retains Glock progress through actual grenade preparation")
	phase("release-grenade")
	if not await wait_for(func():return actor.reload_weapon=="glock","resume after throwing grenade"): return
	check(actor.reload_total==4 and actor.reload_left<3.5,"Glock resumes its original four-second animation after the grenade throw")
	if not await wait_for(func():return actor.ammo.glock==12 and actor.reload_weapon.is_empty(),"Glock completion",6): return
	check(actor.reserves.glock==52,"resumed Glock conserves finite reserve")
	phase("prepare-death")
	if not await wait_for(func():return game.reports.has("death-ready"),"death reset setup"): return
	check(actor.paused_reloads.has("fal") and actor.reload_weapon=="glock","server has both active and paused state before death")
	actor.take_damage(1000,"chest",0)
	check(actor.hp==0 and actor.paused_reloads.is_empty() and actor.reload_weapon.is_empty(),"death clears authoritative active and paused state")
	var old_life:=actor.life_id;game._reset_server_player(actor)
	check(actor.life_id==old_life+1 and actor.paused_reloads.is_empty() and actor.reload_weapon.is_empty(),"authoritative respawn does not carry reload state into the next life")
	phase("new-life")
	if not await wait_for(func():return game.reports.has("new-life"),"client confirms new-life state"): return
	phase("finish");await create_timer(.5).timeout
func shooter_flow() -> void:
	var actor:=game.local_player as GamePlayer
	if not await wait_for(func():return game.phase=="partial-fal" and actor.ammo.fal==12,"initial authoritative inventory"): return
	actor.start_reload()
	if not await wait_for(func():return actor.reload_weapon=="fal","FAL reload starts"): return
	await create_timer(1.2).timeout;actor.equip_slot(4)
	if not await wait_for(func():return actor.weapon_id=="glock" and actor.paused_reloads.has("fal") and actor.reload_weapon.is_empty(),"Glock selected with paused FAL"): return
	check(absf(float(actor.paused_reloads.fal.total)-6)<.01,"client keeps the original full FAL animation duration while paused")
	game.rpc_id(1,"qa_report","paused-fal",{})
	if not await wait_for(func():return game.phase=="resume-fal","resume phase",20): return
	actor.equip_slot(3)
	if not await wait_for(func():return actor.reload_weapon=="fal","local FAL resumes"): return
	check(actor.reload_total==6 and actor.reload_left<5.1,"local resumed FAL does not restart its full timer")
	await capture("fal-resumed")
	if is_instance_valid(actor.reload_audio): check(actor.reload_audio.get_playback_position()>.6,"reload sound resumes beyond its already-played opening")
	var ammo:=int(actor.ammo.fal);actor.fire_cooldown=0;actor.fire()
	check(actor.ammo.fal==ammo,"local prediction blocks firearm shots during resumed reload")
	if not await wait_for(func():return actor.ammo.fal==30 and actor.reload_weapon.is_empty(),"local authoritative FAL completion",8): return
	check(actor.reserves.fal==162,"client receives exact server reserve after completion")
	game.rpc_id(1,"qa_report","fal-complete",{})
	if not await wait_for(func():return game.phase=="grenade-pause","grenade phase"): return
	actor.equip_slot(4);await create_timer(.25).timeout;actor.start_reload()
	if not await wait_for(func():return actor.reload_weapon=="glock","Glock starts"): return
	await create_timer(.8).timeout;actor.equip_grenade();game.prime_grenade(actor)
	if not await wait_for(func():return not actor.grenade_held_id.is_empty() and actor.paused_reloads.has("glock"),"grenade held without losing Glock"): return
	check(actor.reload_weapon.is_empty() and float(actor.paused_reloads.glock.left)<3.5,"client pauses Glock while holding a live grenade")
	game.rpc_id(1,"qa_report","grenade-paused",{})
	if not await wait_for(func():return game.phase=="release-grenade","release grenade phase"): return
	game.request_grenade(actor)
	if not await wait_for(func():return actor.ammo.glock==12 and actor.reload_weapon.is_empty(),"Glock resumes after throw and completes",7): return
	check(actor.paused_reloads.is_empty() and actor.reserves.glock==52,"grenade completion leaves no stale paused reload")
	if not await wait_for(func():return game.phase=="prepare-death","death phase"): return
	# The fixture sets partial magazines using an authoritative QA event; input
	# below still starts/pauses both real reloads through normal requests.
	game.rpc_id(1,"qa_prepare_death")
	if not await wait_for(func():return actor.ammo.fal==11 and actor.ammo.glock==3,"death fixture inventory"): return
	actor.equip_slot(3);await create_timer(.2).timeout;actor.start_reload()
	if not await wait_for(func():return actor.reload_weapon=="fal","death FAL starts"): return
	await create_timer(.3).timeout;actor.equip_slot(4);await create_timer(.2).timeout;actor.start_reload()
	if not await wait_for(func():return actor.reload_weapon=="glock" and actor.paused_reloads.has("fal"),"active and paused before death"): return
	var life:=actor.life_id;game.rpc_id(1,"qa_report","death-ready",{})
	if not await wait_for(func():return game.phase=="new-life" and actor.life_id>life,"new life replication"): return
	check(actor.paused_reloads.is_empty() and actor.reload_weapon.is_empty() and actor.ammo.fal==30 and actor.ammo.glock==12,"new life client has fresh inventory with no inherited progress")
	game.rpc_id(1,"qa_report","new-life",{})
	await wait_for(func():return game.phase=="finish","finish")
func observer_flow() -> void:
	if not await wait_for(func():return game.phase=="observer-leave","observer leave phase"): return
	game.show_menu();await create_timer(1.3).timeout;game.join_game("pvp")
	if not await wait_for(func():return game.players.size()==2 and is_instance_valid(game.local_player),"observer reconnect"): return
	var remote: GamePlayer
	for actor: GamePlayer in game.players.values():
		if not actor.is_local: remote=actor
	check(await wait_for(func():return remote.paused_reloads.has("fal") and remote.weapon_id=="glock","late paused baseline"),"late join receives the remote equipped gun and paused reload")
	game.rpc_id(1,"qa_report","late-baseline",{})
	if not await wait_for(func():return game.phase=="resume-fal","remote resume phase"): return
	if not await wait_for(func():return remote.reload_weapon=="fal","remote FAL animation resumes"): return
	check(remote.reload_total==6 and remote.reload_left<5.1,"observer sees the resumed animation at the actual progress")
	if not await wait_for(func():return remote.ammo.fal==30 and remote.reload_weapon.is_empty(),"remote completion",8): return
	check(remote.reserves.fal==162,"observer receives the same final magazine and reserve")
	game.rpc_id(1,"qa_report","remote-resume",{})
	await wait_for(func():return game.phase=="finish","finish",30)
