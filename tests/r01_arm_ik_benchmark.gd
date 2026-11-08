extends SceneTree

# CPU-only 28-remote-actor IK fixture. No AI, network, or GPU rendering.
# Compare separate processes using TDC_R01_IK_NODE_CACHE=0|1.
var failures: Array[String] = []
var samples: Array[float] = []
var actors: Array[WarPlayer] = []

func _initialize() -> void:
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 60
	_run.call_deferred()

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var ordered := values.duplicate()
	ordered.sort()
	var sum := 0.0
	for number in ordered: sum += number
	var size := ordered.size()
	return {"mean_ms": sum / size, "p50_ms": ordered[int((size - 1) * 0.5)],
		"p95_ms": ordered[int((size - 1) * 0.95)],
		"p99_ms": ordered[int((size - 1) * 0.99)], "max_ms": ordered[-1],
		"samples": size}

func _run() -> void:
	var optimized := OS.get_environment("TDC_R01_IK_NODE_CACHE") == "1"
	var game: WarGame = load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var first: WarPlayer = game.players[2] as WarPlayer
	actors.append(first)
	for i in 27:
		actors.append(game.make_actor(3 + i, false, i % 2, "soldier",
			Vector3(float(i % 7) * 4, 0, -20 - float(i / 7) * 5)))
	for actor in actors:
		actor.set_process(false)
		actor.set_physics_process(false)
	if actors.size() != 28: failures.append("actor count")
	await process_frame
	await process_frame
	var grip_error_max := 0.0
	var checksum := 0.0
	for step in 700:
		var phase := float(step) * 0.027
		for index in actors.size():
			var actor := actors[index]
			actor.pitch = 0.38 * sin(phase + index * 0.13)
			actor.lean = 0.48 * sin(phase * 0.73 + index * 0.17)
			actor._update_weapon_pose()
		var t0 := Time.get_ticks_usec()
		for actor in actors:
			var right_target: Vector3 = actor.weapon_root.to_global(Vector3(0.17, -0.06, -0.31))
			var left_target: Vector3 = actor.weapon_root.to_global(Vector3(-0.22, -0.07, -0.20))
			WarHumanRig.pose(actor, actor.avatar_parts.arm_r, right_target, "armR")
			WarHumanRig.pose(actor, actor.avatar_parts.arm_l, left_target, "armL")
		var milliseconds := float(Time.get_ticks_usec() - t0) * 0.001
		if step >= 100: samples.append(milliseconds)
		if step % 140 == 0 or step == 699:
			for actor in actors:
				for arm_name in ["arm_l", "arm_r"]:
					var arm: Node3D = actor.avatar_parts[arm_name]
					var hand: MeshInstance3D = arm.get_node("HandL" if arm_name == "arm_l" else "HandR")
					var err: float = float(arm.get_meta("grip_error", 0.0))
					grip_error_max = maxf(grip_error_max, err)
					if not hand.global_position.is_finite() or not is_finite(err): failures.append("nonfinite pose")
					checksum += hand.global_position.x + hand.global_position.y * 0.17 + hand.global_position.z * 0.013
		await process_frame
	if grip_error_max > 2.0: failures.append("excessive grip error")
	var output := {"optimized": optimized, "actors": actors.size(), "ik_calls": samples.size() * actors.size() * 2,
		"duration_frames": samples.size(), "batch_ms": _stats(samples),
		"checksum": checksum, "max_grip_error": grip_error_max,
		"failures": failures, "godot": Engine.get_version_info().string}
	print("R01_ARM_IK_BENCH ", JSON.stringify(output))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
