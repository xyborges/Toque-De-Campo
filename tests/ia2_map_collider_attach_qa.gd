extends SceneTree

# Compare full static collision geometry with in-tree vs deferred setup.
# Dedicated to checking 11,624 shape nodes and physics-server ray hits.
var run_number:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):run_number=int(arg.trim_prefix("--run="))
	Engine.max_fps=0
	_go.call_deferred()

func _go() -> void:
	var fails: Array[String]=[]
	var started:=Time.get_ticks_usec()
	var game: WarGame=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var ready_deadline:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<ready_deadline:
		await process_frame
	if not game.join_ready:
		push_error("WORLD DID NOT READY")
		quit(2);return
	var ready_ms:float=(Time.get_ticks_usec()-started)*.001
	game.set_physics_process(false)
	if is_instance_valid(game.bot_director):game.bot_director.stop()
	if is_instance_valid(game.vehicle_system):game.vehicle_system.set_physics_process(false)
	var map: WarFavelaMap=game.world_root.get_node_or_null("FavelaWar") as WarFavelaMap
	if map==null:fails.append("FavelaWar absent")
	var sectors: Array[StaticBody3D]=[]
	for child: Node in map.get_children():
		if child is StaticBody3D and child.name.begins_with("EnvironmentSector_"):sectors.append(child)
	sectors.sort_custom(func(a: StaticBody3D,b: StaticBody3D)->bool:return a.name<b.name)
	var descriptors: Array[String]=[]
	var unlabelled_descriptors: Array[String]=[]
	var sector_geometry: Dictionary={}
	var total_shapes:=0
	for sector in sectors:
		var sector_descriptors: Array[String]=[]
		if sector.collision_layer!=1 or sector.collision_mask!=0:fails.append("incorrect sector mask")
		for child in sector.get_children():
			if child is CollisionShape3D:
				total_shapes+=1
				if child.disabled or child.shape==null:fails.append("invalid shape "+str(child.name))
				var shape: Shape3D=child.shape
				var dimensions: String=""
				if shape is BoxShape3D:dimensions=str((shape as BoxShape3D).size)
				elif shape is CylinderShape3D:dimensions=str([(shape as CylinderShape3D).height,(shape as CylinderShape3D).radius])
				elif shape is SphereShape3D:dimensions=str((shape as SphereShape3D).radius)
				elif shape is ConvexPolygonShape3D:dimensions=str((shape as ConvexPolygonShape3D).points)
				var descriptor:=str([sector.name,child.name,child.transform,str(child.get_meta("surface","")),shape.get_class(),dimensions])
				descriptors.append(descriptor)
				sector_descriptors.append(descriptor)
				unlabelled_descriptors.append(str([sector.name,child.transform,shape.get_class(),dimensions]))
		sector_descriptors.sort()
		sector_geometry[str(sector.name)]={"hash":JSON.stringify(sector_descriptors).sha256_text(),"count":sector_descriptors.size()}
	if total_shapes!=11624:fails.append("incorrect static collider count "+str(total_shapes))
	await physics_frame
	var world: PhysicsDirectSpaceState3D=game.world_root.get_world_3d().direct_space_state
	var results: Array[String]=[]
	# Probe the same (x,z) in each scenario; check that static world is
	# registered with the physics server and presents identical hit geometry.
	for x in [-460.0,-220.0,0.0,220.0,460.0]:
		for z in [-400.0,-150.0,100.0,350.0]:
			var q:=PhysicsRayQueryParameters3D.create(Vector3(x,500,z),Vector3(x,-200,z),1)
			var hit: Dictionary=world.intersect_ray(q)
			if hit.is_empty():fails.append("missing map terrain probe "+str(Vector2(x,z)))
			else:results.append(str([x,z,hit.position,hit.normal]))
	var d:=JSON.stringify(descriptors).sha256_text()
	descriptors.sort()
	unlabelled_descriptors.sort()
	var sorted_hash:=JSON.stringify(descriptors).sha256_text()
	var unlabelled_hash:=JSON.stringify(unlabelled_descriptors).sha256_text()
	var hits_hash:=JSON.stringify(results).sha256_text()
	var v:=map.build_metrics
	var record={"run":run_number,"defer":OS.get_environment("TDC_IA2_DEFER_SECTOR_ATTACH")=="1",
		"ready_ms":ready_ms,"world_build_ms":game.world_build_ms,
		"map_build_ms":v.build_ms,"stages_ms":v.get("ia2_stage_times_ms",{}),
		"sectors":sectors.size(),"shapes":total_shapes,
		"tiles":v.terrain_tiles,"houses":v.houses,
		"hill_trees":v.hill_trees,"hill_colliders":v.hill_colliders,
		"hill_shrubs":v.hill_shrubs,"hill_grass":v.hill_grass,"hill_rocks":v.hill_rocks,
		"hill_visual_plan_skipped":v.get("hill_visual_plan_skipped",false),
		"deferred_attached":map.get_meta("ia2_deferred_sector_bodies",0),
		"geometry_sha256":d,"sorted_geometry_sha256":sorted_hash,"unlabelled_sha256":unlabelled_hash,
		"sectors_sha256":JSON.stringify(sector_geometry).sha256_text(),
		"sector_geometry":sector_geometry,"probe_sha256":hits_hash,
		"probes_hit":results.size(),"errors":fails}
	print("IA2_MAP_COLLIDERS ",JSON.stringify(record))
	game.queue_free()
	await process_frame
	quit(0 if fails.is_empty() else 2)
