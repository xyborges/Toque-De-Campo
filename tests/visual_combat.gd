extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/" + name_value + ".png")

func run() -> void:
	root.title = "Toque de Campo · Validação de combate"
	var game: Node3D = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode = "training"
	game.map_kind = "sandbox"
	game._enter_match_world()
	game._static_box(game.world_root,"Floor",Vector3(0,-0.25,-20),Vector3(100,0.4,100),Color("#9c9c8f"))
	game._static_box(game.world_root,"Wall",Vector3(0,2,-12),Vector3(12,4,0.4),Color("#63737b"))
	var actor: GamePlayer = game._spawn_player(1,true,false,Vector3.ZERO)
	actor.set_physics_process(false)
	var other: GamePlayer = game._spawn_player(2,false,false,Vector3(0,0,-6))
	other.set_physics_process(false)
	other._animate_walk()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/screens"))
	for weapon in ["glock","fal","sniper"]:
		actor.weapon_id = weapon
		actor._refresh_weapon()
		actor._animate_walk()
		game.third_person = false
		actor._update_view()
		actor._update_weapon_pose()
		game.update_hud()
		await capture("fpp-"+weapon)
		actor.aiming = true
		actor.iron_sights = true
		actor._update_view()
		actor._update_weapon_pose()
		game.update_hud()
		await capture("ads-"+weapon)
		actor.aiming = false
		actor.iron_sights = false
		game.third_person = true
		actor._update_view()
		actor._update_weapon_pose()
		game.update_hud()
		await capture("tpp-"+weapon)
		var inspection := Camera3D.new()
		game.world_root.add_child(inspection)
		inspection.global_position = Vector3(2.4,1.65,0.9)
		inspection.look_at(Vector3(0,1.20,-0.30))
		inspection.current = true
		await capture("world-grip-"+weapon)
		inspection.queue_free()
		actor.camera.current = true
	game.ui_focus.open(game.pause_panel)
	game._toggle_shop()
	await capture("menus")
	print("VISUAL_CAPTURES_OK")
	game.queue_free()
	await process_frame
	quit()
