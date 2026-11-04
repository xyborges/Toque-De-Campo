extends SceneTree
func _initialize() -> void: run.call_deferred()
func volume(mesh: Mesh) -> float:
	var v:=0.0
	for s in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(s);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size() if indices.size()>0 else points.size(),3):
			var a:=points[indices[i] if indices.size()>0 else i];var b:=points[indices[i+1] if indices.size()>0 else i+1];var c:=points[indices[i+2] if indices.size()>0 else i+2]
			v+=a.dot(b.cross(c))/6
	return v
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("65766f");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("d5dbcf");env.environment.ambient_light_energy=.65;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,60,0);light.light_energy=1.5;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,-120,0);fill.light_energy=.7;stage.add_child(fill)
	var model:=FALModel.create();stage.add_child(model)
	var camera:=Camera3D.new();camera.position=Vector3(1.1,.32,.45);camera.fov=42;stage.add_child(camera);camera.look_at(Vector3(0,-.01,-.23));camera.current=true
	var box:=BoxMesh.new();print("BOX_VOLUME ",volume(box))
	for finish in FALModel.meshes:
		var mesh: Mesh=FALModel.meshes[finish];var arrays:=mesh.surface_get_arrays(0)
		print("MESH_VOLUME ",finish," ",volume(mesh)," BOUNDS ",mesh.get_aabb()," VERTS ",arrays[Mesh.ARRAY_VERTEX].size()," INDICES ",arrays[Mesh.ARRAY_INDEX].size())
	FALModel._slab(stage,"Polymer",[Vector2(0,0),Vector2(0,.2),Vector2(.2,.2),Vector2(.2,0)],.1,.001)
	var diagnostic:=stage.get_child(stage.get_child_count()-1) as MeshInstance3D
	print("SLAB_VOLUME ",volume(diagnostic.mesh)," BOUNDS ",diagnostic.mesh.get_aabb());diagnostic.hide()
	for face in ["normal","double"]:
		if face=="double":
			for material in FALModel.materials.values(): material.cull_mode=BaseMaterial3D.CULL_DISABLED
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/rifles185-model-"+face+".png")
	stage.queue_free();await process_frame;quit()
