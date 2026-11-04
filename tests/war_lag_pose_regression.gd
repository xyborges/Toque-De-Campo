extends SceneTree
# Compare the complete final combat rig with the saved pre-fix sources.
var checks:=0
var failures: Array[String]=[]
var capture_path:="res://work/war-lag-pose-after.json"
var reference_path:=""
var game: WarGame
var poses: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):capture_path=arg.trim_prefix("--capture=")
		if arg.begins_with("--reference="):reference_path=arg.trim_prefix("--reference=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func components(value: Transform3D) -> Array:
	return [value.origin.x,value.origin.y,value.origin.z,value.basis.x.x,value.basis.x.y,value.basis.x.z,value.basis.y.x,value.basis.y.y,value.basis.y.z,value.basis.z.x,value.basis.z.y,value.basis.z.z]
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game)
	game.vehicle_system.set_process(false);game.third_person=true
	var actor:=game.local_player as WarPlayer
	for weapon in ["fal","ak","sniper","glock"]:
		actor.weapon_id=weapon;actor._refresh_weapon()
		for posture in [0,1,2]:
			actor.set_posture(posture,false,true)
			actor.stance.crouch_weight=1. if posture==1 else 0.
			actor.stance.prone_weight=1. if posture==2 else 0.
			for pitch in [-.38,0.,.75]:
				for lean in [-.6,0.,.6]:
					for reloading in [false,true]:
						actor.pitch=pitch;actor.lean=lean;actor.velocity=Vector3.ZERO
						actor.reload_weapon=weapon if reloading else "";actor.reload_total=3.;actor.reload_left=1.2 if reloading else 0.
						actor.stance.advance(actor,0.);actor.locomotion.moving=0.;actor.locomotion.sprint=0.;actor._animate_walk()
						var key:="%s:%d:%s:%s:%s"%[weapon,posture,pitch,lean,reloading]
						var row: Dictionary={"body":components(actor.body_root.global_transform),"weapon":components(actor.weapon_root.global_transform),"muzzle":components(actor.muzzle_marker.global_transform)}
						for id in actor.hit_regions:row[id]=components((actor.hit_regions[id] as Area3D).global_transform)
						poses[key]=row
						for side in ["L","R"]:check(float(actor.avatar_parts["arm_"+side.to_lower()].get_meta("grip_error",1.))<.002,"hand contact "+key+side)
	actor.set_posture(0,false,true);actor.stance.crouch_weight=0.;actor.stance.prone_weight=0.;actor.reload_weapon="";actor.reload_left=0.;actor.pitch=0.;actor.lean=0.;actor.stance.advance(actor,0.);actor._animate_walk()
	actor._set_hitboxes_enabled(true)
	await physics_frame;await physics_frame
	for id in ["head","chest","abdomen","legL","shinR"]:
		var area: Area3D=actor.hit_regions[id]
		var centre:=area.global_position
		var query:=PhysicsRayQueryParameters3D.create(centre+Vector3(-2,0,0),centre+Vector3(2,0,0),2)
		query.collide_with_areas=true;query.collide_with_bodies=false
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and actor.is_ancestor_of(hit.collider),"ballistics still hit live body region "+id)
	for phase in [0.,.3,1.2,2.6,4.1,5.7]:
		actor.locomotion.phase=phase;actor.locomotion.moving=1.;actor.locomotion.sprint=.5;actor.locomotion.grounded=true;actor._animate_walk()
		var lowest:=INF
		for data: Dictionary in actor.stance.leg_parts.values():
			var pose: Transform3D=data.joint.transform*data.knee.transform*data.shoe.transform
			for point: Vector3 in data.foot_corners:lowest=minf(lowest,(actor.body_root.basis*(pose*point)).y)
		check(absf(actor.stance._walking_ground_offset(actor)-(actor.stance.reference_foot_y-lowest))<.00001,"walking sole support remains exact "+str(phase))
	if not reference_path.is_empty():
		var reference:=NavalStorage.read_json(reference_path)
		check(reference.has("poses") and reference.poses.size()==poses.size(),"complete reference")
		for key in poses:
			if not reference.get("poses",{}).has(key):continue
			for part in poses[key]:
				var expected: Array=reference.poses[key][part];var actual: Array=poses[key][part];var error:=0.
				for index in actual.size():error=maxf(error,absf(float(expected[index])-float(actual[index])))
				check(error<.0001,"same final rig "+key+"/"+part+" error="+str(error))
	NavalStorage.write_json(capture_path,{"checks":checks,"failures":failures,"poses":poses})
	print("WAR_LAG_POSE ",JSON.stringify({"checks":checks,"failures":failures,"poses":poses.size()}))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
