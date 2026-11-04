extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	while not game.join_ready: await process_frame
	game.request_deploy(0,"soldier","fal","stinger","base")
	await create_timer(.3).timeout
	game.bot_director.set_physics_process(false)
	for other in game.players.values(): other.set_physics_process(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var actor:=game.local_player as WarPlayer
	var original:=actor.position;actor._physics_process(1./60)
	print("PROBE_MOVEMENT ",original," -> ",actor.position)
	actor.position=original;actor.fire_cooldown=0;actor.ammo.fal=0;actor.start_reload()
	for i in 361: actor._physics_process(1./60)
	print("PROBE_RELOAD ",actor.ammo," ",actor.reload_weapon," ",actor.reload_left)
	var thermal:=game.vehicle_system.get_node("Thermal") as WarThermal
	thermal.set_enabled(true)
	game.members[1].shield=0.;actor.take_damage(1000,"chest",1)
	print("PROBE_DEATH ",actor.hp," ",game.members[1])
	await create_timer(8.7).timeout
	print("PROBE_RESPAWN ",actor.hp," ",actor.position," ",game.members[1])
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit()
