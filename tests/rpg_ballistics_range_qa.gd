extends SceneTree

var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func verify(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func run() -> void:
	verify(is_equal_approx(float(WarRules.SPECIAL.rpg.speed), WarRpgBallistics.SPEED), "authority uses RPG muzzle speed")
	verify(is_equal_approx(float(GameWeapons.ITEMS.rpg.speed), WarRpgBallistics.SPEED), "arsenal uses identical RPG muzzle speed")
	verify(is_equal_approx(float(WarRules.SPECIAL.rpg.gravity), WarRpgBallistics.GRAVITY), "authority uses RPG gravity")
	verify(is_equal_approx(float(GameWeapons.ITEMS.rpg.gravity), WarRpgBallistics.GRAVITY), "arsenal uses identical RPG gravity")
	verify(is_equal_approx(WarArmorBallistics.drag_for("stinger", .008, 350., 120.), .008), "Stinger drag unchanged")
	verify(is_equal_approx(WarArmorBallistics.drag_for("rpg", .016, 50., 160.), .016), "RPG keeps initial drag up to 90 m")
	verify(WarArmorBallistics.drag_for("rpg", .016, 140., 150.) > .18, "RPG drag builds up smoothly after 100 m")
	var previous_hold := 0.0
	for i in WarRpgBallistics.MARK_RANGES.size():
		var distance: float = WarRpgBallistics.MARK_RANGES[i]
		var hold: float = WarRpgBallistics.MARK_HOLD_MRAD[i]
		var height := WarRpgBallistics.impact_height(distance, hold * .001)
		verify(absf(height) < .3, "%d m dot hits within 30 cm vertically (offset %.3f m)" % [int(distance), height])
		verify(hold > previous_hold, "%d m dot stays below previous mark" % int(distance))
		previous_hold = hold
	verify(WarRpgBallistics.impact_height(100., 0.) < -1.7, "zero-elevation RPG has visible 100 m drop")
	verify(WarRpgBallistics.impact_height(400., 0.) < -30., "RPG develops strong drop by 400 m")
	verify(WarRpgBallistics.flight_seconds(100.) < .7 and WarRpgBallistics.flight_seconds(400.) > 2.8, "RPG reaches 100 m fast and slows down later")
	verify(WarRpgBallistics.flight_seconds(600.) > WarRpgBallistics.flight_seconds(500.), "flight times increase with distance")
	var shader := load("res://shaders/scope_reticle.gdshader") as Shader
	verify(shader != null and shader.code.contains("rpg_marks_near") and shader.code.contains("rpg_marks_far"), "launcher optic draws calibrated six RPG marks")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("rpg_marks_near", WarRpgBallistics.reticle_near())
	material.set_shader_parameter("rpg_marks_far", WarRpgBallistics.reticle_far())
	verify(is_equal_approx(float(material.get_shader_parameter("rpg_marks_near").x), float(WarRpgBallistics.MARK_HOLD_MRAD[0])), "reticle receives actual 100 m calibration")
	verify(is_equal_approx(float(material.get_shader_parameter("rpg_marks_far").y), float(WarRpgBallistics.MARK_HOLD_MRAD[5])), "reticle receives actual 600 m calibration")
	# Probe the actual WarProjectiles swept-ray implementation, not only the
	# calibration helper. Elevated origin avoids terrain/obstruction impacts.
	var fixture := load("res://tests/war_optics_fixture.gd").new() as WarGame
	root.add_child(fixture)
	await process_frame
	var projectiles := fixture.war_fx as WarProjectiles
	var launched := projectiles.spawn(1, Vector3(0.0, 400.0, 0.0), Vector3.FORWARD, "rpg", false, "rpg_range_qa", WarRules.SPECIAL.rpg)
	verify(launched, "real WarProjectiles path launches RPG")
	if launched:
		var shot: Dictionary = projectiles.rounds[projectiles.active_slots[-1]]
		var speed_at := {}
		for tick in 1000:
			if not bool(shot.active) or float(shot.distance) >= 420.0: break
			projectiles._step(shot, 1.0 / 120.0)
			for mark in [100, 200, 400]:
				if not speed_at.has(mark) and float(shot.distance) >= mark:
					speed_at[mark] = Vector3(shot.velocity).length()
		verify(float(speed_at.get(100, 0.0)) > 154.0, "real projectile keeps fast first 100 m")
		verify(float(speed_at.get(200, 999.0)) < 150.0, "real projectile slows after 100 m")
		verify(float(speed_at.get(400, 999.0)) < 120.0, "real projectile loses substantial speed by 400 m")
	# Six end-to-end shots use the actual live physics integrator and rays,
	# not the independent calibration helper.
	for i in WarRpgBallistics.MARK_RANGES.size():
		var target_metres: float = WarRpgBallistics.MARK_RANGES[i]
		var angle: float = WarRpgBallistics.MARK_HOLD_MRAD[i] * .001
		var origin := Vector3(0.0, 400.0, 0.0)
		var direction := Vector3(0.0, sin(angle), -cos(angle))
		var id := "range_dot_shot_" + str(int(target_metres))
		if not projectiles.spawn(1, origin, direction, "rpg", false, id, WarRules.SPECIAL.rpg):
			verify(false, "%d m dot shot spawns" % int(target_metres))
			continue
		var round: Dictionary = projectiles.find_round(id)
		var end_y := -999.0
		for tick in 1200:
			if not bool(round.active): break
			var old: Vector3 = round.position
			projectiles._step(round, 1.0 / 120.0)
			var current: Vector3 = round.position
			if -current.z >= target_metres:
				var t := clampf((-target_metres - old.z) / (current.z - old.z), 0.0, 1.0)
				end_y = lerpf(old.y, current.y, t) - origin.y
				break
		print("REAL_RPG_DOT ", int(target_metres), "m vertical error=", end_y)
		verify(absf(end_y) < .3, "%d m dot lands within 30 cm with real WarProjectiles" % int(target_metres))
	fixture.queue_free()
	await process_frame
	print("RPG_RANGE_QA ", passed, " passed; ", failures.size(), " failed")
	quit(0 if failures.is_empty() else 1)
