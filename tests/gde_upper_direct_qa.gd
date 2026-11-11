extends SceneTree
## Full runtime pose parity including every visual pivot and regional hitbox.
## No render/physics culling: upper native direct mutates same nodes at 60 Hz.
var checks:=0
var failures: Array[String]=[]
var max_error:=0.0
var median_reference:=0.0
var median_native:=0.0

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool,why: String) -> void:
	checks+=1
	if not ok and failures.size()<24:failures.append(why)

func _error(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),
		maxf(a.basis.x.distance_to(b.basis.x),
		maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))

func _snapshot(actor: WarPlayer) -> Dictionary:
	var result: Dictionary={}
	var pelvis:=actor.body_root.get_node("Pelvis") as Node3D
	result["pelvis"]=pelvis.transform
	for key in ["torso","head","arm_l","arm_r","leg_l","leg_r"]:
		var node:=actor.avatar_parts.get(key) as Node3D
		if node:result[key]=node.transform
	for key in actor.hit_regions:
		var area:=actor.hit_regions[key] as Area3D
		if area:result["region_"+str(key)]=area.global_transform
	return result

func _apply(actor: WarPlayer,native: bool,torso_rotation: Vector3,legs_rotation: Vector3) -> Dictionary:
	actor.avatar_parts.torso.rotation=torso_rotation
	actor.avatar_parts.leg_l.rotation=legs_rotation
	actor.avatar_parts.leg_r.rotation=legs_rotation
	GameInfantryPose.native_upper_direct_enabled=native
	GameInfantryPose.apply(actor)
	return _snapshot(actor)

func _bench(actor: WarPlayer,native: bool,iterations: int) -> float:
	GameInfantryPose.native_upper_direct_enabled=native
	var start:=Time.get_ticks_usec()
	for i in iterations:
		actor.pitch=sin(i*.035)*1.0
		actor.lean=sin(i*.046)*.8
		actor.avatar_parts.torso.rotation.x=sin(i*.02)*.09
		GameInfantryPose.apply(actor)
	return (Time.get_ticks_usec()-start)*.001

func _median(data: Array) -> float:
	var sorted:=data.duplicate()
	sorted.sort()
	return float(sorted[sorted.size()/2])

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath") or not ClassDB.class_has_method("WarNativePoseMath","apply_upper_direct"):
		failures.append("native upper direct method missing")
		_finish(null,0);return
	var original_mode:=GameInfantryPose.native_pose_enabled
	var original_direct:=GameInfantryPose.native_upper_direct_enabled
	var args:=OS.get_cmdline_user_args()
	verify(original_direct==(args.has("--experimental-native-upper") and not args.has("--war-upper-legacy")),"native upper must require explicit experimental flag")
	GameInfantryPose.native_pose_enabled=true
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	if not is_instance_valid(actor) or not GameInfantryPose.allowed(actor):
		failures.append("WarPlayer fixture not ready")
		GameInfantryPose.native_pose_enabled=original_mode
		GameInfantryPose.native_upper_direct_enabled=original_direct
		_finish(game,0);return
	# Seed the original upper-body rest dictionary before varying animation.
	GameInfantryPose.native_upper_direct_enabled=false
	GameInfantryPose.apply(actor)
	var cases:=0
	for weapon in ["fal","g3","glock","ak","sniper"]:
		actor.weapon_id=weapon
		actor._refresh_weapon()
		for pitch in [-1.15,-.65,0.,.44,.98]:
			for lean in [-1.,-.5,0.,.5,1.]:
				for body_size in [.68,1.,1.42]:
					actor.pitch=pitch
					actor.lean=lean
					actor.body_proportions["torso"]=body_size
					actor.body_proportions["head"]=1.6-body_size*.4
					var rot:=Vector3(.06*sin(cases*.2),.01,-.04*cos(cases*.17))
					var leg_rot:=Vector3(.13,-.05,.03)
					var reference:=_apply(actor,false,rot,leg_rot)
					var actual:=_apply(actor,true,rot,leg_rot)
					cases+=1
					for key in reference:
						verify(actual.has(key),"missing "+str(key))
						if actual.has(key):
							var e:=_error(reference[key],actual[key])
							max_error=maxf(max_error,e)
							verify(e<.00012,"pose difference "+str(key)+" #"+str(cases)+" "+str(e))
	# Four alternating passes avoid counting only first-call library warm-up.
	actor.weapon_id="fal"
	actor._refresh_weapon()
	var measures: Dictionary={"gd":[],"native":[]}
	for i in 2:
		_bench(actor,false,100)
		_bench(actor,true,100)
	for round_id in 5:
		var modes:=["gd","native"] if round_id%2==0 else ["native","gd"]
		for mode in modes:
			measures[mode].append(_bench(actor,mode=="native",800))
	median_reference=_median(measures["gd"])
	median_native=_median(measures["native"])
	GameInfantryPose.native_pose_enabled=original_mode
	GameInfantryPose.native_upper_direct_enabled=original_direct
	_finish(game,cases)

func _finish(game: WarGame,cases: int) -> void:
	print("GDE_UPPER_DIRECT_QA ",JSON.stringify({"checks":checks,"failures":failures,
		"cases":cases,"max_error":max_error,"gd_median_ms":median_reference,
		"native_median_ms":median_native,
		"speedup":median_reference/maxf(.001,median_native)}))
	if is_instance_valid(game):game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
