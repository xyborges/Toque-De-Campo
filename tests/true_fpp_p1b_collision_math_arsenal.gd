extends SceneTree
## P1b offline fixture. Geometry is calibrated in a neutral frame once per
## equipped firearm; every subsequent pose is solved without reading nodes.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")

func _initialize() -> void:
	run.call_deferred()

func benchmark_28(bind: Dictionary,neutral: Dictionary) -> Dictionary:
	# Isolated solver cost. Emulates 28 different pitch/lean samples from
	# ONE bound rig; it is not a full 28-bot frame or a rendering benchmark.
	var samples: Array[float]=[]
	var calls:=0
	for batch in 76:
		var start_usec:=Time.get_ticks_usec()
		for index in 28:
			var state: Dictionary=neutral.duplicate(true)
			state.pitch=sin(float(batch+index)*.039)*.55
			state.lean=cos(float(batch+index)*.027)*.50
			var result: Dictionary=Solver.solve(bind,state)
			if bool(result.get("supported",false)):calls+=1
		if batch>=8:samples.append(float(Time.get_ticks_usec()-start_usec)/1000.)
	samples.sort()
	return {
		"calls":calls,"batches":samples.size(),
		"batch_p50_ms":samples[roundi(float(samples.size()-1)*.50)],
		"batch_p95_ms":samples[roundi(float(samples.size()-1)*.95)],
		"batch_p99_ms":samples[roundi(float(samples.size()-1)*.99)]
	}

func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.players[2] as WarPlayer
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.deployed=true
	actor.hp=100.
	actor.owned=["g3","ak","fal","glock","sniper"]
	actor.loadout=actor.owned.duplicate()
	var poses: Array[Dictionary]=[
		{"pitch":0., "lean":0.},
		{"pitch":.36, "lean":0.},
		{"pitch":-.5, "lean":0.},
		{"pitch":.2, "lean":.45},
		{"pitch":-.25, "lean":-.35}
	]
	var completed:=0
	var rejected_ok:=0
	var totals: Array[Dictionary]=[]
	for weapon: String in actor.owned:
		actor.weapon_id=weapon
		actor.set_meta("weapon_optics",{})
		actor._refresh_weapon()
		actor.velocity=Vector3.ZERO
		actor.locomotion.reset(actor)
		actor.stance.crouch_weight=0
		actor.stance.prone_weight=0
		actor.set_posture(0,false,true)
		actor.pitch=0
		actor.lean=0
		actor.recoil=0
		actor.attack_anim=0
		actor.reload_left=0
		actor.reload_weapon=""
		actor.iron_sights=false
		actor.aiming=false
		actor.next_pose_usec=0
		actor._animate_walk()
		var bind: Dictionary=Solver.bind(actor)
		var maximum_m:=0.
		var maximum_basis:=0.
		var maximum_muzzle:=0.
		var notable: Array[String]=[]
		var cases:=0
		for pose: Dictionary in poses:
			actor.pitch=pose.pitch
			actor.lean=pose.lean
			actor.next_pose_usec=0
			actor._animate_walk()
			var reference: Dictionary=Snapshot.capture(actor)
			var result: Dictionary=Solver.solve(bind,Solver.state(actor))
			if not bool(result.get("supported",false)):
				notable.append("unsupported "+str(pose)+": "+str(result.get("reason","")))
				continue
			var diff: Dictionary=Snapshot.compare(reference,result)
			maximum_m=maxf(maximum_m,diff.max_origin_m)
			maximum_basis=maxf(maximum_basis,diff.max_basis_delta)
			maximum_muzzle=maxf(maximum_muzzle,diff.muzzle_origin_m)
			var top_id: String=""
			var top_error:=0.
			for region: String in diff.per_region:
				var error_m: float=diff.per_region[region].origin_m
				if error_m>top_error:
					top_id=region
					top_error=error_m
			if top_error>.01:
				notable.append(str(pose)+" "+top_id+"="+str(snappedf(top_error,.0001)))
			cases+=1
			completed+=1
		# Re-run the same angles in crouch; no re-bind is allowed.
		# The solver must derive stance from the input state.
		var crouch_set: bool=actor.set_posture(1,false,true)
		actor.stance.advance(actor,1.0)
		var crouch_confirmed: bool=crouch_set and actor.crouched and actor.stance.crouch_weight>.9 and actor.body_collision.shape.height<1.6
		if not crouch_confirmed:
			notable.append("CROUCH_NOT_APPLIED: "+str(actor.stance.crouch_weight))
		for pose: Dictionary in poses:
			actor.pitch=pose.pitch
			actor.lean=pose.lean
			actor.next_pose_usec=0
			actor._animate_walk()
			var reference: Dictionary=Snapshot.capture(actor)
			var result: Dictionary=Solver.solve(bind,Solver.state(actor))
			if not bool(result.get("supported",false)):
				notable.append("crouch unsupported "+str(pose)+": "+str(result.get("reason","")))
				continue
			var diff: Dictionary=Snapshot.compare(reference,result)
			maximum_m=maxf(maximum_m,diff.max_origin_m)
			maximum_basis=maxf(maximum_basis,diff.max_basis_delta)
			maximum_muzzle=maxf(maximum_muzzle,diff.muzzle_origin_m)
			var top_id: String=""
			var top_error:=0.
			for region: String in diff.per_region:
				var error_m: float=diff.per_region[region].origin_m
				if error_m>top_error:
					top_id=region
					top_error=error_m
			if top_error>.01:
				notable.append("crouch "+str(pose)+" "+top_id+"="+str(snappedf(top_error,.0001)))
			cases+=1
			completed+=1
		var invalid: Dictionary=Solver.state(actor)
		for field: String in ["prone_weight","moving","reload_left","scoped","special"]:
			var bad: Dictionary=invalid.duplicate(true)
			bad[field]=true if field in ["scoped","special"] else .8
			if field=="prone_weight": bad[field]=1.2
			if not bool(Solver.solve(bind,bad).get("supported",true)):
				rejected_ok+=1
		var wrong_weapon: Dictionary=invalid.duplicate(true)
		wrong_weapon.weapon="ak" if weapon!="ak" else "g3"
		if not bool(Solver.solve(bind,wrong_weapon).get("supported",true)):
			rejected_ok+=1
		var cost: Dictionary=benchmark_28(bind,Solver.state(actor))
		totals.append({
			"cost_28_solves":cost,
			"weapon":weapon,"regions":bind.bound_regions,"cases":cases,
			"crouch_confirmed":crouch_confirmed,"crouch_weight":actor.stance.crouch_weight,
			"max_position_m":maximum_m,"max_basis_delta":maximum_basis,
			"max_muzzle_m":maximum_muzzle,"notes":notable,
			"pass":crouch_confirmed and cases==10 and int(cost.calls)==2128 and bind.bound_regions>=13 and maximum_m<.015 and maximum_basis<.05 and maximum_muzzle<.005
		})
		print("P1B_FIREARM ",JSON.stringify(totals.back()))
	var passed:=completed==50 and rejected_ok==30
	for row: Dictionary in totals: passed=passed and bool(row.pass)
	print("P1B_ARSENAL_RESULT ",JSON.stringify({"pass":passed,"cases":completed,"weapons":totals.size(),"unsupported_rejected":rejected_ok}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
