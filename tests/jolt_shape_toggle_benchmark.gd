extends SceneTree

# Isolated Jolt experiment: retain shape owners and stable indices while
# disabling one shape in a compound static body. Does not mutate the game.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var space:=Node3D.new();root.add_child(space)
	var body:=StaticBody3D.new();body.collision_layer=1;space.add_child(body)
	var shape:=BoxShape3D.new();shape.size=Vector3(.7,1,.7)
	for i in 256:
		var collision:=CollisionShape3D.new();collision.shape=shape
		collision.position=Vector3(float(i%16)*2,0,float(i/16)*2);body.add_child(collision)
	await physics_frame;await physics_frame
	var state:=space.get_world_3d().direct_space_state
	var probe:=PhysicsRayQueryParameters3D.create(Vector3(0,3,0),Vector3(0,-3,0),1)
	var before:=state.intersect_ray(probe)
	if before.is_empty(): push_error("missing baseline collision");quit(1);return
	var shape_index:=int(before.shape);var owner:=body.shape_find_owner(shape_index)
	body.shape_owner_set_disabled(owner,true)
	await physics_frame
	var after:=state.intersect_ray(probe)
	var retained:=body.shape_find_owner(shape_index)==owner
	body.shape_owner_set_disabled(owner,false)
	await physics_frame
	if not after.is_empty() or not retained or state.intersect_ray(probe).is_empty():
		push_error("Disabled collision or stable index validation failed");quit(2);return
	var results: Array[Dictionary]=[]
	for block in ["A1","B1","A2","B2","A3"]:
		var change: bool=str(block).begins_with("B");var calls: Array[float]=[];var frames: Array[float]=[];var physics: Array[float]=[]
		for i in 100:
			var target:=body.shape_find_owner(i%256)
			var start:=Time.get_ticks_usec()
			if change: body.shape_owner_set_disabled(target,true)
			calls.append((Time.get_ticks_usec()-start)*.001)
			await physics_frame
			frames.append((Time.get_ticks_usec()-start)*.001)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
			if change: body.shape_owner_set_disabled(target,false)
			await physics_frame
		calls.sort();frames.sort();physics.sort()
		results.append({"block":block,"calls_p95_ms":calls[95],"calls_max_ms":calls.back(),"frame_p95_ms":frames[95],"frame_max_ms":frames.back(),"physics_p95_ms":physics[95],"physics_max_ms":physics.back()})
	var result:={"backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"shapes":256,"index_stable":retained,"ray_removed":after.is_empty(),"ray_restored":not state.intersect_ray(probe).is_empty(),"results":results,"limits":"Single isolated body, not a combat or multiplayer benchmark; frame time includes scheduler and fixed physics interval."}
	var file:=FileAccess.open("res://work/nova-jolt-shape-toggle.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result));file.close();print(JSON.stringify(result));quit()
