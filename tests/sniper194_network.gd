extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1;print(("PASS " if value else "FAIL ")+label)
	if not value: failures.append(label)
func wait_for(test: Callable,label: String,seconds:=30.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	failures.append("timeout "+label);print("FAIL timeout ",label);return false
func run() -> void:
	game=load("res://tests/bugs187_network_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
	if role=="server": game.set_meta("war_host",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server":
		if await wait_for(func():return game.members.size()==2 and game.members.values().all(func(s):return s.deployed),"both deployed",80):
			game._broadcast("qa_phase",["fire"])
			if await wait_for(func():return game.get("reports").has("shooter") and game.get("reports").has("observer"),"reload completed and observed",40):
				check(true,"server processed synchronized sniper reload for both clients")
				await runover_on_server()
			game._broadcast("qa_phase",["done"])
			await create_timer(.8).timeout
	else:
		await game.join_game("pvp")
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join",60):
			var team:=0 if role=="shooter" else 1
			game.request_deploy(team,"marksman" if role=="shooter" else "soldier","sniper" if role=="shooter" else "ak",WarRules.launcher_for_team(team),"base")
			if await wait_for(func():return game.local_player.deployed and game.get("phase")=="fire","deploy",50):
				game.ui_focus.close_all()
				if role=="shooter":
					var actor:=game.local_player as WarPlayer
					actor.pitch=.3;actor.camera_pivot.rotation.x=.3;actor.fire()
					if await wait_for(func():return int(actor.ammo.sniper)<5,"shot consumed",5):
						actor.start_reload()
						check(await wait_for(func():return actor.reload_left>0,"reload started",5),"client receives server reload")
						check(await wait_for(func():return actor.reload_weapon.is_empty() and int(actor.ammo.sniper)==5,"reload completed",10),"server reloads exactly five rounds")
						game.rpc_id(1,"qa_report","shooter")
				else:
					var remote: WarPlayer
					for actor: WarPlayer in game.players.values():
						if actor!=game.local_player: remote=actor
					if is_instance_valid(remote) and await wait_for(func():return remote.weapon_id=="sniper" and remote.reload_left>0,"observer receives reload",15):
						var initial:=remote._sniper_hand_target(true)
						var moved:=0.
						while remote.reload_left>0:
							remote._update_weapon_pose();moved=maxf(moved,remote._sniper_hand_target(true).distance_to(initial));await process_frame
						check(moved>.12,"remote sniper hand follows replicated reload")
						game.rpc_id(1,"qa_report","observer")
				if role=="observer":
					check(await wait_for(func():return game.local_player.hp<=0,"runover death replicated",20),"other client receives the authoritative runover death")
					game.rpc_id(1,"qa_report","runover-observed")
				await wait_for(func():return game.get("phase")=="done","test end",30)
	var result: Dictionary={"role":role,"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/sniper194-network-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)

func runover_on_server() -> void:
	var driver: WarPlayer
	var victim: WarPlayer
	for actor: WarPlayer in game.players.values():
		if actor.name=="shooter": driver=actor
		elif actor.name=="observer": victim=actor
	if not is_instance_valid(driver) or not is_instance_valid(victim): failures.append("missing runover participants");return
	game.vehicle_system.set_physics_process(false)
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	var ground:=StaticBody3D.new();ground.collision_layer=1;var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(50,.5,50);collider.shape=box;ground.position=Vector3(0,199.75,0);ground.add_child(collider);game.world_root.add_child(ground)
	vehicle.global_position=Vector3(0,200,0);vehicle.heading=0;vehicle.rotation=Vector3.ZERO;vehicle.speed=9.
	driver.set_meta("fixture_freeze",true);victim.set_meta("fixture_freeze",true)
	driver.global_position=Vector3(8,200,8);victim.global_position=Vector3(0,200,-4);victim.velocity=Vector3.ZERO
	vehicle.allocate_seat(driver.peer_id);driver.vehicle_id=vehicle.vehicle_id;game.members[driver.peer_id].vehicle=vehicle.vehicle_id;game.members[victim.peer_id].shield=0.
	await physics_frame;await physics_frame
	for i in 60:
		vehicle.simulate(1./60.,{"throttle":1.,"steer":0.,"aim":vehicle.aim_target});await physics_frame
		if victim.hp<=0: break
	check(victim.hp<=0 and victim.last_impact_weapon=="runover","network authority handles a real fast vehicle collision")
	check(await wait_for(func():return game.get("reports").has("runover-observed"),"client sees runover",12),"runover death reached the other client")
