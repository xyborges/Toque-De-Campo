extends SceneTree
var game: WarGame
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DisplayServer.window_set_title("Toque de Campo — posturas 1.9.3")
	game=load("res://tests/review192_game.gd").new();game.offline_operation=true;game.set_meta("test_mode",true);game.set_meta("war_test",true);game.set_meta("war_visual_preview",true);root.add_child(game)
	game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.join_ready=true;game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	game.hud_layer.hide();game.ui_focus.close_all()
	for v: WarVehicle in game.vehicle_system.vehicles.values(): v.position=Vector3(500,0,500);v.collision_layer=0
	for i in 3:
		var id:=i+1;var actor:=game._spawn_player(id,false,false,Vector3.ZERO) as WarPlayer
		game.members[id]={"team":i%2,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"respawn_pending":false,"shield":0.,"gadget":WarRules.launcher_for_team(i%2),"pending":{}}
		game._deploy(id,i%2,"soldier",WarRules.TEAM_RIFLES[i%2],WarRules.launcher_for_team(i%2),"base")
		actor.set_physics_process(false);actor.position=Vector3(i*2.7-2.7,.03,0);actor.yaw=0;actor.rotation=Vector3.ZERO;actor.pitch=0
		actor.set_posture(i)
		for j in 80: actor.stance.advance(actor,1./60.);actor.next_pose_usec=0;actor._animate_walk()
	var camera:=Camera3D.new();root.add_child(camera);camera.fov=45;camera.position=Vector3(4,2.2,-5.5);camera.look_at(Vector3(0,.7,-.1));camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await create_timer(1).timeout;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/offline193-postures.png")
	for i in 3:
		var p: Vector3=game.players[i+1].position
		camera.position=p+Vector3(1.8,1.3,-2.5);camera.look_at(p+Vector3(0,.7,0));await create_timer(.3).timeout
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/offline193-posture-%d.png"%i)
	for i in 15:
		await create_timer(1).timeout
	game.show_menu();game.queue_free();await process_frame;quit()
