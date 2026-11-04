extends SceneTree
var game: WarGame
var viewport: SubViewport
var camera: Camera3D
var measurements: Dictionary={}
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func view(label: String,target: Vector3,offset: Vector3,measure:=false) -> void:
	camera.position=target+offset
	camera.position.y=maxf(camera.position.y,WarTerrain.height_at(camera.position.x,camera.position.z)+1.2)
	camera.look_at(target);camera.make_current()
	await create_timer(3.).timeout;RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png("res://work/library190-"+label+".png")
	if not measure: return
	var times: Array[float]=[];var end:=Time.get_ticks_usec()+4000000;var last:=Time.get_ticks_usec()
	while Time.get_ticks_usec()<end:
		await process_frame;var now:=Time.get_ticks_usec();times.append((now-last)*.001);last=now
	times.sort();var total:=0.;var slow:=0.;var count:=maxi(1,ceili(times.size()*.01))
	for t in times: total+=t
	for i in count: slow+=times[times.size()-1-i]
	measurements[label]={"fps":times.size()*1000./total,"one_percent_low":count*1000./slow,"p95_ms":times[int(times.size()*.95)],"peak_ms":times[-1],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	viewport=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.own_world_3d=true;root.add_child(viewport)
	var display:=TextureRect.new();display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(display)
	game=WarGame.new();game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_visual_preview",true);viewport.add_child(game)
	game.online=false;game.mode="pvp";game.map_kind="desert"
	var start:=Time.get_ticks_usec();game._enter_match_world();measurements.build_ms=float(Time.get_ticks_usec()-start)*.001
	game.set_process(false);game.set_physics_process(false);game.vehicle_system.set_process(false);game.vehicle_system.set_physics_process(false)
	game.soundscape.set_process(false);game.hud_layer.hide();game.menu_layer.hide()
	camera=Camera3D.new();camera.fov=58;camera.far=4200;game.world_root.add_child(camera)
	await view("base",WarRules.BASES[0]+Vector3(42,1,8),Vector3(-35,24,43),true)
	var trench:=WarRules.BASES[0]+Vector3(81,0,41);trench.y=WarTerrain.height_at(trench.x,trench.z)+1.1
	await view("trench",trench,Vector3(5.5,4.8,6.8),true)
	await view("village",WarTerrain.point(-610,610)+Vector3.UP*1.5,Vector3(-45,28,65),true)
	await view("west-quay",Vector3(-875,4,-445),Vector3(-65,40,-45),true)
	await view("east-quay",Vector3(1240,4,470),Vector3(70,36,50),true)
	var report: Dictionary={"failures":failures,"scope":"full map static views, no combat or twelve-player load","resolution":str(viewport.size),"gpu":RenderingServer.get_video_adapter_name(),"measurements":measurements}
	NavalStorage.write_json("res://tests/library190-visual-results.json",report);print(JSON.stringify(report))
	viewport.queue_free();display.queue_free();await create_timer(.8).timeout;quit()
