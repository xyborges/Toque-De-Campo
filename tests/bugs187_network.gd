extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
var rtt: Array[float]=[]
var frame_ms: Array[float]=[]
var last_frame:=0
var last_ping:=0
func _process(_delta: float) -> bool:
	var now:=Time.get_ticks_usec()
	if is_instance_valid(game) and game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed:
		if last_frame>0: frame_ms.append((now-last_frame)*.001)
		if now>last_ping and not game.multiplayer.is_server():
			last_ping=now+500000
			var peer: ENetPacketPeer=(game.multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
			if peer: rtt.append(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	last_frame=now
	return false
func stat(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted:=values.duplicate();sorted.sort();var sum:=0.
	for v in sorted: sum+=v
	return {"n":sorted.size(),"mean":sum/sorted.size(),"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max":sorted[-1]}
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
	print("TIMEOUT ",role," ",label," phase ",game.phase," notice ",game.last_notice)
	if is_instance_valid(game.local_player):
		var a:=game.local_player
		print("LOCAL_STATE ",{"hp":a.hp,"life":a.life_id,"vehicle":a.vehicle_id,"weapon":a.weapon_id,"ammo":a.ammo,"reserves":a.reserves,"reload":a.reload_weapon,"left":a.reload_left,"revision":a.authoritative_reload_revision,"gadget":a.gadget_equipped,"camera":str(root.get_camera_3d()),"current":a.camera.current})
	failures.append(label);return false
func phase(id: String) -> void: game.phase=id;game._broadcast("qa_phase",[id])
func report(id: String) -> void: game.rpc_id(1,"qa_report",role+":"+id)
func press(actor: GamePlayer,value: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=value;actor._unhandled_input(event)
func cycle(actor: WarPlayer,weapon: String,label: String) -> void:
	actor.equip_slot(["broom","squeegee","axe","ak","glock","sniper","fal"].find(weapon));await wait_for(func():return actor.weapon_id==weapon,"equip "+weapon,3)
	await create_timer(.25).timeout
	press(actor,true);await create_timer(.4).timeout;press(actor,false)
	if weapon=="glock":
		await create_timer(.25).timeout;press(actor,true);press(actor,false)
	var before:=int(actor.ammo.get(weapon,0))
	check(before<int(GameWeapons.ITEMS[weapon].mag),label+" fires "+weapon)
	actor.start_reload()
	check(await wait_for(func():return actor.reload_left>0,label+" reload begins "+weapon,3),label+" reload request accepted "+weapon)
	check(await wait_for(func():return actor.reload_weapon.is_empty() and int(actor.ammo.get(weapon,0))==int(GameWeapons.ITEMS[weapon].mag),label+" reload finishes "+weapon,9),label+" reload completes "+weapon)
func run() -> void:
	game=load("res://tests/bugs187_network_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
	if role=="server": game.set_meta("war_host",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server()
	else:
		await game.join_game("pvp")
		var team:=1 if role=="alpha" else 0
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join",55):
			game.request_deploy(team,"soldier",WarRules.primary_for("soldier",team)[0],WarRules.launcher_for_team(team),"base")
			if await wait_for(func():return game.local_player.deployed,"deploy"): await client()
	var result: Dictionary={"checks":checks,"failures":failures,"role":role,"rtt_ms":stat(rtt),"frame_ms":stat(frame_ms)};NavalStorage.write_json("res://tests/bugs187-network-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.5).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
	if not await wait_for(func():return game.members.size()==2 and game.members.values().all(func(s):return s.deployed),"deploy all",65): return
	var pilot: WarPlayer;var enemy: WarPlayer
	for actor: WarPlayer in game.players.values():
		if actor.name=="alpha": pilot=actor
		else: enemy=actor
	phase("initial")
	if not await wait_for(func():return game.reports.has("alpha:initial") and game.reports.has("bravo:initial"),"both teams reload",35): return
	check(game.pose_relays>10,"validated infantry poses are relayed immediately to observers")
	phase("drone")
	if not await wait_for(func():return pilot.vehicle_id.begins_with("drone_"),"launch drone"): return
	var drone:=game.vehicle_system.drones[pilot.vehicle_id] as WarDrone
	check(pilot.reload_weapon.is_empty() and pilot.reload_left<=0,"launch cancels the server reload before remote-control physics stops")
	drone.position=pilot.position+Vector3(25,12,0)
	await create_timer(.4).timeout
	game.members[pilot.peer_id].shield=0
	var before:=pilot.hp
	game._apply_hit(enemy.peer_id,{"collider":pilot.hit_regions.chest,"position":pilot.position},10,"chest","glock",Vector3.LEFT)
	check(pilot.hp<before,"body remains vulnerable while operating a drone")
	check(pilot.vehicle_id.is_empty() and drone.driver==0,"body damage interrupts remote control")
	check(drone.falling,"interrupted drone enters replicated free fall")
	phase("after-drone")
	if not await wait_for(func():return game.reports.has("alpha:after-drone"),"combat after drone",30): return
	var life:=pilot.life_id
	game._apply_hit(enemy.peer_id,{"collider":pilot.hit_regions.chest,"position":pilot.position},1000,"chest","ak",Vector3.LEFT)
	if not await wait_for(func():return pilot.life_id>life and pilot.hp>0,"respawn after drone",11): return
	var vehicle:=game.vehicle_system.vehicles.v_bmp2 as WarVehicle
	pilot.position=vehicle.position+Vector3(3,0,2);pilot.set_meta("fixture_freeze",true);game._broadcast("qa_pose",[pilot.peer_id,pilot.position,0.,0.])
	phase("board")
	if not await wait_for(func():return vehicle.driver==pilot.peer_id,"APC board"): return
	phase("apc")
	if not await wait_for(func():return game.reports.has("alpha:apc"),"APC fire",15): return
	check(vehicle.shot_sequence>=5,"APC emits authoritative projectiles after drone and respawn")
	phase("tv")
	if not await wait_for(func():return game.vehicle_system.tv.has_flight(vehicle.vehicle_id),"TV launch",6): return
	var missile_id: String=game.vehicle_system.tv.flights.keys()[0]
	await create_timer(.6).timeout
	var missile: Dictionary=game.war_fx.find_round(missile_id)
	var point: Vector3=missile.position
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3(4,0,0),point-Vector3(4,0,0),CombatRules.SHOT_MASK);query.collide_with_areas=true
	var contact:=game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not contact.is_empty() and contact.collider.has_meta("tv_shot_id"),"authority exposes the in-flight TV missile to projectile contact")
	game._confirm_impact(enemy.peer_id,contact,{"id":"fal","damage":62.},"qa-network-tv-intercept",Vector3.LEFT)
	check(not missile.active,"authority destroys TV missile on a validated physical hit")
	phase("tv-intercepted")
	if not await wait_for(func():return game.reports.has("alpha:tv") and game.reports.has("bravo:tv"),"TV result on both clients",8): return
	life=pilot.life_id
	game.vehicle_system.damage_from_hit(enemy.peer_id,vehicle,10000,"rpg",Vector3.LEFT)
	phase("dead-in-apc")
	if not await wait_for(func():return pilot.life_id>life and pilot.hp>0,"APC respawn",11): return
	phase("respawn")
	if not await wait_for(func():return game.reports.has("alpha:respawn"),"post APC combat",30): return
	phase("done");await create_timer(.5).timeout
func client() -> void:
	var actor:=game.local_player as WarPlayer;var rifle:=actor.weapon_id
	actor.set_process_unhandled_input(false);game.vehicle_system.set_process_input(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await wait_for(func():return game.phase=="initial","initial")
	game.third_person=true;actor.pitch=.35;actor.camera_pivot.rotation.x=.35
	await cycle(actor,rifle,"initial team "+str(actor.war_team+1));await cycle(actor,"glock","initial team "+str(actor.war_team+1));report("initial")
	if role=="bravo":
		if await wait_for(func():return game.phase=="tv","TV observer phase",70):
			check(await wait_for(func():return not game.vehicle_system.tv.flights.is_empty(),"remote TV appears",5),"observer receives the same real TV missile")
			await wait_for(func():return game.phase=="tv-intercepted","TV observer intercept",5)
			check(await wait_for(func():return game.vehicle_system.tv.flights.is_empty(),"remote TV disappears",3),"observer removes the intercepted missile")
			report("tv")
		await wait_for(func():return game.phase=="done","end",55);return
	await wait_for(func():return game.phase=="drone","drone phase")
	actor.equip_slot(["broom","squeegee","axe","ak","glock","sniper","fal"].find(rifle));await create_timer(.3).timeout;press(actor,true);await create_timer(.4).timeout;press(actor,false);actor.start_reload()
	await wait_for(func():return actor.reload_left>0,"reload before drone",3)
	game.vehicle_system.request_command("drone",{})
	await wait_for(func():return actor.vehicle_id.begins_with("drone_"),"drone control",4)
	await wait_for(func():return game.phase=="after-drone","drone damaged",5)
	# Also permit explicit exit so the old broken build can complete diagnosis.
	if not actor.vehicle_id.is_empty(): game.vehicle_system.request_command("exit",{})
	await wait_for(func():return actor.vehicle_id.is_empty(),"return from drone",4)
	await cycle(actor,rifle,"after drone");await cycle(actor,"glock","after drone");report("after-drone")
	await wait_for(func():return game.phase=="board","board phase",14)
	check(actor.camera.current and actor.camera.global_position.distance_to(actor.position)<6,"respawn restores player camera after drone")
	game.vehicle_system.request_command("enter",{"id":"v_bmp2"})
	await wait_for(func():return game.phase=="apc" and game.vehicle_system.last_controlled=="v_bmp2","APC ready",5)
	var manager:=game.vehicle_system as WarVehicles;var vehicle:=manager.vehicles.v_bmp2 as WarVehicle
	manager.orbit_yaw=0;manager.orbit_pitch=.35;manager.aim_point=vehicle.position+Vector3(0,60,-200);manager.fire_held=true
	check(await wait_for(func():return vehicle.ammo<=25,"APC bullets",8),"APC actually consumes ammunition and emits bullets")
	manager.fire_held=false;report("apc")
	await wait_for(func():return game.phase=="tv","TV pilot phase",5)
	manager.request_command("weapon",{"slot":2});await create_timer(.3).timeout;manager.fire_held=true
	check(await wait_for(func():return manager.tv.viewing(),"TV camera opens",4),"operator camera follows the launched TV missile")
	manager.fire_held=false
	await wait_for(func():return game.phase=="tv-intercepted","TV destroyed",5)
	check(await wait_for(func():return not manager.tv.viewing() and manager.tv.flights.is_empty(),"TV camera closes",3),"interception ends guidance without losing the APC operator seat")
	manager.request_command("weapon",{"slot":1});report("tv")
	await wait_for(func():return game.phase=="dead-in-apc","APC death",5)
	var life:=actor.life_id
	await wait_for(func():return game.phase=="respawn" and actor.hp>0 and actor.life_id>life,"APC respawn",12)
	await create_timer(.3).timeout
	check(actor.camera.current and root.get_camera_3d()==actor.camera,"APC death returns the active viewport to player camera")
	check(actor.position.distance_to(WarRules.BASES[1])<35 and actor.vehicle_id.is_empty(),"team 2 returns to selected base")
	await cycle(actor,rifle,"after APC death");await cycle(actor,"glock","after APC death");report("respawn")
	await wait_for(func():return game.phase=="done","done",5)

