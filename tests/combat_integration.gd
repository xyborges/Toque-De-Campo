extends SceneTree

var errors: Array[String] = []
var checks := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: errors.append(label)

func cast_region(actor: GamePlayer, key: String) -> Dictionary:
	var area: Area3D = actor.hit_regions[key]
	var center := area.global_position
	var query := PhysicsRayQueryParameters3D.create(center + Vector3(0,0,2),center - Vector3(0,0,2),CombatRules.SHOT_MASK,game._collision_excludes(1,false))
	query.collide_with_areas = true
	return game.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode = "training"
	game.map_kind = "sandbox"
	game._enter_match_world()
	game._static_box(game.world_root,"TestFloor",Vector3(0,-0.25,-30),Vector3(200,0.4,200),Color.GRAY)
	var shooter: GamePlayer = game._spawn_player(1,true,false,Vector3.ZERO)
	shooter.set_physics_process(false)
	var target: GamePlayer = game._spawn_player(2,false,true,Vector3(0,0,-15))
	target.set_physics_process(false)
	await physics_frame
	await physics_frame
	for region in target.hit_regions:
		target.hp = 100.0
		target.limbs = CombatRules.fresh_limbs()
		var hit := cast_region(target,region)
		var name_region: String = "abdomen" if region == "abdomenPelvis" else region
		check(not hit.is_empty(),"physical ray " + region)
		if hit.is_empty(): continue
		check(str(hit.collider.get_meta("hit_region","none")) == name_region,"exact region " + region)
		if region == "head":
			check(CombatRules.health_damage(1.0,"head","training") == 100.0,"fatal headshot rule")
			continue
		game._apply_hit(1,hit,10.0,"chest","glock",Vector3.FORWARD)
		var expected := 100.0 - 10.0 * float(CombatRules.DAMAGE[name_region])
		check(absf(target.hp - expected) < 0.01,"multiplier " + region)
	# Real model muzzle axis and pitch are measured from the imported model transform.
	for weapon in ["glock","fal","sniper"]:
		shooter.weapon_id = weapon
		shooter._refresh_weapon()
		for angle in [-1.2,0.0,1.2]:
			shooter.pitch = angle
			shooter._update_weapon_pose()
			var model := shooter.weapon_root.get_node("Imported_" + weapon) as Node3D
			var actual := (model.global_basis * (Vector3.LEFT if weapon == "glock" else Vector3.RIGHT)).normalized()
			var expected := shooter.global_basis * (Basis(Vector3.RIGHT,angle) * Vector3.FORWARD)
			check(actual.dot(expected) > 0.999,"model barrel forward %s %.1f" % [weapon,angle])
			check(shooter.get_muzzle_position().is_equal_approx(shooter.muzzle_marker.global_position),"physical muzzle " + weapon)
	# One reload path, bounded reserve, cancellation never manufactures ammo.
	shooter.weapon_id = "glock"
	shooter.ammo.glock = 7
	shooter.reserves.glock = 20
	shooter.begin_reload("glock",4.0)
	shooter.complete_reload()
	check(shooter.ammo.glock == 12 and shooter.reserves.glock == 15,"partial magazine transfer")
	shooter.ammo.glock = 7
	shooter.reserves.glock = 2
	shooter.begin_reload("glock",4.0)
	shooter.complete_reload()
	check(shooter.ammo.glock == 9 and shooter.reserves.glock == 0,"limited reserve")
	shooter.begin_reload("glock",4.0)
	shooter.equip_slot(3)
	check(shooter.reload_weapon.is_empty() and shooter.ammo.glock == 9,"switch cancels reload")
	# Exact per-shot integration: gravity changes velocity only after launch.
	for pending in game.projectiles: game._release_projectile_visual(pending)
	game.projectiles.clear()
	game._spawn_projectile(1,Vector3(30,5,0),Vector3.FORWARD,"sniper",false,true,"drop-test")
	var projectile: Dictionary = game.projectiles.back()
	check(absf(projectile.vel.y) < 0.0001,"sniper zero upward launch impulse")
	for i in range(12): game._step_projectiles(1.0/120.0)
	check(projectile.pos.y < 5.0 and projectile.vel.y < 0,"progressive gravity")
	# Authority: a repeated sequence or an empty magazine cannot spawn a shot.
	shooter.weapon_id = "glock"
	shooter.pitch = 0.0
	shooter.rotation = Vector3.ZERO
	shooter._refresh_weapon()
	shooter.ammo.glock = 1
	game.shot_clocks.clear()
	game._server_accept_shot(1,1,shooter.life_id,shooter.camera_pivot.global_position,Vector3.FORWARD,"glock")
	var size_after: int = game.projectiles.size()
	game._server_accept_shot(1,1,shooter.life_id,shooter.camera_pivot.global_position,Vector3.FORWARD,"glock")
	check(shooter.ammo.glock == 0 and game.projectiles.size() == size_after,"one sequence one round")
	game.shot_clocks.clear()
	game._server_accept_shot(1,2,shooter.life_id,shooter.camera_pivot.global_position,Vector3.FORWARD,"glock")
	check(shooter.ammo.glock == 0 and game.projectiles.size() == size_after,"empty gun no projectile")
	shooter.ammo.glock = 5
	game._server_accept_shot(1,3,shooter.life_id,Vector3(100,2,100),Vector3.FORWARD,"glock")
	check(shooter.ammo.glock == 5,"invalid camera origin rejected")
	game._server_accept_shot(1,4,shooter.life_id,shooter.camera_pivot.global_position,Vector3.BACK,"glock")
	check(shooter.ammo.glock == 5,"implausible aim rejected")
	# A wall between character and muzzle blocks even a camera that sees past it.
	game.shot_clocks.clear()
	var wall: Node3D = game._static_box(game.world_root,"MuzzleWall",Vector3(0,1.4,-0.20),Vector3(2,2,0.08),Color.GRAY)
	await physics_frame
	await physics_frame
	var before: int = game.projectiles.size()
	game._server_accept_shot(1,5,shooter.life_id,shooter.camera_pivot.global_position,Vector3.FORWARD,"glock")
	check(shooter.ammo.glock == 4 and game.projectiles.size() == before,"muzzle wall obstructs physical shot")
	wall.get_parent().queue_free()
	# Menu stack blocks gameplay and duplicates, restoring only the upper panel.
	game.ui_focus.open(game.pause_panel)
	game.ui_focus.open(game.pause_panel)
	check(game.ui_focus.stack.size() == 1 and not game.gameplay_input_allowed(),"unique modal blocks combat")
	game._toggle_shop()
	check(game.ui_focus.stack.size() == 2 and not game.pause_panel.visible and game.shop_panel.visible,"top modal owns input")
	game.ui_focus.close_top()
	check(game.pause_panel.visible and not game.shop_panel.visible,"modal restores prior menu")
	game.ui_focus.close_all()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"closing menu requires recapture click")
	for pending in game.projectiles:
		game._release_projectile_visual(pending)
	game.projectiles.clear()
	# Rig and hitboxes follow crouching and proportions rather than a capsule proxy.
	target.apply_body_proportions({"head":1.2,"torso":0.9,"arms":1.1,"legs":1.0})
	target._set_crouched(true)
	await physics_frame
	await physics_frame
	var crouch_head := cast_region(target,"head")
	check(not crouch_head.is_empty() and crouch_head.collider.get_meta("hit_region") == "head","scaled crouched head has physical region")
	target._set_crouched(false)
	target.apply_body_proportions({})
	# Actual simulated rounds at 20 and 60 metres, then a moving target.
	game.set_physics_process(false)
	for distance in [20.0,60.0]:
		target.hp = 100.0
		target.limbs = CombatRules.fresh_limbs()
		target.global_position = Vector3(0,0,-distance)
		shooter.weapon_id = "fal"
		shooter.pitch = atan2(1.32 - 1.68,distance)
		shooter._refresh_weapon()
		shooter._update_weapon_pose()
		await physics_frame
		await physics_frame
		var end: Vector3 = target.hit_regions.chest.global_position
		var origin := shooter.get_muzzle_position()
		game._spawn_projectile(1,origin,(end-origin).normalized(),"fal",false,true,"range-"+str(distance))
		for i in range(120): game._step_projectiles(1.0/120.0)
		check(target.hp > 0.0 and target.hp < 100.0,"simulated projectile damage at %.0f metres" % distance)
		target.hp = 100.0
		target.limbs = CombatRules.fresh_limbs()
	# Hitscan is a separate immediate path, not an extra damage pass on projectiles.
	var ray_origin: Vector3 = target.hit_regions.chest.global_position + Vector3(0,0,3)
	game._resolve_hitscan(1,ray_origin,Vector3.FORWARD,CombatRules.weapon("glock"),"hitscan-case")
	check(target.hp == 70.0,"hitscan applies one immediate chest hit")
	target.hp = 100.0
	var cover: Node3D = game._static_box(game.world_root,"Cover",Vector3(0,1.2,-50),Vector3(3,3,0.2),Color.GRAY)
	await physics_frame
	await physics_frame
	game._spawn_projectile(1,Vector3(0,1.3,0),Vector3.FORWARD,"fal",false,true,"cover-case")
	for i in range(120): game._step_projectiles(1.0/120.0)
	check(target.hp == 100.0,"cover blocks damage to the body behind it")
	cover.get_parent().queue_free()
	# A slow frame still clamps the ray to the weapon's configured range.
	game._spawn_projectile(1,Vector3(30,20,0),Vector3.RIGHT,"fal",false,true,"max-range-case")
	var limited: Dictionary = game.projectiles.back()
	game._step_projectiles(1.0)
	check(limited.distance <= 80.001,"maximum range survives a large physics step")
	target.global_position = Vector3(-0.1,0,-30)
	target.hp = 100.0
	target.limbs = CombatRules.fresh_limbs()
	await physics_frame
	await physics_frame
	var moving_origin := Vector3(0,1.32,0)
	game._spawn_projectile(1,moving_origin,Vector3.FORWARD,"fal",false,true,"moving-case")
	for i in range(12):
		target.global_position.x += 1.0/60.0
		await physics_frame
		game._step_projectiles(1.0/60.0)
	check(target.hp < 100.0,"swept projectile hits moving body regions")
	# Repeated pistol hits can disable only the struck arm while leaving health.
	target.hp = 100.0
	target.limbs = CombatRules.fresh_limbs()
	for i in range(3): target.take_damage(34.0,"armL",1)
	check(target.hp > 0.0 and target.limbs.armL == 0.0 and target.limbs.armR == 100.0,"localized accumulated arm impairment")
	check(target.detached_region.is_empty(),"pistol damage never arbitrarily dismembers")
	game.player_in_vehicle = true
	var old_sequence := shooter.shot_sequence
	shooter.fire()
	check(shooter.shot_sequence == old_sequence,"vehicle state blocks personal firearms")
	game.player_in_vehicle = false
	game.set_physics_process(true)
	# Lethal headshot -> one corpse -> no stale actor or live hitboxes.
	target.hp = 100.0
	target.take_damage(1.0,"head",1)
	check(target.hp == 0.0 and not game.players.has(2),"fatal headshot and NPC cleanup")
	var corpse_count := get_nodes_in_group("death_ragdolls").size()
	game.spawn_ragdoll(target.global_position,1,target)
	check(get_nodes_in_group("death_ragdolls").size() == corpse_count,"death effect deduplicated")
	await physics_frame
	await physics_frame
	game.update_hud()
	for i in range(30): await physics_frame
	print("COMBAT_CHECKS=",checks," FAILURES=",errors.size())
	FileAccess.open("res://tests/local-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":errors}))
	game.show_menu()
	game.queue_free()
	await create_timer(0.15).timeout
	await process_frame
	quit(0 if errors.is_empty() else 1)
