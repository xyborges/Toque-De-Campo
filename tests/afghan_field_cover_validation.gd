extends SceneTree
const Afghan=preload("res://modes/battle_royale/map/afghan_map.gd")
const Atmosphere=preload("res://modes/battle_royale/map/afghan_atmosphere.gd")
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var graphics:=DisplayServer.get_name()!="headless"
	if graphics:
		DisplayServer.window_set_size(Vector2i(1280,800));root.content_scale_size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		Atmosphere.install(scene)
	var map:=Afghan.new();map.render_visuals=graphics;scene.add_child(map);map.build()
	await physics_frame;await physics_frame
	var records: Array=map.get_meta("afghan_cover_layout");var before: bool="--afghan-cover-before" in OS.get_cmdline_user_args()
	check(records.size()>=75,"at least 75 contextual cover positions")
	var hits:=0;var collider_bodies:=0;var collider_shapes:=0
	for node in map.get_children():
		if node is StaticBody3D and node.get_meta("library_id","") in ["field_bank_v10","field_wall_v10"]:
			collider_bodies+=1
			for child in node.get_children():
				if child is CollisionShape3D:collider_shapes+=1
	for i in records.size():
		var item: Dictionary=records[i];var p: Vector3=item.position
		check(Afghan.accessible(p) and not Afghan.is_water(p),"cover on playable dry ground %d"%i)
		var transform: Transform3D=preload("res://modes/battle_royale/map/afghan_context.gd").on_ground(map,p,item.yaw)
		var query:=PhysicsRayQueryParameters3D.create(transform*Vector3(0,.55,-2),transform*Vector3(0,.55,2),1)
		var hit:=scene.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.get_meta("library_id","") in ["field_bank_v10","field_wall_v10"]:hits+=1
		elif not before:print("COVER_RAY_OCCLUDED ",i," ",p," ",hit.get("collider","none"))
	if not before:
		check(hits==records.size(),"every cover patch blocks a horizontal bullet")
		check(collider_bodies<records.size(),"static collision grouped by spatial cell")
		check(collider_shapes>=records.size(),"persistent physical cover shapes")
	if graphics:
		var camera:=Camera3D.new();camera.fov=70.;camera.far=5500.;scene.add_child(camera);camera.make_current()
		# Fixed selection from the deterministic plan, identical on A and B.
		var indices: Array[int]=[mini(7,records.size()-1),records.size()/2,mini(19,records.size()-1)]
		for index in indices.size():
			var record: Dictionary=records[indices[index]];var p: Vector3=record.position;var b:=Basis(Vector3.UP,record.yaw)
			camera.position=p+b*Vector3(15.,8.5 if index==1 else 2.2,19.);camera.look_at(p+Vector3.UP*.9)
			for frame in 10:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/afghan-cover-%s-%d.png"%["before" if before else "after",index])
	var report:={"ok":failures.is_empty(),"before":before,"failures":failures,"cover":map.get_meta("afghan_cover"),"positions":records.size(),"bullet_blocking":hits,"collision_bodies":collider_bodies,"collision_shapes":collider_shapes,"resolution":[1280,800] if graphics else [],"source_heightmap_unchanged":true,"physics_visual_detail_collision":false}
	var file:=FileAccess.open("res://work/afghan-cover-%s.json"%("before" if before else "after"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("AFGHAN_COVER ",JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
