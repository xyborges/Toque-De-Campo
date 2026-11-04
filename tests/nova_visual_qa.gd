extends SceneTree

const VISUALS=preload("res://modes/war/scripts/vegetation_visuals.gd")
var game: WarGame
var errors: Array[String]=[]

func check(value: bool,message: String) -> void:
	if not value: errors.append(message)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	seed(193);game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: errors.append("world readiness");finish();return
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(3).timeout
	var terrain_shapes: Array=[]
	for shape: CollisionShape3D in game.world_root.find_children("*","CollisionShape3D",true,false):
		if shape.get_parent() is StaticBody3D: terrain_shapes.append([weakref(shape),shape.shape,shape.transform,shape.disabled])
	var original: Dictionary={}
	for node: MultiMeshInstance3D in game.world_root.find_children("*","MultiMeshInstance3D",true,false): original[node.get_instance_id()]={"ref":weakref(node),"mesh":node.multimesh,"visible":node.visible}
	var material_before:=WarTerrain.material
	var camera:=Camera3D.new();root.add_child(camera);camera.position=WarTerrain.point(-150,-650)+Vector3.UP*2.;camera.look_at(WarTerrain.point(-150,-690)+Vector3.UP);camera.make_current()
	var visuals=VISUALS.new();game.world_root.add_child(visuals);visuals.initialize(game.world_root)
	check(visuals.apply_level(2),"activate medium")
	var until:=Time.get_ticks_msec()+20000
	while (not is_instance_valid(visuals.streamer) or not visuals.streamer.pending.is_empty()) and Time.get_ticks_msec()<until: await process_frame
	check(is_instance_valid(visuals.streamer),"stream starts")
	var stats: Dictionary={}
	if is_instance_valid(visuals.streamer):
		check(visuals.streamer.cells.size()<=25,"bounded working set")
		for node: Variant in visuals.streamer.cells.values():
			if not is_instance_valid(node): continue
			check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"grass casts no shadow")
			check(node.get_script()==null and node.get_child_count()==0,"no script or collision on a patch")
			for i in node.multimesh.instance_count:
				var p: Vector3=node.to_global(node.multimesh.get_instance_transform(i).origin)
				check(visuals.biome.footprint_field(Vector2(p.x,p.z),1.35),"field footprint only")
		check(visuals.apply_level(1) and visuals.apply_level(3),"live preset changes")
		stats={"cells":visuals.streamer.cells.size(),"created":visuals.streamer.created,"max_build_ms":visuals.streamer.max_build_ms,"max_candidates_per_frame":visuals.streamer.max_candidates_per_frame}
	check(visuals.apply_level(0),"rollback")
	await process_frame;await process_frame
	check(WarTerrain.material==material_before,"terrain material source unchanged")
	for entry: Array in terrain_shapes:
		var shape: CollisionShape3D=entry[0].get_ref()
		check(is_instance_valid(shape) and shape.shape==entry[1] and shape.transform==entry[2] and shape.disabled==entry[3],"physics unchanged")
	for record: Dictionary in original.values():
		var node: MultiMeshInstance3D=record.ref.get_ref()
		check(is_instance_valid(node) and node.multimesh==record.mesh and node.visible==record.visible,"original LODs and visibility restored")
	check(visuals.ground_slots.is_empty() and visuals.legacy_slots.is_empty() and visuals.streamer==null,"rollback releases state")
	NavalStorage.write_json("res://work/nova-visual-qa.json",{"ok":errors.is_empty(),"errors":errors,"stats":stats,"physics_shapes":terrain_shapes.size(),"original_batches":original.size()})
	finish()

func finish() -> void:
	print("NOVA_VISUAL_QA ",JSON.stringify({"ok":errors.is_empty(),"errors":errors}))
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
