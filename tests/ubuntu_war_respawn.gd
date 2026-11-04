extends SceneTree
var game: WarGame
var accounts: NavalAccounts
var role:="host"
var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}
const STAGE:="res://work/central163-respawn-stage.json"
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="): role=argument.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func wait_for(condition: Callable,seconds:=15.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())
func run() -> void:
	accounts=NavalAccounts.new();root.add_child(accounts)
	var credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var response: Dictionary=await accounts.sign_in("login",str(credentials[role].username),str(credentials[role].password))
	check(response.get("ok",false) and accounts.validated_session,"real central account signs in over validated TLS")
	if failures.is_empty():
		game=WarGame.new();game.accounts_service=accounts;root.add_child(game)
		check(await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.players.size()>=2),"both real accounts join the central War authority")
		if failures.is_empty():
			game.request_deploy(0 if role=="host" else 1,"soldier","fal","rpg","rally")
			check(await wait_for(func():return game.local_player.deployed and game._battle_active()),"both opposing teams deploy through ordinary server validation")
		if failures.is_empty():
			if role=="host": await host_flow()
			else: await guest_flow()
	if role=="host": NavalStorage.write_json(STAGE,{"finished":true,"failures":failures})
	var report: Dictionary={"checks":checks,"failures":failures,"measurements":measurements,"role":role,"test_bypass":false}
	NavalStorage.write_json("res://tests/ubuntu-war-respawn-"+role+".json",report);print(JSON.stringify(report))
	if is_instance_valid(game): game.show_menu();game.queue_free()
	await create_timer(.4).timeout;accounts.queue_free();quit(0 if failures.is_empty() else 1)
func host_flow() -> void:
	var actor:=game.local_player as WarPlayer
	game.third_person=true;actor._update_view();game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var before: Dictionary=await accounts.call_api("profile")
	check(before.get("ok",false),"profile counters are read before the real self-grenade death")
	if not before.get("ok",false): return
	var old: Dictionary=before.profile
	game.request_deploy(0,"medic","fal","rpg","rally")
	check(await wait_for(func():return str(game.members[actor.peer_id].get("pending",{}).get("role",""))=="medic"),"M's pending next-life class is confirmed by the production server")
	actor.equip_quick_slot(3);game.prime_grenade(actor)
	check(await wait_for(func():return not actor.grenade_held_id.is_empty()),"production authority primes an actual held grenade")
	var life:=actor.life_id;var begun:=Time.get_ticks_msec()
	check(await wait_for(func():return actor.hp==0,7),"the real five-second fuse kills the holding QA player")
	if actor.hp>0: return
	var died:=Time.get_ticks_msec();measurements.held_fuse_seconds=(died-begun)*.001
	await create_timer(.15).timeout
	check(game.war_ui.death_notice.visible and game.deployment_wait_left()>6.0 and game.deployment_wait_left()<=8.0,"production client shows the synchronized eight-second death notice")
	var weapon_before:=actor.weapon_id
	actor.equip_slot(4);actor.fire();actor.start_reload();game.vehicle_system.request_interact()
	check(actor.weapon_id==weapon_before and actor.reload_weapon.is_empty() and actor.vehicle_id.is_empty(),"production dead client blocks firing, equipment, reload and boarding")
	check(await wait_for(func():return actor.life_id==life+1 and actor.hp==100 and actor.deployed,11),"central authority applies the saved deployment on the next life")
	measurements.respawn_seconds=(Time.get_ticks_msec()-died)*.001
	check(float(measurements.respawn_seconds)>=7.9 and float(measurements.respawn_seconds)<9.0,"central respawn occurs at eight seconds within network/frame timing")
	check(actor.war_class=="medic" and str(game.members[actor.peer_id].get("spawn",""))=="rally","selected medic and rally are preserved after real death")
	check(actor.camera.current and game.third_person and not game.death_view.active and not actor.view_root.visible,"real respawn restores TPP and ends the death camera")
	var fresh: Dictionary={}
	for attempt in 5:
		var latest: Dictionary=await accounts.call_api("profile")
		if latest.get("ok",false): fresh=latest.profile
		if int(fresh.get("deaths",-1))>=int(old.deaths)+1: break
		await create_timer(.6).timeout
	check(int(fresh.get("deaths",-1))==int(old.deaths)+1,"one actual environment/self death persists exactly once in the central account")
	check(int(fresh.get("kills",-1))==int(old.kills) and int(fresh.get("coins",-1))==int(old.coins),"persisting a self death grants no kill or coins")
	NavalStorage.write_json(STAGE,{"finished":true,"failures":failures})
	await create_timer(1).timeout
func guest_flow() -> void:
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var other: WarPlayer
	for actor: WarPlayer in game.players.values():
		if not actor.is_local: other=actor
	check(is_instance_valid(other),"observer has the opposing QA player")
	if not is_instance_valid(other): return
	var life:=other.life_id
	check(await wait_for(func():return not is_instance_valid(other) or other.hp==0,14) and is_instance_valid(other),"observer receives the real death while the grenade stays at its owner")
	if not is_instance_valid(other) or other.hp>0: return
	check(await wait_for(func():return not is_instance_valid(other) or (other.hp==100 and other.life_id==life+1 and other.deployed),11) and is_instance_valid(other),"observer receives the same new life and deployed state")
	check(is_instance_valid(other) and other.war_class=="medic" and other.body_root.visible,"observer sees the restored body with the newly selected class")
	await wait_for(func():return NavalStorage.read_json(STAGE).get("finished",false),8)
