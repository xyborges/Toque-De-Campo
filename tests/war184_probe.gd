extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	while not game.join_ready: await process_frame
	game.war_ui.deploy_button.pressed.emit();await create_timer(.3).timeout
	if game.bot_director: game.bot_director.set_physics_process(false)
	game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	var actor:=game.local_player as WarPlayer
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=true
	actor.global_position=WarRules.BASES[0]+Vector3(0,.2,30);actor.weapon_id="fal";actor._refresh_weapon();actor._update_view()
	for distance_value in [3.25,4.0]:
		actor.shoulder_distance=distance_value;actor.shoulder_arm.spring_length=distance_value
		await physics_frame;await physics_frame
		actor._update_camera_collision(.016)
		actor.fire_cooldown=0;var before: int=actor.ammo.fal;actor.fire()
		print("TPP_PROBE ",JSON.stringify({"distance_setting":distance_value,"eye_distance":actor.camera.global_position.distance_to(actor.camera_pivot.global_position),"ammo_before":before,"ammo_after":actor.ammo.fal,"blocked":not game.gameplay_input_allowed(),"limbs":actor.limbs,"hp":actor.hp,"deployed":actor.deployed}))
		await create_timer(.15).timeout
	var ship:=game.vehicle_system.vehicles.v_naval_assault_0 as WarShip
	actor.vehicle_id=ship.vehicle_id;game.members[1].vehicle=ship.vehicle_id;ship.allocate_seat(1)
	ship.global_position=Vector3(-1200,0,-650);await physics_frame;await physics_frame
	print("EXIT_PROBE ",game.vehicle_system.safe_exit(ship,actor))
	var p: Vector3=WarCoast.PORTS[1];print("GROUND_PROBE terrain=",WarTerrain.height_at(p.x,p.z)," quay_top=",p.y)
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit()
