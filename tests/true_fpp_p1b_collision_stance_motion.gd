extends SceneTree
## P1b prone parity; an independent solve must match the live rig after
## explicit posture activation, not merely after altering an input number.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")
const WEAPONS:=["g3","ak","fal","glock","sniper"]
const POSES: Array[Dictionary]=[
	{"pitch":0., "lean":0.},
	{"pitch":.36, "lean":0.},
	{"pitch":-.5, "lean":0.},
	{"pitch":.2, "lean":.45},
	{"pitch":-.25, "lean":-.35}
]

func _initialize() -> void:
	run.call_deferred()

func benchmark_28_moving(bind: Dictionary,base: Dictionary) -> Dictionary:
	# Microbenchmark of pure pose solves only. No visual/physics updates,
	# collisions, player entities, ENet or GPU. 28 synthetic motion states.
	var states: Array[Dictionary]=[]
	for i in 28:
		var st: Dictionary=base.duplicate(true)
		var scenario: int=i%4
		st.moving=[.7,1.,.65,.45][scenario]
		st.sprint=[0.,.85,0.,0.][scenario]
		st.crouch_weight=1. if scenario==2 else 0.
		st.prone_weight=1. if scenario==3 else 0.
		st.crouched=scenario==2
		st.prone=scenario==3
		st.grounded=true
		st.legs_intact=true
		st.aiming=false
		st.fire_cooldown=0.
		st.direction=Vector3(1,0,0) if scenario==2 else Vector3(0,0,-1)
		st.phase=.24+float(i)*.19
		st.pitch=.12
		st.lean=.20
		states.append(st)
	var samples: Array[float]=[]
	var calls:=0
	for batch in 76:
		var started: int=Time.get_ticks_usec()
		for st: Dictionary in states:
			var out: Dictionary=Solver.solve(bind,st)
			if bool(out.get("supported",false)):calls+=1
		if batch>=8:samples.append(float(Time.get_ticks_usec()-started)/1000.)
	samples.sort()
	return {"calls":calls,"batches":samples.size(),
		"p50_ms":samples[roundi(float(samples.size()-1)*.5)],
		"p95_ms":samples[roundi(float(samples.size()-1)*.95)],
		"p99_ms":samples[roundi(float(samples.size()-1)*.99)]}

func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.players[2] as WarPlayer
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.deployed=true
	actor.hp=100.
	actor.owned=WEAPONS.duplicate()
	actor.loadout=actor.owned.duplicate()
	var passed:=true
	var evaluated:=0
	var movement_evaluated:=0
	var transitions_evaluated:=0
	var rejected:=0
	var soft_supported:=0
	var summary: Array[Dictionary]=[]
	for weapon: String in WEAPONS:
		actor.weapon_id=weapon
		actor.set_meta("weapon_optics",{})
		actor._refresh_weapon()
		actor.locomotion.reset(actor)
		actor.velocity=Vector3.ZERO
		actor.stance.crouch_weight=0.
		actor.stance.prone_weight=0.
		actor.set_posture(0,false,true)
		actor.pitch=0.
		actor.lean=0.
		actor.recoil=0.
		actor.attack_anim=0.
		actor.reload_left=0.
		actor.reload_weapon=""
		actor.iron_sights=false
		actor.aiming=false
		actor.next_pose_usec=0
		actor._animate_walk()
		var bind: Dictionary=Solver.bind(actor)
		var posture_set: bool=actor.set_posture(2,false,true)
		actor.stance.advance(actor,1.)
		var shape: CapsuleShape3D=actor.body_collision.shape as CapsuleShape3D
		var full_prone: bool=posture_set and actor.prone and actor.stance.prone_weight>.99 and is_instance_valid(shape) and actor.body_collision.rotation.x>1.
		var cases:=0
		var max_origin:=0.
		var max_basis:=0.
		var max_muzzle:=0.
		var notable: Array[String]=[]
		for pose: Dictionary in POSES:
			actor.pitch=pose.pitch
			actor.lean=pose.lean
			actor.next_pose_usec=0
			actor._animate_walk()
			var expected: Dictionary=Snapshot.capture(actor)
			var result: Dictionary=Solver.solve(bind,Solver.state(actor))
			if not bool(result.get("supported",false)):
				notable.append("unsupported "+str(pose)+": "+str(result.get("reason","")))
				continue
			var diff: Dictionary=Snapshot.compare(expected,result)
			max_origin=maxf(max_origin,float(diff.max_origin_m))
			max_basis=maxf(max_basis,float(diff.max_basis_delta))
			max_muzzle=maxf(max_muzzle,float(diff.muzzle_origin_m))
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
			evaluated+=1
		var movement_cases:=0
		var movement_origin:=0.
		var movement_basis:=0.
		var movement_muzzle:=0.
		var movement_varied:=true
		var modes: Array[Dictionary]=[
			{"posture":0,"moving":.7,"sprint":0.,"direction":Vector3(0,0,-1)},
			{"posture":0,"moving":1.,"sprint":.85,"direction":Vector3(0,0,-1)},
			{"posture":1,"moving":.65,"sprint":0.,"direction":Vector3(1,0,0)},
			{"posture":2,"moving":.45,"sprint":0.,"direction":Vector3(0,0,-1)}
		]
		for mode: Dictionary in modes:
			actor.locomotion.moving=0.
			actor.locomotion.sprint=0.
			var motion_posture_set: bool=actor.set_posture(int(mode.posture),false,true)
			actor.stance.advance(actor,1.)
			if not motion_posture_set:
				notable.append("cannot set posture: "+str(mode.posture))
				continue
			actor.locomotion.moving=float(mode.moving)
			actor.locomotion.sprint=float(mode.sprint)
			actor.locomotion.grounded=true
			actor.locomotion.local_direction=Vector3(mode.direction)
			var first_leg_position:=Vector3.ZERO
			var first_sample:=true
			var changed_pose:=false
			for phase in [.55,1.6,3.2]:
				actor.locomotion.phase=phase
				actor.pitch=.12
				actor.lean=.20
				actor.next_pose_usec=0
				actor._animate_walk()
				var motion_reference: Dictionary=Snapshot.capture(actor)
				var motion_result: Dictionary=Solver.solve(bind,Solver.state(actor))
				if not bool(motion_result.get("supported",false)):
					notable.append("moving unsupported "+str(mode)+" "+str(motion_result.get("reason","")))
					continue
				var drift: Dictionary=Snapshot.compare(motion_reference,motion_result)
				var actual_leg: Transform3D=motion_reference.regions["legL"]
				if first_sample:
					first_leg_position=actual_leg.origin
					first_sample=false
				elif actual_leg.origin.distance_to(first_leg_position)>.002:
					changed_pose=true
				movement_origin=maxf(movement_origin,float(drift.max_origin_m))
				movement_basis=maxf(movement_basis,float(drift.max_basis_delta))
				movement_muzzle=maxf(movement_muzzle,float(drift.muzzle_origin_m))
				var bad_region: String=""
				var worst:=0.
				for region: String in drift.per_region:
					if float(drift.per_region[region].origin_m)>worst:
						bad_region=region
						worst=float(drift.per_region[region].origin_m)
				if worst>.001 or drift.muzzle_origin_m>.001 or drift.max_basis_delta>.005:
					notable.append("moving "+str(mode.posture)+" phase="+str(phase)+" "+bad_region+"="+str(snappedf(worst,.0001))+" muzzle="+str(snappedf(float(drift.muzzle_origin_m),.0001)))
				movement_cases+=1
				movement_evaluated+=1
			if not changed_pose:
				notable.append("No physical gait for posture="+str(mode.posture)+" sprint="+str(mode.sprint))
				movement_varied=false
		var transition_cases:=0
		for postures: Array in [[0,2],[2,0],[1,2],[2,1]]:
			actor.set_posture(postures[0],false,true)
			actor.stance.advance(actor,1.)
			actor.set_posture(postures[1],false,true)
			actor.locomotion.phase=1.6
			actor.pitch=-.36 if actor.prone else -.64
			actor.lean=.25
			for sample in 3:
				actor.stance.advance(actor,1./60.)
				actor.next_pose_usec=0
				actor._animate_walk()
				var state:=Solver.state(actor)
				var frame:=Solver.solve(bind,state)
				if not bool(frame.get("supported",false)):
					notable.append("unsupported transition "+str(postures))
					continue
				var diff:=Snapshot.compare(Snapshot.capture(actor),frame)
				if not diff.missing.is_empty() or diff.max_origin_m>=.001 or diff.max_basis_delta>=.005 or diff.muzzle_origin_m>=.001:
					notable.append("transition "+str(postures)+": "+str(diff))
					continue
				transition_cases+=1
				transitions_evaluated+=1
		var invalid_motion: Dictionary=Solver.state(actor)
		for field: String in ["grounded","legs_intact","fire_cooldown"]:
			var forbidden: Dictionary=invalid_motion.duplicate(true)
			forbidden[field]=false if field in ["grounded","legs_intact"] else .2
			if not bool(Solver.solve(bind,forbidden).get("supported",true)):
				rejected+=1
		var airborne_run: Dictionary=invalid_motion.duplicate(true)
		airborne_run.moving=0.
		airborne_run.sprint=.25
		airborne_run.grounded=false
		if not bool(Solver.solve(bind,airborne_run).get("supported",true)):
			rejected+=1
		var soft_aim: Dictionary=invalid_motion.duplicate(true)
		soft_aim.aiming=true
		if bool(Solver.solve(bind,soft_aim).get("supported",false)):
			soft_supported+=1
		else:
			notable.append("soft aim unexpectedly rejected")
		var motion_cost: Dictionary=benchmark_28_moving(bind,Solver.state(actor))
		var ok: bool=full_prone and int(motion_cost.calls)==2128 and movement_varied and cases==POSES.size() and movement_cases==12 and transition_cases==12 and bind.bound_regions==16 and max_origin<.001 and max_basis<.005 and max_muzzle<.001 and movement_origin<.001 and movement_basis<.005 and movement_muzzle<.001
		passed=passed and ok
		var row: Dictionary={
			"weapon":weapon,"prone_applied":full_prone,"cases":cases,"movement_cases":movement_cases,"transition_cases":transition_cases,"regions":bind.bound_regions,
			"movement_origin_m":movement_origin,"movement_basis":movement_basis,"movement_muzzle_m":movement_muzzle,"motion_cost_28":motion_cost,
			"origin_m":max_origin,"basis_delta":max_basis,"muzzle_m":max_muzzle,
			"notes":notable,"pass":ok}
		summary.append(row)
		print("P1B_PRONE_WEAPON ",JSON.stringify(row))
	passed=passed and evaluated==25 and movement_evaluated==60 and transitions_evaluated==60 and rejected==20 and soft_supported==5
	print("P1B_PRONE_RESULT ",JSON.stringify({"pass":passed,"cases":evaluated,"motion_cases":movement_evaluated,"transition_cases":transitions_evaluated,"invalid_motion_rejected":rejected,"soft_aim_supported":soft_supported,"weapons":WEAPONS.size()}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
