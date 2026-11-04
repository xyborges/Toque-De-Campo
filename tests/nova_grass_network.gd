extends SceneTree

# Functional localhost/DTLS validation, deliberately not a performance test.
# Two graphical processes have their own real WarGame world and visual stream;
# a headless process remains authoritative for deployment/positions/cleanup.
const FIXTURE=preload("res://tests/nova_grass_network_fixture.gd")
var role:="server"
var prefix:="nova-grass-network"
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var snapshots: Array[Dictionary]=[]
var manager: Node3D
var camera: Camera3D
var stream_stats: Dictionary={}
var cleanup_ok:=false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--qa-run="): prefix=arg.trim_prefix("--qa-run=")
	run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);print("FAIL ",role," ",label)

func wait_for(test: Callable,label: String,seconds:=90.0) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	check(false,"timeout "+label)
	return false

func report_key(id: int,token: String) -> String: return str(id)+":"+token

func validate_client_report(id: int,token: String) -> void:
	var record: Dictionary=game.grass_reports.get(report_key(id,token),{})
	check(not record.is_empty(),"client report exists "+token)
	check(bool(record.get("ok",false)),"client validation "+token+": "+str(record.get("failures",[])))
	check(int(record.get("level",0))==2 and int(record.get("cells",0))>0,"graphical client has active stream "+token)
	check(int(record.get("grass_instances",0))>0 and int(record.get("grass_contacts",-1))==0,"grass is visible data without contact "+token)

func headless_check() -> void:
	check(DisplayServer.get_name()=="headless","authority is headless")
	check(game.world_root.get_node_or_null("VegetationVisuals")==null,"headless world has no vegetation controller")
	check(get_nodes_in_group("war_vegetation_visuals").is_empty(),"headless allocates no visual vegetation group")
	check(game.world_root.find_children("GrassStreamCell*","MultiMeshInstance3D",true,false).is_empty(),"headless allocates no streamed grass cells")

func server_run() -> void:
	if not await wait_for(func():return is_instance_valid(game.world_root) and game.online,"server world",120.): return
	headless_check()
	if not await wait_for(func():return game.grass_clients.has("first") and bool(game.members.get(game.grass_clients.first,{}).get("deployed",false)),"first deployment",150.): return
	await create_timer(2.).timeout
	var first_id:=int(game.grass_clients.first)
	game.grass_authority_snapshot("initial",[first_id])
	if not await wait_for(func():return game.grass_reports.has(report_key(first_id,"initial")),"first independent world",90.): return
	validate_client_report(first_id,"initial")
	NavalStorage.write_json("res://work/"+prefix+"-first-ready.json",{"ready":true,"first_id":first_id,"failures":failures})
	if not await wait_for(func():return game.grass_clients.has("late") and bool(game.members.get(game.grass_clients.late,{}).get("deployed",false)),"late deployment",150.): return
	await create_timer(2.).timeout
	var late_id:=int(game.grass_clients.late)
	check(first_id!=late_id,"independent peers have distinct ids")
	game.grass_authority_snapshot("late",[first_id,late_id])
	if not await wait_for(func():return game.grass_reports.has(report_key(first_id,"late")) and game.grass_reports.has(report_key(late_id,"late")),"late world on both peers",90.): return
	validate_client_report(first_id,"late");validate_client_report(late_id,"late")
	game.rpc_id(first_id,"qa_grass_command","exit")
	if not await wait_for(func():return not game.members.has(first_id) and not game.players.has(first_id),"authority cleans departing peer",35.): return
	game.grass_clients.erase("first")
	game.grass_authority_snapshot("after-exit",[late_id])
	if not await wait_for(func():return game.grass_reports.has(report_key(late_id,"after-exit")),"remaining client observes cleanup",45.): return
	validate_client_report(late_id,"after-exit")
	headless_check()
	game.rpc_id(late_id,"qa_grass_command","exit")
	cleanup_ok=await wait_for(func():return not game.members.has(late_id) and not game.players.has(late_id),"authority cleans final peer",35.)

func count_contacts(node: Node) -> int:
	var result:=1 if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D else 0
	for child in node.get_children(): result+=count_contacts(child)
	return result

func stream_ready() -> bool:
	return is_instance_valid(manager) and is_instance_valid(manager.streamer) and manager.streamer.initialised and manager.streamer.pending.is_empty() and manager.streamer.retired.is_empty()

func validate_snapshot(request: Dictionary) -> void:
	var before:=failures.size();var expected: Dictionary=request.expected
	# The payload is only a reference from the authority. Values checked here
	# come from ordinary production snapshots, never from a QA pose setter.
	await wait_for(func():
		for key: String in expected:
			var actor:=game.players.get(int(key)) as WarPlayer
			if not is_instance_valid(actor) or actor.life_id!=int(expected[key].life) or actor.global_position.distance_to(expected[key].position)>.30: return false
		return true,"production positions settle",15.)
	var positions: Dictionary={}
	for key: String in expected:
		var actor:=game.players.get(int(key)) as WarPlayer
		check(is_instance_valid(actor),"snapshot player exists "+key)
		if not is_instance_valid(actor): continue
		var reference: Dictionary=expected[key]
		check(actor.life_id==int(reference.life) and actor.war_team==int(reference.team) and actor.deployed==bool(reference.deployed),"authority identity "+key)
		check(actor.global_position.distance_to(reference.position)<=.30,"authority position "+key)
		check(absf(actor.avatar_parts.leg_l.scale.y-float(reference.legs))<.001,"same saved leg proportions "+key)
		check(actor.avatar_parts.head.global_position.distance_to(reference.head)<=.30,"grounded presentation agrees with authority "+key)
		positions[key]={"position":actor.global_position,"reference":reference.position,"life":actor.life_id,"team":actor.war_team}
	for row: Dictionary in request.heights:
		var p: Vector2=row.point
		check(absf(WarTerrain.height_at(p.x,p.y)-float(row.height))<.0001,"same terrain height "+str(p))
	if str(request.token)=="after-exit":
		var human_count:=0
		for state: Dictionary in game.members.values():
			if not bool(state.get("bot",false)): human_count+=1
		check(human_count==1,"remaining client removes departed human")
	check(stream_ready(),"stream stays settled across peer changes")
	var contacts:=0;var instances:=0
	if is_instance_valid(manager.streamer):
		for cell: Variant in manager.streamer.cells.values():
			if is_instance_valid(cell): contacts+=count_contacts(cell);instances+=cell.multimesh.instance_count
	check(contacts==0,"no new grass collider")
	var result:={"token":request.token,"ok":failures.size()==before,"failures":failures.slice(before),"positions":positions,"level":manager.level,"cells":manager.streamer.cells.size(),"grass_instances":instances,"grass_contacts":contacts}
	snapshots.append(result)
	game.rpc_id(1,"qa_grass_report",str(request.token),result)

func client_run() -> void:
	check(DisplayServer.get_name()!="headless","client is graphical")
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"client joins",150.): return
	var team:=0 if role=="first" else 1
	game.request_deploy(team,"soldier",WarRules.primary_for("soldier",team)[0],WarRules.launcher_for_team(team),"base")
	if not await wait_for(func():return game.local_player.deployed,"client deployment",50.): return
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	manager=game.world_root.get_node_or_null("VegetationVisuals")
	check(is_instance_valid(manager),"graphical runtime manager exists")
	if not is_instance_valid(manager): return
	camera=Camera3D.new();game.world_root.add_child(camera)
	camera.global_position=WarTerrain.point(-150,-650)+Vector3(0,2.,8.)
	camera.look_at(WarTerrain.point(-150,-650)+Vector3.UP*.3);camera.make_current()
	check(manager.apply_level(2),"medium preset applies")
	if not await wait_for(stream_ready,"stream settles",90.): return
	stream_stats={"peak_cells":manager.streamer.peak_cell_count,"max_build_ms":manager.streamer.max_build_ms}
	game.rpc_id(1,"qa_grass_register",role)
	var completed: Dictionary={}
	var until:=Time.get_ticks_msec()+240000
	while Time.get_ticks_msec()<until and game.grass_command!="exit":
		var request: Dictionary=game.grass_request
		if not request.is_empty() and not completed.has(str(request.token)):
			completed[str(request.token)]=true
			await validate_snapshot(request)
		await process_frame
	check(game.grass_command=="exit","authority completes client phases")
	check(completed.has("initial") and completed.has("late") if role=="first" else completed.has("late") and completed.has("after-exit"),"required session phases observed")
	check(manager.apply_level(0),"old vegetation restored before leaving")
	await process_frame;await process_frame
	check(manager.level==0 and is_instance_valid(manager.streamer) and manager.streamer.pool.size()==25,"comparison keeps the preallocated pool")
	for cell: MultiMeshInstance3D in manager.streamer.pool:check(not cell.visible,"comparison hides every pooled cell")
	var world_ref: WeakRef=weakref(game.world_root);var manager_ref: WeakRef=weakref(manager)
	game.show_menu();game.queue_free();game=null
	for i in 4: await process_frame
	cleanup_ok=not is_instance_valid(world_ref.get_ref()) and not is_instance_valid(manager_ref.get_ref()) and get_nodes_in_group("war_vegetation_visuals").is_empty()
	check(cleanup_ok,"disconnect frees local world and visual group")

func run() -> void:
	seed(193);Engine.max_fps=30
	game=FIXTURE.new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
	game.set_meta("war_host",role=="server")
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_run()
	else: await client_run()
	var report:={"role":role,"ok":failures.is_empty(),"checks":checks,"failures":failures,"graphical":DisplayServer.get_name()!="headless","snapshots":snapshots,"stream":stream_stats,"cleanup_ok":cleanup_ok,"scope":"Real WarGame worlds, production localhost DTLS join/deploy/snapshots/disconnect; two graphical clients, one joins late. Not 18-player performance, gameplay movement, central accounts or publication approval."}
	NavalStorage.write_json("res://work/"+prefix+"-"+role+".json",report)
	print("NOVA_GRASS_NETWORK ",JSON.stringify({"role":role,"ok":report.ok,"checks":checks,"failures":failures}))
	if is_instance_valid(game): game.show_menu();game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
