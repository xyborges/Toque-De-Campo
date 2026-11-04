extends "res://tests/nova_render_inventory.gd"

# Quick renderer inventory only; does not establish a performance gain.
func run() -> void:
	seed(193);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: push_error("shadow inventory world failed");quit(1);return
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(3).timeout
	var camera:=Camera3D.new();camera.far=3000;root.add_child(camera)
	camera.position=WarTerrain.point(-80,-315)+Vector3(0,2.5,10);camera.look_at(WarTerrain.point(-80,-260)+Vector3.UP*.4);camera.make_current()
	var originals: Array[Dictionary]=[]
	for light: DirectionalLight3D in game.world_root.find_children("*","DirectionalLight3D",true,false): originals.append({"light":light,"mode":light.directional_shadow_mode,"enabled":light.shadow_enabled,"distance":light.directional_shadow_max_distance})
	RenderingServer.render_loop_enabled=false
	var values: Dictionary={"original":await draw_count()}
	for mode in [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,DirectionalLight3D.SHADOW_ORTHOGONAL]:
		for item: Dictionary in originals: item.light.directional_shadow_mode=mode
		values[str(mode)]=await draw_count()
	for item: Dictionary in originals: item.light.directional_shadow_mode=item.mode
	values.restored=await draw_count()
	var lights: Array=[]
	for item: Dictionary in originals: lights.append({"mode":item.mode,"enabled":item.enabled,"distance":item.distance})
	var report:={"draw_calls":values,"lights":lights,"note":"Fixed-view draw counts only; changes shadow detail, not measured FPS or runtime adoption."}
	NavalStorage.write_json("res://work/nova-shadow-inventory.json",report)
	print("SHADOW_INVENTORY ",JSON.stringify(report));game.queue_free();await process_frame;quit()
