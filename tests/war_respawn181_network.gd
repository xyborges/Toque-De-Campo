extends SceneTree
var game: WarGame
var role:="server"
var failures: Array[String]=[]
var checks:=0
var measurements: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func wait_for(condition: Callable,label_text: String,seconds:=25.0) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if condition.call(): return true
		await process_frame
	check(false,"timeout: "+label_text);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func run() -> void:
	Engine.max_fps=60
	game=load("res://tests/war_respawn181_fixture.gd").new()
	game.set_meta("war_host",role=="server");game.set_meta("war_test",true);game.set_meta("test_mode",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	elif await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed,"client deployed",65):
		game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if role=="hero": await hero_flow()
		else: await observer_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures,"measurements":measurements,"network":"ENet localhost, actual authority and two clients"}
	NavalStorage.write_json("res://work/respawn181/network-"+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2,"two ENet clients join",65): return
	var hero: WarPlayer;var enemy: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="hero": hero=actor
		else: enemy=actor
	check(game._deploy(hero.peer_id,0,"marksman","sniper","stinger","base"),"deploy marksman")
	check(game._deploy(enemy.peer_id,1,"soldier","fal","rpg","base"),"deploy opposing player")
	phase("ready")
	if not await wait_for(func():return game.reports.has("initial-ready"),"client ready"): return
	var manager:=game.vehicle_system as WarVehicles
	var vehicle:=manager.vehicles.v_guarani as WarVehicle
	var life:=hero.life_id
	game.members[hero.peer_id].shield=0.0
	var death_at:=Time.get_ticks_msec()
	game._apply_hit(enemy.peer_id,{"collider":hero.hit_regions.chest,"position":hero.global_position},1000,"chest","fal",Vector3.FORWARD)
	phase("dead")
	check(hero.hp==0 and not hero.deployed and bool(game.members[hero.peer_id].respawn_pending),"real damage schedules authoritative respawn")
	if not await wait_for(func():return game.reports.has("dead-checks"),"client death HUD and forged requests",6): return
	check(hero.hp==0 and hero.life_id==life and hero.weapon_id=="sniper" and hero.reload_weapon.is_empty(),"authority rejects equipment, reload and early deploy while dead")
	check(hero.vehicle_id.is_empty() and vehicle.seat_of(hero.peer_id)<0,"authority rejects dead player's vehicle entry")
	check(not game.war_fx.rounds.any(func(shot):return not shot.is_empty() and shot.get("active",false) and int(shot.get("owner",-1))==hero.peer_id),"authority rejects dead player's shot request")
	if not await wait_for(func():return hero.hp==100 and hero.life_id==life+1 and hero.deployed,"automatic online respawn",10): return
	var elapsed:=(Time.get_ticks_msec()-death_at)*.001;measurements.respawn_seconds=elapsed
	check(elapsed>=8.0-1.0/60.0 and elapsed<9.0,"online respawn follows eight real seconds within one physics tick")
	check(hero.war_class=="marksman" and hero.weapon_id=="sniper" and str(game.members[hero.peer_id].spawn)=="base","no M-menu selection preserves previous class, weapon and spawn")
	phase("respawned")
	if not await wait_for(func():return game.reports.has("restored"),"client restored camera and UI"): return
	if not await wait_for(func():return game.reports.has("observer-restored"),"observer sees respawn"): return
	# A delayed previous-life damage packet must not restart the new life timer.
	phase("done");await create_timer(.5).timeout
func hero_flow() -> void:
	var actor:=game.local_player as WarPlayer
	game.third_person=true;actor._update_view()
	actor.iron_sights=true;actor.aiming=true;actor._update_view()
	game.rpc_id(1,"qa_report","initial-ready")
	if not await wait_for(func():return actor.hp<=0,"death replicates"): return
	await create_timer(.15).timeout
	check(game.war_ui.death_notice.visible and game.war_ui.death_notice_text.text=="VOCÊ MORREU","online client shows the death notice")
	measurements.initial_countdown=game.deployment_wait_left()
	check(game.deployment_wait_left()>6.8 and game.deployment_wait_left()<=8.0,"client receives the server's eight-second deadline")
	check(not actor.iron_sights and not actor.aiming and not actor.view_root.visible,"death clears sniper scope and first-person presentation")
	check(not game.gameplay_input_allowed(),"dead client cannot use ordinary gameplay controls")
	var old_weapon:=actor.weapon_id;var old_position:=actor.global_position
	actor.equip_slot(3);actor.equip_quick_slot(1);actor.fire();actor.start_reload();game.vehicle_system.request_interact()
	check(actor.weapon_id==old_weapon and actor.reload_weapon.is_empty() and actor.vehicle_id.is_empty(),"local dead weapon/reload/vehicle actions remain blocked")
	game.rpc_id(1,"server_equip","fal")
	game.rpc_id(1,"server_reload_request","sniper")
	game.vehicle_system.rpc_id(1,"command","enter",{"id":"v_guarani"})
	game.rpc_id(1,"server_shot_request",10000,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,"sniper",0)
	game.request_deploy(0,"marksman","sniper","stinger","base")
	var yaw_before:=actor.yaw
	if DisplayServer.get_name()!="headless":
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(110,-30);Input.parse_input_event(motion)
		await process_frame
		check(not is_equal_approx(actor.yaw,yaw_before),"native mouse input rotates the dead player's camera")
	else:
		actor._apply_dead_camera_look(Vector2(110,-30))
		check(not is_equal_approx(actor.yaw,yaw_before),"dead camera look math remains active")
	await create_timer(.3).timeout
	check(actor.global_position.distance_to(old_position)<.01 and actor.velocity==Vector3.ZERO,"dead client remains at the death position while looking around")
	check(actor.camera.current and not game.death_view.active,"player camera stays current during the wait")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/respawn181/death-notice.png")
	game.rpc_id(1,"qa_report","dead-checks")
	var life:=actor.life_id
	if not await wait_for(func():return actor.hp==100 and actor.life_id==life+1 and actor.deployed,"client automatically respawns",11): return
	await create_timer(.2).timeout
	check(not game.war_ui.death_notice.visible and not game.war_ui.deployment.visible,"respawn dismisses death notice and deployment screen")
	check(actor.camera.current and not game.death_view.active and game.third_person and not actor.view_root.visible,"respawn restores TPP without scope or first-person arms")
	check(actor.war_class=="marksman" and actor.weapon_id=="sniper","client restores the correct weapon and class")
	if DisplayServer.get_name()!="headless":
		var previous_vehicle:=actor.vehicle_id
		actor.vehicle_id="v_guarani"
		var previous_orbit: float=game.vehicle_system.orbit_yaw
		var vehicle_motion:=InputEventMouseMotion.new();vehicle_motion.relative=Vector2(70,0)
		game._input(vehicle_motion)
		check(not is_equal_approx(game.vehicle_system.orbit_yaw,previous_orbit),"alive vehicle camera retains ordinary mouse input routing")
		actor.vehicle_id=previous_vehicle
	game.rpc_id(1,"qa_report","restored")
	await wait_for(func():return game.phase=="done","completion")
func observer_flow() -> void:
	var other: WarPlayer
	for actor: WarPlayer in game.players.values():
		if not actor.is_local: other=actor
	if not await wait_for(func():return is_instance_valid(other) and other.hp<=0,"observer receives death"): return
	var life:=other.life_id
	check(not other.deployed,"observer sees the player as dead and undeployed")
	if not await wait_for(func():return other.hp==100 and other.life_id==life+1 and other.deployed,"observer receives automatic respawn",11): return
	check(other.war_class=="marksman" and other.weapon_id=="sniper" and other.body_root.visible,"observer sees restored body, class and weapon")
	game.rpc_id(1,"qa_report","observer-restored")
	await wait_for(func():return game.phase=="done","completion")
