extends SceneTree

# Rendered Forward+ QA: verify the exact shader is visible at all six
# projected positions, plus the live RPG FPP sight config.
const OUT := "res://work/rpg-range-qa/"
var failures: Array[String] = []
var passed := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func snap(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := OUT + label + ".png"
	print("CAPTURE ", path, " ", img.get_size(), " result=", img.save_png(path))
	return img

func click_right() -> void:
	var evt := InputEventMouseButton.new()
	evt.button_index = MOUSE_BUTTON_RIGHT
	evt.pressed = true
	Input.parse_input_event(evt)
	var release := evt.duplicate()
	release.pressed = false
	Input.parse_input_event(release)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual test requires graphical Forward+")
		quit(2)
		return
	Engine.max_fps = 60
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var game := load("res://tests/war_optics_fixture.gd").new() as WarGame
	root.add_child(game)
	await process_frame
	await process_frame
	var actor := game.local_player as WarPlayer
	actor.apply_identity(1, "antitank")
	game.members[1].team = 1
	actor.set_gadget(true, "rpg")
	actor._update_weapon_pose()
	game.third_person = false
	actor._update_view()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.camera.make_current()
	click_right()
	await process_frame
	await process_frame
	var mat := game.scope_overlay.material as ShaderMaterial
	verify(actor.weapon_id == "rpg" and actor.gadget_equipped, "real FPP RPG is equipped")
	verify(actor.uses_telescopic_sight() and game.scope_overlay.visible, "RPG PGO-7 scope is visible while aiming")
	verify(is_equal_approx(actor.camera.fov, 26.0), "FPP scope keeps its 26-degree FOV")
	verify(int(mat.get_shader_parameter("launcher_mode")) == 1, "FPP viewport selects the RPG reticle")
	verify(is_equal_approx(float(mat.get_shader_parameter("rpg_marks_near").x), WarRpgBallistics.MARK_HOLD_MRAD[0]), "real FPP reticle gets 100 m hold")
	verify(is_equal_approx(float(mat.get_shader_parameter("rpg_marks_far").y), WarRpgBallistics.MARK_HOLD_MRAD[5]), "real FPP reticle gets 600 m hold")
	var original := await snap("rpg-fpp-forward-plus-1080")
	verify(original.get_width() >= 1900 and original.get_height() >= 1000, "real FPP capture has adequate resolution")
	# Put this SAME shader on a white calibration background. This makes dot
	# visibility measurable independent of the terrain behind the real scope.
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color.WHITE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var overlay := ColorRect.new()
	overlay.color = Color.WHITE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var visual := ShaderMaterial.new()
	visual.shader = mat.shader
	overlay.material = visual
	layer.add_child(overlay)
	await process_frame
	var sz := root.get_visible_rect().size
	GameScopeReticle.configure(visual, sz, actor.camera.fov)
	visual.set_shader_parameter("launcher_mode", 1)
	visual.set_shader_parameter("rpg_marks_near", WarRpgBallistics.reticle_near())
	visual.set_shader_parameter("rpg_marks_far", WarRpgBallistics.reticle_far())
	await process_frame
	var capture := await snap("rpg-dots-isolated-forward-plus-1080")
	var w := capture.get_width()
	var h := capture.get_height()
	var spacing := GameScopeReticle.pixels_per_mrad(float(h), actor.camera.fov)
	var cx := w / 2 + 3
	var cy := h / 2
	var previous_y := cy
	for i in WarRpgBallistics.MARK_RANGES.size():
		var distance := int(WarRpgBallistics.MARK_RANGES[i])
		var hold: float = WarRpgBallistics.MARK_HOLD_MRAD[i]
		var y := cy + roundi(hold * spacing)
		var mark := capture.get_pixel(cx, y).get_luminance()
		var gap := capture.get_pixel(cx, y + 8).get_luminance()
		print("DOT_RENDER ", distance, " m / ", hold, " mrad / y=", y, " mark=", mark, " gap=", gap)
		verify(y > previous_y and y < h, "%d m dot is vertically ordered and on screen" % distance)
		verify(mark + .15 < gap, "%d m mark is darker than its adjacent gap" % distance)
		previous_y = y
	layer.queue_free()
	game.queue_free()
	await process_frame
	print("RPG_FORWARD_VISUAL ", passed, " PASS / ", failures.size(), " FAIL")
	quit(0 if failures.is_empty() else 1)
