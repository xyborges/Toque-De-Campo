extends SceneTree
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: run.call_deferred()
func draw() -> Image:
	for frame in 4:
		await process_frame
		RenderingServer.force_draw(false)
	return root.get_texture().get_image()
func run() -> void:
	root.content_scale_size=Vector2i(800,600)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	RenderingServer.render_loop_enabled=false
	var camera:=Camera3D.new();root.add_child(camera);camera.far=3000;camera.fov=60;camera.make_current()
	var original:=StandardMaterial3D.new();original.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;original.albedo_color=Color("aa4444")
	var box:=BoxMesh.new()
	var left:=MeshInstance3D.new();left.mesh=box;left.material_override=original;root.add_child(left);left.position=Vector3(-1,0,-4)
	var tinted:=original.duplicate() as StandardMaterial3D;tinted.albedo_color=Color.WHITE;tinted.vertex_color_use_as_albedo=true;tinted.vertex_color_is_srgb=true
	var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_colors=true;instances.mesh=box;instances.instance_count=1;instances.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(1,0,-4)));instances.set_instance_color(0,Color("aa4444"))
	var right:=MultiMeshInstance3D.new();right.multimesh=instances;right.material_override=tinted;root.add_child(right)
	var image: Image=await draw()
	var lp:=camera.unproject_position(left.position);var rp:=camera.unproject_position(Vector3(1,0,-4))
	var before:=image.get_pixelv(lp);var after:=image.get_pixelv(rp)
	check(absf(before.r-after.r)<.012 and absf(before.g-after.g)<.012 and absf(before.b-after.b)<.012,"instance tint matches material tint in native pixels")
	image.save_png("res://work/perf181/tint-parity.png")
	right.hide();left.position=Vector3(0,0,-1200);left.scale=Vector3(14,14,14);camera.fov=7
	var thermal:=WarThermal.new();root.add_child(thermal);thermal.set_process(false);thermal.enabled=true;thermal.overlay.show();thermal._register_mesh(left,1.)
	image=await draw();var point:=camera.unproject_position(left.position);var hot:=image.get_pixelv(point).r
	check(hot>.7,"thermal silhouette visible at 1200 meters")
	image.save_png("res://work/perf181/heat-exposed.png")
	var cover:=MeshInstance3D.new();cover.mesh=box;var dark:=StandardMaterial3D.new();dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;dark.albedo_color=Color(.05,.05,.05);cover.material_override=dark;root.add_child(cover);cover.position=Vector3(0,0,-600);cover.scale=Vector3(30,30,1)
	image=await draw();var covered:=image.get_pixelv(point).r
	check(covered<hot-.4,"opaque wall blocks the thermal target")
	image.save_png("res://work/perf181/heat-covered.png")
	thermal.set_enabled(false);cover.hide();image=await draw()
	check(left.material_override==original,"normal material returns after FLIR")
	var result:={"checks":checks,"failures":failures,"material_pixel":str(before),"instance_pixel":str(after),"exposed_luma":hot,"covered_luma":covered}
	FileAccess.open("res://work/perf181/visual-regression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
