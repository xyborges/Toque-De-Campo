extends SceneTree

const FIXTURE = preload("res://tests/war_optics_fixture.gd")
const BODY_POSE = preload("res://modes/war/scripts/tactical_body_pose.gd")
const OUT = "res://work/realismo-r2b-g3"

var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func measure(actor: WarPlayer, label: String, weights: Vector3) -> void:
	var loco := actor.locomotion
	loco.presentation_longitudinal = weights.x
	loco.presentation_lateral = weights.y
	loco.presentation_landing = weights.z
	loco.tactical_body_pilot = false
	actor._update_weapon_pose()
	var base_view := actor.view_root.transform
	var base_world := actor.weapon_root.transform
	var base_camera := actor.camera.transform
	var base_torso: Transform3D = actor.avatar_parts.torso.transform

	loco.tactical_body_pilot = true
	actor._update_weapon_pose()
	var on_view := actor.view_root.transform
	var on_world := actor.weapon_root.transform
	var on_camera := actor.camera.transform
	var on_torso: Transform3D = actor.avatar_parts.torso.transform
	var observed := on_view.basis.get_euler() - base_view.basis.get_euler()
	var expected := BODY_POSE.fpp_weapon_angles(weights.x, weights.y, weights.z)
	check(observed.is_equal_approx(expected),label + ": displayed G3 angle equals R2 pose contract")
	check(base_world.is_equal_approx(on_world),label + ": physical G3 remains unchanged")
	check(base_camera.is_equal_approx(on_camera),label + ": camera remains unchanged")
	check(base_torso.is_equal_approx(on_torso),label + ": torso physics/visual pivot stays unchanged")
	check(base_view.origin.is_equal_approx(on_view.origin),label + ": R1 presentation translation stays unchanged")
	await RenderingServer.frame_post_draw
	var path := OUT + "/" + label + ".png"
	var status := root.get_texture().get_image().save_png(path)
	check(status == OK,label + ": rendered screenshot saved")
	captures.append({
		"case":label,
		"input_weights":str(weights),
		"angles_expected_rad":str(expected),
		"angles_observed_rad":str(observed),
		"world_weapon_equal":base_world.is_equal_approx(on_world),
		"camera_equal":base_camera.is_equal_approx(on_camera),
		"screenshot":path
	})

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("R2B visual calibration needs a renderer")
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var game := FIXTURE.new() as WarGame
	root.add_child(game)
	await process_frame
	var actor := game.local_player as WarPlayer
	actor.weapon_id = "g3"
	actor.owned = ["g3","glock"]
	actor.loadout = actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor._refresh_weapon()
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.is_local = true
	actor.hp = 100.
	actor.deployed = true
	actor.vehicle_id = ""
	actor.aiming = false
	actor.iron_sights = false
	actor.reload_left = 0.
	actor.fire_cooldown = 0.
	actor.crouched = false
	actor.prone = false
	actor.utility_mode = ""
	actor.grenade_selected = false
	actor.gadget_equipped = false
	game.third_person = false
	actor._update_view()
	actor.camera.make_current()
	game.hud_layer.hide()
	game.menu_layer.hide()
	actor.locomotion.tactical_motion_pilot = true
	actor.locomotion.tactical_body_pilot = true
	actor.locomotion.moving = 1.
	actor.locomotion.sprint = 0.
	actor.locomotion.phase = 0.
	for i in 4: await process_frame
	check(actor.camera.get_parent() != actor.shoulder_arm,"G3 capture uses FPP camera, not TPP")

	await measure(actor,"neutral",Vector3.ZERO)
	await measure(actor,"accelerate",Vector3(.75,0.,0.))
	await measure(actor,"strafe",Vector3(0.,-.70,0.))
	await measure(actor,"landing",Vector3(0.,0.,.65))

	var report := {"checks":checks,"failures":failures,"captures":captures,"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method","unknown"),"physics_changed":false}
	var file := FileAccess.open(OUT+"/calibration.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("REALISMO_R2B_VISUAL "+JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
