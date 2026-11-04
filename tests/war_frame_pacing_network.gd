extends SceneTree
var game: WarGame
var role:="client"
var failures: Array[String]=[]
var frames: Array=[]
var recording:=false
var previous:=0
var previous_position:=Vector3.ZERO
var previous_physics:=0
var phases: Array=[]
var bot_count:=0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()

func wait_for(condition: Callable,label_text: String,seconds:=120.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while not condition.call() and Time.get_ticks_msec()<until:await process_frame
	if condition.call():return true
	failures.append("timeout: "+label_text);print("PACING_TIMEOUT ",label_text," status=",game.status_label.text," online=",game.online," ready=",game.join_ready," loading=",game.loading_screen.is_visible_in_tree());return false

func sample() -> void:
	if not recording:return
	var now:=Time.get_ticks_usec();var camera:=root.get_camera_3d();var tick:=Engine.get_physics_frames()
	var vehicle: WarVehicle=game.vehicle_system.find_target(game.local_player.vehicle_id) as WarVehicle
	if previous>0:frames.append([now*.001,(now-previous)*.001,tick-previous_physics,camera.global_position.distance_to(previous_position),Performance.get_monitor(Performance.TIME_PROCESS)*1000.,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,game.corrections,vehicle.received_state_sequence if vehicle else 0])
	previous=now;previous_position=camera.global_position;previous_physics=tick

func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value]);print("NETWORK_PACING ",role," ",value," bots=",game.bot_director.bots.size())

func run() -> void:
	game=load("res://tests/war_frame_pacing_game.gd").new()
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	if role=="client":game.set_meta("war_visual_preview",true)
	else:game.set_meta("online_bots_test",true)
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	Engine.max_fps=60 if role=="server" else 0
	if role=="server":await server_flow()
	else:await client_flow()
	var result:={"role":role,"failures":failures,"phases":phases,"frame_columns":["clock_ms","frame_ms","physics_steps","camera_distance_m","process_ms","physics_ms","corrections","vehicle_sequence"],"note":"Real local ENet authority and native client, all 28 production online bots active; same map, movement validator, vehicle controls and replication. Loopback does not reproduce the remote host or Internet conditions."}
	GamePerformanceProbe.stop();result.probe=GamePerformanceProbe.report()
	result.pose_frames=game.pose_frames
	if role=="server":
		result.physics=game.physics_samples
		if is_instance_valid(game.bot_director):result.bot_ticks=game.bot_director.ticks;result.bot_thoughts=game.bot_director.thoughts;result.bot_count=bot_count;result.bot_diagnostics=game.bot_director.diagnostics
	else:
		result.refresh_hz=DisplayServer.screen_get_refresh_rate();result.physics_hz=Engine.physics_ticks_per_second
	NavalStorage.write_json("res://work/microstutter1105/network-"+role+".json",result)
	print("NETWORK_PACING_DONE ",role," ",failures)
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)

func server_flow() -> void:
	if not await wait_for(func():return game.multiplayer.get_peers().size()==1,"client connection"):return
	var id:=int(game.multiplayer.get_peers()[0])
	if not await wait_for(func():return game.players.has(id),"client admission"):return
	if not await wait_for(func():return game.loading_baselines.is_empty() and game.reports.has("baseline-ready"),"baseline admission barrier"):return
	if not game._deploy(id,0,"soldier","fal","rpg","base"):failures.append("deployment failed");return
	if not await wait_for(func():return is_instance_valid(game.bot_director) and game.bot_director.bots.size()==28 and game.reports.has("client-ready"),"all 28 bots and client ready"):return
	bot_count=game.bot_director.bots.size();GamePerformanceProbe.start()
	var actor:=game.players[id] as WarPlayer
	game.qa_pose(id,WarTerrain.point(-1050,64)+Vector3.UP*.1,-PI*.5,0.)
	game._broadcast("qa_pose",[id,actor.position,-PI*.5,0.])
	game.measuring=true;game.bot_director.measuring=true
	phase("idle");await create_timer(20.).timeout
	phase("foot");await create_timer(20.).timeout
	phase("foot-finished");await create_timer(.4).timeout
	var tank:=game.vehicle_system.vehicles.v_abrams as WarVehicle
	# Move the unoccupied test hull only once, onto the existing clear lane.
	if tank.driver>0:game.vehicle_system.release(tank.driver,true)
	tank.position=WarTerrain.point(-1050,88)+Vector3.UP*.4;tank.heading=-PI*.5;tank.rotation.y=tank.heading;tank.resting=false;tank.speed=0
	game.qa_pose(id,tank.position+Vector3(0,0,4),-PI*.5,0.)
	game._broadcast("qa_pose",[id,actor.position,-PI*.5,0.])
	game.vehicle_system.command_for(id,"enter",{"id":tank.vehicle_id})
	if tank.driver!=id:failures.append("tank boarding failed")
	await create_timer(.5).timeout
	phase("tank");await create_timer(20.).timeout
	phase("finish");game.measuring=false;game.bot_director.measuring=false
	await create_timer(1.).timeout

func client_flow() -> void:
	game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.world_prebuilt=true
	await create_timer(1.).timeout
	game.ui_focus.close_all();game.loading_screen.hide()
	await game.join_game("pvp")
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"client baseline",100.):return
	game.rpc_id(1,"qa_report","baseline-ready")
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed and game.players.size()==29,"deployed client and 28 replicated bots",100.):return
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	game.vehicle_system.set_process_input(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	RenderingServer.frame_pre_draw.connect(sample)
	game.rpc_id(1,"qa_report","client-ready")
	if not await wait_for(func():return game.phase=="idle","idle phase"):return
	GamePerformanceProbe.start()
	game.measuring=true
	for label_text in ["idle","foot","tank"]:
		if not await wait_for(func():return game.phase==label_text,label_text+" phase"):return
		previous=0;frames=[];recording=true
		if label_text!="idle":Input.action_press("move_forward")
		var start:=game.local_player.global_position
		await wait_for(func():return game.phase!=label_text,label_text+" completion",30.)
		recording=false;Input.action_release("move_forward")
		var distance:=game.local_player.global_position.distance_to(start)
		phases.append({"label":label_text,"frames":frames,"distance":distance,"actors":game.players.size(),"corrections":game.corrections})
		print("NETWORK_PACING client ",label_text," frames=",frames.size()," distance=",distance," actors=",game.players.size()," corrections=",game.corrections)
		if label_text!="idle" and distance<15.:failures.append(label_text+" did not move 15 m")
	RenderingServer.frame_pre_draw.disconnect(sample)
