extends SceneTree
## Compare the old two-arm preparation with the shared per-pair inputs:
## same real player, weapon models, reload state, pitch, lean and wrist.
var checks:=0
var failures: Array[String]=[]
var max_error:=0.0

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool,message: String) -> void:
	checks+=1
	if not ok and failures.size()<12:failures.append(message)

func _diff(a: Variant,b: Variant) -> float:
	if a is Vector3:return (a as Vector3).distance_to(b)
	if a is Basis:
		var aa: Basis=a
		var bb: Basis=b
		return maxf(aa.x.distance_to(bb.x),maxf(aa.y.distance_to(bb.y),aa.z.distance_to(bb.z)))
	if a is float:return absf(a-b)
	return 0. if a==b else INF

func _median(values: Array) -> float:
	var sorted: Array=values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size()/2])

func _bench(actor: WarPlayer,batched: bool,iterations: int) -> float:
	var right: Vector3=actor.weapon_hand_target(false)
	var left: Vector3=actor.weapon_hand_target(true)
	var total:=0.0
	var start:=Time.get_ticks_usec()
	for i in iterations:
		actor.pitch=sin(i*.074)*.8
		actor.lean=sin(i*.046)*.6
		var shared: Dictionary={"pair":true} if batched else {}
		var r: Dictionary=WarHumanRig._prepare_arm(actor,actor.avatar_parts.arm_r,right,"armR",null,shared)
		var l: Dictionary=WarHumanRig._prepare_arm(actor,actor.avatar_parts.arm_l,left,"armL",null,shared)
		if not r.is_empty():total+=r.upper_basis.x.x
		if not l.is_empty():total+=l.upper_basis.z.z
	if not is_finite(total):failures.append("bench checksum invalid")
	return (Time.get_ticks_usec()-start)*.001

func _run() -> void:
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	if not is_instance_valid(actor) or not bool(actor.get_meta("articulated_arms",false)):
		failures.append("fixture does not provide articulated WarPlayer")
		_finish(game,{});return
	var cases:=0
	for weapon in ["g3","fal","glock","ak","sniper"]:
		actor.weapon_id=weapon
		actor._refresh_weapon()
		for pitch in [-1.1,0.,1.0]:
			for lean in [-.8,0.,.8]:
				for prone_weight in [0.,.7]:
					actor.pitch=pitch
					actor.lean=lean
					actor.stance.prone_weight=prone_weight
					actor._update_weapon_pose()
					var targets: Array[Vector3]=[actor.weapon_hand_target(false),actor.weapon_hand_target(true)]
					var shared: Dictionary={"pair":true}
					for side in 2:
						var arm: Node3D=actor.avatar_parts.arm_r if side==0 else actor.avatar_parts.arm_l
						var group: String="armR" if side==0 else "armL"
						var original: Dictionary=WarHumanRig._prepare_arm(actor,arm,targets[side],group)
						var optimized: Dictionary=WarHumanRig._prepare_arm(actor,arm,targets[side],group,null,shared)
						cases+=1
						verify(original.is_empty()==optimized.is_empty(),"empty mismatch "+str(cases))
						if original.is_empty() or optimized.is_empty():continue
						for field in ["canonical","shoulder","grip","hand_basis","upper_basis","cuff","proportion","firearm","grabbing","side"]:
							var err:=_diff(original[field],optimized[field])
							max_error=maxf(max_error,err)
							verify(err<.00001,"field "+field+" diverged case "+str(cases)+": "+str(err))
					verify(shared.has("body_inv") and shared.has("upper_basis") and shared.has("hand_basis"),"shared input missing "+str(cases))
	# A/B repeated with alternating order to cancel warm-up / scheduling bias.
	actor.weapon_id="fal"
	actor._refresh_weapon()
	actor._update_weapon_pose()
	var measured: Dictionary={"plain":[],"dedup":[]}
	for warmup in 2:
		_bench(actor,false,100)
		_bench(actor,true,100)
	for round_id in 7:
		var order:=["plain","dedup"] if round_id%2==0 else ["dedup","plain"]
		for mode in order:
			measured[mode].append(_bench(actor,mode=="dedup",1600))
	var medians: Dictionary={}
	for mode: String in measured:
		medians[mode]=_median(measured[mode])
	_finish(game,{"cases":cases,"medians_ms":medians,"shared_speedup":float(medians.plain)/maxf(.001,float(medians.dedup)),"native_mode":GameInfantryPose.native_pose_enabled})

func _finish(game: WarGame,stats: Dictionary) -> void:
	print("GDE_NATIVE_DEDUP_QA ",JSON.stringify({"checks":checks,"failures":failures,"max_error":max_error,"stats":stats}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
