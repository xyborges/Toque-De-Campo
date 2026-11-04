extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode = "training"
	game.map_kind = "sandbox"
	game._enter_match_world()
	var actor: GamePlayer = game._spawn_player(1,true,false,Vector3.ZERO)
	actor.set_physics_process(false)
	for weapon in ["broom","squeegee","axe"]:
		actor.weapon_id = weapon
		actor._refresh_weapon()
		actor._update_weapon_pose()
		actor.melee_rig.start()
		for moment in [float(MeleeRig.SPECS[weapon].active_start),lerpf(float(MeleeRig.SPECS[weapon].active_start),float(MeleeRig.SPECS[weapon].active_end),0.5),float(MeleeRig.SPECS[weapon].active_end)]:
			actor.melee_rig.animator.seek(moment,true)
			print(weapon," t=",moment," head=",actor.melee_rig.samples())
	game.queue_free()
	await process_frame
	quit()
