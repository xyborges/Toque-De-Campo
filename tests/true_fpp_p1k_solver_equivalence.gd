extends "res://tests/true_fpp_p1k_paired_cost.gd"
## Compare against the unmodified solver extracted from the pinned Git commit.
var reference: Script
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")
var failures: Array[String]=[]
var comparisons:=0
var maximum:=0.

func equal_value(a: Variant,b: Variant,path: String) -> void:
	comparisons+=1
	if typeof(a)!=typeof(b):
		failures.append(path+" type")
		return
	if a is Dictionary:
		if a.size()!=b.size(): failures.append(path+" keys")
		for key in a:
			if not b.has(key): failures.append(path+" missing "+str(key))
			else: equal_value(a[key],b[key],path+"/"+str(key))
		return
	var error:=0.
	if a is Transform3D:
		error=a.origin.distance_to(b.origin)
		for axis in 3: error=maxf(error,a.basis[axis].distance_to(b.basis[axis]))
	elif a is Basis:
		for axis in 3: error=maxf(error,a[axis].distance_to(b[axis]))
	elif a is Vector3: error=a.distance_to(b)
	elif a is float: error=absf(a-b)
	elif a!=b: failures.append(path+" value")
	maximum=maxf(maximum,error)
	if not is_finite(error) or error>.00001: failures.append(path+" numeric "+str(error))

func run() -> void:
	# A fresh checkout can import this script before the runner extracts Git.
	if not FileAccess.file_exists("res://work/p1k-reference/collision_pose_solver.gd"):
		push_error("Run tests/run_true_fpp_p1k_solver_equivalence.py to prepare the reference")
		quit(1)
		return
	reference=load("res://work/p1k-reference/collision_pose_solver.gd")
	equal_value(reference.solve({},{}),Solver.solve({},{}),"empty input/binding")
	game=Fixture.new()
	root.add_child(game)
	await process_frame
	for actor: WarPlayer in game.players.values():
		actor.set_process(false)
		actor.set_physics_process(false)
	var actor:=game.players[2] as WarPlayer
	var cases:=0
	var rejected:=0
	var rng:=RandomNumberGenerator.new()
	rng.seed=523117
	for index in WEAPONS.size():
		configure(actor,index,false)
		var binding:=Solver.bind(actor)
		equal_value(reference.bind(actor),binding,"bind")
		equal_value(reference.solve({},Solver.state(actor)),Solver.solve({},Solver.state(actor)),"missing binding")
		var cached:=Solver.Calibration.from_dictionary(binding)
		var captured:=Solver.PoseInput.new()
		actor.p1g_set_collision_pilot(true)
		for tick in 240:
			advance(actor,index,tick)
			Solver.capture(actor,captured)
			var input: Dictionary=reference.state(actor)
			for key in input: equal_value(input[key],captured.get(key),"capture/"+key)
			input.pitch=rng.randf_range(-1.5,1.5)
			input.lean=rng.randf_range(-1.,1.)
			input.direction=Vector3(rng.randf_range(-1.,1.),0.,rng.randf_range(-1.,1.))
			input.moving=rng.randf()
			input.sprint=rng.randf()
			input.crouch_weight=rng.randf()
			input.prone_weight=rng.randf()
			input.aiming=tick%3==0
			input.iron=tick%5==0
			if tick%4==0:
				input.reload_total=3.
				input.reload_left=3.*rng.randf()
				input.reload_weapon=actor.weapon_id
			var presentation:=tick%2==0
			var expected: Dictionary=reference.solve(binding,input,presentation)
			var actual:=Solver.solve_cached(cached,Solver.PoseInput.from_dictionary(input),presentation)
			equal_value(expected,actual,"solve/"+actor.weapon_id+"/"+str(tick))
			if tick%32==0: equal_value(expected,Solver.solve(binding,input,presentation),"adapter")
			var packed:=Solver.solve_cached(cached,Solver.PoseInput.from_dictionary(input),presentation,true)
			var unpacked:=packed.duplicate()
			unpacked.erase("poses")
			var regions: Dictionary={}
			for region_index in cached.region_ids.size():
				regions[cached.region_ids[region_index]]=packed.poses[region_index]
			unpacked["regions"]=regions
			equal_value(expected,unpacked,"packed")
			if not actor.p1g_collision_rig.sync_packed(packed): failures.append("packed sync rejected")
			var snapshot:=actor.p1g_collision_rig.snapshot()
			equal_value(expected.regions,snapshot.regions,"physical regions")
			equal_value(expected.muzzle,snapshot.muzzle,"physical muzzle")
			cases+=1
			if failures.size()>20: break
		var input: Dictionary=reference.state(actor)
		for field in ["reaction","attack","recoil","fire_cooldown","special","legs_intact","grounded"]:
			var invalid:=input.duplicate()
			invalid[field]=false if field in ["legs_intact","grounded"] else (true if field=="special" else .25)
			var expected: Dictionary=reference.solve(binding,invalid)
			var actual:=Solver.solve_cached(cached,Solver.PoseInput.from_dictionary(invalid))
			equal_value(expected,actual,"reject/"+field)
			if not actual.supported: rejected+=1
	var passed:=failures.is_empty() and cases==1200 and rejected==35
	print("P1K_EQUIVALENCE ",JSON.stringify({"pass":passed,"cases":cases,"comparisons":comparisons,"rejected":rejected,"max_error":maximum,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
