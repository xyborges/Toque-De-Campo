extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	if "--ticks40" in OS.get_cmdline_user_args(): Engine.physics_ticks_per_second=40
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode = "training"
	game.map_kind = "sandbox"
	game._enter_match_world()
	game._static_box(game.world_root,"Floor",Vector3(0,-0.25,0),Vector3(100,0.4,100),Color.GRAY)
	var actor: GamePlayer = game._spawn_player(1,true,false,Vector3.ZERO)
	actor.set_physics_process(false)
	await physics_frame
	actor.take_damage(100,"chest",0)
	var bodies: Array = get_nodes_in_group("death_ragdolls")[0].get_children().filter(func(node): return node is RigidBody3D)
	var maximum_speed := 0.0
	var minimum_ground := INF
	for i in range(150):
		await physics_frame
		for body in bodies:
			if not CombatRules.finite_vector(body.global_position): failures.append("non-finite body")
			maximum_speed = maxf(maximum_speed,body.linear_velocity.length())
			# Clothing/face attachments add visual children; locate the physical
			# collider by type instead of depending on child ordering.
			var collision := body.find_children("*","CollisionShape3D",false,false)[0] as CollisionShape3D
			var half: Vector3 = collision.shape.size * 0.5
			var extent := absf(body.global_basis.x.y) * half.x + absf(body.global_basis.y.y) * half.y + absf(body.global_basis.z.y) * half.z
			minimum_ground = minf(minimum_ground,body.global_position.y - extent)
	if maximum_speed > 15.0: failures.append("excessive impulse")
	if minimum_ground < -0.22: failures.append("body penetrates floor")
	if get_nodes_in_group("death_ragdolls").size() != 1: failures.append("duplicate corpse")
	await create_timer(9.0).timeout
	if not get_nodes_in_group("death_ragdolls").is_empty(): failures.append("corpse lifetime exceeded")
	var report := {"failures":failures,"maximum_speed":maximum_speed,"minimum_ground":minimum_ground,"checks":4}
	FileAccess.open("res://work/ragdoll-40-results.json" if "--ticks40" in OS.get_cmdline_user_args() else "res://tests/ragdoll-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	game.show_menu()
	game.queue_free()
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
