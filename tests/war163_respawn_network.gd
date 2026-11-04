extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}
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
func key(code: int,pressed:=true) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func capture(label_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/war163-respawn-network-"+label_text+".png")
func run() -> void:
	game=load("res://tests/war163_respawn_network_fixture.gd").new();game.set_meta("war_host",role=="server");game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	elif await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed,"first deployment"):
		game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=true;game.local_player._update_view()
		if role=="hero": await hero_flow()
		else: await wait_for(func():return game.phase=="finish","enemy stays connected",30)
	var report: Dictionary={"role":role,"checks":checks,"failures":failures,"measurements":measurements}
	NavalStorage.write_json("res://tests/war163-respawn-network-"+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.25).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2,"two clients join"): return
	var hero: WarPlayer;var enemy: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="hero": hero=actor
		else: enemy=actor
	check(game._deploy(hero.peer_id,0,"soldier","fal","rpg","base") and game._deploy(enemy.peer_id,1,"soldier","fal","rpg","base"),"server deploys two opposing players normally")
	await create_timer(.6).timeout;phase("save-choice")
	if not await wait_for(func():return game.reports.has("choice-saved"),"explicit M choice accepted"): return
	check(str(game.members[hero.peer_id].pending.role)=="medic" and str(game.members[hero.peer_id].pending.spawn)=="rally" and hero.war_class=="soldier","M selection is saved on the server without replacing the current living class")
	var life:=hero.life_id;game.members[hero.peer_id].shield=0.;var killed_at:=Time.get_ticks_msec()
	game._apply_hit(enemy.peer_id,{"collider":hero.hit_regions.chest,"position":hero.position},1000,"chest","glock",Vector3.FORWARD)
	phase("queued-death")
	check(hero.hp==0 and not hero.deployed and float(game.members[hero.peer_id].ready_at)>game.war_clock+3.9,"death starts a real four-second server timegate")
	if not await wait_for(func():return hero.hp==100 and hero.life_id==life+1,"queued selection deploys",7): return
	var elapsed:=(Time.get_ticks_msec()-killed_at)*.001;measurements.queued_respawn_seconds=elapsed
	check(elapsed>=3.8 and elapsed<4.5,"queued respawn occurs after the authority interval rather than an indefinite menu wait")
	check(hero.war_class=="medic" and str(game.members[hero.peer_id].spawn)=="rally" and game.members[hero.peer_id].pending.is_empty(),"server applies the exact explicitly saved class and point once")
	if not await wait_for(func():return game.reports.has("queued-confirmed"),"native confirms resumed control"): return
	game.members[hero.peer_id].shield=0.;life=hero.life_id
	game._apply_hit(enemy.peer_id,{"collider":hero.hit_regions.chest,"position":hero.position},1000,"chest","glock",Vector3.FORWARD)
	phase("manual-death")
	var ready:=float(game.members[hero.peer_id].ready_at)
	if not await wait_for(func():return game.war_clock>=ready+.35,"manual readiness"): return
	check(hero.hp==0 and hero.life_id==life and not hero.deployed,"without an explicit saved choice the server waits for manual deployment")
	phase("manual-ready")
	if not await wait_for(func():return hero.hp==100 and hero.life_id==life+1,"manual deployment after wait"): return
	check(hero.war_class=="marksman" and hero.weapon_id=="sniper" and str(game.members[hero.peer_id].spawn)=="base","manual menu selection is applied instead of defaulting to a previous class")
	if not await wait_for(func():return game.reports.has("manual-confirmed"),"native confirms manual camera/input"): return
	phase("finish");await create_timer(.5).timeout
func hero_flow() -> void:
	var actor:=game.local_player as WarPlayer
	if not await wait_for(func():return game.phase=="save-choice","save choice phase"): return
	key(KEY_M);key(KEY_M,false)
	if not await wait_for(func():return game.war_ui.deployment.visible,"M opens real deployment menu"): return
	game.war_ui.class_select.select(0);game.war_ui._class_changed();game.war_ui.spawn_select.select(1)
	game.war_ui.deploy_button.pressed.emit()
	check(await wait_for(func():return str(game.members[actor.peer_id].get("pending",{}).get("role",""))=="medic","confirmed M choice"),"native menu receives authoritative confirmation of the next-life choice")
	check(game.war_ui.saved_deployment.visible or not game.members[actor.peer_id].pending.is_empty(),"saved choice is available to the matching HUD confirmation")
	game.close_deployment();game.rpc_id(1,"qa_report","choice-saved")
	if not await wait_for(func():return actor.hp==0,"queued death replicated"): return
	var life:=actor.life_id;var dead_at:=Time.get_ticks_msec()
	check(game.deployment_wait_left()>3.5 and not game.deployment_ready(),"client receives the server readiness deadline for this life")
	var selected:=actor.weapon_id;key(KEY_R);key(KEY_R,false);key(KEY_1);key(KEY_1,false);actor.equip_slot(4);game.remote_reload_started(actor.peer_id,selected,6,6,life,999)
	check(actor.weapon_id==selected and actor.reload_weapon.is_empty(),"dead native input and late reload presentation cannot change equipment")
	if DisplayServer.get_name()!="headless": check(game.death_view.active and not actor.camera.current,"death camera owns the initial cinematic interval")
	if not await wait_for(func():return game.war_ui.deployment.visible,"death menu after cinematic",4): return
	var menu_elapsed:=(Time.get_ticks_msec()-dead_at)*.001;measurements.death_menu_seconds=menu_elapsed
	check(menu_elapsed>2.6 and menu_elapsed<3.5 and game.deployment_wait_left()>0 and game.war_ui.deploy_button.disabled,"menu opens near three seconds and disables deployment until the server is ready")
	await create_timer(.22).timeout
	check(game.war_ui.feedback.text.contains("REIMPLANTAÇÃO EM") and game.war_ui.saved_deployment.text.contains("MÉDICO") and game.war_ui.saved_deployment.text.contains("LINHA AVANÇADA"),"visible countdown identifies the server-confirmed class and spawn during the remaining wait")
	await capture("waiting")
	if not await wait_for(func():return actor.hp==100 and actor.life_id==life+1 and actor.deployed,"queued spawn replicated",3): return
	check(actor.war_class=="medic" and game.gameplay_input_allowed() and not game.war_ui.deployment.visible,"saved M choice returns the player to combat with the selected class")
	check(game.third_person and actor.camera.current and not game.death_view.active and not actor.view_root.visible,"queued respawn restores the selected TPP camera without a lingering cinematic or FPP clone")
	await capture("queued-restored");game.rpc_id(1,"qa_report","queued-confirmed")
	if not await wait_for(func():return game.phase=="manual-ready","manual wait ends",7): return
	check(actor.hp==0 and game.war_ui.deployment.visible and game.deployment_ready(),"with no saved choice the ready player remains in a usable manual menu")
	game.war_ui.class_select.select(3);game.war_ui._class_changed();game.war_ui.spawn_select.select(0);game.war_ui.deploy_button.pressed.emit()
	if not await wait_for(func():return actor.hp==100 and actor.deployed and actor.war_class=="marksman","manual spawn replicated"): return
	check(actor.weapon_id=="sniper" and actor.camera.current and game.gameplay_input_allowed(),"manual sniper deployment restores the camera and gameplay controls")
	game.rpc_id(1,"qa_report","manual-confirmed")
	await wait_for(func():return game.phase=="finish","finish")
