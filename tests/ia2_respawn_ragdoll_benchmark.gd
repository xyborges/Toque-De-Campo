extends SceneTree

# Headless CPU fixture with 28 remote WarPlayer actors.
# Does NOT model a real ENet client, GPU, combat AI, or player input.
# Usage: --mode=weapons|ragdolls --optimized=0|1 --run=1
var game: WarGame
var errors: Array[String]=[]
var actors: Array[WarPlayer]=[]
var mode: String=""
var optimized:=false
var run_id:=0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
		if arg.begins_with("--optimized="):optimized=arg.trim_prefix("--optimized=")=="1"
		if arg.begins_with("--run="):run_id=int(arg.trim_prefix("--run="))
	Engine.max_fps=0
	Engine.physics_ticks_per_second=60
	_run.call_deferred()

func _check(value: bool,desc: String) -> void:
	if not value:
		errors.append(desc)
		push_error("IA2_BENCH_FAIL "+desc)

func _summary(values: Array[float]) -> Dictionary:
	if values.is_empty():return {"count":0}
	var sorted:=values.duplicate()
	sorted.sort()
	var total:=0.0
	for number in sorted: total+=number
	return {"count":sorted.size(),"mean_ms":total/sorted.size(),
		"median_ms":sorted[(sorted.size()-1)/2],
		"p95_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*.95)-1)],
		"p99_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*.99)-1)],
		"max_ms":sorted.back(),
		"over_16ms":sorted.filter(func(t: float)->bool:return t>16.667).size(),
		"over_33ms":sorted.filter(func(t: float)->bool:return t>33.333).size()}

func _run() -> void:
	if mode not in ["weapons","ragdolls"]:
		push_error("INVALID MODE")
		quit(3);return
	game=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.set_meta("war_mode",true)
	game.set_meta("ia2_allow_headless_queue_test",true)
	game.ia2_remote_ragdoll_queue_enabled=optimized
	var first: WarPlayer=game.players.get(2)
	if is_instance_valid(first):actors.append(first)
	for index in 27:
		var point:=Vector3(10.0+float(index%7)*5.0,0.0,-30.0-float(index/7)*5.0)
		var soldier: WarPlayer=game.make_actor(3+index,false,1,"soldier",point)
		actors.append(soldier)
	_check(actors.size()==28,"28 remote actors deployed")
	for actor in actors:
		actor.set_physics_process(false)
		actor.ia2_respawn_weapon_reuse=optimized if mode=="weapons" else false
		_check(not actor.is_local and is_instance_valid(actor.muzzle_marker),"remote actor with full weapon/muzzle")
	await process_frame
	await process_frame
	var started:=Time.get_ticks_usec()
	var report: Dictionary={}
	if mode=="weapons":
		report=await _measure_weapons()
	else:
		report=await _measure_ragdolls()
	report.merge({"mode":mode,"optimized":optimized,"run_id":run_id,"actor_count":actors.size(),
		"fixture_ms":(Time.get_ticks_usec()-started)*.001,
		"failures":errors,"godot_version":Engine.get_version_info().string,
		"physics_ticks":Engine.physics_ticks_per_second},true)
	print("IA2_RAGDOLL_WEAPON_BENCH ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)

func _measure_weapons() -> Dictionary:
	var times: Array[float]=[]
	var frames: Array[float]=[]
	var total_reuses:=0
	var total_builds:=0
	# Real repeated respawn/equip events: same rifle for all 28 observers.
	for batch in 20:
		await process_frame
		var start:=Time.get_ticks_usec()
		var originals: Array[Node3D]=[]
		for actor in actors:originals.append(actor.muzzle_marker)
		for actor in actors:
			actor._refresh_weapon()
			actor._update_weapon_pose()
		var cost:float=(Time.get_ticks_usec()-start)*.001
		times.append(cost)
		var frame_start:=Time.get_ticks_usec()
		await process_frame
		frames.append((Time.get_ticks_usec()-frame_start)*.001+cost)
		for i in actors.size():
			var actor:=actors[i]
			_check(is_instance_valid(actor.muzzle_marker),"muzzle still exists after refresh")
			if optimized:_check(actor.muzzle_marker==originals[i],"unchanged muzzle reused")
			else:_check(actor.muzzle_marker!=originals[i],"baseline rebuilds muzzle")
	for actor in actors:
		total_reuses+=actor.ia2_weapon_reuse_hits
		total_builds+=actor.ia2_weapon_full_builds
	# Weapon changes remain a full build even when reusing same-ID model.
	var first:=actors[0]
	var original:=first.muzzle_marker
	first.weapon_id="glock"
	first._refresh_weapon()
	_check(first.muzzle_marker!=original,"new weapon rebuilds muzzle")
	_check(is_instance_valid(first.muzzle_marker),"new weapon has valid muzzle")
	return {"batches":times.size(),"events":times.size()*actors.size(),
		"refresh_ms":_summary(times),"approx_frame_ms":_summary(frames),
		"reuses":total_reuses,"full_builds":total_builds}

func _measure_ragdolls() -> Dictionary:
	var callback: Array[float]=[]
	var frame_intervals: Array[float]=[]
	var each_wave: Array[Dictionary]=[]
	var count_old:=game.get_tree().get_nodes_in_group("death_ragdolls").size()
	# A burst of 8 deaths at one moment, four independent simulated waves.
	# Each physical corpse includes its normal clearance test, bodies and joints.
	for wave in 4:
		await process_frame
		var initial_created:=game.ia2_remote_ragdoll_created
		var t0:=Time.get_ticks_usec()
		for i in 8:
			var actor:=actors[(wave*8+i)%actors.size()]
			actor.death_presented=actor.life_id-1
			game.spawn_ragdoll(actor.global_position,1,actor)
		var elapsed:float=(Time.get_ticks_usec()-t0)*.001
		callback.append(elapsed)
		var times: Array[float]=[elapsed]
		var previous:=Time.get_ticks_usec()
		# Spawn and settle across 16 frames; include deferred presentation.
		for tick in 16:
			await process_frame
			var current:=Time.get_ticks_usec()
			times.append((current-previous)*.001)
			previous=current
		frame_intervals.append_array(times)
		if optimized:
			_check(game.ia2_remote_ragdoll_created-initial_created==8,"all 8 corpses scheduled")
			_check(game.ia2_remote_ragdoll_jobs.is_empty(),"ragdoll queue drained")
		each_wave.append({"wave":wave,"callback_ms":elapsed,
			"intervals_ms":_summary(times),
			"presentations":game.get_tree().get_nodes_in_group("death_ragdolls").size()})
	var now_count:=game.get_tree().get_nodes_in_group("death_ragdolls").size()
	_check(now_count>=count_old,"visible corpses constructed")
	return {"waves":4,"death_events":32,"per_wave":each_wave,
		"death_callback_ms":_summary(callback),
		"intervals_ms":_summary(frame_intervals),
		"deferred_created":game.ia2_remote_ragdoll_created}
