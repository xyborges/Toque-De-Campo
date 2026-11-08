extends SceneTree

# Combined IA2 flags QA. Validates remote reuse, deferred burst,
# strict cap, stale life IDs, local synchronous death and cleanup.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error("IA2_COMBO_FAIL " + description)

func _run() -> void:
	var game: WarGame = load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_meta("war_mode", true)
	game.set_meta("ia2_allow_headless_queue_test", true)
	game.ia2_remote_ragdoll_queue_enabled = true
	game.ia2_ragdoll_strict_cap = true
	var remotes: Array[WarPlayer] = []
	remotes.append(game.players.get(2) as WarPlayer)
	for index in 11:
		var actor: WarPlayer = game.make_actor(index + 3, false, 1, "soldier", Vector3(8.0 + index * 4.0, 0, -25.0))
		actor.set_physics_process(false)
		remotes.append(actor)
	_check(remotes.size() == 12, "12 remote actors")
	var first: WarPlayer = remotes[0]
	first.ia2_respawn_weapon_reuse = true
	var old_muzzle: Node3D = first.muzzle_marker
	first._refresh_weapon()
	_check(is_instance_valid(old_muzzle) and first.muzzle_marker == old_muzzle, "same weapon reuses remote muzzle")
	first.weapon_id = "glock"
	first._refresh_weapon()
	_check(is_instance_valid(first.muzzle_marker) and first.muzzle_marker != old_muzzle, "changed weapon rebuilds muzzle")
	for actor in remotes:
		actor.death_presented = actor.life_id - 1
		game.spawn_ragdoll(actor.global_position, 1, actor)
	_check(game.ia2_remote_ragdoll_jobs.size() == 12, "12 corpses queued in burst")
	var maximum_visible := 0
	for tick in 20:
		await process_frame
		var bodies: int = get_nodes_in_group("death_ragdolls").size()
		maximum_visible = maxi(maximum_visible, bodies)
		_check(bodies <= 10, "no corpse cap overflow, frame " + str(tick))
	_check(game.ia2_remote_ragdoll_jobs.is_empty(), "remote queue drained")
	_check(game.ia2_remote_ragdoll_created == 12, "all remote deaths presented")
	_check(get_nodes_in_group("death_ragdolls").size() == 10, "ten corpses after burst")
	var local_actor: WarPlayer = game.local_player
	var before_local: int = get_nodes_in_group("death_ragdolls").size()
	local_actor.death_presented = local_actor.life_id - 1
	game.spawn_ragdoll(local_actor.global_position, 1, local_actor)
	_check(game.ia2_remote_ragdoll_jobs.is_empty(), "local death never queued")
	_check(get_nodes_in_group("death_ragdolls").size() == before_local + 1, "local corpse created synchronously")
	await process_frame
	_check(get_nodes_in_group("death_ragdolls").size() == 10, "strict cap after local death")
	var previously_created: int = game.ia2_remote_ragdoll_created
	first.life_id += 1
	first.death_presented = first.life_id - 1
	game.spawn_ragdoll(first.global_position, 1, first)
	first.life_id += 1
	for i in 3:
		await process_frame
	_check(game.ia2_remote_ragdoll_jobs.is_empty(), "stale-life queue drained")
	_check(game.ia2_remote_ragdoll_created == previously_created, "stale-life corpse skipped")
	for corpse in get_nodes_in_group("death_ragdolls"):
		corpse.queue_free()
	await process_frame
	_check(get_nodes_in_group("death_ragdolls").is_empty(), "corpse cleanup")
	var report := {"ok": failures.is_empty(), "failures": failures, "maximum_visible": maximum_visible, "created": game.ia2_remote_ragdoll_created, "local_death_synchronous": true}
	print("IA2_FLAGS_COMBO_QA ", JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
