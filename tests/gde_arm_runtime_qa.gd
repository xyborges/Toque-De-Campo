extends SceneTree
## End-to-end G3/FAL/AK/Glock/Sniper both-arm batch parity (real scene/hitboxes).
var checks:=0
var failures: Array[String]=[]
var worst_error:=0.0

func _initialize() -> void:_run.call_deferred()

func check(value: bool,message: String) -> void:
	checks+=1
	if not value and failures.size()<16:failures.append(message)

func error(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),
		maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))

func snapshot(actor: WarPlayer) -> Array:
	var result: Array=[]
	for side in ["R","L"]:
		var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
		for node in [arm,arm.get_node("Arm"+side+"Mesh"),arm.get_node("Forearm"+side+"Mesh"),arm.get_node("Hand"+side)]:
			result.append((node as Node3D).transform)
		for region_id in ["arm"+side,"forearm"+side,"hand"+side]:
			var area: Area3D=actor.hit_regions.get(region_id)
			if area:result.append(area.global_transform)
	return result

func clear_arm_cache(actor: WarPlayer) -> void:
	actor.avatar_parts.arm_r.remove_meta("human_pose_cache")
	actor.avatar_parts.arm_l.remove_meta("human_pose_cache")

func _run() -> void:
	if not ClassDB.class_exists("WarNativePoseMath"):
		print("GDE_ARM_RUNTIME_QA ",JSON.stringify({"error":"native class absent"}))
		quit(2);return
	var original_mode: bool=GameInfantryPose.native_pose_enabled
	GameInfantryPose.native_pose_enabled=false
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	if actor==null or not actor.get_meta("articulated_arms",false):
		print("GDE_ARM_RUNTIME_QA ",JSON.stringify({"error":"no articulated WarPlayer fixture"}))
		GameInfantryPose.native_pose_enabled=original_mode
		game.queue_free()
		quit(2);return
	var cases:=0
	for weapon in ["g3","fal","glock","ak","sniper"]:
		actor.weapon_id=weapon
		actor._refresh_weapon()
		for pitch in [-1.2,-.45,0.,.55,1.15]:
			for lean in [-.85,0.,.85]:
				for prone_weight in [0.,.7]:
					actor.pitch=pitch
					actor.lean=lean
					actor.stance.prone_weight=prone_weight
					actor._update_weapon_pose()
					var right:=actor.weapon_hand_target(false)
					var left:=actor.weapon_hand_target(true)
					clear_arm_cache(actor)
					GameInfantryPose.native_pose_enabled=false
					actor._pose_arms_pair(right,left)
					var baseline:=snapshot(actor)
					clear_arm_cache(actor)
					var prev_calls:=WarHumanRig.native_batch_calls
					var prev_arms:=WarHumanRig.native_solved_arms
					var prev_direct:=WarHumanRig.native_direct_arms
					GameInfantryPose.native_pose_enabled=true
					actor._pose_arms_pair(right,left)
					var native:=snapshot(actor)
					cases+=1
					check(WarHumanRig.native_batch_calls-prev_calls==1,
						"expected 1 native crossing on pair "+str(cases))
					check(WarHumanRig.native_solved_arms-prev_arms==2,
						"expected 2 arms per native call "+str(cases))
					check(WarHumanRig.native_direct_arms-prev_direct==2,
						"expected direct native scene writes for 2 arms "+str(cases))
					check(baseline.size()==native.size(),"missing pose outputs "+str(cases))
					if baseline.size()!=native.size():continue
					for i in baseline.size():
						var e:=error(baseline[i],native[i])
						worst_error=maxf(worst_error,e)
						check(e<.001,"scene pose diverged "+weapon+" case "+str(cases)+" part "+str(i)+" error "+str(e))
	GameInfantryPose.native_pose_enabled=original_mode
	game.queue_free()
	await process_frame
	print("GDE_ARM_RUNTIME_QA ",JSON.stringify({"checks":checks,"failures":failures,
		"cases":cases,"max_transform_error":worst_error,
		"native_calls_total":WarHumanRig.native_batch_calls,
		"native_arms_total":WarHumanRig.native_solved_arms,
		"native_direct_arms":WarHumanRig.native_direct_arms}))
	quit(0 if failures.is_empty() else 1)
