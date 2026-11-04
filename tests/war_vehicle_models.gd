extends SceneTree
var failures: Array[String]=[]
var checks:=0
var label:="before"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(meshes(child))
	return result
func mesh_vertices(node: MeshInstance3D) -> Array[Vector3]:
	var vertices: Array[Vector3]=[]
	for surface in node.mesh.get_surface_count():
		for vertex: Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: vertices.append(node.transform*vertex)
	return vertices
func geometric_key(vertex: Vector3) -> String:
	return "%d,%d,%d"%[roundi(vertex.x*100000),roundi(vertex.y*100000),roundi(vertex.z*100000)]
func closed_geometry(node: MeshInstance3D,label_text: String) -> void:
	var edges: Dictionary={};var volume:=0.;var valid_indices:=true;var degenerate:=0
	for surface in node.mesh.get_surface_count():
		var arrays:=node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		valid_indices=valid_indices and not indices.is_empty() and indices.size()%3==0
		for triangle in indices.size()/3:
			var points: Array[Vector3]=[]
			for corner in 3:
				var index:=indices[triangle*3+corner]
				valid_indices=valid_indices and index>=0 and index<vertices.size()
				if index>=0 and index<vertices.size(): points.append(vertices[index])
			if points.size()!=3: continue
			volume+=points[0].dot(points[1].cross(points[2]))/6.
			if (points[1]-points[0]).cross(points[2]-points[0]).length_squared()<.0000000001: degenerate+=1
			for edge in 3:
				var a:=geometric_key(points[edge]);var b:=geometric_key(points[(edge+1)%3])
				var key:=a+":"+b if a<b else b+":"+a
				edges[key]=int(edges.get(key,0))+1
	check(valid_indices,label_text+" custom faces have valid explicit indices")
	check(degenerate==0,label_text+" custom faces have no degenerate triangles")
	var sealed:=true
	for incidence: int in edges.values(): sealed=sealed and incidence==2
	check(sealed,label_text+" custom shell is closed along every geometric edge")
	# Godot's clockwise front faces give a negative signed volume. A closed
	# inverted shell can still pass an index/count test, so check orientation.
	check(volume<-.01,label_text+" shell faces point outwards (signed volume)")
func custom_shell_regression(world: Node3D) -> void:
	var actor:=WarVehicle.new();actor.kind="guarani";actor.vehicle_id="structural_shells"
	world.add_child(actor);actor.set_physics_process(false)
	var builder:=WarVehicleModels.new();builder.v=actor;builder.paint="657052"
	builder.hull("QAClosedHull",[[-3.4,.83,.76,1.32,1.28,1.44,1.12],[-2.25,.43,.62,1.57,1.38,1.95,1.10],[2.95,.62,.75,1.57,1.33,1.95,1.12],[3.4,.94,.86,1.57,1.20,1.84,1.05]],builder.paint)
	closed_geometry(actor.get_node("QAClosedHull"),"faceted V-bottom hull")
	var outline: Array[Vector2]=[Vector2(-.48,-1.69),Vector2(-1.56,-1.12),Vector2(-1.34,2.34),Vector2(1.34,2.34),Vector2(1.56,-1.12),Vector2(.48,-1.69)]
	builder.turret_shell("QAClosedTurret",outline,-.24,.87,.83,builder.paint,.64)
	closed_geometry(actor.turret.get_node("QAClosedTurret"),"faceted tank turret")
	actor.queue_free()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("929e9d")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("c0ccd2");environment.environment.ambient_light_energy=.65
	world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.5;sun.shadow_enabled=true;world.add_child(sun)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane
	var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("565c55");floor_mesh.material_override=floor_mat;world.add_child(floor_mesh)
	var camera:=Camera3D.new();camera.fov=40;world.add_child(camera);camera.make_current()
	var results: Dictionary={}
	for kind in ["guarani","bmp2","abrams","t90"]:
		var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="review_"+kind
		world.add_child(vehicle);vehicle.set_physics_process(false)
		var count:=0;var triangles:=0
		var near_triangles:=0;var far_triangles:=0;var far_meshes:=0
		var materials_opaque:=true;var ranges_consistent:=true
		var main_tip_vertices:=0;var secondary_tip_vertices:=0;var frontmost:=INF
		for mesh in meshes(vehicle):
			count+=1
			var is_far:=mesh.has_meta("vehicle_lod")
			if is_far: far_meshes+=1
			ranges_consistent=ranges_consistent and ((is_equal_approx(mesh.visibility_range_begin,160.) and is_equal_approx(mesh.visibility_range_end,2300.)) if is_far else (mesh.visibility_range_begin==0 and is_equal_approx(mesh.visibility_range_end,160.)))
			for surface in mesh.mesh.get_surface_count():
				var arrays:=mesh.mesh.surface_get_arrays(surface)
				var amount: int=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
				triangles+=amount
				if is_far: far_triangles+=amount
				else: near_triangles+=amount
				var material:=mesh.get_active_material(surface) as BaseMaterial3D
				materials_opaque=materials_opaque and material!=null and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_BACK
			if mesh.get_parent()==vehicle.elevation and not is_far:
				for vertex in mesh_vertices(mesh):
					frontmost=minf(frontmost,vertex.z)
					if absf(vertex.z-vehicle.muzzle.position.z)<.00001 and Vector2(vertex.x,vertex.y).length()<.20: main_tip_vertices+=1
					if absf(vertex.z-vehicle.secondary_muzzle.position.z)<.00001 and Vector2(vertex.x-vehicle.secondary_muzzle.position.x,vertex.y-vehicle.secondary_muzzle.position.y).length()<.04: secondary_tip_vertices+=1
		var origin:=vehicle.muzzle.position
		check(vehicle.wheels.size()==(6 if kind=="guarani" else (14 if kind=="abrams" else 12)),kind+" running gear count")
		for yaw_value in [0.,.8,2.4,-2.6]:
			vehicle.rotation.y=yaw_value
			for aim_pitch in [-.08,.15,.3]:
				var direction:=Vector3(-.65,sin(aim_pitch),-.76).normalized()
				vehicle.aim(1,vehicle.turret.global_position+direction*400,true)
				check((-vehicle.muzzle.global_basis.z).normalized().dot(direction)>.9999,kind+" authoritative muzzle direction")
		check(vehicle.muzzle.position==origin,kind+" visual changes preserve muzzle anchor")
		vehicle.rotation=Vector3.ZERO;vehicle.aim(1,Vector3(0,vehicle.muzzle.global_position.y,-500),true)
		var detail:=vehicle.get_meta("model_details",{}) as Dictionary
		if label!="before":
			check(detail.get("version",0)==2,kind+" dedicated reference-based model")
			check(int(detail.get("pieces",0))>100,kind+" authored hull and weapon detail")
			check(count<65,kind+" rigid details batched below 65 meshes")
			check(triangles<90000,kind+" model triangle budget")
			check(vehicle.elevation.get_meta("barrel_tip",Vector3.INF).distance_to(origin)<.00001,kind+" visible barrel ends at shot marker")
			check(vehicle.elevation.get_meta("secondary_tip",Vector3.INF).distance_to(vehicle.secondary_muzzle.position)<.00001,kind+" secondary barrel ends at shot marker")
			check(materials_opaque,kind+" armour materials opaque with back-face culling")
			check(ranges_consistent and far_meshes>0,kind+" near/far LOD ranges meet without a visibility gap")
			check(far_triangles<2000 and far_triangles<near_triangles/8,kind+" distant silhouette uses less than one eighth of near geometry")
			check(main_tip_vertices>=32 and absf(frontmost-origin.z)<.00001,kind+" actual visible main muzzle geometry ends at authoritative marker")
			check(secondary_tip_vertices>=32,kind+" actual visible secondary muzzle geometry ends at authoritative marker")
		var view_draws: Dictionary={}
		for view in ["front","side","rear","weapon","far"]:
			camera.fov=40
			camera.position=Vector3(10,6,-12) if view=="front" else (Vector3(13,3.9,1) if view=="side" else Vector3(-9,5,11))
			var target:=Vector3(0,1.25,0)
			if view=="weapon":
				camera.fov=35;camera.position=vehicle.elevation.global_position+Vector3(2.8,1.7,-3.5)
				target=vehicle.elevation.global_position+Vector3(0,0,-.8)
			elif view=="far":
				camera.fov=4;camera.position=Vector3(110,40,-140)
			camera.look_at(target)
			await create_timer(.15).timeout
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://work/vehicle-%s-%s-%s.png"%[label,kind,view])
			view_draws[view]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		results[kind]={"meshes":count,"triangles":triangles,"near_triangles":near_triangles,"far_triangles":far_triangles,"far_meshes":far_meshes,"details":detail,"draw_calls":view_draws.get("front",0),"view_draw_calls":view_draws}
		vehicle.queue_free();await process_frame
	custom_shell_regression(world)
	await process_frame
	# Regression for the actual disappearing-casement cause: custom geometry
	# without an index array mixed into the same material batch as a BoxMesh.
	var assembly:=Node3D.new();world.add_child(assembly)
	var material:=StandardMaterial3D.new()
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.add_vertex(Vector3.ZERO);surface.add_vertex(Vector3.UP);surface.add_vertex(Vector3.RIGHT)
	var authored:=MeshInstance3D.new();authored.mesh=surface.commit();authored.material_override=material;assembly.add_child(authored)
	var primitive:=MeshInstance3D.new();primitive.mesh=BoxMesh.new();primitive.material_override=material;assembly.add_child(primitive)
	WarRenderBatch.merge(assembly,"vehicle-index-regression",[authored,primitive])
	var combined:=assembly.get_child(0) as MeshInstance3D
	check(combined.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()==39,"batch retains non-indexed custom triangle alongside indexed box faces")
	assembly.queue_free()
	var report: Dictionary={"checks":checks,"failures":failures,"models":results}
	NavalStorage.write_json("res://tests/war-vehicle-models-"+label+".json",report);print(JSON.stringify(report))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
