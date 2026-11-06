extends SceneTree

# Offline A/B for identical LOS endpoints and traffic sweeps, no production
# code changed. Checks *equivalence*, not networked combat or performance.
var operation:="afghan"
var failures: Array[String]=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--operation="):operation=arg.trim_prefix("--operation=")
	run.call_deferred()

func check(condition: bool,message: String) -> void:
	if not condition:failures.append(message)

func run() -> void:
	seed(712907)
	var game:=WarGame.new()
	game.operation_id=WarOperation.FAVELA if operation=="favela" else WarOperation.AFGHAN
	game.offline_operation=true
	game.offline_participants=29
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+120000
	while (not game.join_ready or not is_instance_valid(game.bot_director)) and Time.get_ticks_msec()<deadline:
		await process_frame
	if not is_instance_valid(game.bot_director):
		push_error("IA2_GUARD_SETUP_FAIL: no director")
		quit(2);return
	var director:=game.bot_director as WarBotDirector
	director.populate(0)
	deadline=Time.get_ticks_msec()+60000
	while director.bots.size()<28 and Time.get_ticks_msec()<deadline:await process_frame
	check(director.bots.size()==28,"not 28 bots")
	# Let the authoritative deployment happen before querying opponents.
	for frame in 60:await physics_frame

	var line_checks:=0
	var stale_checks:=0
	director.ia2_reuse_los=true
	for id in director.bot_ids:
		var actor:=game.players.get(id) as WarPlayer
		if not is_instance_valid(actor) or not actor.deployed or actor.hp<=0:continue
		var found:=director._visible_enemy(actor)
		if not is_instance_valid(found):continue
		var baseline:=director._has_clear_shot(actor,found)
		var reused:=director._ia2_think_line_clear(actor,found)
		check(baseline==reused,"LOS result mismatch bot "+str(id))
		check(reused,"visible_enemy returned blocked enemy "+str(id))
		line_checks+=1
		# Invalidate the cached origin: original ray MUST run and agree.
		director.ia2_visible_from+=Vector3.UP*.1
		var fallback:=director._ia2_think_line_clear(actor,found)
		check(fallback==baseline,"LOS fallback mismatch bot "+str(id))
		stale_checks+=1

	var sweep_checks:=0
	var vehicles_count:=0
	var t0:=Time.get_ticks_usec()
	for vehicle: WarVehicle in game.vehicle_system.vehicles.values():
		if not is_instance_valid(vehicle):continue
		vehicles_count+=1
		var origin: Vector3=vehicle.global_position
		for vector in [Vector3(0,0,12),Vector3(0,0,20),Vector3(20,0,0),Vector3(0,0,-9),Vector3(-17,0,0)]:
			# Run both modes in same engine physics world and same rendered frame.
			director.ia2_reuse_traffic=false
			var baseline:=director._traffic_clear(vehicle,origin,origin+vector)
			director.ia2_reuse_traffic=true
			var reuse:=director._traffic_clear(vehicle,origin,origin+vector)
			check(baseline==reuse,"TRAFFIC mismatch vehicle "+str(vehicle.vehicle_id)+" vector "+str(vector))
			sweep_checks+=1
			# Switch to the baseline again to catch state leaking across vehicles.
			director.ia2_reuse_traffic=false
			var again:=director._traffic_clear(vehicle,origin,origin+vector)
			check(again==baseline,"TRAFFIC baseline drift "+str(vehicle.vehicle_id))
	var result={"map":operation,"bots":director.bots.size(),"los_checks":line_checks,
		"stale_origin_checks":stale_checks,"vehicles":vehicles_count,
		"traffic_sweep_checks":sweep_checks,
		"traffic_reused":director.ia2_traffic_reused,"los_reused":director.ia2_los_reused,
		"los_fallback":director.ia2_los_fallback,"elapsed_ms":(Time.get_ticks_usec()-t0)*.001,
		"failures":failures,"pass":failures.is_empty()}
	print("IA2_PHASE2_GUARDS ",JSON.stringify(result))
	if not failures.is_empty():push_error("IA2_PHASE2_GUARDS_FAIL "+JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
