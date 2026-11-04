extends SceneTree
# Fixed world/camera ablation test. Timed sections never capture images or write files.
var label := "baseline"
var report_dir := "res://work/perf181"
var diagnostic := false
var game: WarGame
var camera: Camera3D
var rows: Array[Dictionary] = []
var viewer: WarThermal
var seconds := 5.0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg.begins_with("--report-root="): report_dir=arg.trim_prefix("--report-root=")
		if arg=="--ablation": diagnostic=true
	run.call_deferred()

func run() -> void:
	Engine.max_fps=0
	OS.low_processor_usage_mode=false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+60000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: push_error("Map did not load");quit(1);return
	game.request_deploy(0,"soldier","fal","rpg","rally")
	await create_timer(1).timeout
	game.process_mode=Node.PROCESS_MODE_DISABLED
	game.ui_focus.close_all();game.hud_layer.hide();game.menu_layer.hide()
	for node in game.world_root.find_children("*","Node",true,false):
		if node is GameDayNight: node.apply_time(0,true)
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.scaling_3d_scale=1.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	# Explicit single draws also work when Windows occludes/minimizes the window.
	# Never count idle process frames as rendered frames.
	RenderingServer.render_loop_enabled=false
	camera=Camera3D.new();camera.far=5000;camera.fov=75;root.add_child(camera);camera.make_current()
	viewer=game.vehicle_system.get_node("Thermal") as WarThermal
	# The same actor meshes, positions and scene are used on both revisions.
	var n:=0
	for actor: WarPlayer in game.players.values():
		actor.position=WarTerrain.point(-240+(n%6)*4,-140+(n/6)*5)
		actor.body_root.show();actor.weapon_root.show();n+=1
	var index:=0
	for id in ["v_guarani","v_bmp2","v_abrams","v_t90"]:
		var vehicle: WarVehicle=game.vehicle_system.vehicles[id]
		vehicle.global_position=WarTerrain.point(-270+index*16,-145)
		index+=1
	await phase("combat",WarTerrain.point(-250,-185)+Vector3.UP*2.2,WarTerrain.point(-245,-140)+Vector3.UP*2)
	viewer.set_enabled(true)
	await measure("combat_thermal")
	viewer.set_enabled(false)
	if diagnostic:
		var lights: Array=[]
		for light in game.world_root.find_children("*","DirectionalLight3D",true,false):
			lights.append([light,light.shadow_enabled]);light.shadow_enabled=false
		await measure("combat_no_shadows")
		for entry in lights: entry[0].shadow_enabled=entry[1]
		var sea:=game.world_root.find_child("WarSea",true,false)
		if sea: sea.hide()
		await measure("combat_no_sea")
		if sea: sea.show()
		var batches: Array=[]
		for node in game.world_root.find_children("*","MultiMeshInstance3D",true,false):
			batches.append([node,node.visible]);node.hide()
		await measure("combat_no_environment_batches")
		for entry in batches: entry[0].visible=entry[1]
		var hidden: Array=[]
		for node in game.vehicle_system.vehicles.values(): hidden.append([node,node.visible]);node.hide()
		await measure("combat_no_vehicles")
		for entry in hidden: entry[0].visible=entry[1]
	var centre: Vector2=WarUrbanLayout.CENTRES[0]
	await phase("city",WarTerrain.point(centre.x-75,centre.y-80)+Vector3.UP*3,WarTerrain.point(centre.x,centre.y)+Vector3.UP*5)
	await phase("harbor",Vector3(-1160,30,-650),Vector3(-890,8,-430))
	await phase("forest",WarTerrain.point(-720,470)+Vector3.UP*2,WarTerrain.point(-620,600)+Vector3.UP*4)
	var report:={"label":label,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"render_size":str(root.get_texture().get_size()),"window_size":str(root.size),"vsync":false,"fps_cap":0,"single_process":true,"frozen_simulation":true,"explicit_single_draw":true,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"rows":rows}
	var file:=FileAccess.open(report_dir.path_join(label+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RENDER_PERF181 "+JSON.stringify(report))
	game.queue_free();camera.queue_free();await process_frame;await process_frame;quit()

func phase(id: String,at: Vector3,target: Vector3) -> void:
	camera.global_position=at;camera.look_at(target);camera.make_current()
	await measure(id)

func measure(id: String) -> void:
	var warm:=Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<warm:
		await process_frame
		RenderingServer.force_draw(false)
	var times: Array[float]=[];var cpu:=0.;var gpu:=0.;var setup:=0.;var calls:=0.;var triangles:=0.;var maximum:=0.
	var started:=Time.get_ticks_usec();var previous:=started
	while Time.get_ticks_usec()-started<int(seconds*1000000):
		await process_frame
		RenderingServer.force_draw(false)
		var at:=Time.get_ticks_usec();times.append((at-previous)*.001);previous=at
		cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		setup+=RenderingServer.get_frame_setup_time_cpu()
		calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		triangles+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		maximum=maxf(maximum,Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.)
	var sorted:=times.duplicate();sorted.sort();var total:=0.;var tail:=0.;var slow:=maxi(1,ceili(times.size()*.01))
	for value in times: total+=value
	for i in slow: tail+=sorted[sorted.size()-1-i]
	var count:=times.size()
	var row:={"phase":id,"samples":count,"seconds":total*.001,"fps":count*1000./total,"one_percent_low":slow*1000./tail,"frame_mean_ms":total/count,"frame_p95_ms":sorted[int(count*.95)],"frame_max_ms":sorted.back(),"render_cpu_ms":cpu/count,"render_gpu_ms":gpu/count,"frame_setup_cpu_ms":setup/count,"draw_calls":calls/count,"primitives":triangles/count,"memory_mib":maximum}
	rows.append(row);print("PHASE "+JSON.stringify(row))
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(report_dir.path_join(label+"-"+id+".png"))
