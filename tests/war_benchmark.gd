extends SceneTree
const Probe=preload("res://scripts/performance_probe.gd")
var probe_armed:=false
var game: WarGame
var role:="server"
var fixture_path:="res://tests/war_benchmark_fixture.gd"
var report_root:="res://work"
var count:=12
var label:="baseline"
var duration:=28.0
var started:=0.0
var measure_start:=-1.0
var samples: Array[float]=[]
var script_times: Array[float]=[]
var physics_times: Array[float]=[]
var disconnect_frames: Array[float]=[]
var failures: Array[String]=[]
var peer_order: Array=[]
var maximum_projectiles:=0
var maximum_players:=0
var peak_memory:=0.0
var maximum_draw_calls:=0.0
var maximum_nodes:=0.0
var assigned:=false
var vehicles_started:=false
var drones_started:=false
var disconnected:=false
var thermal_frames: Array[float]=[]
var last_explosion:=-1.0
var last_clock:=0.0
var physics_max:=0.0
var bytes_sent:=0
var bytes_received:=0
var spikes: Array[Dictionary]=[]
var client_ready:=false
var explicit_draw:=false
var render_cpu: Array[float]=[]
var render_gpu: Array[float]=[]

func now() -> float: return Time.get_ticks_usec()*.000001
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
		if arg.begins_with("--count="): count=int(arg.trim_prefix("--count="))
		if arg.begins_with("--bench-fixture="): fixture_path=arg.trim_prefix("--bench-fixture=")
		if arg.begins_with("--report-root="): report_root=arg.trim_prefix("--report-root=")
		if arg.begins_with("--label="): label=arg.trim_prefix("--label=")
		if arg=="--explicit-draw": explicit_draw=true
	run.call_deferred()

func run() -> void:
	game=load(fixture_path).new()
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	root.add_child(game)
	if explicit_draw and DisplayServer.get_name()!="headless":
		root.content_scale_size=Vector2i(1920,1080)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		root.scaling_3d_scale=1.0
		OS.low_processor_usage_mode=false
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		RenderingServer.render_loop_enabled=false
	game.address_input.text="127.0.0.1";game.nickname_input.text="bench_"+role
	started=now();last_clock=started
	while now()-started<150:
		await process_frame
		if explicit_draw and DisplayServer.get_name()!="headless": RenderingServer.force_draw(false)
		var dt:=now()-last_clock;last_clock=now()
		maximum_players=maxi(maximum_players,game.players.size())
		if role=="server": server_step()
		else: client_step()
		if measure_start>0:
			var elapsed:=now()-measure_start
			if elapsed>3 and elapsed<duration:
				if not probe_armed:
					probe_armed=true;Probe.start({"role":role,"label":label,"warmup_seconds":3,"clients":count})
					if EngineDebugger.is_active() and EngineDebugger.has_profiler("servers"):
						EngineDebugger.profiler_enable("servers",true,[128])
				samples.append(dt)
				if explicit_draw and DisplayServer.get_name()!="headless":
					render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
					render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				if game.vehicle_system.thermal: thermal_frames.append(dt)
				if dt>.05 and spikes.size()<40: spikes.append({"elapsed":elapsed,"frame_ms":dt*1000,"projectiles":WarProjectiles.LIMIT-game.war_fx.available.size()})
				script_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
				physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
				peak_memory=maxf(peak_memory,Performance.get_monitor(Performance.MEMORY_STATIC)/1048576)
				maximum_draw_calls=maxf(maximum_draw_calls,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				maximum_nodes=maxf(maximum_nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
				if elapsed>=21 and elapsed<23: disconnect_frames.append(dt)
			if is_instance_valid(game.war_fx) and game.online: maximum_projectiles=maxi(maximum_projectiles,game.war_fx.active_slots.size())
			if elapsed>duration+(2 if role=="server" else 0):
				await finish();return
		if not failures.is_empty(): await finish();return
	failures.append("benchmark did not complete within 150 seconds")
	await finish()

func server_step() -> void:
	if not assigned and game.players.size()==count:
		assigned=true;peer_order=game.players.keys()
		peer_order.sort_custom(func(a,b): return int(str(game.players[a].name).trim_prefix("bench_"))<int(str(game.players[b].name).trim_prefix("bench_")))
		for index in peer_order.size():
			var id: int=peer_order[index]
			var team:=index%2
			game._deploy(id,team,"soldier",WarRules.primary_for("soldier",team)[0],WarRules.launcher_for_team(team),"base")
			var actor:=game.players[id] as WarPlayer
			actor.global_position=WarTerrain.point((index%6)*4-10,-210+(index/6)*10)+Vector3.UP*.15
			game._broadcast("remote_player_respawn",[id,actor.global_position,actor.life_id])
			game._broadcast("war_spawn_pose",[id,PI])
	if assigned and measure_start<0 and game.benchmark_ready.size()==count:
		measure_start=now();game.benchmark_begun=true
		game._broadcast("bench_begin",[])
		print("BENCH_BARRIER_READY count=",count," startup_seconds=",now()-started)
	if measure_start<0: return
	var elapsed:=now()-measure_start
	if elapsed>8 and not vehicles_started:
		vehicles_started=true
		if count>=6:
			for index in 4:
				var vehicle: WarVehicle=game.vehicle_system.vehicles[["v_guarani","v_bmp2","v_abrams","v_t90"][index]]
				var id: int=peer_order[count-4+index]
				var actor:=game.players[id] as WarPlayer
				vehicle.team=actor.war_team;vehicle.allocate_seat(id)
				vehicle.global_position=WarTerrain.point(index*10-15,-175)+Vector3.UP*.2
				actor.vehicle_id=vehicle.vehicle_id;actor._set_hitboxes_enabled(false);actor.body_collision.set_deferred("disabled",true)
				game.members[id].vehicle=vehicle.vehicle_id
				game.members[id].vehicle_seat=0;game.members[id].vehicle_role="operator"
				game.vehicle_system._send_occupancy(vehicle)
				game._broadcast("war_identity",[id,game.members[id]])
	if elapsed>16 and count>=6 and not drones_started:
		drones_started=true
		game.vehicle_system.launch_drone(peer_order[2]);game.vehicle_system.launch_drone(peer_order[3])
	for vehicle: WarVehicle in game.vehicle_system.vehicles.values():
		if vehicle.driver>0:
			game.vehicle_system.controls[vehicle.driver]={"throttle":.35 if int(elapsed)%8<4 else -.25,"steer":.12*sin(elapsed),"aim":WarTerrain.point(0,-80)+Vector3.UP*2,"fire":true,"at":game.war_clock}
	for drone: WarDrone in game.vehicle_system.drones.values():
		game.vehicle_system.controls[drone.driver]={"throttle":.5,"strafe":sin(elapsed)*.2,"lift":.15,"yaw":PI,"fire":false,"at":game.war_clock}
	if elapsed>10 and elapsed-last_explosion>2.0:
		last_explosion=elapsed
		for index in 4: game.vehicle_system.explode(0,WarTerrain.point(index*9-18,-135),0,7,"tank","bench-blast:"+str(index)+":"+str(int(elapsed)))
	if elapsed>21 and count>=6 and not disconnected:
		disconnected=true
		var id: int=peer_order.back()
		(game.multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)

func client_step() -> void:
	if not is_instance_valid(game.local_player) or not game.local_player.deployed: return
	if not client_ready and game.players.size()==count:
		client_ready=true;game.rpc_id(1,"bench_ready")
		game.ui_focus.close_all()
		game.third_person=true;game.local_player._update_view()
	if measure_start<0 and game.benchmark_begun: measure_start=now()
	if measure_start<0: return
	var actor:=game.local_player as WarPlayer
	if "--bench-thermal" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless" and not actor.vehicle_id.is_empty() and not game.vehicle_system.thermal:
		game.vehicle_system.vehicle_view.external=false;game.vehicle_system.toggle_thermal()
	if actor.vehicle_id.is_empty():
		actor.yaw=PI;actor.rotation.y=PI;actor.pitch=-.015;actor.camera_pivot.rotation.x=actor.pitch
		actor.trigger_held=true
		if int(actor.ammo.get(actor.weapon_id,0))==0 and actor.reload_weapon.is_empty(): actor.start_reload()
	if not game.online:
		if int(role)==count-1 and now()-measure_start>18: disconnected=true;return
		failures.append("unexpected disconnect at %.2f s; %s"%[now()-measure_start,game.status_label.text])

func metrics(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted:=values.duplicate();sorted.sort()
	var total:=0.0
	for value in values: total+=value
	var slow_count:=maxi(1,int(ceil(values.size()*.01)));var slow:=0.0
	for i in slow_count: slow+=sorted[sorted.size()-1-i]
	return {"frames":values.size(),"average_fps":values.size()/total,"one_percent_low":slow_count/slow,"frame_ms_mean":total/values.size()*1000,"frame_ms_p95":sorted[int(values.size()*.95)]*1000,"frame_ms_max":sorted.back()*1000}

func finish() -> void:
	Probe.stop()
	if EngineDebugger.is_active() and EngineDebugger.is_profiling("servers"): EngineDebugger.profiler_enable("servers",false)
	if role=="0" and maximum_players!=count: failures.append("did not observe every participant")
	if role=="0" and maximum_projectiles<mini(12,count*2): failures.append("not enough actual simulated projectiles for load")
	var result:=metrics(samples)
	if Probe.is_enabled(): result.performance_probe=Probe.report()
	result.merge({"render_resolution":str(root.get_texture().get_size()) if DisplayServer.get_name()!="headless" else "headless","explicit_single_draw":explicit_draw,"render_cpu_ms":mean(render_cpu),"render_gpu_ms":mean(render_gpu)})
	result.merge({"role":role,"count":count,"label":label,"failures":failures,"maximum_players":maximum_players,"maximum_projectiles":maximum_projectiles,"memory_mib":peak_memory,"max_draw_calls":maximum_draw_calls,"max_nodes":maximum_nodes,"thermal_window":metrics(thermal_frames),"fixed_daylight":"--bench-fixed-daylight" in OS.get_cmdline_user_args(),"disconnect_window":metrics(disconnect_frames),"physics_ms_mean":mean(physics_times),"script_frame_ms_mean":mean(script_times),"gpu":RenderingServer.get_video_adapter_name(),"resolution":str(root.size) if DisplayServer.get_name()!="headless" else "headless","invulnerable_fixture":true,"real_network_clients":true,"spikes":spikes})
	NavalStorage.write_json(report_root.path_join("war-bench-"+label+"-"+str(count)+"-"+role+".json"),result)
	print("WAR_BENCHMARK "+JSON.stringify(result))
	game.show_menu();game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func mean(values: Array[float]) -> float:
	var total:=0.0
	for value in values: total+=value
	return total/maxi(1,values.size())
