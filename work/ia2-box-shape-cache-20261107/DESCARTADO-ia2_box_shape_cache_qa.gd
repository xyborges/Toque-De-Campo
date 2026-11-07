extends SceneTree

# Offline Godot 4.7.2, one real Favela world per fresh process.
# Validate full physics shape geometry, resource sharing and raycast contacts.
var run_id:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):run_id=int(arg.trim_prefix("--run="))
	_test.call_deferred()

func _test() -> void:
	var problems: Array[String]=[]
	var start_usec:=Time.get_ticks_usec()
	var game: WarGame=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	var ready_ms:float=(Time.get_ticks_usec()-start_usec)*.001
	if not game.join_ready:problems.append("join_ready timeout")
	var map: WarFavelaMap=game.world_root.get_node_or_null("FavelaWar") as WarFavelaMap if is_instance_valid(game.world_root) else null
	var metrics: Dictionary={}
	var profile: Dictionary={}
	var geo_hash: String=""
	var ray_hash: String=""
	var box_count:=0
	var unique_box_shape_ids: Dictionary={}
	var unique_box_size_keys: Dictionary={}
	if not is_instance_valid(map):
		problems.append("FavelaWar missing")
	else:
		metrics=map.build_metrics
		profile=map.get_meta("ia2_box_profile",{})
		if int(metrics.get("houses",0))!=4188:problems.append("house count unexpected")
		if int(metrics.get("terrain_tiles",0))!=225:problems.append("tile count unexpected")
		if int(metrics.get("collision_shapes",0))!=11146:problems.append("collider count unexpected")
		var parts: Array[String]=[]
		for c in map.find_children("*","CollisionShape3D",true,false):
			var node: CollisionShape3D=c as CollisionShape3D
			var shape: Shape3D=node.shape
			if shape==null:continue
			var pose: Transform3D=node.global_transform
			var line: String=str(pose.origin.snapped(Vector3.ONE*.0001))+":"+str(pose.basis)+":"+shape.get_class()
			if shape is BoxShape3D:
				var box: BoxShape3D=shape as BoxShape3D
				line+=":"+str(box.size)
				box_count+=1
				unique_box_shape_ids[box.get_instance_id()]=true
				unique_box_size_keys[box.size]=true
			elif shape is SphereShape3D:line+=":"+str((shape as SphereShape3D).radius)
			elif shape is CylinderShape3D:line+=":"+str((shape as CylinderShape3D).radius)+":"+str((shape as CylinderShape3D).height)
			elif shape is ConvexPolygonShape3D:line+=":"+str((shape as ConvexPolygonShape3D).points)
			elif shape is ConcavePolygonShape3D:line+=":"+str((shape as ConcavePolygonShape3D).get_faces())
			parts.append(line)
		parts.sort()
		geo_hash=("\n".join(parts)).sha256_text()
		await physics_frame
		var space: PhysicsDirectSpaceState3D=map.get_world_3d().direct_space_state
		var probe_results: Array[String]=[]
		for xy: Vector2 in [Vector2(-470,400),Vector2(200,350),Vector2(-100,-180),Vector2(390,-300),
				Vector2(0,0),Vector2(-315,65),Vector2(155,-490),Vector2(420,410)]:
			var query:=PhysicsRayQueryParameters3D.create(Vector3(xy.x,400,xy.y),Vector3(xy.x,-50,xy.y),1)
			var hit: Dictionary=space.intersect_ray(query)
			probe_results.append(str(Vector3(hit.get("position",Vector3.INF)).snapped(Vector3.ONE*.001))+":"+str(Vector3(hit.get("normal",Vector3.ZERO)).snapped(Vector3.ONE*.001)))
		ray_hash=JSON.stringify(probe_results).sha256_text()
		if int(profile.get("cache_hits",-1))<0:problems.append("box profile missing")
		if box_count<7000:problems.append("box count unexpectedly low")
	var result: Dictionary={"run":run_id,
		"cache_enabled":OS.get_environment("TDC_IA2_BOX_SHAPE_CACHE")=="1",
		"world_ms":game.world_build_ms,"ready_ms":ready_ms,
		"houses":metrics.get("houses",0),"terrain_tiles":metrics.get("terrain_tiles",0),
		"collision_shapes":metrics.get("collision_shapes",0),
		"box_count":box_count,
		"unique_box_shape_resources":unique_box_shape_ids.size(),
		"unique_box_sizes":unique_box_size_keys.size(),
		"profile":profile,"geometry_sha256":geo_hash,
		"ray_sha256":ray_hash,"errors":problems}
	print("IA2_BOX_CACHE_BENCH ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if problems.is_empty() else 2)
