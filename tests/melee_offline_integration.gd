extends SceneTree

var game: Node3D
var actor: GamePlayer
var target: GamePlayer
var errors: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ")+label)
	if not value: errors.append(label)

func reset_target(pos: Vector3) -> void:
	target.global_position = pos
	target.hp = 1000.0
	target.limbs = CombatRules.fresh_limbs()
	target.reaction = 0.0
	target.last_hit_region = "none"
	for key in target.hit_regions: target.hit_regions[key].collision_layer = 2

func attack(id: String) -> void:
	actor.weapon_id = id
	actor._refresh_weapon()
	actor._animate_walk()
	game.shot_clocks.clear()
	actor.shot_sequence += 1
	game._server_accept_shot(1,actor.shot_sequence,actor.life_id,actor.camera.global_position,Vector3.FORWARD,id)

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode = "training"
	game.map_kind = "sandbox"
	game._enter_match_world()
	game.set_physics_process(false)
	game._static_box(game.world_root,"Floor",Vector3(0,-0.15,0),Vector3(100,0.3,100),Color.GRAY)
	actor = game._spawn_player(1,true,false,Vector3.ZERO)
	actor.set_physics_process(false)
	target = game._spawn_player(-100,false,true,Vector3(0,0,-1.4))
	target.set_physics_process(false)
	await physics_frame
	await physics_frame
	for weapon in ["broom","squeegee","axe"]:
		for moving in [false,true]:
			reset_target(Vector3(-0.1,0,-1.45 if weapon != "axe" else -1.14))
			await physics_frame
			attack(weapon)
			check(is_instance_valid(actor.melee_rig.animator),weapon+" AnimationPlayer")
			check(actor.melee_rig.grip_right.global_position.distance_to(actor.avatar_parts.arm_r.to_global(Vector3(0,-0.78,0))) < 0.04,weapon+" right hand grip")
			check(actor.melee_rig.grip_left.global_position.distance_to(actor.avatar_parts.arm_l.to_global(Vector3(0,-0.78,0))) < 0.04,weapon+" left hand grip")
			actor._advance_melee(float(MeleeRig.SPECS[weapon].active_start)-0.015)
			check(target.hp == 1000.0,weapon+" no windup damage")
			var hit_count := 0
			var previous_hp := target.hp
			for frame in range(150):
				if moving: target.global_position.x += 0.002
				await physics_frame
				actor._advance_melee(1.0/120.0)
				actor._animate_walk()
				if target.hp != previous_hp:
					hit_count += 1
					previous_hp = target.hp
			check(target.hp < 1000.0,weapon+" actual contact "+("moving" if moving else "stationary"))
			check(hit_count == 1,weapon+" one damage per swing")
			check(target.last_hit_region != "none",weapon+" local region")
			check(target.reaction > 0.0,weapon+" impact reaction")
			check(target.detached_region.is_empty(),weapon+" no first-hit dismemberment")
		# Same animation misses when the enemy is outside the head's swept path.
		reset_target(Vector3(4,0,-1.2))
		await physics_frame
		attack(weapon)
		for frame in range(150): actor._advance_melee(1.0/120.0)
		check(target.hp == 1000.0,weapon+" physical miss")
		reset_target(Vector3(-0.1,0,-1.45 if weapon != "axe" else -1.14))
		var wall: Node3D = game._static_box(game.world_root,"BlockingWall",Vector3(0,1.4,-0.68),Vector3(4,3,0.15),Color.GRAY).get_parent()
		await physics_frame
		attack(weapon)
		for frame in range(150): actor._advance_melee(1.0/120.0)
		check(target.hp == 1000.0,weapon+" wall blocks damage")
		wall.queue_free()
		await physics_frame
	# A known isolated arm is hit by the true blade path, not a camera ray.
	reset_target(Vector3(0.65,0,-1.6))
	for key in target.hit_regions:
		target.hit_regions[key].collision_layer = 2 if key == "armL" else 0
	await physics_frame
	attack("broom")
	for frame in range(150): actor._advance_melee(1.0/120.0)
	check(target.last_hit_region == "armL","specific upper-arm region")
	check(float(target.limbs.armL) < 100.0,"localized limb integrity")
	# NPC spawn/director test runs in the actual furnished office.
	game.start_offline("training")
	actor = game.local_player
	actor.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	check(game.npcs.size() >= 8,"eight immediate office NPCs")
	var valid_spawns := true
	for npc in game.npcs:
		valid_spawns = valid_spawns and game.offline_director.walkable(game.offline_director.point_id(npc.global_position))
		for other in game.npcs:
			if other != npc and npc.global_position.distance_to(other.global_position) < 1.99: valid_spawns = false
	check(valid_spawns,"NPCs outside obstacles and separated")
	var victim: GamePlayer = game.npcs[0]
	game.npcs.erase(victim)
	game.players.erase(victim.peer_id)
	victim.queue_free()
	game.npc_spawn_clock = 0.0
	for i in range(4): game._physics_process(0.16)
	check(game.npcs.size() >= 8,"quick replenishment without a wave barrier")
	for npc in game.npcs: npc.set_physics_process(false)
	game.offline_elapsed = 180.0
	actor.yaw = PI
	actor.rotation.y = PI
	for i in range(40): game._physics_process(0.16)
	check(game.npcs.size() == 16,"office pressure grows to sixteen")
	for npc in game.npcs: npc.set_physics_process(false)
	# Route around the desk bank (the direct line passes through the desks).
	actor.global_position = Vector3(0,0,-7)
	var chaser: GamePlayer = game.npcs[0]
	chaser.global_position = Vector3(0,0,0)
	await physics_frame
	var route: Vector3 = game.offline_director.direction_for(chaser,actor)
	check(route.length() > 0.5,"A-star route around office furniture")
	# Delayed, animated NPC strike and obstacle protection.
	actor.global_position = Vector3(4,0,-15)
	chaser.global_position = Vector3(4,0,-13.6)
	chaser.npc_attack_wait = 0.0
	chaser.npc_attack_clock = -1.0
	chaser.npc_attack_landed = false
	chaser.velocity=Vector3.ZERO
	actor.hp = 100.0
	await physics_frame
	await physics_frame
	chaser._npc_step(0.016)
	check(actor.hp == 100.0 and chaser.npc_attack_clock >= 0.0,"NPC punch windup")
	chaser._npc_step(0.33)
	chaser._animate_walk()
	if actor.hp==100:
		var query:=PhysicsRayQueryParameters3D.create(chaser.global_position+Vector3.UP*.85,actor.global_position+Vector3.UP*.85,1)
		query.hit_from_inside=true
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		print("NPC_CONTACT_DIAGNOSTIC ",{"actor":actor.global_position,"npc":chaser.global_position,"clock":chaser.npc_attack_clock,"landed":chaser.npc_attack_landed,"limbs":chaser.limbs,"hit":str(hit)})
	check(actor.hp < 100.0,"NPC punch active contact")
	check(absf(chaser.avatar_parts.arm_r.rotation.x) > 0.3,"NPC visible arm animation")
	# A wall between a close attacker and the player prevents the delayed punch.
	var punch_wall: Node3D = game._static_box(game.world_root,"PunchWall",Vector3(4,1.0,-14.3),Vector3(3,2,0.15),Color.GRAY).get_parent()
	await physics_frame
	actor.hp = 100.0
	chaser.npc_attack_clock = 0.1
	chaser.npc_attack_landed = false
	chaser._npc_step(0.3)
	check(actor.hp == 100.0,"NPC punch blocked by wall")
	punch_wall.queue_free()
	game.start_offline("desert")
	game.local_player.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	check(game.npcs.size() == 12,"twelve immediate desert NPCs")
	game.local_player.yaw = PI
	game.local_player.rotation.y = PI
	game.offline_elapsed = 300.0
	for frame in range(100): game._physics_process(0.16)
	check(game.npcs.size() == 24,"desert pressure grows to twenty-four")
	for npc in game.npcs: npc.set_physics_process(false)
	var result := {"checks":checks,"failures":errors}
	var output := FileAccess.open("res://tests/melee-offline-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result))
	output.close()
	game._stop_world_audio()
	game.queue_free()
	await process_frame
	print(JSON.stringify(result))
	quit(0 if errors.is_empty() else 1)
