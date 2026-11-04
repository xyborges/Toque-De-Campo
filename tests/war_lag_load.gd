extends SceneTree
# Full-map authority workload, isolated from the production server.
var game: WarGame
var requested_bots:=28
var label:="baseline"
var frames: Array=[]
var physics: Array=[]
var processing: Array=[]
var tick_gaps: Array=[]
var last_tick:=0
var recording:=false
var report_path:=""
var simulation_seconds:=0.
var wall_seconds:=0.
var failures: Array[String]=[]
class LoadBots extends WarBotDirector:
	var requested:=28
	func populate(_team: int) -> void:pass
	func _online_targets() -> Array:return [requested/2,requested-requested/2]
	func _physics_process(delta: float) -> void:
		var t:=GamePerformanceProbe.begin(&"bots.tick")
		super._physics_process(delta)
		GamePerformanceProbe.end(&"bots.tick",t)
	func _move(actor: WarPlayer,record: Dictionary,delta: float) -> void:
		var t:=GamePerformanceProbe.begin(&"bots.move")
		super._move(actor,record,delta)
		GamePerformanceProbe.end(&"bots.move",t)
	func _think(id: int) -> void:
		var t:=GamePerformanceProbe.begin(&"bots.think")
		super._think(id)
		GamePerformanceProbe.end(&"bots.think",t)
	func _drive(actor: WarPlayer,record: Dictionary,delta: float) -> void:
		var t:=GamePerformanceProbe.begin(&"bots.drive")
		super._drive(actor,record,delta)
		GamePerformanceProbe.end(&"bots.drive",t)
class LoadPlayer extends WarPlayer:
	func _physics_process(delta: float) -> void:
		var t:=GamePerformanceProbe.begin(&"actors.physics")
		super._physics_process(delta)
		GamePerformanceProbe.end(&"actors.physics",t)
	func _animate_walk() -> void:
		var t:=GamePerformanceProbe.begin(&"actors.pose")
		super._animate_walk()
		GamePerformanceProbe.end(&"actors.pose",t)
class LoadGame extends WarGame:
	func _new_player() -> GamePlayer:return LoadPlayer.new()
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bots="):requested_bots=int(arg.trim_prefix("--bots="))
		if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
		if arg.begins_with("--lag-report="):report_path=arg.trim_prefix("--lag-report=")
	run.call_deferred()
func _physics_process(_delta: float) -> bool:
	if recording:
		var now:=Time.get_ticks_usec()
		if last_tick>0:tick_gaps.append((now-last_tick)*.001)
		last_tick=now
	return false
func run() -> void:
	seed(2903);Engine.max_fps=60
	game=LoadGame.new();game.offline_operation=true;game.offline_participants=40;root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:failures.append("world not ready");finish();return
	game.bot_director.stop();game.bot_director.queue_free()
	var bots:=LoadBots.new();bots.requested=requested_bots;game.bot_director=bots
	bots.setup(game,true);game.world_root.add_child(bots)
	game.request_deploy(0,"soldier","fal","stinger","base");game.ui_focus.close_all()
	deadline=Time.get_ticks_msec()+45000
	while bots.bots.size()<requested_bots and Time.get_ticks_msec()<deadline:await process_frame
	if bots.bots.size()!=requested_bots:failures.append("bot population incomplete")
	await create_timer(4.).timeout
	if "--authority-observer" in OS.get_cmdline_user_args():game.local_player=null
	if "--control-no-monitoring" in OS.get_cmdline_user_args():
		for actor: WarPlayer in game.players.values():
			for area: Area3D in actor.hit_regions.values():area.monitoring=false;area.monitorable=false
	var deployed:=0
	for id in bots.bots:
		if (game.players[id] as WarPlayer).deployed:deployed+=1
	if deployed!=requested_bots:failures.append("deployed "+str(deployed)+" of "+str(requested_bots));finish();return
	if "--control-no-actor-presentation" in OS.get_cmdline_user_args():
		for actor: WarPlayer in game.players.values():
			if not actor.is_local:actor.next_pose_usec=Time.get_ticks_usec()+120000000
	GamePerformanceProbe.start({"bots":requested_bots,"label":label,"authority_observer":"--authority-observer" in OS.get_cmdline_user_args(),"no_monitoring":"--control-no-monitoring" in OS.get_cmdline_user_args()})
	var start:=Time.get_ticks_usec();var previous:=start;recording=true
	var initial_clock:=game.war_clock
	print("WAR_LAG_LOAD_BEGIN ",label," bots=",bots.bots.size())
	while Time.get_ticks_usec()-start<24000000:
		await process_frame
		var now:=Time.get_ticks_usec();frames.append((now-previous)*.001);previous=now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		processing.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
	simulation_seconds=game.war_clock-initial_clock;wall_seconds=(Time.get_ticks_usec()-start)*.000001
	recording=false;GamePerformanceProbe.stop();finish()
func finish() -> void:
	var result: Dictionary={"label":label,"bots":requested_bots,"failures":failures,"headless":DisplayServer.get_name()=="headless","frame_ms":GameNetworkDiagnostics.stats(frames),"tick_gap_ms":GameNetworkDiagnostics.stats(tick_gaps),"physics_ms":GameNetworkDiagnostics.stats(physics),"process_ms":GameNetworkDiagnostics.stats(processing),"probe":GamePerformanceProbe.report(),"scope":"Current local sources; full Guerra map, online bot routes and incremental filling on offline authority. One stationary human; no clients, forced shots or production changes. Wall timers are inclusive, not additive."}
	if is_instance_valid(game) and is_instance_valid(game.bot_director):result.diagnostics=game.bot_director.diagnostics
	result.simulation_seconds=simulation_seconds;result.wall_seconds=wall_seconds
	NavalStorage.write_json(report_path if not report_path.is_empty() else "res://work/war-lag-load-"+label+".json",result)
	print("WAR_LAG_LOAD_RESULT ",JSON.stringify({"label":label,"bots":requested_bots,"frame_ms":result.frame_ms,"physics_ms":result.physics_ms,"failures":failures}))
	if is_instance_valid(game):game.show_menu();game.queue_free()
	await create_timer(.5).timeout;quit(0 if failures.is_empty() else 1)
