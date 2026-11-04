extends SceneTree
var errors: Array[String]=[]
var checks:=0
var game: WarGame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)
func frames(count: int) -> void:
	for index in count:await process_frame
func capture(label: String) -> void:
	await frames(2);RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/render-distance-"+label+".png")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<until:await process_frame
	check(game.join_ready,"production War world loaded")
	if not game.join_ready:quit(1);return
	var slots:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",1);slots.optic="scope4x"
	game.request_deploy(1,"soldier","ak","rpg","base",slots)
	var actor:=game.local_player as WarPlayer
	game.ui_focus.close_all();game.third_person=false;actor._update_view()
	var manager: Node=game.world_root.get_node_or_null("VegetationVisuals")
	check(is_instance_valid(manager) and manager.available,"new grass enabled without a QA flag")
	if not is_instance_valid(manager) or not manager.available:game.queue_free();quit(1);return
	check(manager.level==2,"normal default is medium grass")
	check(get_nodes_in_group("war_legacy_grass").is_empty(),"normal match does not build old grass")
	var controller: Node=game.world_root.get_node_or_null("ScenarioRendering")
	check(is_instance_valid(controller) and controller.distance==400.,"normal default is 400 metres")
	actor.global_position=WarTerrain.point(-150,-650)+Vector3.UP*.2;actor.yaw=0.;actor.rotation.y=0.
	await create_timer(.8).timeout
	var stream: Node=manager.streamer
	check(stream.pool.size()==49 and stream.far_pool.size()==49,"near and far pools are fixed at 49 each")
	var initial_nodes:=game.world_root.find_children("Grass*Pool*","MultiMeshInstance3D",true,false).size()
	var shapes:=game.world_root.find_children("*","CollisionShape3D",true,false).size()
	for metres in [250,400,650,900]:
		GameOptions.set_value("render_distance",metres);GameOptions.apply(root,game.world_root);await frames(3)
		check(controller.distance==metres,"video range applied: %d"%metres)
		check(game.world_root.find_children("*","CollisionShape3D",true,false).size()==shapes,"range preserves physical world")
	for level in [1,2,3]:
		GameOptions.set_value("war_vegetation",level);GameOptions.apply(root,game.world_root);await frames(3)
		check(manager.level==level and stream.mesh==stream.variants[level-1],"prepared vegetation variant applied")
		check(stream.pool.size()+stream.far_pool.size()==98,"quality does not allocate cells")
	GameOptions.set_value("render_distance",400);GameOptions.set_value("war_vegetation",2);GameOptions.apply(root,game.world_root)
	await capture("near-medium")
	actor.iron_sights=true;actor.aiming=true;actor._update_view();await create_timer(.5).timeout
	check(actor.weapon_optics.active,"actual AK optical viewport active")
	check(controller.focus_active,"AK optic feeds the focus controller")
	check(controller.switches>0,"actual scenery detail is promoted by the optic")
	await capture("scope")
	actor.clear_aim();actor.weapon_optics.stop();actor.apply_identity(1,"marksman");actor.set_utility("binoculars");actor.set_utility_zoom(1)
	await create_timer(.5).timeout
	check(actor.utility_zoom==1 and actor.camera.fov<42.,"actual binocular zoom active")
	check(controller.focus_active,"binocular feeds the same focus controller")
	await capture("binocular")
	actor.set_utility("");actor._update_view()
	# Rapid camera pitch while walking crosses real terrain and cell borders.
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	actor.global_position=WarTerrain.point(-150,-650)+Vector3.UP*.2;var origin:=actor.global_position
	await create_timer(1.).timeout
	var samples: Array[float]=[];var start:=Time.get_ticks_usec();var previous:=start
	Input.action_press("move_forward")
	while Time.get_ticks_usec()-start<20000000:
		var elapsed:=float(Time.get_ticks_usec()-start)/1000000.
		actor.pitch=sin(elapsed*3.)*.45;actor.camera_pivot.rotation.x=actor.pitch
		await process_frame
		var now:=Time.get_ticks_usec();samples.append((now-previous)*.001);previous=now
	Input.action_release("move_forward");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	check(actor.global_position.distance_to(origin)>2.,"physical walking remained active during pitch stress")
	check(game.world_root.find_children("Grass*Pool*","MultiMeshInstance3D",true,false).size()==initial_nodes,"stream crossing creates or destroys no cells")
	var sorted:=samples.duplicate();sorted.sort();var over33:=0;var over50:=0
	for ms in samples:
		if ms>33.:over33+=1
		if ms>50.:over50+=1
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors,"gpu":RenderingServer.get_video_adapter_name(),"resolution":str(root.get_texture().get_size()),"participants":game.players.size(),"median_fps":1000./sorted[sorted.size()/2],"p99_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*.99)-1)],"worst_ms":sorted.back(),"over33_count":over33,"over50_count":over50,"movement_metres":actor.global_position.distance_to(origin),"rendering":controller.diagnostics(),"near_cells":stream.pool.size(),"far_cells":stream.far_pool.size(),"scope":"20-second graphical movement stress with real War actors, rapid pitch, actual scope/binocular and all presets; not paired A/B acceptance"}
	NavalStorage.write_json("res://work/render-distance-gameplay.json",report);print("RENDER_DISTANCE_GAMEPLAY ",JSON.stringify(report))
	game.show_menu();game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
