extends SceneTree
const FIXTURE=preload("res://tests/equipment_network_fixture.gd")
var role:="server"
var game: WarGame
var checks:=0
var errors: Array[String]=[]
var ship_steps: Array[float]=[]
var ship_previous:=Vector3.INF
var ship_clock:=0.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: errors.append(label);print("FAIL ",role," ",label)
func wait_for(test: Callable,label: String,seconds:=90.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	check(false,"timeout: "+label);return false
func phase(token: String) -> void:
	game.phase=token;game._broadcast("qa_phase",[token]);print("NETWORK_PHASE ",token)
func reported(id: int,token: String) -> bool: return game.records.has(str(id)+":"+token)
func send_result(token: String,before: int) -> void:
	game.rpc_id(1,"qa_result",token,{"ok":errors.size()==before,"errors":errors.slice(before)})
func verify_result(id: int,token: String) -> void:
	check(bool(game.records.get(str(id)+":"+token,{}).get("ok",false)),"client result "+token)
func stage_and_deploy(id: int,role_name: String,scope: bool) -> void:
	var actor:=game.players[id] as WarPlayer
	actor.hp=0;actor.deployed=false;game.members[id].ready_at=0.
	var team:=int(game.members[id].team);var loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,role_name,team)
	if scope: loadout.optic="scope4x"
	check(game._deploy(id,team,role_name,str(loadout.primary),WarRules.launcher_for_team(team),"base",loadout),"authority deploys "+role_name)
func server_flow() -> void:
	if not await wait_for(func():return game.clients.has("first"),"first joins"): return
	var first:=int(game.clients.first)
	game.members[first].team=0;stage_and_deploy(first,"soldier",true)
	phase("first-scope")
	if not await wait_for(func():return reported(first,"first-scope"),"first physical optic"): return
	verify_result(first,"first-scope")
	NavalStorage.write_json("res://work/equipment-network-first-ready.json",{"ready":true})
	if not await wait_for(func():return game.clients.has("late"),"late client joins"): return
	var late:=int(game.clients.late);game.members[late].team=1;stage_and_deploy(late,"soldier",true)
	phase("late-scopes")
	if not await wait_for(func():return reported(first,"late-scopes") and reported(late,"late-scopes"),"late baseline and own optics"): return
	verify_result(first,"late-scopes");verify_result(late,"late-scopes")
	stage_and_deploy(first,"marksman",false);game.vehicle_system._set_utility(first,"binoculars")
	phase("binoculars")
	if not await wait_for(func():return game.players[first].utility_zoom==1,"zoom command accepted"): return
	if not await wait_for(func():return reported(first,"binoculars") and reported(late,"binoculars"),"both see binoculars"): return
	verify_result(first,"binoculars");verify_result(late,"binoculars")
	game.vehicle_system._set_utility(first,"");stage_and_deploy(first,"soldier",true)
	var bike: WarVehicle=game.vehicle_system.vehicles.v_bike_0_0
	var actor:=game.players[first] as WarPlayer
	var point:=bike.position+Vector3(1.8,.3,0)
	actor.position=point;actor.velocity=Vector3.ZERO;game._broadcast("qa_pose",[first,point,0.,0.])
	phase("bike-enter")
	if not await wait_for(func():return bike.driver==first,"native motorcycle entry"): return
	var start:=bike.position
	phase("bike-drive")
	if not await wait_for(func():return bike.position.distance_to(start)>12.,"motorcycle moves",20.): return
	phase("bike-exit")
	if not await wait_for(func():return actor.vehicle_id.is_empty() and bike.driver==0,"motorcycle safe exit"): return
	if not await wait_for(func():return reported(first,"bike-exit") and reported(late,"bike-exit"),"seat and body state observed"): return
	verify_result(first,"bike-exit");verify_result(late,"bike-exit")
	# Scripted authority autopilot: reservation/snapshots remain production
	# code. Boarding at sea is not under test in this scenario.
	var ship:=game.vehicle_system.vehicles.v_naval_assault_0 as WarShip
	ship.allocate_seat(first);actor.vehicle_id=ship.vehicle_id;game.members[first].vehicle=ship.vehicle_id
	game.members[first].vehicle_role="operator";game.members[first].vehicle_seat=0
	game.vehicle_system._send_occupancy(ship);game._broadcast("war_identity",[first,game.members[first]])
	phase("ship-motion")
	var until:=Time.get_ticks_msec()+9000
	while Time.get_ticks_msec()<until:
		game.vehicle_system.controls[first]={"vehicle":ship.vehicle_id,"occupancy":ship.control_epoch,"life":actor.life_id,"throttle":.7,"steer":0.,"fire":false,"aim":ship.aim_target,"at":game.war_clock}
		await physics_frame
	phase("ship-stop");game.vehicle_system.controls.erase(first)
	if not await wait_for(func():return reported(first,"ship-stop") and reported(late,"ship-stop"),"ship observations"): return
	verify_result(first,"ship-stop");verify_result(late,"ship-stop")
	game.vehicle_system.release(first,true)
	game.match_left=.05
	if not await wait_for(func():return game.match_ended,"round ends normally",10.): return
	check(game.round_restart_left>58.5,"sixty-second intermission starts normally")
	if not await wait_for(func():return reported(first,"round-ended") and reported(late,"round-ended"),"both clients display results"): return
	verify_result(first,"round-ended");verify_result(late,"round-ended")
	if not await wait_for(func():return not game.match_ended,"full intermission and restart",70.): return
	phase("round-restarted")
	if not await wait_for(func():return reported(first,"round-restarted") and reported(late,"round-restarted"),"both clients survive round restart"): return
	verify_result(first,"round-restarted");verify_result(late,"round-restarted")
	check(game.players.size()==2 and game.online,"server retains connected players")
	phase("finish");await create_timer(1.).timeout
func client_flow() -> void:
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"client joined"): return
	game.rpc_id(1,"qa_register",role)
	var completed: Dictionary={};var until:=Time.get_ticks_msec()+240000
	while Time.get_ticks_msec()<until:
		var current:=str(game.phase);var actor:=game.local_player as WarPlayer
		if game.match_ended and not completed.has("round-ended"):
			var count:=errors.size();check(game.war_ui.round_panel.visible,"round result panel visible")
			check(is_instance_valid(game.world_root),"round retains live world");send_result("round-ended",count);completed["round-ended"]=true
		if current=="ship-motion":
			var ship:=game.vehicle_system.vehicles.v_naval_assault_0 as WarShip
			ship_clock+=game.get_process_delta_time()
			if ship_clock>1. and ship_previous.is_finite():
				var forward:=Basis(Vector3.UP,ship.heading)*Vector3.FORWARD
				ship_steps.append((ship.position-ship_previous).dot(forward))
			ship_previous=ship.position
		if not current.is_empty() and not completed.has(current):
			var before:=errors.size()
			if current in ["first-scope","late-scopes"]:
				if not actor.deployed: await process_frame;continue
				game.ui_focus.close_all()
				check(actor.weapon_optics.enabled(actor),"own optional scope arrives through authority loadout")
				actor.clear_aim();actor.cycle_weapon_aim();actor._update_weapon_pose()
				await process_frame
				check(actor.weapon_optics.active,"physical lens renders on graphical client")
				actor.clear_aim()
				if current=="late-scopes":
					check(game.players.size()==2,"both actual peers visible")
					for remote: WarPlayer in game.players.values(): check(is_instance_valid(remote.weapon_root.find_child("Scope4x",true,false)),"late baseline includes remote scope")
				send_result(current,before)
			elif current=="binoculars":
				var marksman: WarPlayer
				for player: WarPlayer in game.players.values():
					if player.war_class=="marksman": marksman=player
				if not is_instance_valid(marksman) or marksman.utility_mode!="binoculars": await process_frame;continue
				if role=="first":
					marksman.set_utility_zoom(1);game.vehicle_system.request_command("utility_zoom",{"level":1,"life":marksman.life_id})
				elif marksman.utility_zoom!=1: await process_frame;continue
				await create_timer(.35).timeout
				check(marksman.utility_zoom==1 and is_instance_valid(marksman.utility_model),"binocular model and zoom synchronized")
				check(not marksman.weapon_root.visible,"no simultaneous firearm presentation")
				send_result(current,before)
			elif current=="bike-enter" and role=="first":
				game.ui_focus.close_all();game.vehicle_system.request_command("enter",{"id":"v_bike_0_0"})
			elif current=="bike-drive" and role=="first": Input.action_press("move_forward")
			elif current=="bike-exit":
				Input.action_release("move_forward")
				if role=="first": game.vehicle_system.request_command("exit",{})
				if not await wait_for(func():return game.vehicle_system.vehicles.v_bike_0_0.driver==0,"exit replicated",12.): return
				check(actor.body_root.visible,"infantry body restored after exit")
				if role=="first": check(actor.vehicle_id.is_empty(),"local camera no longer assigned to motorcycle")
				send_result(current,before)
			elif current=="ship-stop":
				check(ship_steps.size()>30,"moving ship sampled per graphical frame")
				var backwards:=ship_steps.filter(func(value):return value<-.015).size()
				check(backwards==0,"moving ship does not jump backwards")
				send_result(current,before)
			elif current=="round-restarted":
				check(not game.match_ended and not game.war_ui.round_panel.visible,"restart clears result panel")
				check(is_instance_valid(actor) and is_instance_valid(game.vehicle_system),"client remains alive after complete round boundary")
				send_result(current,before)
			elif current=="finish": return
			completed[current]=true
		await process_frame
	check(false,"client scenario timed out at "+str(game.phase))
func run() -> void:
	seed(193);Engine.max_fps=30
	game=FIXTURE.new();game.set_meta("war_host",role=="server");game.set_meta("war_test",true);game.set_meta("test_mode",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	await create_timer(3.).timeout
	print("NETWORK_BOOT ",JSON.stringify({"role":role,"online":game.online,"ready":game.join_ready,"testing":game.testing,"hosting":game.dedicated_pvp,"status":game.status_label.text,"address":game.address_input.text,"prebuilt":game.world_prebuilt,"preparing":game.preparing_world,"port":game._network_port()}))
	if role=="server": await server_flow()
	else: await client_flow()
	check(game.phase=="finish","entire scenario reached completion")
	var backwards:=ship_steps.filter(func(value):return value<-.015).size()
	var report:={"ok":errors.is_empty(),"role":role,"checks":checks,"errors":errors,"ship_samples":ship_steps.size(),"backward_steps":backwards,"scope":"Local DTLS, real War worlds and two graphical clients, late baseline, optional optics, binocular RPC, motorcycle entry/drive/exit, scripted ship motion, full 60s intermission. Not a native-crash dump analysis, WAN latency benchmark or publication."}
	NavalStorage.write_json("res://work/equipment-network-"+role+".json",report);print("EQUIPMENT_NETWORK ",JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if errors.is_empty() else 1)
