extends SceneTree
var game: BattleRoyaleGame
func _initialize() -> void:run.call_deferred()
func capture(path: String) -> void:
	for frame in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,800));root.content_scale_size=Vector2i(1280,800)
	game=BattleRoyaleGame.new();game.set_meta("test_mode",true);root.add_child(game)
	for frame in 30:await physics_frame
	if game.phase!="active":push_error("Full-map BR did not start");game.free();quit(1);return
	game.set_physics_process(false)
	for actor: GamePlayer in game.players.values():actor.set_physics_process(false)
	var actor:=game.local_player as BRPlayer
	var house: Vector3=BRAfghanMap.building_layout()[0].position
	var best:=Vector3.INF;var score:=INF
	for point: Vector3 in game.navigation.spawn_candidates():
		var distance:=point.distance_to(house+Vector3(0,0,22))
		if distance<score:score=distance;best=point
	actor.global_position=best+Vector3.UP*.08
	var aim:=house+Vector3.UP*1.5-actor.camera_pivot.global_position
	actor.yaw=atan2(-aim.x,-aim.z);actor.rotation.y=actor.yaw;actor.pitch=asin(clampf(aim.normalized().y,-1.,1.));actor.camera_pivot.rotation.x=actor.pitch
	actor._update_view();game.ui_focus.close_all();game._send_br_states();game._refresh_br_ui()
	await capture("res://work/br-final-map-hud.png")
	for item in [{"kind":"weapon","weapon":"fal","magazine":12},{"kind":"optic","optic":"prism4x"},{"kind":"optic","optic":"pso4x"},{"kind":"pack","level":3},{"kind":"vest","level":3},{"kind":"helmet","level":2},{"kind":"ammo","calibre":"76251","amount":40}]:
		item.position=actor.global_position+Vector3(.4,0,0)
		var id:=game.br_inventory.add_loot(item)
		game._br_action(actor.peer_id,"pickup",{"id":id},actor.life_id,game.br_generation)
	game.request_br_optic("fal","prism4x");game._refresh_br_ui();game.ui_focus.open(game.br_hud.inventory_panel)
	await capture("res://work/br-final-inventory.png")
	game.ui_focus.close_all();actor.iron_sights=true;actor.aiming=true;actor._update_view();actor._update_weapon_pose();actor.weapon_optics.update(actor)
	await capture("res://work/br-final-optic.png")
	actor.clear_aim();actor._update_view()
	var center:=Vector2(actor.global_position.x,actor.global_position.z)+Vector2(sin(actor.yaw),cos(actor.yaw))*35.
	game.zone_parameters={"center":center,"radius":45.,"target_center":center,"target_radius":45.,"close_started_at":game._now()+40.,"duration":40.,"phase":4}
	game.snapshot.zone=game.zone_parameters;game._refresh_br_ui();game.zone_effect._process(.2)
	await capture("res://work/br-final-zone.png")
	game.settings_panel.present(1)
	for frame in 3:await process_frame
	var scroll:=game.settings_panel.tabs.get_child(1) as ScrollContainer;scroll.scroll_vertical=700
	await capture("res://work/br-final-voice-settings.png")
	game.ui_focus.close_all();game.free();await process_frame
	print("BR_VISUAL_REVIEW complete, full Afghan scene and actual HUD/inventory/optics/zone/audio settings, 1280x800; no FPS measurement.");quit(0)
