extends SceneTree
## QA contract for the eventual collision rig independent from visual rig.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Physical=preload("res://modes/war/scripts/collision_pose_state.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var observer:=game.local_player as WarPlayer
	var target:=game.players[2] as WarPlayer
	target.set_process(false)
	target.set_physics_process(false)
	target.deployed=true
	target.hp=100.
	target.weapon_id="g3"
	target.owned=["g3","glock"]
	target.loadout=target.owned.duplicate()
	target._refresh_weapon()
	var checks: Array[Dictionary]=[]
	var passed:=true
	for stance_value in [0,1,2]:
		target.set_posture(stance_value,false,true)
		target.stance.advance(target,1.0)
		target.next_pose_usec=0
		target._animate_walk()
		var base: Dictionary=Physical.capture(target)
		game.third_person=false
		observer._update_view()
		var in_fpp: Dictionary=Physical.capture(target)
		game.third_person=true
		observer._update_view()
		var in_tpp: Dictionary=Physical.capture(target)
		var parity: Dictionary=Physical.compare(in_fpp,in_tpp)
		var initial: Dictionary=Physical.compare(base,in_fpp)
		var valid: bool=base.regions.size()>=13 and base.has_muzzle and parity.missing.is_empty() and initial.missing.is_empty() and parity.max_origin_m<.000001 and initial.max_origin_m<.000001 and parity.muzzle_origin_m<.000001
		passed=passed and valid
		checks.append({"posture":stance_value,"regions":base.regions.size(),"view_parity":parity,"unchanged":initial,"ok":valid})
	var snapshot: Dictionary=Physical.capture(target)
	target.pitch=.45
	target.lean=.5
	target.next_pose_usec=0
	target._animate_walk()
	var moved: Dictionary=Physical.capture(target)
	var updated: Dictionary=Physical.compare(snapshot,moved)
	var moved_ok: bool=updated.max_origin_m>.02 and updated.muzzle_origin_m>.02
	passed=passed and moved_ok
	var result: Dictionary={"pass":passed,"posture_checks":checks,"pose_reacts_to_aim":updated,"pose_reacts_ok":moved_ok,"note":"Read-only collision transform contract. No separated collision hierarchy yet."}
	var file:=FileAccess.open("res://work/fpp-tpp-p1a-20261104/collision-snapshot-qa.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("COLLISION_POSE_SNAPSHOT ",JSON.stringify({"pass":passed,"postures":checks.size(),"pose_reacts":moved_ok,"max_aim_delta_m":updated.max_origin_m,"muzzle_aim_delta_m":updated.muzzle_origin_m}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
