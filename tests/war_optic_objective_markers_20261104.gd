extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
const TEST_LAYER:=1<<19
var checks:=0
var failures: Array[String]=[]
var observations: Array[Dictionary]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)

func rendered() -> void:
	for _i in 4:await process_frame
	await RenderingServer.frame_post_draw

func red_near(img: Image,screen: Vector2,radius:=11) -> bool:
	if img==null:return false
	var scale:=Vector2(img.get_size())/root.get_visible_rect().size
	var pixel:=Vector2i(screen*scale)
	for y in range(maxi(0,pixel.y-radius),mini(img.get_height(),pixel.y+radius+1)):
		for x in range(maxi(0,pixel.x-radius),mini(img.get_width(),pixel.x+radius+1)):
			var c:=img.get_pixel(x,y)
			if c.r>.42 and c.r>c.g*1.7 and c.r>c.b*1.7:return true
	return false

func configure_optic(actor: WarPlayer,optic: String) -> void:
	actor.weapon_id="g3"
	actor.hp=100.;actor.deployed=true;actor.aiming=false;actor.iron_sights=false
	actor.set_meta("weapon_optics",{"g3":optic})
	actor.set_meta("weapon_attachments",{"g3":GameAttachmentState.from_legacy("g3",optic)})
	actor._refresh_weapon()
	actor.camera.make_current()
	actor.iron_sights=true;actor.aiming=true
	actor.weapon_optics.advance(actor,1.)
	actor._update_view();actor._update_weapon_pose()
	actor.weapon_optics.update(actor)
	await rendered()

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("graphical test required");quit(2);return
	root.content_scale_size=Vector2i(1024,768)
	var game: WarGame=FIXTURE.new();root.add_child(game)
	await rendered()
	game.third_person=false
	var actor:=game.local_player as WarPlayer
	actor.set_process(false);actor.set_physics_process(false);actor.set_process_unhandled_input(false)
	game.ui_focus.close_all();game.war_ui.deployment.hide();game.hud_layer.show()
	var ui:=game.war_ui as WarUI
	ui.set_process(false)
	var target:=MeshInstance3D.new()
	var quad:=QuadMesh.new();quad.size=Vector2(1.,1.)
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(1.,.01,.01);mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	target.mesh=quad;target.material_override=mat;target.layers=TEST_LAYER;game.world_root.add_child(target)

	# Normal FPP/TPP keeps the original main-camera projection.
	var camera:=actor.camera
	var inverse:=ui.get_global_transform_with_canvas().affine_inverse()
	var ordinary_world:=camera.global_position-camera.global_basis.z*80.+camera.global_basis.x*4.
	actor.weapon_optics.stop();actor.iron_sights=false;actor.aiming=false
	var ordinary:=ui._objective_screen_projection(ordinary_world,camera,inverse)
	var ordinary_expected: Vector2=inverse*camera.unproject_position(ordinary_world)
	check(not ordinary.is_empty() and not bool(ordinary.get("optical",true)) and Vector2(ordinary.screen).distance_to(ordinary_expected)<.05,"ordinary objective projection remains unchanged outside optical ADS")

	for optic in ["prism4x","pso4x","hensoldt4x","precision8x"]:
		await configure_optic(actor,optic)
		actor.weapon_optics.camera.cull_mask=TEST_LAYER
		actor.camera.cull_mask&=~TEST_LAYER
		camera=actor.camera;inverse=ui.get_global_transform_with_canvas().affine_inverse()
		var world:=camera.global_position-camera.global_basis.z*100.+camera.global_basis.x*1.0+camera.global_basis.y*.5
		target.global_transform=Transform3D(camera.global_basis,world)
		var marker: Dictionary=ui.markers[0]
		marker.world=world
		actor.weapon_optics.update(actor)
		await rendered()
		var projection:=ui._objective_screen_projection(world,camera,inverse)
		check(not projection.is_empty() and bool(projection.get("optical",false)),optic+" projects objectives through the active optical camera")
		if projection.is_empty():continue
		var screen: Vector2=projection.screen
		var legacy: Vector2=inverse*camera.unproject_position(world)
		var old_error:=legacy.distance_to(screen)
		ui._update_markers()
		check(marker.visible and Vector2(marker.at).distance_to(screen)<.05,optic+" objective record uses the optical projection")
		ui.hide();game.infantry_hud.hide();await rendered()
		check(red_near(root.get_texture().get_image(),screen),optic+" marker position matches the target rendered in the lens")
		ui.show();game.infantry_hud.show()
		check(old_error>5.,optic+" proves the old main-camera marker would visibly drift")
		observations.append({"optic":optic,"old_projection_error_px":old_error,"corrected_screen":screen,"legacy_screen":legacy})

		# Small view motion that stays inside even the narrow 8x field.
		actor.yaw+=deg_to_rad(.15);actor.rotation.y=actor.yaw
		actor._update_weapon_pose();actor.weapon_optics.update(actor)
		await rendered()
		var moved:=ui._objective_screen_projection(world,camera,inverse)
		check(not moved.is_empty(),optic+" keeps objective inside the lens after camera motion")
		if not moved.is_empty():
			ui.hide();game.infantry_hud.hide();await rendered()
			check(red_near(root.get_texture().get_image(),moved.screen),optic+" marker stays glued to the magnified world after camera motion")
			ui.show();game.infantry_hud.show()
		actor.yaw-=deg_to_rad(.15);actor.rotation.y=actor.yaw
		actor._update_weapon_pose();actor.weapon_optics.stop()

	var result:={"checks":checks,"failures":failures,"observations":observations}
	print("WAR_OPTIC_OBJECTIVE_MARKERS ",JSON.stringify(result))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
