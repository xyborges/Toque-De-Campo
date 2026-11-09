extends "res://tests/benchmark/war_1080p_benchmark.gd"

# Same fixture is run in the exact R2C baseline and candidate checkouts.
# Only ordinary movement input is injected; collision and 60 Hz remain live.
var bots:=28
var input_started:=-1
var input_step:=-1
var active_frames:=0
var observed_frames:=0
var motion_peak:=0.
const ACTIONS=["move_forward","move_right","move_back","move_left"]

func _initialize() -> void:
	super._initialize()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bots="):bots=int(arg.trim_prefix("--bots="))

func _process(_delta: float) -> bool:
	if input_started<0 or not is_instance_valid(game) or not is_instance_valid(game.local_player):return false
	var actor:=game.local_player as WarPlayer
	var step:=int((Time.get_ticks_msec()-input_started)/1000)%4
	if step!=input_step:
		for action: String in ACTIONS:Input.action_release(action)
		Input.action_press(ACTIONS[step]);input_step=step
	observed_frames+=1
	if actor.locomotion.world_pelvis_dirty:active_frames+=1
	motion_peak=maxf(motion_peak,absf(actor.locomotion.presentation_longitudinal)+absf(actor.locomotion.presentation_lateral))
	return false

func run() -> void:
	if DisplayServer.get_name()=="headless" or bots not in [0,12,22,28]:fail("requires rendered 0/12/22/28 fixture");return
	if Engine.physics_ticks_per_second!=60:fail("physics must be 60 Hz");return
	seed(712907)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size=Vector2i(1920,1080);root.scaling_3d_scale=1.
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameOptions.ensure();GameOptions.values.merge(GameOptions.PRESETS["Médio"],true)
	GameOptions.values["scale"]=1.;GameOptions.values["fps"]=0;GameOptions.values["vsync"]=false
	game=load("res://tests/war_frame_pacing_game.gd").new()
	game.operation_id=operation;game.offline_operation=true;game.offline_participants=bots+1
	game.set_meta("test_mode",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+120000
	while not game.join_ready and Time.get_ticks_msec()<deadline:await process_frame
	if not game.join_ready:fail("world not ready");return
	game.request_deploy(1,"soldier","g3",WarRules.launcher_for_team(1),"base")
	deadline=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(game.local_player) and game.local_player.deployed and is_instance_valid(game.bot_director) and game.bot_director.bots.size()==bots:break
	if not is_instance_valid(game.local_player) or not game.local_player.deployed or not is_instance_valid(game.bot_director) or game.bot_director.bots.size()!=bots:fail("population/deployment mismatch");return
	var actor:=game.local_player as WarPlayer
	if actor.weapon_id!="g3":fail("G3 deployment was rejected");return
	game.third_person=true;actor._update_view();game.ui_focus.close_all()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	camera=Camera3D.new();camera.far=2200.;camera.fov=70.;game.world_root.add_child(camera)
	var origin:=WarTerrain.point(-85,-20) if operation=="favela" else WarTerrain.point(-260,70)
	camera.global_position=origin+Vector3(-58,27,78);camera.look_at(origin+Vector3.UP*1.5);camera.make_current()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	input_started=Time.get_ticks_msec()
	await create_timer(warmup).timeout
	var rendered:=root.get_texture().get_size()
	if rendered!=Vector2(1920,1080) or not is_equal_approx(root.scaling_3d_scale,1.):fail("resolution/scale");return
	GamePerformanceProbe.start({"label":label,"bots":bots})
	active_frames=0;observed_frames=0;motion_peak=0.
	var start:=Time.get_ticks_usec()
	var start_epoch:=int(Time.get_unix_time_from_system()*1000.)
	var previous:=start
	var unfocused:=0
	var population_min:=bots
	var alive_local:=true
	print("R2C_BENCH_READY ",label," bots=",bots)
	while Time.get_ticks_usec()-start<duration*1000000.:
		await process_frame
		var now:=Time.get_ticks_usec()
		samples.append((now-previous)*.001);previous=now
		gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		cpu_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
		if not DisplayServer.window_is_focused():unfocused+=1
		population_min=mini(population_min,game.bot_director.bots.size())
		alive_local=alive_local and actor.hp>0. and actor.deployed
	var end_epoch:=int(Time.get_unix_time_from_system()*1000.)
	GamePerformanceProbe.stop()
	input_started=-1
	for action: String in ACTIONS:Input.action_release(action)
	var valid: bool=unfocused==0 and population_min==bots and game.bot_director.bots.size()==bots and alive_local and active_frames>0 and motion_peak>.05
	var result:={"label":label,"valid":valid,"bots":bots,"population_min":population_min,"population_final":game.bot_director.bots.size(),"local_alive":alive_local,"active_r2c_frames":active_frames,"observed_frames":observed_frames,"motion_peak":motion_peak,"unfocused_frames":unfocused,"physics_hz":Engine.physics_ticks_per_second,"gpu_name":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"render_texture":[rendered.x,rendered.y],"scale":root.scaling_3d_scale,"preset":"Médio","vsync":DisplayServer.window_get_vsync_mode(),"fps_cap":Engine.max_fps,"duration":duration,"warmup":warmup,"frames":_stats(samples),"physics_ms":_stats(physics_samples),"gpu_ms":_stats(gpu_samples),"process_ms":_stats(cpu_samples),"pose_scopes":GamePerformanceProbe.report(),"frame_time_trace_ms":samples,"measurement_window_unix_ms":{"start":start_epoch,"end":end_epoch},"scope":"Live offline physics, collision and bots; deterministic ordinary local G3 square input; R2C enabled in both source variants"}
	NavalStorage.write_json("res://work/r2c-validation/"+label+".json",result)
	print("R2C_BENCH_RESULT ",JSON.stringify({"label":label,"valid":valid,"fps":result.frames.average_fps,"p95_ms":result.frames.p95_ms,"p99_ms":result.frames.p99_ms,"active":active_frames,"unfocused":unfocused}))
	game.queue_free();await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	quit(0 if valid else 2)
