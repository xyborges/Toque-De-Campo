extends SceneTree

var game: WarGame
var frames: Array[float]=[]
var physics_samples: Array[float]=[]
var recording:=false
var previous_usec:=0
var calls:=0.
var memory:=0.
var player_count:=0
func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
	if recording:
		var at:=Time.get_ticks_usec()
		if previous_usec>0: frames.append(float(at-previous_usec)*.001)
		previous_usec=at
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		calls=maxf(calls,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		memory=maxf(memory,Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.)
		player_count=maxi(player_count,game.players.size())
	return false
func percentile(values: Array[float],ratio: float) -> float:
	return values[mini(values.size()-1,int(values.size()*ratio))] if not values.is_empty() else 0.
func run() -> void:
	Engine.max_fps=60
	game=WarGame.new();game.offline_operation=true;root.add_child(game)
	var deadline:=Time.get_ticks_msec()+35000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: push_error("Offline benchmark did not reach deployment");quit(1);return
	game.request_deploy(0,"soldier","fal","rpg","rally")
	deadline=Time.get_ticks_msec()+15000
	while game.players.size()<12 and Time.get_ticks_msec()<deadline: await process_frame
	game.third_person=true;game.local_player._update_view();game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await create_timer(4).timeout
	recording=true
	await create_timer(30).timeout
	recording=false
	var elapsed: float=frames.reduce(func(a,b):return a+b,0.)
	var ordered:=frames.duplicate();ordered.sort()
	var tail:=ordered.slice(maxi(0,ordered.size()-maxi(1,ceili(ordered.size()*.01))))
	var low_mean: float=tail.reduce(func(a,b):return a+b,0.)/maxi(1,tail.size())
	var physics_mean: float=physics_samples.reduce(func(a,b):return a+b,0.)/maxi(1,physics_samples.size())
	var result: Dictionary={"offline":true,"bots":game.bot_director.bots.size(),"maximum_players":player_count,"seconds":elapsed*.001,"frames":frames.size(),"average_fps":1000.*frames.size()/maxf(elapsed,.001),"one_percent_low":1000./maxf(low_mean,.001),"frame_ms_max":percentile(ordered,1),"frame_ms_p95":percentile(ordered,.95),"frame_ms_mean":elapsed/maxi(1,frames.size()),"physics_ms_mean":physics_mean,"max_draw_calls":calls,"memory_mib":memory,"diagnostics":game.bot_director.diagnostics.duplicate(),"note":"Native1080p; one human observer stationary at rally, eleven actual AI bots. No forced immortality, teleport or fake combat load. Single exploratory run, not a human gameplay session."}
	NavalStorage.write_json("res://work/war-offline-benchmark-161.json",result);print("WAR_OFFLINE_BENCH "+JSON.stringify(result))
	game.show_menu();game.queue_free();await process_frame;await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	quit(0 if player_count==12 and not frames.is_empty() else 1)
