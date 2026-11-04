extends SceneTree
## P0b collision-pose LOD audit: no changes to game code.
const Fixture=preload("res://tests/war_optics_fixture.gd")
var game: WarGame

func _initialize() -> void:
	run.call_deferred()

func anchors(actor: WarPlayer) -> Dictionary:
	var out: Dictionary={}
	for name_text in ["head","chest","armL","armR","legL","legR","shinL","shinR"]:
		var node: Area3D=actor.hit_regions.get(name_text)
		if node:
			out[name_text]=actor.to_local(node.global_position)
	return out

func drift(reference: Dictionary,actual: Dictionary) -> Dictionary:
	var per: Dictionary={}
	var maximum:=0.0
	for label: String in reference:
		if not actual.has(label):continue
		var amount: float=Vector3(reference[label]).distance_to(Vector3(actual[label]))
		per[label]=amount
		maximum=maxf(maximum,amount)
	return {"max_m":maximum,"per_region":per}

func run() -> void:
	game=Fixture.new()
	root.add_child(game)
	await process_frame
	var observer: WarPlayer=game.local_player as WarPlayer
	observer.camera.make_current()
	var long_range_observer:=Camera3D.new()
	game.world_root.add_child(long_range_observer)
	long_range_observer.global_position=Vector3(-1600,1.68,-4)
	var results: Array[Dictionary]=[]
	var scenario_index:=0
	for metres in [10.0,70.0,150.0,300.0,1700.0]:
		var x_position: float=100.0 if metres>1000.0 else metres
		if metres>1000.0:long_range_observer.make_current()
		else:observer.camera.make_current()
		var remote: WarPlayer=game.make_actor(1000+scenario_index,false,1,"soldier",Vector3(x_position,0.0,-4.0))
		scenario_index+=1
		remote.set_process(false)
		remote.set_physics_process(false)
		remote.deployed=true
		remote.hp=100.0
		remote.weapon_id="g3"
		remote.owned=["g3","glock"]
		remote.loadout=remote.owned.duplicate()
		remote._refresh_weapon()
		remote.global_position=Vector3(x_position,0.0,-4.0)
		remote.velocity=Vector3.ZERO
		remote.locomotion.reset(remote)
		var standing_set: bool=remote.set_posture(0,false,true)
		remote.stance.crouch_weight=0.0
		remote.stance.prone_weight=0.0
		remote.next_pose_usec=0
		remote._animate_walk()
		var standing: Dictionary=anchors(remote)
		var standing_head: Vector3=remote.avatar_parts.head.position
		var prone_set: bool=remote.set_posture(2,false,true)
		remote.stance.advance(remote,1.0)
		# Force the same LOD skip observed when now < next_pose_usec.
		remote.next_pose_usec=Time.get_ticks_usec()+1500000
		remote._animate_walk()
		var stale: Dictionary=anchors(remote)
		remote.next_pose_usec=0
		remote._animate_walk()
		var updated: Dictionary=anchors(remote)
		var after_rate_usec: int=remote.next_pose_usec-Time.get_ticks_usec()
		var stale_error: Dictionary=drift(updated,stale)
		var stance_delta: Dictionary=drift(standing,updated)
		# More representative six physics ticks while presentation LOD skips.
		remote.set_posture(0,false,true)
		remote.stance.advance(remote,1.0)
		remote.next_pose_usec=0
		remote._animate_walk()
		remote.set_posture(2,false,true)
		remote.next_pose_usec=Time.get_ticks_usec()+1500000
		for tick in 6:
			remote.stance.advance(remote,1.0/60.0)
			remote._animate_walk()
		var normal_stale: Dictionary=anchors(remote)
		remote.next_pose_usec=0
		remote._animate_walk()
		var normal_updated: Dictionary=anchors(remote)
		var normal_gap: Dictionary=drift(normal_updated,normal_stale)
		results.append({
			"distance_m":metres,
			"in_water":remote.in_water(),
			"deployed":remote.deployed,
			"standing_set":standing_set,
			"standing_head":str(standing_head),
			"prone_set":prone_set,
			"prone_flag":remote.prone,
			"LOD_delay_usec_after_update":after_rate_usec,
			"stale_vs_updated":stale_error,
			"six_frame_transition_stale_vs_updated":normal_gap,
			"standing_to_prone":stance_delta,
			"updated_poses":updated.size()
		})
	observer.camera.make_current()
	var outcome: Dictionary={"cases":results,"count":results.size(),"fixture_ok":results.size()==5}
	var saved:=FileAccess.open("res://work/fpp-tpp-p0-20261104/hitbox-lod-baseline.json",FileAccess.WRITE)
	if saved:saved.store_string(JSON.stringify(outcome,"\t"));saved.close()
	print("TRUE_FPP_P0_LOD ",JSON.stringify({"cases":outcome.count,"ok":outcome.fixture_ok}))
	for row: Dictionary in results:print("P0_HIT_REGION ",JSON.stringify({"range_m":row.distance_m,"scheduled_us":row.LOD_delay_usec_after_update,"prone_set":row.prone_set,"prone":row.prone_flag,"water":row.in_water,"deployed":row.deployed,"stale_m":row.stale_vs_updated.max_m,"six_frame_m":row.six_frame_transition_stale_vs_updated.max_m,"posture_m":row.standing_to_prone.max_m}))
	game.queue_free()
	await process_frame
	quit(0 if outcome.fixture_ok else 1)
