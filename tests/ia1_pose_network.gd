extends SceneTree
const PROBE=preload("res://scripts/pose_cost_probe.gd")
var role:="client"
var operation:="favela"
var game
var failures: Array=[]
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):role=a.trim_prefix("--role=")
		if a.begins_with("--pose-map="):operation=a.trim_prefix("--pose-map=")
	run.call_deferred()
func wait_for(test: Callable,seconds:=150.) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000.)
	while not test.call() and Time.get_ticks_msec()<end:await process_frame
	return test.call()
func population() -> int:
	var n:=0
	for m in game.members.values():
		if m.get("bot",false):n+=1
	return n
func run() -> void:
	seed(712907);Engine.max_fps=60 if role=="server" else 0
	if role=="client":
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_size=Vector2i(1920,1080);root.scaling_3d_scale=1.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure();GameOptions.values.merge(GameOptions.PRESETS[GameOptions.PRESETS.keys()[1]],true)
	GameOptions.values.merge({"scale":1.,"vsync":false,"fps":0},true)
	preload("res://scripts/maps/definition.gd").checked[operation]=true
	game=load("res://tests/war_locomotion_network_fixture.gd").new();game.operation_id=operation
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	game.set_meta("war_visual_preview",role=="client");game.set_meta("online_bots_test",role=="server")
	root.add_child(game);game.nickname_input.text="pose-"+role;game.address_input.text="127.0.0.1"
	if role=="server":
		if not await wait_for(func():return game.multiplayer.get_peers().size()==1 and game.loading_baselines.is_empty() and game.reports.has("ready")):failures.append("admission timeout");await finish({});return
		var id:=int(game.multiplayer.get_peers()[0])
		if not game._deploy(id,0,"soldier","fal","","base"):failures.append("deploy rejected");await finish({});return
		if not await wait_for(func():return population()==28 and game.reports.has("deployed")):failures.append("population timeout");await finish({});return
		game._broadcast("qa_phase",["warmup"])
		if not await wait_for(func():return game.reports.has("measuring")):failures.append("measure timeout");await finish({});return
	else:
		game.join_game("pvp")
		if not await wait_for(func():return game.join_ready):failures.append("join timeout");await finish({});return
		game.rpc_id(1,"qa_report","ready")
		if not await wait_for(func():return is_instance_valid(game.local_player) and game.local_player.deployed):failures.append("deploy timeout");await finish({});return
		game.rpc_id(1,"qa_report","deployed")
		if not await wait_for(func():return game.phase=="warmup" and population()==28):failures.append("warmup timeout");await finish({});return
		game.ui_focus.close_all()
		var camera:=Camera3D.new();camera.far=2200.;camera.fov=70.;game.world_root.add_child(camera)
		var point:=WarTerrain.point(-85.,-20.);camera.global_position=point+Vector3(-58,27,78);camera.look_at(point+Vector3.UP*1.5);camera.make_current()
		DisplayServer.window_move_to_foreground();await create_timer(10.).timeout
		game.rpc_id(1,"qa_report","measuring")
	PROBE.reset();PROBE.collecting=PROBE.enabled
	var start:=Time.get_unix_time_from_system();var begin:=Time.get_ticks_usec();var last:=begin
	var tick_start:=Engine.get_physics_frames();var previous_tick:=tick_start
	var frames: Array[float]=[];var physics: Array[float]=[];var trace: Array=[]
	var min_bots:=28;var focus_lost:=0;var multi:=0;var max_ticks:=0
	while (Time.get_ticks_usec()-begin)*.000001<30.:
		await process_frame
		var now:=Time.get_ticks_usec();var tick:=Engine.get_physics_frames();var step:=tick-previous_tick
		frames.append((now-last)*.001);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		trace.append([now,Time.get_unix_time_from_system(),frames[-1],step,physics[-1]])
		if step>1:multi+=1
		max_ticks=maxi(max_ticks,step);min_bots=mini(min_bots,population())
		if role=="client" and not DisplayServer.window_is_focused():focus_lost+=1
		previous_tick=tick;last=now
	PROBE.collecting=false
	if min_bots!=28:failures.append("lost bot population")
	if focus_lost>0:failures.append("focus lost")
	await finish({"role":role,"map":operation,"window_unix":[start,Time.get_unix_time_from_system()],"ticks":Engine.get_physics_frames()-tick_start,"frames":frames.size(),"mean_frame_ms":frames.reduce(func(a,b):return a+b,0.)/maxi(1,frames.size()),"multi_tick_frames":multi,"max_ticks":max_ticks,"focus_lost":focus_lost,"bots":min_bots,"probe":PROBE.report(Engine.get_physics_frames()-tick_start,frames.size()),"frame_trace":trace,"combat":game.bot_director.diagnostics if is_instance_valid(game.bot_director) else {}})
func finish(result: Dictionary) -> void:
	result.failures=failures;result.valid=failures.is_empty()
	var path:=OS.get_environment("POSE_NETWORK_OUT").path_join(role+".json")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("POSE_NETWORK_FINISHED ",role," ",result.valid)
	await create_timer(2.).timeout
	game.show_menu();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 2)
