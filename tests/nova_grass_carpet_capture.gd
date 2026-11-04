extends SceneTree

var game: WarGame

func _initialize() -> void: run.call_deferred()

func snap(name: String) -> bool:
	for frame in 5: await process_frame
	var picture:=root.get_texture().get_image()
	return picture.save_png(ProjectSettings.globalize_path("res://work/"+name+".png"))==OK

func run() -> void:
	seed(193);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: push_error("carpet capture world not ready");quit(1);return
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(3).timeout
	game.hud_layer.hide();game.menu_layer.hide();game.ui_focus.close_all()
	var p:=Vector2(-150,-650);var camera:=Camera3D.new();camera.far=3000;root.add_child(camera)
	var start:=WarTerrain.point(p.x,p.y+12)+Vector3.UP*2.
	var target:=WarTerrain.point(p.x,p.y-25)+Vector3.UP*.7
	camera.position=start;camera.look_at(target);camera.make_current()
	if not await snap("nova-carpet-current"): push_error("old screenshot failed");quit(2);return
	var lab=load("res://tests/nova_grama_lab.gd").new();lab.ground_only=true;game.world_root.add_child(lab)
	if not lab.activate(): push_error("biome material failed");quit(3);return
	var carpet=load("res://tests/nova_grass_carpet.gd").new();game.world_root.add_child(carpet)
	if not carpet.build(game.world_root,p): push_error("carpet generation failed");quit(4);return
	if not await snap("nova-carpet-prototype"): push_error("new screenshot failed");quit(5);return
	print("CARPET_COUNTS ",JSON.stringify(carpet.counts))
	game.queue_free();camera.queue_free();await process_frame;quit()
