extends "res://tests/true_fpp_p1k_paired_cost.gd"
## Diagnostic only. Timer overhead is included; this does not approve a gate.

func run() -> void:
	game=Fixture.new()
	root.add_child(game)
	await process_frame
	for actor: WarPlayer in game.players.values():
		actor.set_process(false)
		actor.set_physics_process(false)
	var actors: Array[WarPlayer]=[]
	for index in ACTORS:
		var actor:=game.make_actor(7200+index,false,1,"soldier",Vector3(index*4.,0,-30.)) as WarPlayer
		configure(actor,index,true)
		actors.append(actor)
	var totals: Dictionary={"advance":0,"state":0,"solve":0,"sync":0,"apply":0,"legacy":0}
	var measured:=0
	for tick in 480:
		await physics_frame
		for index in ACTORS:
			var actor:=actors[index]
			var started:=Time.get_ticks_usec()
			advance(actor,index,tick)
			var advanced:=Time.get_ticks_usec()
			WarCollisionPoseSolver.capture(actor,actor._p1k_input)
			var captured:=Time.get_ticks_usec()
			var cadence:=2 if index<7 else (4 if index<21 else 8)
			var due: bool=(tick+index)%cadence==0
			var frame:=WarCollisionPoseSolver.solve_cached(actor._p1k_calibration,actor._p1k_input,due,true)
			var solved:=Time.get_ticks_usec()
			if not frame.get("supported",false):
				push_error("Unsupported profiling state")
				quit(1)
				return
			actor.p1g_collision_rig.sync_packed(frame)
			var synced:=Time.get_ticks_usec()
			if due: actor._p1g_apply_remote_pose(frame.presentation)
			var applied:=Time.get_ticks_usec()
			if due: actor._pose_infantry()
			var legacy:=Time.get_ticks_usec()
			if tick>=120:
				totals.advance+=advanced-started
				totals.state+=captured-advanced
				totals.solve+=solved-captured
				totals.sync+=synced-solved
				totals.apply+=applied-synced
				totals.legacy+=legacy-applied
		if tick>=120: measured+=1
	for key in totals: totals[key]=float(totals[key])/float(measured)/1000.
	print("P1K_PROFILE mean_ms_per_28 ",JSON.stringify(totals))
	game.queue_free()
	await process_frame
	quit()
