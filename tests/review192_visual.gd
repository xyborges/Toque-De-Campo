extends SceneTree
var game: WarGame
var failures: Array[String]=[]
var folder:="res://work/review192-visual"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(label: String) -> void:
	await create_timer(.7).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+75000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: quit(1);return
	for resolution in [Vector2i(1920,1080),Vector2i(1280,800),Vector2i(1024,768)]:
		root.size=resolution;root.content_scale_size=resolution
		game.open_deployment()
		await capture("deployment-"+str(resolution.x))
		var map:=game.war_ui.deployment_map
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(map.get_global_rect()),"deployment map fits "+str(resolution))
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(game.war_ui.deploy_button.get_global_rect()),"deployment confirmation remains visible "+str(resolution))
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	game.request_deploy(0,"soldier","fal","stinger","base")
	until=Time.get_ticks_msec()+20000
	while game.players.size()<12 and Time.get_ticks_msec()<until: await process_frame
	if game.bot_director: game.bot_director.stop()
	game.set_physics_process(false)
	game.third_person=true;game.local_player._update_view();game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await capture("infantry-hud")
	game.war_ui.toggle_map();await capture("full-map");game.war_ui.close_map()
	var actor:=game.local_player as WarPlayer
	actor.set_physics_process(false)
	var manager:=game.vehicle_system
	var tank:=manager.vehicles.v_abrams as WarVehicle
	tank.position=WarTerrain.point(0,85)+Vector3.UP*.08;tank.heading=0;tank.rotation=Vector3.ZERO;tank.ground_support=WarVehicleGround.new();tank.speed=0;tank.velocity=Vector3.ZERO
	tank.allocate_seat(actor.peer_id);actor.vehicle_id=tank.vehicle_id;game.members[actor.peer_id].vehicle=tank.vehicle_id;manager.sync_occupants(tank)
	manager.vehicle_view.reset(false);manager.orbit_yaw=tank.heading+.6;manager.orbit_pitch=.12
	await capture("tank-optic-intent")
	var origin:=tank.muzzle.global_position
	var direction: Vector3=-tank.muzzle.global_basis.z
	manager._present_shot(actor.peer_id,origin,direction,"tank","visual-recoil")
	await process_frame
	check(is_instance_valid(tank.barrel_recoil) and tank.barrel_recoil_age<.2,"accepted tank shot starts mechanical recoil")
	await capture("tank-recoil-return")
	manager.vehicle_view.external=true;await capture("tank-external")
	var smoke: WarEffects=game.combat_effects
	smoke.explosion(tank.global_position+Vector3(0,2,-35),10,192,"tank")
	await create_timer(1.2).timeout;await capture("heavy-smoke")
	check(smoke.pool.visible_instance_count>0 and smoke.slots.size()==256,"heavy smoke uses the bounded existing visual pool")
	var excludes:=game.combat_audio.occlusion_excludes()
	check(tank.get_rid() in excludes and actor.get_rid() in excludes,"own hull and occupant are excluded from weapon occlusion")
	var confirmation_count:=game.combat_audio.confirmations.size()
	game.combat_audio.confirm_elimination("visual-positive",false);game.combat_audio.confirm_elimination("visual-positive",false)
	check(confirmation_count==4 and game.combat_audio.confirmation_events.size()==1,"private confirmation uses four reused 2D voices and deduplicates events")
	var explosion:=game.combat_audio.explosion_audio
	check(float(explosion.event_profile("tank").range)>float(explosion.event_profile("grenade").range),"heavy explosion range exceeds hand grenade range")
	NavalStorage.write_json(folder.path_join("results.json"),{"failures":failures,"native":true})
	game.show_menu();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
