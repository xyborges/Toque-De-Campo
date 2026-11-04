extends SceneTree
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.players[2] as WarPlayer
	actor.set_process(false);actor.set_physics_process(false)
	actor.deployed=true;actor.hp=100.;actor.weapon_id="g3"
	actor.owned=["g3","glock"];actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor._refresh_weapon()
	actor.velocity=Vector3.ZERO
	actor.locomotion.reset(actor)
	actor.stance.crouch_weight=0;actor.stance.prone_weight=0
	actor.set_posture(0,false,true)
	actor.pitch=0;actor.lean=0;actor.recoil=0;actor.attack_anim=0
	actor.iron_sights=false;actor.aiming=false
	actor.next_pose_usec=0;actor._animate_walk()
	var binding: Dictionary=Solver.bind(actor)
	var rows: Array[Dictionary]=[]
	var errors: Array[String]=[]
	var max_pos:=0.
	var max_basis:=0.
	var max_muzzle:=0.
	for opts in [
		{"pitch":0.0,"lean":0.0},
		{"pitch":0.36,"lean":0.0},
		{"pitch":-0.50,"lean":0.0},
		{"pitch":0.2,"lean":0.45},
		{"pitch":-0.25,"lean":-0.35}
	]:
		actor.pitch=opts.pitch;actor.lean=opts.lean
		actor.next_pose_usec=0;actor._animate_walk()
		var expected: Dictionary=Snapshot.capture(actor)
		var state: Dictionary=Solver.state(actor)
		var solved: Dictionary=Solver.solve(binding,state)
		if not bool(solved.get("supported",false)):
			errors.append("unsupported "+str(opts)+" "+str(solved.get("reason","")))
			continue
		var diff: Dictionary=Snapshot.compare(expected,solved)
		max_pos=maxf(max_pos,diff.max_origin_m)
		max_basis=maxf(max_basis,diff.max_basis_delta)
		max_muzzle=maxf(max_muzzle,diff.muzzle_origin_m)
		rows.append({"inputs":opts,"position_m":diff.max_origin_m,"basis_delta":diff.max_basis_delta,"muzzle_m":diff.muzzle_origin_m,"missing":diff.missing,"per_region":diff.per_region})
	var bad: Dictionary=Solver.state(actor)
	bad.prone_weight=.8
	var reject: Dictionary=Solver.solve(binding,bad)
	var summary: Dictionary={"binding_regions":binding.bound_regions,"cases":rows,"errors":errors,"max_position_m":max_pos,"max_basis_delta":max_basis,"max_muzzle_m":max_muzzle,"unsupported_rejected":not bool(reject.get("supported",true))}
	summary["pass"]=binding.bound_regions>=13 and errors.is_empty() and rows.size()==5 and max_pos<.015 and max_basis<.05 and max_muzzle<.005 and summary.unsupported_rejected
	var file:=FileAccess.open("res://work/fpp-tpp-p1a-20261104/collision-math-standing.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("COLLISION_MATH_STANDING ",JSON.stringify({"pass":summary.pass,"rows":rows.size(),"position_m":max_pos,"basis_delta":max_basis,"muzzle_m":max_muzzle,"binding_regions":binding.bound_regions,"errors":errors}))
	for row: Dictionary in rows:
		var top: Array[String]=[]
		for id: String in row.per_region:
			if float(row.per_region[id].origin_m)>.01:top.append(id+":"+str(snappedf(float(row.per_region[id].origin_m),.001)))
		print("DETAIL_MATH ",JSON.stringify({"input":row.inputs,"offsets":top,"muzzle":row.muzzle_m}))
	game.queue_free()
	await process_frame
	quit(0 if summary.pass else 1)
