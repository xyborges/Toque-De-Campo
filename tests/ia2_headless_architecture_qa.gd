extends SceneTree

# Headless Favela fixture: full offline WarGame and authoritative world.
# Flags are process-wide and selected by launcher in distinct Godot processes.
var run_id:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):run_id=int(arg.trim_prefix("--run="))
	_test.call_deferred()

func _canonical_shapes(world: Node3D) -> Dictionary:
	var records: Array[String]=[]
	var material_count:=0
	for c in world.find_children("*","CollisionShape3D",true,false):
		var shape: Shape3D=c.shape
		if shape==null:continue
		material_count+=1
		var xform: Transform3D=(c as CollisionShape3D).global_transform
		var key: String=str(xform.origin.snapped(Vector3.ONE*.0001))+":"+str(xform.basis)+":"+shape.get_class()
		if shape is BoxShape3D:key+=":"+str((shape as BoxShape3D).size)
		elif shape is SphereShape3D:key+=":"+str((shape as SphereShape3D).radius)
		elif shape is CylinderShape3D:key+=":"+str((shape as CylinderShape3D).radius)+":"+str((shape as CylinderShape3D).height)
		elif shape is ConvexPolygonShape3D:key+=":"+str((shape as ConvexPolygonShape3D).points)
		elif shape is ConcavePolygonShape3D:key+=":"+str((shape as ConcavePolygonShape3D).get_faces())
		records.append(key)
	records.sort()
	return {"shapes":material_count,"geometry_sha256":("\n".join(records)).sha256_text()}

func _test() -> void:
	var problems: Array[String]=[]
	var started:=Time.get_ticks_usec()
	var game: WarGame=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while is_instance_valid(game) and not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	if not game.join_ready:problems.append("world never became ready")
	var world=game.world_root.get_node_or_null("FavelaWar") as WarFavelaMap if is_instance_valid(game.world_root) else null
	var data: Dictionary={}
	if not is_instance_valid(world):problems.append("FavelaWar missing")
	else:
		data=world.build_metrics
		if int(data.get("houses",0))!=4188:problems.append("houses changed")
		if int(data.get("terrain_tiles",0))!=225:problems.append("terrain tiles changed")
		if int(data.get("collision_shapes",0))!=11146:problems.append("collision shapes changed")
	var world_geom: Dictionary=_canonical_shapes(world) if is_instance_valid(world) else {}
	var probes: Array[String]=[]
	if is_instance_valid(world):
		var space:=world.get_world_3d().direct_space_state
		for xy: Vector2 in [Vector2(-470,400),Vector2(200,350),Vector2(-100,-180),Vector2(390,-300),Vector2(0,0),Vector2(-315,65),Vector2(155,-490),Vector2(420,410)]:
			var q:=PhysicsRayQueryParameters3D.create(Vector3(xy.x,400,xy.y),Vector3(xy.x,-50,xy.y),1)
			var hit:=space.intersect_ray(q)
			probes.append(str(hit.get("position",Vector3.INF).snapped(Vector3.ONE*.001))+":"+str(hit.get("normal",Vector3.ZERO).snapped(Vector3.ONE*.001)))
	var result: Dictionary={
		"run":run_id,"flag_enabled":OS.get_environment("TDC_IA2_SKIP_HEADLESS_ARCH_VISUALS")=="1",
		"world_ms":game.world_build_ms,
		"join_ready_ms":(Time.get_ticks_usec()-started)*.001,
		"houses":data.get("houses",0),"tiles":data.get("terrain_tiles",0),
		"collisions":data.get("collision_shapes",0),
		"geometry":world_geom,"probe_digest":JSON.stringify(probes).sha256_text(),
		"errors":problems
	}
	print("IA2_HEADLESS_ARCH_BENCH ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if problems.is_empty() else 2)
