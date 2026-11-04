extends SceneTree
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var game: WarGame
var actor: WarPlayer
var observer: Camera3D
var errors: Array[String]=[]
var checks:=0
var captures: Array[String]=[]
var output:="res://work/equipment-visual"
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: errors.append(label);print("FAIL ",label)
func capture(label: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path:=output.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"save "+label);captures.append(path)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));Engine.max_fps=60
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	game=FIXTURE.new();root.add_child(game);await process_frame
	actor=game.local_player;actor.set_process(false)
	game.hud_layer.hide();observer=Camera3D.new();observer.fov=55;root.add_child(observer)
	# Contrasting vertical target and geometry show real scene magnification.
	for x in [-.8,0.,.8]:
		WarUniform.box(game.world_root,"OpticTarget",Vector3(x,1.7,-100),Vector3(.22,2.,.2),EnvironmentKit.material("metal:963c2b"))
	for weapon in ["fal","ak"]:
		actor.weapon_id=weapon;actor.set_meta("weapon_optics",{weapon:"scope4x"});actor._refresh_weapon();actor.clear_aim()
		game.third_person=false;actor._update_view();actor._update_weapon_pose();actor.camera.make_current()
		await capture(weapon+"-lowered")
		check(not is_instance_valid(actor.weapon_optics.view) or actor.weapon_optics.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"no second world rendering while scope lowered "+weapon)
		actor.cycle_weapon_aim();actor._update_weapon_pose();actor.weapon_optics.update(actor)
		await capture(weapon+"-4x")
		check(actor.weapon_optics.active,"lens renders actual world "+weapon)
		check(actor.weapon_optics.view.size==Vector2i(384,384),"bounded optical resolution")
		var lens:=actor.weapon_optics.lens as MeshInstance3D
		var centre:=actor.camera.unproject_position(lens.global_position)
		check(centre.distance_to(Vector2(960,540))<2.,"physical lens aligned with aiming centre "+weapon)
		var target:=Vector3(0,1.68,-100)
		var width_main:=actor.camera.unproject_position(target+Vector3.RIGHT).x-actor.camera.unproject_position(target).x
		var width_optic:=actor.weapon_optics.camera.unproject_position(target+Vector3.RIGHT).x-actor.weapon_optics.camera.unproject_position(target).x
		var lens_pixels: float=actor.camera.unproject_position(lens.global_position+actor.camera.global_basis.x*.032).distance_to(centre)*2.
		var magnification:=width_optic*lens_pixels/384./width_main
		check(absf(magnification-4.)<.03,"4x projection calibrated in screen pixels "+weapon)
		# The performance fixture freezes actor processing; this check exercises
		# the normal per-frame renderer and real look input, without calling
		# optics.update() from the test after moving the mouse.
		actor.set_process(true)
		game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;actor.mouse_captured=true
		check(game.gameplay_input_allowed(),"interactive look input available "+weapon)
		var signatures: Dictionary={}
		for relative in [Vector2(0,0),Vector2(70,-25),Vector2(-140,50),Vector2(70,-25)]:
			actor.apply_look(relative)
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(actor.weapon_optics.camera.global_transform.is_equal_approx(actor.camera.global_transform),"live lens follows every horizontal/vertical look "+weapon)
			signatures[hash(actor.weapon_optics.view.get_texture().get_image().get_data())]=true
		check(signatures.size()>=3,"live lens image changes with the scene direction "+weapon)
		actor.set_process(false)
		actor.clear_aim();actor.weapon_optics.update(actor)
		check(not actor.weapon_optics.active and actor.weapon_optics.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"lowering stops second rendering "+weapon)
	# Equipment hands/pose on the same real character rig.
	actor.set_meta("weapon_optics",{});actor.apply_identity(0,"marksman");game.members[1].role="marksman"
	game.vehicle_system._set_utility(1,"binoculars");actor.utility_equip_weight=1.
	game.third_person=true;actor._update_view();actor._animate_walk();actor._utility_pose()
	observer.position=Vector3(1.4,1.8,-2.3);observer.look_at(Vector3(0,1.45,-.2));observer.make_current()
	await capture("binoculars-tpp")
	game.third_person=false;actor._update_view();actor.camera.make_current();actor._utility_pose()
	await capture("binoculars-fpp-lowered")
	actor.set_utility_zoom(1);actor.utility_raise_weight=1.;actor._utility_pose();actor._update_binocular_overlay();game.hud_layer.show()
	await capture("binoculars-zoom")
	check(actor.binocular_overlay.visible and not game.scope_overlay.visible and not game.aim_dot.visible,"binocular optical edge without gun reticle")
	game.vehicle_system._set_utility(1,"");game.hud_layer.hide()
	check(not actor.binocular_overlay.visible,"binocular mask clears on stow")
	var bike: WarVehicle=game.vehicle_system.vehicles.v_bike_0_0
	bike.position=Vector3(0,.08,0);bike.heading=0;bike.rotation=Vector3.ZERO;bike.show()
	actor.vehicle_id=bike.vehicle_id;bike.allocate_seat(1);game.members[1].vehicle=bike.vehicle_id
	game.vehicle_system.sync_occupants(bike);actor._physics_process(.016)
	game.vehicle_system.set_process(false)
	observer.position=Vector3(2.,1.7,-2.6);observer.look_at(Vector3(0,.95,0));observer.make_current()
	await capture("motorcycle-rider")
	check(actor.body_root.visible and not actor.view_root.visible,"rider visible without infantry first-person presentation")
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors,"captures":captures}
	NavalStorage.write_json(output.path_join("report.json"),report);print("EQUIPMENT_VISUAL ",JSON.stringify(report))
	game.queue_free();observer.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
