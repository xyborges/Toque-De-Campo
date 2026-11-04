extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/melee-"+label+".png")

func run() -> void:
	var game: Node3D = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.start_offline("training")
	game.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	var actor: GamePlayer = game.local_player
	actor.set_physics_process(false)
	actor.global_position = Vector3(0,0,-16)
	var inspection := Camera3D.new()
	game.world_root.add_child(inspection)
	inspection.global_position = actor.global_position+Vector3(1.9,1.75,2.2)
	inspection.look_at(actor.global_position+Vector3(0,1.1,-0.45))
	for weapon in ["broom","squeegee","axe"]:
		actor.weapon_id = weapon
		actor._refresh_weapon()
		actor._animate_walk()
		game.update_hud()
		inspection.current = true
		await capture(weapon+"-held")
		actor.play_fire_animation(weapon)
		var moment := lerpf(float(MeleeRig.SPECS[weapon].active_start),float(MeleeRig.SPECS[weapon].active_end),0.6)
		while actor.melee_rig.elapsed < moment-0.00001: actor._advance_melee(minf(0.10,moment-actor.melee_rig.elapsed))
		actor._animate_walk()
		await capture(weapon+"-swing")
		game.third_person = false
		actor._update_view()
		actor.camera.current = true
		actor._update_weapon_pose()
		await capture(weapon+"-fpp")
		game.third_person = true
		actor._update_view()
	print("MELEE_VISUAL_OK")
	game._stop_world_audio()
	game.queue_free()
	await process_frame
	quit()
