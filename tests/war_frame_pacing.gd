extends SceneTree

# Native rendering and actual production movement/cameras, with bots stopped
# on a temporary physical test lane above the unchanged authored map.
var game: WarGame
var report: Dictionary={"phases":[],"failures":[]}
var frames: Array=[]
var recording:=false
var previous_usec:=0
var previous_physics:=0
var previous_position:=Vector3.ZERO
var phase_started:=0
var platform:=Vector3.ZERO

func _initialize() -> void: run.call_deferred()

func sample() -> void:
	if not recording:return
	var now:=Time.get_ticks_usec()
	var camera:=root.get_camera_3d()
	var tick:=Engine.get_physics_frames()
	if previous_usec>0:
		frames.append([(now-phase_started)*.001,(now-previous_usec)*.001,tick-previous_physics,camera.global_position.distance_to(previous_position),Performance.get_monitor(Performance.TIME_PROCESS)*1000.,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.])
	previous_usec=now;previous_physics=tick;previous_position=camera.global_position

func phase(label_text: String,seconds: float) -> void:
	await create_timer(2.).timeout
	frames=[];previous_usec=0;phase_started=Time.get_ticks_usec();recording=true
	var camera_start:=root.get_camera_3d().global_position
	await create_timer(seconds).timeout
	recording=false
	var values: Array=[];var repeated:=0;var double_ticks:=0
	for row: Array in frames:
		values.append(row[1])
		if row[3]<.00001:repeated+=1
		if row[2]>1:double_ticks+=1
	values.sort()
	var result:={"label":label_text,"frames":frames,"distance":root.get_camera_3d().global_position.distance_to(camera_start),"p50_ms":values[values.size()/2],"p95_ms":values[int(values.size()*.95)],"max_ms":values.back(),"repeated_camera_frames":repeated,"multiple_physics_steps":double_ticks}
	report.phases.append(result)
	print("PACING ",label_text," p50=",result.p50_ms," p95=",result.p95_ms," max=",result.max_ms," repeats=",repeated," double=",double_ticks," distance=",result.distance)
	if result.distance<8.:report.failures.append(label_text+": movement did not run")

func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	game=WarGame.new();game.offline_operation=true;game.offline_participants=2
	game.set_meta("test_mode",true);game.set_meta("war_test",true);root.add_child(game)
	var until:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<until:await process_frame
	if not game.join_ready:quit(1);return
	game.request_deploy(0,"soldier","fal","rpg","base")
	await create_timer(.5).timeout
	game.bot_director.stop()
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED);Engine.max_fps=0
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(700,1,40);shape.shape=box;body.add_child(shape);game.world_root.add_child(body)
	platform=WarTerrain.point(-850,40)+Vector3.UP*30;body.position=platform
	var actor:=game.local_player as WarPlayer
	actor.position=platform+Vector3(-250,1,0);actor.yaw=-PI*.5;actor.rotation.y=actor.yaw;actor.pitch=0;actor.velocity=Vector3.ZERO
	game.third_person=false;actor._update_view()
	RenderingServer.frame_pre_draw.connect(sample)
	Input.action_press("move_forward")
	await phase("foot-vsync",12.)
	var day: Node=game.world_root.get_node("WarDayNight");day.set_process(false)
	await phase("foot-sky-frozen",12.)
	Input.action_release("move_forward");day.set_process(true)
	var tank:=game.vehicle_system.vehicles.v_abrams as WarVehicle
	tank.position=platform+Vector3(-250,1.2,0);tank.heading=-PI*.5;tank.rotation.y=tank.heading;tank.resting=false;tank.speed=0
	actor.position=tank.position+Vector3(0,0,4)
	game.vehicle_system.command_for(1,"enter",{"id":tank.vehicle_id})
	if actor.vehicle_id!=tank.vehicle_id:report.failures.append("tank boarding failed")
	Input.action_press("move_forward")
	await phase("tank-vsync",12.)
	day.set_process(false)
	await phase("tank-sky-frozen",12.)
	Input.action_release("move_forward")
	RenderingServer.frame_pre_draw.disconnect(sample)
	report.gpu=RenderingServer.get_video_adapter_name();report.refresh_hz=DisplayServer.screen_get_refresh_rate();report.physics_hz=Engine.physics_ticks_per_second
	report.sample_columns=["elapsed_ms","frame_ms","physics_steps","camera_distance_m","process_ms","physics_ms"]
	NavalStorage.write_json("res://work/microstutter1105/native-pacing.json",report)
	print("PACING_DONE ",report.failures)
	game.show_menu();game.queue_free();await process_frame;await process_frame;quit(0 if report.failures.is_empty() else 1)
