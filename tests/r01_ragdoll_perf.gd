extends SceneTree

# Isolated headless test of sustained ragdoll physics with 10 corpses on a floor.
# Run with TDC_R01_RAGDOLL_OPT=0 or 1; does not measure rendered game FPS.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("R01_RAGDOLL_FAIL " + label)

func _snapshot() -> Dictionary:
	var result := {"corpses": 0, "bodies": 0, "active_bodies": 0, "frozen_bodies": 0, "joints": 0}
	for corpse in get_nodes_in_group("death_ragdolls"):
		if not is_instance_valid(corpse) or corpse.is_queued_for_deletion():
			continue
		result.corpses += 1
		for child in corpse.get_children():
			if child is RigidBody3D:
				result.bodies += 1
				if child.freeze or child.sleeping:
					result.frozen_bodies += 1
				else:
					result.active_bodies += 1
			elif child is Joint3D and not child.is_queued_for_deletion():
				result.joints += 1
	return result

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	var sum := 0.0
	for v in values: sum += v
	return {"count": values.size(), "mean_ms": sum / maxf(1.0, float(values.size())),
		"p95_ms": values[mini(values.size() - 1, ceili(float(values.size()) * 0.95) - 1)]}

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	var optimized := OS.get_environment("TDC_R01_RAGDOLL_OPT") == "1"
	var game = load("res://scripts/main.gd").new()
	game.set_meta("test_mode", true)
	root.add_child(game)
	game.mode = "training"
	game.map_kind = "sandbox"
	game._enter_match_world()
	game._static_box(game.world_root, "R01Floor", Vector3(0, -0.25, 0), Vector3(100, 0.4, 100), Color.GRAY)
	var actors: Array[GamePlayer] = []
	for i in 10:
		var pos := Vector3(float(i % 5) * 4.0, 0, float(i / 5) * 4.0)
		var actor: GamePlayer = game._spawn_player(100 + i, false, true, pos)
		actor.set_physics_process(false)
		actors.append(actor)
	await physics_frame
	var start := Time.get_ticks_usec()
	for actor in actors:
		DeathRagdoll.create(game.world_root, actor, actor.global_position)
	var spawn_ms := (Time.get_ticks_usec() - start) * 0.001
	var checkpoints: Dictionary = {}
	var samples: Array[float] = []
	for tick in 240:
		await physics_frame
		if tick >= 30:
			samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		if tick in [60, 120, 180, 239]:
			checkpoints[str(tick + 1)] = _snapshot()
	var final_state: Dictionary = checkpoints["240"]
	_check(int(final_state.corpses) == 10, "ten corpses still visible")
	_check(int(final_state.bodies) >= 100, "all physical parts represented")
	if optimized:
		_check(int(final_state.frozen_bodies) > 0, "at least one corpse frozen after settling")
	if optimized:
		# Local death camera and persistent BR loot corpses must remain fully physical.
		var persistent_torso := DeathRagdoll.create(game.world_root, actors[0], actors[0].global_position, true) as RigidBody3D
		_check(persistent_torso.continuous_cd, "persistent corpse keeps continuous collision")
		_check(not persistent_torso.get_parent().has_node("R01SettleProbe"), "persistent corpse has no accelerated settling")
		actors[1].is_local = true
		var local_torso := DeathRagdoll.create(game.world_root, actors[1], actors[1].global_position) as RigidBody3D
		_check(local_torso.continuous_cd, "local corpse keeps continuous collision")
		_check(not local_torso.get_parent().has_node("R01SettleProbe"), "local death view has no accelerated settling")
		actors[1].is_local = false
	var report := {"optimized": optimized, "godot": Engine.get_version_info().string,
		"spawn_10_ms": spawn_ms, "physics_monitor_ms": _stats(samples),
		"checkpoints": checkpoints, "failures": failures}
	print("R01_RAGDOLL_CPU ", JSON.stringify(report))
	game.show_menu()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
