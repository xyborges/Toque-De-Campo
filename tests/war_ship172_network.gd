extends SceneTree
var role:="server"
var game: WarGame
var failures: Array[String]=[]
var checks:=0
var measurements: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(value: bool,text: String) -> void:
	checks+=1;print(("PASS " if value else "FAIL ")+text)
	if not value: failures.append(text)
func wait_for(condition: Callable,label: String,seconds:=18.) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		await process_frame
		if condition.call(): return true
	failures.append("timeout: "+label);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func run() -> void:
	game=load("res://tests/war_ship172_fixture.gd").new();game.set_meta("war_host",role=="server");game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server()
	elif await wait_for(func():return game.join_ready and game.local_player and game.local_player.deployed,"deployment",40): await client()
	var report:={"role":role,"checks":checks,"failures":failures,"measurements":measurements}
	FileAccess.open("res://tests/war-ship172-network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify(report));print(JSON.stringify(report));game.show_menu();game.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
	if not await wait_for(func():return game.players.size()==3,"three clients",45): return
	var actors: Dictionary={}
	for actor: WarPlayer in game.players.values(): actors[str(actor.name)]=actor
	for label in ["operator","enemy","passenger"]:
		var a:=actors[label] as WarPlayer
		check(game._deploy(a.peer_id,1 if label=="enemy" else 0,"soldier","fal","rpg","base"),"balanced team deployment "+label)
	await create_timer(.5).timeout
	var ship:=game.vehicle_system.vehicles.v_naval_assault_0 as WarShip
	var swimmer:=actors.enemy as WarPlayer
	var water_start:=Vector3(-1150,-.85,-485)
	swimmer.global_position=water_start;swimmer.velocity=Vector3.ZERO;swimmer.set_meta("fixture_warp_point",water_start)
	game._broadcast("qa_pose",[swimmer.peer_id,water_start,0.,0.])
	var swimmer_ammo:=int(swimmer.ammo.fal)
	phase("swimming")
	if not await wait_for(func():return game.reports.has("swimming"),"remote swimming"): return
	check(swimmer.in_water() and swimmer.global_position.distance_to(water_start)>1.,"authority receives actual swimming movement")
	check(int(swimmer.ammo.fal)==swimmer_ammo and swimmer.reload_weapon.is_empty(),"authority rejects remote firearm and reload commands in water")
	for label in ["operator","passenger"]:
		var actor:=actors[label] as WarPlayer;var at:=ship.global_position+Vector3(-2 if label=="operator" else 2,2.9,6.4)
		actor.position=at;actor.velocity=Vector3.ZERO;actor.set_meta("fixture_warp_point",at);game._broadcast("qa_pose",[actor.peer_id,at,0.,0.])
	phase("operator-board")
	if not await wait_for(func():return ship.driver==actors.operator.peer_id,"operator aboard"): return
	phase("passenger-board")
	if not await wait_for(func():return ship.seat_of(actors.passenger.peer_id)==1,"passenger aboard"): return
	check(ship.seats.size()==2,"independent clients occupy different server seats")
	phase("passenger-input")
	if not await wait_for(func():return game.reports.has("passenger-input"),"forged passenger controls rejected"): return
	check(not game.vehicle_system.controls.has(actors.passenger.peer_id),"passenger cannot command the hull or weapons")
	var origin:=ship.global_position;var ammo:=ship.ammo
	phase("drive")
	await create_timer(2.6).timeout
	measurements.drive={"speed":ship.speed,"from":str(origin),"to":str(ship.global_position),"controls":str(game.vehicle_system.controls),"driver":ship.driver,"epoch":ship.control_epoch,"ammo":ship.ammo,"blocked":ship.gun_blocked}
	check(ship.global_position.distance_to(origin)>3,"real remote throttle moves the hull continuously")
	check(ship.ammo<ammo,"remote operator fires real naval rounds")
	phase("stop")
	await create_timer(.55).timeout
	var remaining:=ship.ammo;await create_timer(.4).timeout
	check(ship.ammo==remaining,"releasing the remote trigger stops naval fire")
	# Capture does not transfer an occupied vessel to a second operator.
	game.objective_states.D.owner=1;game.vehicle_system._step_port_control()
	check(ship.team==0 and ship.driver==actors.operator.peer_id,"port capture preserves current occupants")
	var enemy:=actors.enemy as WarPlayer;var before:=game.multi_kill_count(enemy.peer_id)
	game.vehicle_system.explode(enemy.peer_id,ship.global_position+Vector3.UP*1.2,10000,12,"tank","ship172-multikill",{"collider":ship,"position":ship.global_position,"normal":Vector3.UP})
	check(actors.operator.hp==0 and actors.passenger.hp==0,"ship destruction kills every transported player")
	check(game.multi_kill_count(enemy.peer_id)==before+2,"one explosion credits both deaths once")
	check(game.multi_kill_events.has("ship172-multikill"),"one authoritative multikill notice groups the explosion")
	phase("destroyed")
	if not await wait_for(func():return game.reports.has("dead"),"replicated crew death"): return
	game.vehicle_system._step_vehicle_respawns(60.1)
	check(not ship.destroyed and ship.seats.is_empty() and ship.hp==float(ship.spec.hp),"destroyed ship respawns empty after60seconds")
	game.vehicle_system._step_port_control();check(ship.team==1,"replacement ship belongs to the team controlling its port")
	phase("finish");await create_timer(.4).timeout
func client() -> void:
	var manager:=game.vehicle_system as WarVehicles;var actor:=game.local_player as WarPlayer;var ship:=manager.vehicles.v_naval_assault_0 as WarShip
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# This scenario sends explicit control RPCs. Disable the keyboard-neutral
	# sender so it cannot interleave a second command stream with this harness.
	manager.set_physics_process(false)
	var seen: Dictionary={};var sequence:=100;var elapsed:=0.;var previous:=ship.global_position;var zero_frames:=0;var moving_frames:=0;var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<80000:
		await process_frame
		var phase_value:=str(game.phase)
		if phase_value=="finish":
			measurements.moving_frames=moving_frames;measurements.stationary_frames=zero_frames;return
		if phase_value=="drive":
			var step:=ship.global_position.distance_to(previous)
			if ship.speed>1:
				moving_frames+=1
				if step<.0001: zero_frames+=1
			if role=="operator":
				elapsed+=root.get_process_delta_time()
				if elapsed>.05:
					elapsed=0;sequence+=1
					manager.rpc_id(1,"control",sequence,{"throttle":1.,"steer":0.,"aim":ship.global_position-ship.global_basis.z*400+Vector3.UP*3,"fire":true,"occupancy":ship.control_epoch,"vehicle":ship.vehicle_id,"life":actor.life_id})
		previous=ship.global_position
		if seen.has(phase_value): continue
		seen[phase_value]=true
		if phase_value=="swimming" and role=="enemy":
			Input.action_press("move_forward");await create_timer(.8).timeout;Input.action_release("move_forward")
			check(actor.in_water() and actor.swimming and not actor.weapon_root.visible,"remote player swims with weapons hidden")
			game.rpc_id(1,"server_shot_request",88,actor.life_id,actor.camera.global_position,Vector3.FORWARD,"fal",0)
			game.rpc_id(1,"server_reload_request","fal")
			await create_timer(.2).timeout;game.rpc_id(1,"qa_report","swimming")
		elif phase_value=="operator-board" and role=="operator": manager.rpc_id(1,"command","enter",{"id":ship.vehicle_id})
		elif phase_value=="passenger-board" and role=="passenger": manager.rpc_id(1,"command","enter",{"id":ship.vehicle_id})
		elif phase_value=="passenger-input" and role=="passenger":
			manager.rpc_id(1,"control",999,{"throttle":1.,"steer":1.,"aim":Vector3(0,80,0),"fire":true,"occupancy":ship.control_epoch,"vehicle":ship.vehicle_id,"life":actor.life_id});await create_timer(.2).timeout;game.rpc_id(1,"qa_report","passenger-input")
		elif phase_value=="stop":
			check(moving_frames>20 and zero_frames<maxi(2,moving_frames/5),"client ship advances between snapshots instead of stepping by packets")
			if role=="operator": sequence+=1;manager.rpc_id(1,"trigger",sequence,false,ship.control_epoch,ship.vehicle_id,actor.life_id)
		elif phase_value=="destroyed" and role=="passenger":
			check(await wait_for(func():return actor.hp<=0 and ship.seats.is_empty(),"crew death"),"native passenger receives destruction and cleared seats");game.rpc_id(1,"qa_report","dead")
	failures.append("client scenario timed out")

