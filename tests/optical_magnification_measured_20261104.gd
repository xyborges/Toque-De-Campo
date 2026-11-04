extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var failures: Array[String]=[]
var observations: Array[Dictionary]=[]

func _initialize() -> void:
	run.call_deferred()

func measure(img: Image) -> int:
	if img==null:return -1
	var y:=img.get_height()/2
	var count:=0
	for x in img.get_width():
		var c:=img.get_pixel(x,y)
		if c.r>0.65 and c.r>c.g*2. and c.r>c.b*2.:count+=1
	return count

func sample(optics: RefCounted,path: String) -> int:
	for j in 4:await process_frame
	await RenderingServer.frame_post_draw
	var img: Image=optics.view.get_texture().get_image()
	if img:img.save_png(path)
	return measure(img)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("graphical test needed")
		quit(2);return
	root.content_scale_size=Vector2i(1024,768)
	var game: WarGame=FIXTURE.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.hud_layer.hide()
	game.third_person=false
	var actor: WarPlayer=game.local_player
	actor.set_process(false);actor.set_physics_process(false);actor.set_process_unhandled_input(false)
	var target:=MeshInstance3D.new()
	target.name="MagnificationTestTarget"
	var mesh:=QuadMesh.new();mesh.size=Vector2(.10,.10)
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(1.0,.03,.03)
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	target.mesh=mesh
	target.material_override=mat
	game.world_root.add_child(target)
	var scopes:=["hensoldt4x","precision8x"]
	for weapon in ["sniper","g3","ak","fal"]:
		var widths: Dictionary={}
		for optic in scopes:
			actor.weapon_id=weapon
			actor.hp=100.;actor.deployed=true;actor.aiming=false;actor.iron_sights=false
			actor.set_meta("weapon_optics",{weapon:optic})
			actor.set_meta("weapon_attachments",{weapon:GameAttachmentState.from_legacy(weapon,optic)})
			actor._refresh_weapon()
			actor.camera.make_current()
			actor.iron_sights=true;actor.aiming=true
			# Measure the settled optical endpoint, independently of the live ADS test.
			actor.weapon_optics.advance(actor,1.)
			actor._update_view();actor._update_weapon_pose()
			actor.weapon_optics.update(actor)
			await process_frame
			var lens:=actor.weapon_optics.lens as Node3D
			var source:=actor.weapon_optics.camera as Camera3D
			var viewport:=actor.weapon_optics.view as SubViewport
			if not lens or not source or not viewport:
				failures.append(weapon+" missing optical camera "+optic);continue
			# Exact same 10cm target at 8m directly in both cameras' optical axis.
			target.global_transform=Transform3D(actor.camera.global_basis, actor.camera.global_position - actor.camera.global_basis.z*8.)
			actor.weapon_optics.update(actor)
			var live_fov:=source.fov
			var live_px:=await sample(actor.weapon_optics,"res://work/magnification-"+weapon+"-"+optic+"-live.png")
			var definition:=GameAttachmentRegistry.definition(optic) as GameAttachmentDefinition
			var distance:=maxf(.04,-actor.camera.to_local(lens.global_position).z)
			var radius:=float(definition.behavior_parameters.get("lens_radius",.032))
			var unzoom_fov:=rad_to_deg(2.*atan(radius/distance))
			source.fov=unzoom_fov
			var baseline_px:=await sample(actor.weapon_optics,"res://work/magnification-"+weapon+"-"+optic+"-baseline.png")
			var ratio:=float(live_px)/maxf(1.,float(baseline_px))
			var record: Dictionary={"weapon":weapon,"optic":optic,"effective_zoom":ratio,"live_target_width_px":live_px,"baseline_target_width_px":baseline_px,"lens_camera_fov":live_fov,"baseline_camera_fov":unzoom_fov,"lens_distance_m":distance}
			observations.append(record)
			print("MEASURE_ZOOM ",JSON.stringify(record))
			widths[optic]=live_px
			if live_px<=1 or baseline_px<=1 or absf(ratio-(8. if optic=="precision8x" else 4.))>1.6:
				failures.append("magnification inaccurate: "+weapon+" "+optic+" x"+str(ratio))
			actor.iron_sights=false;actor.aiming=false
			actor.weapon_optics.stop()
		if widths.has("hensoldt4x") and widths.has("precision8x"):
			var cross_ratio:=float(widths.precision8x)/maxf(1.,float(widths.hensoldt4x))
			if absf(cross_ratio-2.)>.25: failures.append("8x/4x size ratio: "+weapon+" "+str(cross_ratio))
	var report={"ok":failures.is_empty(),"failures":failures,"observations":observations,"note":"Actual GPU rendered optical SubViewport red-target width vs unzoomed same-lens camera, identical target size and distance; no reliance solely on definition metadata."}
	NavalStorage.write_json("res://work/optical-magnification-measured.json",report)
	print("MEASURE_ZOOM_RESULT ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
