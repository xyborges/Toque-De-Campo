extends "res://tests/realismo_r2c_world_pilot.gd"

const FRAME = preload("res://modes/war/scripts/tactical_pose_frame.gd")

func region_mounts(actor: WarPlayer) -> Dictionary:
	var out: Dictionary={}
	for id: String in actor.hit_regions:
		var area:=actor.hit_regions[id] as Area3D
		var parent:=area.get_parent() as Node3D
		out[id]=parent.global_transform.affine_inverse()*area.global_transform
	return out

func pure_contract() -> void:
	var frame:=FRAME.new()
	check(not frame.valid_for(0,0),"new frame has no valid tick/life")
	var pelvis_base:=Transform3D(Basis.from_euler(Vector3(.12,-.24,.07))*Basis.from_scale(Vector3.ONE*1.12),Vector3(.02,.87,-.03))
	var torso_base:=Transform3D(Basis.from_euler(Vector3(-.17,.08,-.05))*Basis.from_scale(Vector3.ONE*.91),Vector3(.01,1.24,.02))
	for longitudinal in [-1.,0.,1.]:
		for lateral in [-1.,0.,1.]:
			for landing in [0.,.5,1.]:
				var offset:=BODY.hip_offset(longitudinal,lateral,landing)
				frame.compose(pelvis_base,torso_base,offset,BODY.hip_angles(longitudinal,lateral),BODY.torso_angles(longitudinal,lateral,landing),60,4)
				check(frame.pelvis_base.is_equal_approx(pelvis_base) and frame.torso_base.is_equal_approx(torso_base),"frame preserves both authored bases")
				check(frame.pelvis.origin.is_equal_approx(pelvis_base.origin+offset) and frame.torso.origin.is_equal_approx(torso_base.origin),"translation stays in the authored parent space")
				check(is_equal_approx(frame.pelvis.basis.determinant(),pelvis_base.basis.determinant()) and is_equal_approx(frame.torso.basis.determinant(),torso_base.basis.determinant()),"composition preserves body scale")
	check(frame.valid_for(60,4) and not frame.valid_for(61,4) and not frame.valid_for(60,5),"tick and life changes reject the prior result")
	frame.invalidate()
	check(not frame.valid_for(60,4),"explicit invalidation rejects the prior result")

func run() -> void:
	pure_contract()
	var game:=FIXTURE.new() as WarGame
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	actor.set_process(false);actor.set_physics_process(false)
	actor.weapon_id="g3";actor._refresh_weapon()
	check(not is_instance_valid(actor.locomotion.world_pose_frame),"OFF creates no frame")
	configure(actor)
	var off:=snapshot(actor,false)
	var mounts:=region_mounts(actor)
	var on:=snapshot(actor,true)
	var frame: FRAME=actor.locomotion.world_pose_frame
	check(is_instance_valid(frame),"eligible non-neutral local pose allocates a frame")
	check(frame.valid_for(Engine.get_physics_frames(),actor.life_id),"runtime frame uses engine physics tick and actor life")
	check(frame.pelvis.is_equal_approx(on.pelvis) and frame.torso.is_equal_approx(on.torso),"both physical pivots publish the same composed result")
	check(frame.pelvis_base.is_equal_approx(off.pelvis) and frame.torso_base.is_equal_approx(off.torso),"frame starts from the unmodified base pose")
	var after:=region_mounts(actor)
	check(mounts.size()==16,"all sixteen damage regions are present")
	for id: String in mounts:
		check((mounts[id] as Transform3D).is_equal_approx(after[id]),"region mount preserved: "+id)
	var again:=snapshot(actor,true)
	check(actor.locomotion.world_pose_frame==frame,"active ticks reuse the frame object")
	check((again.pelvis as Transform3D).is_equal_approx(on.pelvis) and (again.torso as Transform3D).is_equal_approx(on.torso),"rebuilding in the same tick has no accumulated offset")
	check((off.muzzle as Transform3D).is_equal_approx(on.muzzle) and (off.weapon as Transform3D).is_equal_approx(on.weapon),"frame preserves world weapon and true muzzle")
	check((off.camera as Transform3D).is_equal_approx(on.camera) and (off.body_collision as Transform3D).is_equal_approx(on.body_collision),"camera and movement capsule preserve baseline")
	await physics_frame
	check(not frame.valid_for(Engine.get_physics_frames(),actor.life_id),"old result is identifiable after a real physics tick")
	snapshot(actor,true)
	check(frame.valid_for(Engine.get_physics_frames(),actor.life_id),"next physics tick composes a fresh result")
	var restored:=snapshot(actor,false)
	unchanged(off,restored,"frame OFF restores base")
	check(not frame.valid_for(Engine.get_physics_frames(),actor.life_id),"OFF invalidates the published result")

	for state in ["ADS","reload","crouch","prone","vehicle","dead","remote","bot","online"]:
		configure(actor)
		snapshot(actor,true)
		match state:
			"ADS": actor.iron_sights=true
			"reload": actor.reload_left=.5
			"crouch": actor.crouched=true
			"prone": actor.prone=true
			"vehicle": actor.vehicle_id="test_vehicle"
			"dead": actor.hp=0.
			"remote": actor.is_local=false
			"bot": actor.set_meta("war_bot",true)
			"online": actor.game.offline_operation=false
		snapshot(actor,true)
		check(not frame.valid_for(Engine.get_physics_frames(),actor.life_id),state+" invalidates prior frame")
	configure(actor)
	actor.locomotion.world_pose_frame=null
	actor.locomotion.presentation_longitudinal=0.;actor.locomotion.presentation_lateral=0.;actor.locomotion.presentation_landing=0.
	snapshot(actor,true)
	check(not is_instance_valid(actor.locomotion.world_pose_frame),"neutral weights allocate no frame")
	actor.set_meta("war_bot",true)
	actor.locomotion.presentation_longitudinal=1.
	snapshot(actor,true)
	check(not is_instance_valid(actor.locomotion.world_pose_frame),"blocked bot allocates no frame")
	check(Engine.physics_ticks_per_second==60,"physics cadence stays 60 Hz")
	print("REALISMO_R2C_POSE_FRAME_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"regions":mounts.size(),"scope":"local offline pivots only"}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
