extends SceneTree
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Proxy=preload("res://modes/war/scripts/collision_rig_proxy.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.players[2] as WarPlayer
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.deployed=true;actor.hp=100.0
	actor.weapon_id="g3"
	actor.owned=["g3","glock"]
	actor.loadout=actor.owned.duplicate()
	actor._refresh_weapon()
	var replica: Node3D=Proxy.new()
	actor.add_child(replica)
	var count: int=replica.build_from(actor)
	var results: Array[Dictionary]=[]
	var good: bool=count>=13
	for stance_value in [0,1,2]:
		actor.set_posture(stance_value,false,true)
		actor.stance.advance(actor,1.0)
		actor.next_pose_usec=0
		actor._animate_walk()
		var before: Dictionary=Snapshot.capture(actor)
		var synced: bool=replica.sync(before)
		var after: Dictionary=replica.snapshot()
		var drift: Dictionary=Snapshot.compare(before,after)
		var safe: bool=synced and drift.missing.is_empty() and drift.max_origin_m<.000001 and drift.max_basis_delta<.000001 and drift.muzzle_origin_m<.000001
		for area: Area3D in replica.regions.values():
			safe=safe and area.collision_layer==0
			for part in area.get_children():
				if part is CollisionShape3D:
					safe=safe and part.disabled
					safe=safe and part.shape!=null
					safe=safe and not (part.get_parent() is MeshInstance3D)
		good=good and safe
		results.append({"posture":stance_value,"regions":count,"safe":safe,"transform_error_m":drift.max_origin_m,"muzzle_error_m":drift.muzzle_origin_m})
	var before_hidden:=Snapshot.capture(actor)
	actor.body_root.hide()
	var hidden_snapshot: Dictionary=replica.snapshot()
	var visibility_unchanged: bool=Snapshot.compare(before_hidden,hidden_snapshot).max_origin_m<.000001
	good=good and visibility_unchanged
	actor.body_root.show()
	var summary: Dictionary={"pass":good,"physical_region_count":count,"scenarios":results,"independent_hierarchy":true,"isolated_collision_layer":true,"source_hidden_doesnt_change_proxy":visibility_unchanged,"note":"Prototype physical nodes mirror source transforms; still needs independent pure-math solver and authority switch before use in game."}
	var out:=FileAccess.open("res://work/fpp-tpp-p1a-20261104/collision-rig-proxy-qa.json",FileAccess.WRITE)
	if out:out.store_string(JSON.stringify(summary,"\t"));out.close()
	print("COLLISION_RIG_PROXY_QA ",JSON.stringify(summary))
	game.queue_free()
	await process_frame
	quit(0 if good else 1)
