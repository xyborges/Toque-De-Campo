extends SceneTree
var game: WarGame
var camera: Camera3D
var rows: Array[Dictionary]=[]
var report_root:="res://work/perf192"
var label:="current"
var previous:=0
var frames: Array[float]=[]
var cpu: Array[float]=[]
var physics: Array[float]=[]
var gpu: Array[float]=[]
var calls: Array[float]=[]
var memory:=0.0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg.begins_with("--report-root="): report_root=arg.trim_prefix("--report-root=")
	run.call_deferred()
func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var ordered:=values.duplicate();ordered.sort();var sum:=0.;var low:=0.;var n:=maxi(1,ceili(values.size()*.01))
	for value in values: sum+=value
	for i in n: low+=ordered[ordered.size()-1-i]
	return {"mean":sum/values.size(),"p95":ordered[int(ordered.size()*.95)],"maximum":ordered.back(),"one_percent_low_fps":n*1000./maxf(.001,low)}
func measure(name: String,a: Vector3,b: Vector3,target: Vector3) -> void:
	frames.clear();cpu.clear();physics.clear();gpu.clear();calls.clear();memory=0
	camera.global_position=a;camera.look_at(target)
	var started:=Time.get_ticks_usec();previous=started
	while Time.get_ticks_usec()-started<5000000:
		await process_frame
		var elapsed:=(Time.get_ticks_usec()-started)*.000001
		camera.global_position=a.lerp(b,clampf((elapsed-1)/4.,0,1));camera.look_at(target)
		RenderingServer.force_draw(false)
		var now:=Time.get_ticks_usec()
		if elapsed>1.:
			frames.append((now-previous)*.001)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			memory=maxf(memory,Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.)
		previous=now
	var row:={"phase":name,"frame_ms":stats(frames),"cpu_monitor_ms":stats(cpu),"physics_monitor_ms":stats(physics),"gpu_ms":stats(gpu),"draw_calls":stats(calls),"memory_mib":memory}
	rows.append(row);print(JSON.stringify(row))
	root.get_texture().get_image().save_png(report_root.path_join(label+"-"+name+".png"))
func run() -> void:
	Engine.max_fps=0;OS.low_processor_usage_mode=false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var limit:=Time.get_ticks_msec()+65000
	while not game.join_ready and Time.get_ticks_msec()<limit: await process_frame
	if not game.join_ready: quit(1);return
	game.set_physics_process(false)
	if is_instance_valid(game.bot_director): game.bot_director.stop()
	game.ui_focus.close_all();game.hud_layer.hide();game.war_ui.hide()
	game.war_clock=0;game.weather_seed=1
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);RenderingServer.render_loop_enabled=false
	camera=Camera3D.new();camera.far=3000;camera.fov=70;root.add_child(camera);camera.make_current()
	var approach:=WarTerrain.point(1010,441)+Vector3.UP*5
	var inner:=Vector3(1170,9,467)
	await measure("before_E",approach,approach,Vector3(1215,7,470))
	await measure("enter_E",approach,inner,Vector3(1215,7,470))
	await measure("inside_E",inner,inner,Vector3(1215,7,470))
	await measure("leave_E",inner,approach,WarTerrain.point(975,435)+Vector3.UP*4)
	await measure("port_D",Vector3(-850,17,-510),Vector3(-850,17,-510),Vector3(-820,5,-440))
	var report:={"label":label,"size":str(root.get_texture().get_size()),"gpu":RenderingServer.get_video_adapter_name(),"rows":rows,"note":"One real native client, real world and moving camera; no network load or twelve-player performance claim. CPU monitors are inclusive, not additive. Zero GPU timer means unavailable."}
	NavalStorage.write_json(report_root.path_join(label+"-ports.json"),report)
	game.queue_free();camera.queue_free();await process_frame;await process_frame;quit()
