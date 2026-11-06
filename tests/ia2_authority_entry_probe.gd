extends SceneTree
# QA-only: authority logic in an offline headless process. This does NOT
# replace a connected ENet dedicated server or a real GTX1650 client.
var operation:="favela"
var expected_bots:=28
var duration:=120.0
var warmup:=8.0
var label:="diagnostic"
var game: WarGame

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--operation="): operation=WarOperation.normalize(arg.trim_prefix("--operation="))
		if arg.begins_with("--bots="): expected_bots=int(arg.trim_prefix("--bots="))
		if arg.begins_with("--duration="): duration=clampf(float(arg.trim_prefix("--duration=")),10.0,130.0)
		if arg.begins_with("--warmup="): warmup=clampf(float(arg.trim_prefix("--warmup=")),2.0,35.0)
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	run.call_deferred()

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"samples":0}
	var ordered:=values.duplicate()
	ordered.sort()
	var total:=0.0
	for v in ordered:total+=v
	var n:=ordered.size()
	return {"samples":n, "mean_ms":total/n,
		"p50_ms":ordered[mini(n-1,ceili(n*.50)-1)],
		"p95_ms":ordered[mini(n-1,ceili(n*.95)-1)],
		"p99_ms":ordered[mini(n-1,ceili(n*.99)-1)],
		"max_ms":ordered[-1]}

func _fail(text: String) -> void:
	push_error("IA2_AUTHORITY_ENTRY_INVALID "+text)
	print("IA2_AUTHORITY_ENTRY_INVALID "+text)
	quit(2)

func _population() -> Dictionary:
	var count:=0
	var alive:=0
	if is_instance_valid(game.bot_director):
		count=game.bot_director.bots.size()
		for id in game.bot_director.bots:
			var actor:=game.players.get(id) as WarPlayer
			if is_instance_valid(actor) and actor.hp>0 and actor.deployed: alive+=1
	return {"total":count,"alive_and_deployed":alive}

func run() -> void:
	if DisplayServer.get_name()!="headless": _fail("requires --headless");return
	if expected_bots not in [0,28]:_fail("bots must be 0 or 28");return
	if not IA2CostMetrics.enabled:_fail("requires --ia2-profile-bots");return
	seed(712907)
	Engine.max_fps=60
	var entry_start:=Time.get_ticks_usec()
	var utc_start=Time.get_datetime_string_from_system(true)
	game=preload("res://tests/ia2_cost_game.gd").new()
	game.operation_id=operation
	game.offline_operation=true
	game.offline_participants=29 if expected_bots==28 else 1
	game.set_meta("test_mode",true)
	game.set_meta("war_test",true)
	root.add_child(game)
	var initial_ready_usec:=0
	var limit:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<limit:await process_frame
	if not game.join_ready:_fail("join_ready timeout");return
	initial_ready_usec=Time.get_ticks_usec()
	game.request_deploy(0,"soldier","fal","stinger","base")
	var bots_ready_usec:=Time.get_ticks_usec()
	if expected_bots==28:
		limit=Time.get_ticks_msec()+60000
		while (not is_instance_valid(game.bot_director) or game.bot_director.bots.size()<28) and Time.get_ticks_msec()<limit:
			await process_frame
		if not is_instance_valid(game.bot_director) or game.bot_director.bots.size()!=28:
			_fail("wrong bot population "+str(_population()));return
		bots_ready_usec=Time.get_ticks_usec()
	else:
		await create_timer(.25).timeout
		if is_instance_valid(game.bot_director) and game.bot_director.bots.size()!=0:
			_fail("0 bots request created bots");return
		bots_ready_usec=Time.get_ticks_usec()
	await create_timer(warmup).timeout
	var population_before:=_population()
	if int(population_before.total)!=expected_bots:
		_fail("pre-sample population "+str(population_before));return
	var samples: Array[float]=[]
	var physics_monitor: Array[float]=[]
	var process_monitor: Array[float]=[]
	var tick_distribution: Dictionary={}
	var ticks_ge2:=0
	var ticks_ge4:=0
	var ticks_ge8:=0
	var over50:=0
	var over100:=0
	var max_backlog:=0.0
	var population_min:=expected_bots
	var alive_min:=int(population_before.alive_and_deployed)
	var alive_max:=int(population_before.alive_and_deployed)
	var snapshots: Array[Dictionary]=[]
	IA2CostMetrics.start()
	var begin:=Time.get_ticks_usec()
	var start_physics_frames:=Engine.get_physics_frames()
	var wall_begin_unix_ms:=int(Time.get_unix_time_from_system()*1000.)
	var prev:=begin
	var prev_tick:=Engine.get_physics_frames()
	var frame:=0
	var next_snapshot:=begin
	var steps_baseline:=GameStepMotion.qa_report()
	while Time.get_ticks_usec()-begin<duration*1000000.0:
		await process_frame
		IA2CostMetrics.touch_frame()
		var now:=Time.get_ticks_usec()
		var dt:float=(now-prev)*.001
		var ticks:int=Engine.get_physics_frames()-prev_tick
		samples.append(dt)
		physics_monitor.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		process_monitor.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		tick_distribution[ticks]=int(tick_distribution.get(ticks,0))+1
		if ticks>=2:ticks_ge2+=1
		if ticks>=4:ticks_ge4+=1
		if ticks>=8:ticks_ge8+=1
		if dt>50.0:over50+=1
		if dt>100.0:over100+=1
		max_backlog=maxf(max_backlog,maxf(0.0,((now-begin)*.000001)*60.0-float(Engine.get_physics_frames()-start_physics_frames)))
		if now>=next_snapshot:
			var pop:=_population()
			population_min=mini(population_min,int(pop.total))
			alive_min=mini(alive_min,int(pop.alive_and_deployed))
			alive_max=maxi(alive_max,int(pop.alive_and_deployed))
			snapshots.append({"elapsed_s":(now-begin)*.000001,"physics_frames":Engine.get_physics_frames()-start_physics_frames,
				"bots":pop.total,"alive":pop.alive_and_deployed,
				"physics_monitor_ms":physics_monitor[-1]})
			next_snapshot=now+1000000
		prev=now
		prev_tick=Engine.get_physics_frames()
		frame+=1
	IA2CostMetrics.stop()
	var end:=Time.get_ticks_usec()
	var sample_seconds=(end-begin)*.000001
	var report={
		"label":label,"operation":operation,"headless":true,
		"scope":"OFFLINE authority-control only, NOT dedicated ENet, 0 real network clients, no client render",
		"hardware_role":"DESKTOP-R0I0NQG test authority",
		"engine":Engine.get_version_info().string,
		"source_base":"5fceacc (Favela v25, QA)",
		"expected_bots":expected_bots,
		"population_before":population_before,"population_end":_population(),
		"population_min":population_min,
		"alive_min":alive_min,"alive_max":alive_max,
		"entry":{"utc":utc_start,"root_add_to_join_ready_ms":(initial_ready_usec-entry_start)*.001,
			"join_ready_to_bots_ready_ms":(bots_ready_usec-initial_ready_usec)*.001,
			"root_add_to_bots_ready_ms":(bots_ready_usec-entry_start)*.001,
			"world_build_ms":game.world_build_ms,
			"warmup_seconds":warmup},
		"measurement":{"unix_start_ms":wall_begin_unix_ms,"unix_end_ms":int(Time.get_unix_time_from_system()*1000.),
			"duration_seconds":sample_seconds,
			"frame_interval_ms":_stats(samples),
			"process_monitor_ms":_stats(process_monitor),
			"physics_monitor_ms":_stats(physics_monitor),
			"physics_ticks":Engine.get_physics_frames()-start_physics_frames,
			"physics_ticks_per_real_second":(Engine.get_physics_frames()-start_physics_frames)/sample_seconds,
			"max_nominal_tick_deficit_proxy":max_backlog,
			"over50_frames":over50,"over100_frames":over100,
			"process_frames":samples.size(),
			"ticks_ge2_frames":ticks_ge2,"ticks_ge4_frames":ticks_ge4,
			"ticks_ge8_frames":ticks_ge8,"tick_distribution":tick_distribution},
		"scope_timings":IA2CostMetrics.report(),
		"bot_actions":game.bot_director.diagnostics if is_instance_valid(game.bot_director) else {},
		"step_stats_before":steps_baseline,
		"step_stats_after":GameStepMotion.qa_report(),
		"population_snapshots":snapshots
	}
	var out="res://work/ia2-diagnostico-entrada-v25-20261106/"+label+".json"
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	NavalStorage.write_json(out,report)
	print("IA2_AUTHORITY_ENTRY_RESULT ",JSON.stringify({"label":label,
		"bots":expected_bots,"duration":sample_seconds,
		"fps":1000./float(report.measurement.frame_interval_ms.mean_ms),
		"frame_p99_ms":report.measurement.frame_interval_ms.p99_ms,
		"engine_physics_ms":report.measurement.physics_monitor_ms.mean_ms,
		"frames_over100":over100,"output":out}))
	quit(0 if population_min==expected_bots else 3)
