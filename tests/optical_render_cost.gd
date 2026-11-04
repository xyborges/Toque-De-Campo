extends SceneTree
# Isolate the second optical view in a fixed, real War scene. This does not
# measure moving bots, WAN latency or overall combat performance.
var game: WarGame
var actor: WarPlayer
var samples: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func variant(enabled: bool) -> void:
	if enabled: actor.weapon_optics.update(actor)
	else: actor.weapon_optics.stop()
func measure(enabled: bool,label: String) -> void:
	variant(enabled);await create_timer(2.).timeout
	var frames: Array[float]=[];var calls: Array[float]=[];var previous:=Time.get_ticks_usec()
	var until:=previous+10000000
	while Time.get_ticks_usec()<until:
		await process_frame
		var now:=Time.get_ticks_usec();frames.append((now-previous)*.001);previous=now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort();calls.sort()
	var sum:=0.;var slow:=0.;var count:=maxi(1,ceili(frames.size()*.01))
	for value in frames: sum+=value
	for i in count: slow+=frames[frames.size()-1-i]
	var report:={"label":label,"lens":enabled,"frames":frames.size(),"average_fps":1000.*frames.size()/sum,"low_1_percent_fps":1000./(slow/count),"worst_frame_ms":frames[-1],"p99_ms":frames[mini(frames.size()-1,floori(frames.size()*.99))],"median_draw_calls":calls[calls.size()/2],"participants":game.players.size()}
	samples.append(report);print("OPTICAL_COST_SAMPLE ",JSON.stringify(report))
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	seed(193);root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	game=WarGame.new();game.offline_operation=true;game.offline_participants=18;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until: await process_frame
	if not game.join_ready: push_error("world not ready");quit(2);return
	var loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",0);loadout.optic="scope4x"
	game.request_deploy(0,"soldier","fal","stinger","base",loadout);await create_timer(3.).timeout
	actor=game.local_player;game.ui_focus.close_all();game.loading_screen.hide();game.hud_layer.hide()
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.set_process_input(false);game.bot_director.stop()
	for node: Node in game.world_root.find_children("*","Node",true,false):
		node.set_process(false);node.set_physics_process(false);node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	root.title="Medição automática de luneta — controles desativados"
	var cycle:=game.world_root.find_child("WarDayNight",true,false) as WarDayNight
	cycle.apply_time(0.,true)
	actor.global_position=WarTerrain.point(-150,-650);actor.rotation=Vector3.ZERO;actor.pitch=0;actor.yaw=0
	actor.hp=100;actor.clear_aim();actor.cycle_weapon_aim();actor._update_weapon_pose();actor.camera.make_current()
	actor.weapon_optics.update(actor);await create_timer(3.).timeout;actor.weapon_optics.stop();await create_timer(2.).timeout
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for label in ["A1","B1","A2","B2","A3"]: await measure(label.begins_with("B"),label)
	actor.weapon_optics.update(actor);await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/optical-render-world.png")
	var report:={"samples":samples,"seed":193,"resolution":root.get_texture().get_size(),"rendering":"Compatibility","scope":"Fixed real War scene with 18 frozen participants. A/B/A/B/A isolates 384x384 lens rendering at identical main-camera pose/FOV. 10-second exploratory samples; no hardware clock control, not acceptance of overall game performance."}
	NavalStorage.write_json("res://work/optical-render-cost.json",report)
	game.queue_free();await process_frame;quit()
