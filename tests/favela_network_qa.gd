extends SceneTree
## Favela real ENet integration: two independent clients and one dedicated authority.
## No user saves or source files are written. Reports go to FAVELA_NET_QA_DIR.
var game: WarGame
var role := "server"
var checks := 0
var failures: Array[String] = []
var observed_phases: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAVELA_NET_FAIL ",role," ",label)

func wait_for(condition: Callable, label: String, seconds := 30.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await process_frame
	failures.append("timeout: " + label)
	print("FAVELA_NET_TIMEOUT ",role," ",label)
	return false

func _run() -> void:
	game = load("res://tests/war_network_fixture.gd").new()
	game.operation_id = WarOperation.FAVELA
	game.set_meta("war_test", true)
	game.set_meta("test_mode", true)
	if role == "server": game.set_meta("war_host", true)
	root.add_child(game)
	game.nickname_input.text = role
	game.address_input.text = "127.0.0.1"
	if role == "server": await _server()
	else: await _client()
	var result := {"role":role,"checks":checks,"failures":failures,
		"operation":game.operation_id,"actors":game.players.size(),
		"vehicles":game.vehicle_system.vehicles.size() if is_instance_valid(game.vehicle_system) else -1}
	var directory := OS.get_environment("FAVELA_NET_QA_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join(role + ".json"),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result))
		file.close()
	print("FAVELA_NET_RESULT ",JSON.stringify(result))
	game.show_menu()
	game.queue_free()
	await create_timer(.35).timeout
	quit(0 if failures.is_empty() else 1)

func _phase(value: String) -> void:
	game.phase = value
	game._broadcast("qa_phase",[value])

func _pose(actor: WarPlayer, pos: Vector3) -> void:
	actor.position = pos
	actor.velocity = Vector3.ZERO
	actor.network_target = pos
	actor.has_network_state = false
	game._broadcast("qa_pose",[actor.peer_id,pos,actor.yaw,actor.pitch])

func _server() -> void:
	if not await wait_for(func(): return game.players.size()==2 and game.loading_baselines.is_empty(),"both clients and baseline",90.0): return
	check(game.operation_id==WarOperation.FAVELA,"authority uses Favela operation")
	check(game.vehicle_system.vehicles.size()==8,"eight authoritative vehicles")
	check(game.vehicle_system.vehicles.has("v_guarani_0") and game.vehicle_system.vehicles.has("v_guarani_1"),"both police APCs exist")
	check(game.objective_states.size()==5,"five objectives in authority")
	var alpha: WarPlayer
	var bravo: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="alpha": alpha=actor
		elif str(actor.name)=="bravo": bravo=actor
	if not is_instance_valid(alpha) or not is_instance_valid(bravo):
		failures.append("players named alpha/bravo absent")
		return
	check(not game._deploy(alpha.peer_id,0,"antitank","fal","rpg","base"),"police cannot deploy RPG")
	check(game._deploy(alpha.peer_id,0,"soldier","fal","","base"),"police deploys without launcher")
	check(game._deploy(bravo.peer_id,1,"antitank","g3","rpg","base"),"bandits deploy with RPG")
	if not await wait_for(func(): return game.reports.has("alpha-ready") and game.reports.has("bravo-ready"),"clients see deployed identities",30.0): return
	check(game._battle_active(),"two-human battle runs")
	var objective: Vector3=WarRules.OBJECTIVES["A"].position
	_pose(alpha,WarTerrain.point(objective.x,objective.z)+Vector3.UP*.35)
	_phase("capture")
	if not await wait_for(func(): return int(game.objective_states["A"].owner)==0,"live 18s sector capture",30.0): return
	check(int(game.objective_states["A"].owner)==0,"authority owns objective A")
	_phase("captured")
	if not await wait_for(func(): return game.reports.has("alpha-capture") and game.reports.has("bravo-capture"),"objective replicated to both clients",15.0): return
	var vehicle := game.vehicle_system.vehicles["v_guarani_0"] as WarVehicle
	_pose(alpha,vehicle.global_position+Vector3(-3,0,0))
	_pose(bravo,vehicle.global_position+Vector3(3,0,0))
	_phase("denied")
	if not await wait_for(func(): return game.reports.has("bravo-denied"),"enemy attempt recorded",10.0): return
	check(vehicle.driver==0 and bravo.vehicle_id.is_empty(),"enemy cannot board police APC")
	_phase("board")
	if not await wait_for(func(): return vehicle.driver==alpha.peer_id,"police boarded APC",12.0): return
	check(alpha.vehicle_id==vehicle.vehicle_id,"server records driver seat")
	_phase("exit")
	if not await wait_for(func(): return vehicle.driver==0 and alpha.vehicle_id.is_empty(),"driver exit replicated",12.0): return
	check(alpha.position.y>=WarTerrain.height_at(alpha.position.x,alpha.position.z)-.25,"vehicle exit above ground")
	_phase("done")
	await create_timer(.7).timeout

func _client() -> void:
	if not await wait_for(func(): return game.join_ready and is_instance_valid(game.local_player),"Favela join",85.0): return
	var actor := game.local_player as WarPlayer
	if not await wait_for(func(): return actor.deployed and game.players.size()==2,"replicated deployment",40.0): return
	check(game.operation_id==WarOperation.FAVELA,"client entered Favela")
	check(actor.war_team==(0 if role=="alpha" else 1),"client team replicated")
	check(game.vehicle_system.vehicles.size()==8,"client sees entire fleet")
	check(str(actor.gadget)==("" if role=="alpha" else "rpg"),"client launcher restrictions")
	game.ui_focus.close_all()
	game.rpc_id(1,"qa_report",role+"-ready")
	var deadline:=Time.get_ticks_msec()+80000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		var phase: String=str(game.phase)
		if phase.is_empty() or observed_phases.has(phase):continue
		observed_phases[phase]=true
		if phase=="capture":
			check(game.objective_states.has("A"),"client receives objective A")
		elif phase=="captured":
			if not await wait_for(func():return int(game.objective_states["A"].owner)==0,"objective snapshot",12.0):return
			check(true,"replicated capture owner A")
			game.rpc_id(1,"qa_report",role+"-capture")
		elif phase=="denied" and role=="bravo":
			game.vehicle_system.request_command("enter",{"id":"v_guarani_0"})
			await create_timer(.8).timeout
			check(actor.vehicle_id.is_empty(),"opponent denied police APC")
			game.rpc_id(1,"qa_report","bravo-denied")
		elif phase=="board" and role=="alpha":
			game.vehicle_system.request_command("enter",{"id":"v_guarani_0"})
		elif phase=="exit" and role=="alpha":
			if not await wait_for(func():return actor.vehicle_id=="v_guarani_0","local board state",6.0):return
			game.vehicle_system.request_command("exit",{})
			if not await wait_for(func():return actor.vehicle_id.is_empty(),"local exit",9.0):return
			check(true,"owner leaves APC and regains infantry")
		elif phase=="done":return
	failures.append("client timed out on phase "+str(game.phase))
