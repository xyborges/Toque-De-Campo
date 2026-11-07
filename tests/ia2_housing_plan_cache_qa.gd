extends SceneTree

# Offline Favela, same revision, no ENet. --generate creates immutable .res
# cache from the ORIGINAL planner, --run=N compares with/without the opt-in.
var run_id:=0
var generate:=false
var expect_fallback:=false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--generate":generate=true
		if arg=="--expect-fallback":expect_fallback=true
		if arg.begins_with("--run="):run_id=int(arg.trim_prefix("--run="))
	_execute.call_deferred()

func _execute() -> void:
	if generate:
		WarFavelaMap.housing_lots.clear()
		var started:=Time.get_ticks_usec()
		var lots: Array[Dictionary]=WarFavelaMap.housing_plan()
		var signature: String=WarFavelaMap.ia2_housing_source_signature()
		var digest:=JSON.stringify(lots).sha256_text()
		var asset:=Resource.new()
		asset.set_meta("signature",signature)
		asset.set_meta("digest",digest)
		asset.set_meta("lots",lots)
		var result:=ResourceSaver.save(asset,WarFavelaMap.IA2_HOUSING_CACHE_PATH)
		var reload: Resource=ResourceLoader.load(WarFavelaMap.IA2_HOUSING_CACHE_PATH,"",ResourceLoader.CACHE_MODE_IGNORE)
		var payload: Variant=reload.get_meta("lots",[]) if reload else []
		var valid:=result==OK and reload!=null and payload is Array and (
			JSON.stringify(payload).sha256_text()==digest)
		print("IA2_HOUSING_GENERATE ",JSON.stringify({"ok":valid,"lots":lots.size(),
			"digest":digest,"signature":signature,"save_status":result,
			"file":WarFavelaMap.IA2_HOUSING_CACHE_PATH,
			"generated_ms":(Time.get_ticks_usec()-started)*.001}))
		quit(0 if valid and lots.size()==4188 else 2)
		return
	var errors: Array[String]=[]
	var start:=Time.get_ticks_usec()
	var game: WarGame=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	var ready_ms:float=(Time.get_ticks_usec()-start)*.001
	if not game.join_ready:errors.append("join_ready timeout")
	var map: WarFavelaMap=game.world_root.get_node_or_null("FavelaWar") as WarFavelaMap if is_instance_valid(game.world_root) else null
	var metrics: Dictionary={}
	var geometry_hash: String=""
	var ray_hash: String=""
	if not is_instance_valid(map):
		errors.append("favela map missing")
	else:
		metrics=map.build_metrics
		if int(metrics.get("houses",0))!=4188:errors.append("houses changed")
		if int(metrics.get("terrain_tiles",0))!=225:errors.append("terrain tiles changed")
		if int(metrics.get("collision_shapes",0))!=11146:errors.append("physical collision count changed")
		var parts: Array[String]=[]
		for child in map.find_children("*","CollisionShape3D",true,false):
			var node: CollisionShape3D=child as CollisionShape3D
			var shape: Shape3D=node.shape
			if shape==null:continue
			var pose: Transform3D=node.global_transform
			var line:=str(pose.origin.snapped(Vector3.ONE*.0001))+":"+str(pose.basis)+":"+shape.get_class()
			if shape is BoxShape3D:line+=":"+str((shape as BoxShape3D).size)
			elif shape is SphereShape3D:line+=":"+str((shape as SphereShape3D).radius)
			elif shape is CylinderShape3D:line+=":"+str((shape as CylinderShape3D).radius)+":"+str((shape as CylinderShape3D).height)
			elif shape is ConvexPolygonShape3D:line+=":"+str((shape as ConvexPolygonShape3D).points)
			elif shape is ConcavePolygonShape3D:line+=":"+str((shape as ConcavePolygonShape3D).get_faces())
			parts.append(line)
		parts.sort()
		geometry_hash=("\n".join(parts)).sha256_text()
		await physics_frame
		var space: PhysicsDirectSpaceState3D=map.get_world_3d().direct_space_state
		var probes: Array[String]=[]
		for xy: Vector2 in [Vector2(-470,400),Vector2(200,350),Vector2(-100,-180),Vector2(390,-300),Vector2(0,0),Vector2(-315,65),Vector2(155,-490),Vector2(420,410)]:
			var query:=PhysicsRayQueryParameters3D.create(Vector3(xy.x,400,xy.y),Vector3(xy.x,-50,xy.y),1)
			var hit: Dictionary=space.intersect_ray(query)
			probes.append(str(Vector3(hit.get("position",Vector3.INF)).snapped(Vector3.ONE*.001))+":"+str(Vector3(hit.get("normal",Vector3.ZERO)).snapped(Vector3.ONE*.001)))
		ray_hash=JSON.stringify(probes).sha256_text()
	var flag:=OS.get_environment("TDC_IA2_HOUSING_CACHE")=="1"
	var info: Dictionary=WarFavelaMap.ia2_housing_cache_stats
	if flag and str(info.get("status",""))!=("generated" if expect_fallback else "loaded"):
		errors.append("cache status unexpected")
	if not flag and str(info.get("status",""))!="generated":errors.append("baseline unexpectedly loaded")
	var result: Dictionary={"run":run_id,"cache_enabled":flag,"expect_fallback":expect_fallback,
		"ready_ms":ready_ms,"world_ms":game.world_build_ms,
		"layout_ms":info.get("duration_ms",-1.0),"layout_status":info.get("status","missing"),
		"houses":metrics.get("houses",0),"tiles":metrics.get("terrain_tiles",0),
		"collisions":metrics.get("collision_shapes",0),
		"stages":metrics.get("ia2_stage_times_ms",{}),
		"neighbor_substages":metrics.get("ia2_neighborhood_substages",{}),
		"terrain_cache_status":map.ia2_terrain_cache_status if is_instance_valid(map) else "no_map","lots":WarFavelaMap.housing_lots.size(),
		"plan_sha256":JSON.stringify(WarFavelaMap.housing_lots).sha256_text(),
		"geometry_sha256":geometry_hash,"ray_sha256":ray_hash,"errors":errors}
	print("IA2_HOUSING_PLAN_BENCH ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 2)
