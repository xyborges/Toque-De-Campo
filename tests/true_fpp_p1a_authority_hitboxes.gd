extends SceneTree
## P1a: verifies that authoritative hit regions ignore presentation LOD,
## including a host with a local spectator camera at five distances.
const Fixture=preload("res://tests/war_optics_fixture.gd")
var game: WarGame

func _initialize() -> void:
	run.call_deferred()

func physics_pose(actor: WarPlayer) -> Dictionary:
	var result: Dictionary={}
	for id: String in ["head","chest","abdomen","armL","armR","forearmL","forearmR","handL","handR","legL","legR","shinL","shinR"]:
		var area: Area3D=actor.hit_regions.get(id)
		if area:
			result[id]=actor.global_transform.affine_inverse()*area.global_transform
	return result

func max_transform_error(reference: Dictionary,actual: Dictionary) -> float:
	var error:=0.0
	for name_text: String in reference.keys():
		if not actual.has(name_text):continue
		var a: Transform3D=reference[name_text]
		var b: Transform3D=actual[name_text]
		error=maxf(error,a.origin.distance_to(b.origin))
		for col in 3:
			error=maxf(error,a.basis[col].distance_to(b.basis[col]))
	return error

func run() -> void:
	game=Fixture.new()
	root.add_child(game)
	await process_frame
	var observer:=game.local_player as WarPlayer
	var far_camera:=Camera3D.new()
	game.world_root.add_child(far_camera)
	far_camera.global_position=Vector3(-1600,1.68,-4)
	var authority: bool=game.multiplayer.is_server()
	var pilot: bool="--true-fpp-p1a-authority" in OS.get_cmdline_user_args()
	var samples: Array[Dictionary]=[]
	var all_ok:=authority and pilot
	for index in 5:
		var distance: float=[10.,70.,150.,300.,1700.][index]
		var actor_x: float=100.0 if distance>1000.0 else distance
		if distance>1000.0:far_camera.make_current()
		else:observer.camera.make_current()
		var actor:=game.make_actor(1900+index,false,1,"soldier",Vector3(actor_x,0,-4)) as WarPlayer
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.hp=100
		actor.deployed=true
		actor.weapon_id="g3"
		actor.owned=["g3","glock"]
		actor.loadout=actor.owned.duplicate()
		actor._refresh_weapon()
		actor.global_position=Vector3(actor_x,0,-4)
		actor.velocity=Vector3.ZERO
		actor.locomotion.reset(actor)
		actor.set_posture(0,false,true)
		actor.stance.crouch_weight=0.
		actor.stance.prone_weight=0.
		actor.next_pose_usec=0
		actor._animate_walk()
		var standing:=physics_pose(actor)
		# Force a "skip presentation" deadline. Authority must ignore it.
		actor.set_posture(2,false,true)
		actor.stance.advance(actor,1.0)
		actor.next_pose_usec=Time.get_ticks_usec()+1500000
		actor._animate_walk()
		var during:=physics_pose(actor)
		actor.next_pose_usec=0
		actor._animate_walk()
		var settled:=physics_pose(actor)
		var forced_skip_error:=max_transform_error(during,settled)
		var posture_delta:=max_transform_error(standing,settled)
		# Six 60 Hz ticks while a visual update would have been throttled.
		actor.set_posture(0,false,true)
		actor.stance.advance(actor,1.0)
		actor.next_pose_usec=0
		actor._animate_walk()
		actor.set_posture(2,false,true)
		actor.next_pose_usec=Time.get_ticks_usec()+1500000
		for tick in 6:
			actor.stance.advance(actor,1.0/60.0)
			actor._animate_walk()
		var partial:=physics_pose(actor)
		actor.next_pose_usec=0
		actor._animate_walk()
		var partial_resolved:=physics_pose(actor)
		var six_tick_error:=max_transform_error(partial,partial_resolved)
		# Camera preference of observing player should not perturb the
		# authoritative regions of this remote player.
		var reference:=physics_pose(actor)
		game.third_person=false
		observer._update_view()
		actor._animate_walk()
		var before_tpp:=physics_pose(actor)
		game.third_person=true
		observer._update_view()
		actor._animate_walk()
		var after_tpp:=physics_pose(actor)
		var observer_error:=maxf(max_transform_error(reference,before_tpp),max_transform_error(reference,after_tpp))
		var no_water:=not actor.in_water()
		var passed: bool=no_water and forced_skip_error<.001 and six_tick_error<.001 and observer_error<.001 and posture_delta>.3
		all_ok=all_ok and passed
		samples.append({"distance_m":distance,"physical_regions":settled.size(),"prone_pose_delta_m":posture_delta,"forced_skip_error_m":forced_skip_error,"six_tick_error_m":six_tick_error,"observer_camera_error_m":observer_error,"in_water":not no_water,"ok":passed})
	var result: Dictionary={"authority":authority,"pilot_enabled":pilot,"samples":samples,"pass":all_ok and samples.size()==5}
	var file:=FileAccess.open("res://work/fpp-tpp-p1a-20261104/authority-hitbox-qa.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(result,"\t"));file.close()
	print("TRUE_FPP_P1A_AUTHORITY ",JSON.stringify({"authority":authority,"pass":result.pass,"samples":samples}))
	game.queue_free()
	await process_frame
	quit(0 if result.pass else 1)
