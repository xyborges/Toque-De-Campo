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
func wait_for(test: Callable,label: String,seconds:=30.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	print("TIMEOUT ",role," ",label," phase ",game.phase," notice ",game.last_notice);failures.append(label);return false
func phase(id: String) -> void: game.phase=id;game._broadcast("qa_phase",[id])
func report(id: String) -> void: game.rpc_id(1,"qa_report",role+":"+id)
func press(actor: GamePlayer,value: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=value;actor._unhandled_input(event)
func run() -> void:
	game=load("res://tests/bugs186_network_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
	if role=="server": game.set_meta("war_host",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server()
	else:
		await game.join_game("pvp")
		var team:=0 if role=="alpha" else 1
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join"):
			game.request_deploy(team,"soldier",WarRules.primary_for("soldier",team)[0],WarRules.launcher_for_team(team),"base")
			if await wait_for(func():return game.local_player.deployed,"deploy"): await client()
	var result: Dictionary={"checks":checks,"failures":failures,"role":role};NavalStorage.write_json("res://tests/bugs186-network-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.5).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
	if not await wait_for(func():return game.members.size()==2 and game.members.values().all(func(s):return s.deployed),"deploy all",55): return
	var alpha: WarPlayer;var bravo: WarPlayer
	for actor: WarPlayer in game.players.values():
		if actor.name=="alpha": alpha=actor
		else: bravo=actor
	check(game.objective_states.values().all(func(s):return int(s.owner)==-1),"all five sectors start neutral")
	phase("magazines")
	if not await wait_for(func():return game.reports.has("alpha:magazines") and game.reports.has("bravo:magazines"),"full-magazine cycles",35): return
	for actor: WarPlayer in [alpha,bravo]:
		var weapon:=actor.weapon_id
		print("SERVER_MAGAZINES ",actor.name," ",actor.ammo," ",actor.reserves," reload ",actor.reload_weapon)
		check(actor.ammo[weapon]==GameWeapons.ITEMS[weapon].mag and actor.reserves[weapon]==CombatRules.weapon(weapon).reserve-GameWeapons.ITEMS[weapon].mag,"server completed full empty-magazine reload for "+weapon)
		check(actor.ammo.glock==9,"server accepted three separate rapid pistol shots")
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	var armor_before:=vehicle.hp;var stats_before: Dictionary=game.match_stats.rows[bravo.peer_id].duplicate()
	var feedback_before:=game.operation_sequence
	for weapon in ["fal","ak","glock","sniper","hmg","future_rifle"]: game.vehicle_system.damage_from_hit(bravo.peer_id,vehicle,1000,weapon,Vector3.LEFT)
	check(vehicle.hp==armor_before and game.match_stats.rows[bravo.peer_id]==stats_before and game.operation_sequence==feedback_before,"authority ignores infantry damage to armor without points, damage statistics or indicators")
	alpha.position=vehicle.position+Vector3(3,0,2);alpha.set_meta("fixture_freeze",true);game._broadcast("qa_pose",[alpha.peer_id,alpha.position,0.,0.])
	phase("board")
	if not await wait_for(func():return vehicle.driver==alpha.peer_id,"APC board"): return
	phase("apc-burst")
	if not await wait_for(func():return game.reports.has("alpha:apc"),"APC cycles",35): return
	print("APC_CYCLE ",vehicle.shot_sequence," ammo ",vehicle.ammo," reserve ",vehicle.reserve)
	check(vehicle.shot_sequence>=35 and vehicle.reserve<=100 and vehicle.ammo<=25,"authority fires APC through an empty belt, reload and weapon switches")
	var life:=alpha.life_id
	game.members[alpha.peer_id].shield=0;game.members[alpha.peer_id].spawn="base"
	game.vehicle_system.damage_from_hit(bravo.peer_id,vehicle,10000,"rpg",Vector3.LEFT)
	check(vehicle.destroyed and alpha.hp<=0 and game.members[alpha.peer_id].respawn_pending,"APC destruction records occupant death and schedules respawn")
	phase("destroyed")
	if not await wait_for(func():return alpha.life_id>life and alpha.hp>0,"8-second authority respawn",10): return
	check(alpha.position.distance_to(WarRules.BASES[0])<30 and alpha.vehicle_id.is_empty(),"authority respawns at selected base and releases vehicle")
	phase("after-death")
	if not await wait_for(func():return game.reports.has("alpha:respawn"),"client combat after respawn",14): return
	check(alpha.ammo.fal<20 and alpha.reload_weapon.is_empty(),"authority accepts FAL after APC death and completed reload")
	phase("done");await create_timer(.6).timeout
func client() -> void:
	var actor:=game.local_player as WarPlayer;var rifle:=actor.weapon_id
	actor.set_process_unhandled_input(false)
	game.vehicle_system.set_process_input(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not await wait_for(func():return game.phase=="magazines","magazines phase"): return
	game.third_person=true;actor.pitch=.35;actor.camera_pivot.rotation.x=.35
	press(actor,true);await create_timer(4.4 if rifle=="ak" else 3.4).timeout;press(actor,false)
	check(await wait_for(func():return int(actor.ammo[rifle])==0,"magazine empty",3),rifle+" reaches zero using one held press")
	actor.start_reload()
	check(await wait_for(func():return actor.reload_left>0,"reload starts",3),rifle+" reload begins at zero rounds")
	# Switch away and back while loading: resume the same authoritative reload.
	actor.equip_quick_slot(1);await create_timer(.25).timeout;actor.equip_quick_slot(2)
	check(await wait_for(func():return actor.reload_weapon.is_empty() and int(actor.ammo[rifle])==int(GameWeapons.ITEMS[rifle].mag),"reload completion",10),rifle+" resumes and completes after switching")
	actor.equip_quick_slot(1);await create_timer(.2).timeout
	for i in 3: actor.fire_cooldown=0;press(actor,true);press(actor,false);await create_timer(.23).timeout
	actor.equip_quick_slot(2);await create_timer(.3).timeout
	# Simulate a presentation left waiting for a completion acknowledgement.
	actor.reload_weapon=rifle;actor.reload_left=0.;actor.reload_total=6.
	check(await wait_for(func():return actor.reload_weapon.is_empty(),"stale reload recovery",3),rifle+" rechecks authority when its completion display is stale")
	actor.trigger_held=false
	print("CLIENT_MAGAZINES ",role," ",actor.ammo," ",actor.reserves," seq ",actor.shot_sequence)
	report("magazines")
	if role=="bravo": await wait_for(func():return game.phase=="done","end",80);return
	if not await wait_for(func():return game.phase=="board","boarding phase"): return
	game.vehicle_system.request_command("enter",{"id":"v_guarani"})
	if not await wait_for(func():return game.phase=="apc-burst" and actor.vehicle_id=="v_guarani","APC ready"): return
	var manager:=game.vehicle_system as WarVehicles;var vehicle:=manager.vehicles.v_guarani as WarVehicle
	await wait_for(func():return manager.last_controlled=="v_guarani","operator camera ready",4)
	manager.orbit_yaw=0;manager.orbit_pitch=.35;manager.aim_point=vehicle.position+Vector3(0,60,-200)
	manager.fire_held=true
	if not await wait_for(func():return vehicle.reload_left>0 and vehicle.ammo==0,"APC automatic reload",13):
		print("APC_DIAGNOSTIC ",vehicle.snapshot()," held ",manager.fire_held," input ",game.gameplay_input_allowed());return
	check(vehicle.reload_left>0,"APC starts loading when its 30-round belt empties")
	manager.fire_held=false;manager.request_command("weapon",{"slot":2});await create_timer(.3).timeout;manager.request_command("weapon",{"slot":1})
	if not await wait_for(func():return vehicle.reload_left<=0 and vehicle.ammo==30,"APC full again",9): return
	manager.fire_held=true
	check(await wait_for(func():return vehicle.ammo<=25,"APC sustained fire after reload",6),"APC fires five more rounds after reloading and changing weapons")
	manager.fire_held=false;game.drop_next_respawn=true;report("apc")
	if not await wait_for(func():return game.phase=="destroyed","vehicle destruction"): return
	check(await wait_for(func():return vehicle.destroyed,"destroyed snapshot",3) and vehicle.visible,"destroyed APC remains as visible wreck")
	var life:=actor.life_id;var before:=Time.get_ticks_msec()
	if not await wait_for(func():return actor.hp>0 and actor.life_id>life,"client respawn",11): return
	print("RESPAWN_SECONDS ",(Time.get_ticks_msec()-before)*.001)
	check(actor.position.distance_to(WarRules.BASES[0])<35 and actor.vehicle_id.is_empty(),"client returns to selected base instead of the death position")
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;actor.pitch=.3;actor.camera_pivot.rotation.x=.3
	await create_timer(.4).timeout;press(actor,true);await create_timer(.5).timeout;press(actor,false)
	actor.start_reload();await wait_for(func():return actor.reload_left>0,"post-death reload",3);await wait_for(func():return actor.reload_weapon.is_empty(),"post-death reload completion",8)
	press(actor,true);await create_timer(.4).timeout;press(actor,false);report("respawn")
	await wait_for(func():return game.phase=="done","done",8)
