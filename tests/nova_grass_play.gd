extends "res://tests/nova_visual_fixture.gd"

# A playable preview only. The normal game and public release are unchanged.
func _ready() -> void:
	offline_operation=true;offline_participants=18;set_meta("test_mode",true);set_meta("nova_grama_preview",true)
	super._ready()
	preview.call_deferred()

func preview() -> void:
	var until:=Time.get_ticks_msec()+90000
	while not join_ready and Time.get_ticks_msec()<until: await get_tree().process_frame
	if not join_ready: push_error("grass preview world failed to load");return
	request_deploy(0,"soldier","fal","stinger","base")
	local_player.global_position=WarTerrain.point(-150,-650)+Vector3.UP*.15
	local_player.velocity=Vector3.ZERO;local_player.reset_physics_interpolation()
	ui_focus.close_all();third_person=true;local_player._update_view()
	get_window().title="Toque de Campo — Nova Grama · Prévia local"
	for controller in get_tree().get_nodes_in_group("war_vegetation_visuals"):
		if world_root.is_ancestor_of(controller): controller.apply_level(2)
	if "--preview-capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(8.).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://work/nova-grass-play-fixed.png")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-seconds="):
			var seconds:=clampf(float(arg.trim_prefix("--preview-seconds=")),10,600)
			await get_tree().create_timer(seconds).timeout
			get_tree().quit()
