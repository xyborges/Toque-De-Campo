extends RefCounted

# Bounded, passive measurements. No filesystem, scene searches or network
# messages in the per-frame path. Diagnostics' existing worker writes reports.
const CAPACITY:=1200
const WINDOW_USEC:=10000000
# Operation snapshots are normally sent every 200 ms.
const WORLD_STALE_USEC:=450000
var durations:=PackedFloat32Array()
var process_times:=PackedFloat32Array()
var physics_times:=PackedFloat32Array()
var cursor:=0
var count:=0
var started:=0
var previous:=0
var previous_tick:=0
var last_pause:=0
var pauses: Array[Dictionary]=[]
var pause_count:=0
var no_tick_frames:=0
var multiple_tick_frames:=0
var correction_count:=0
var correction_max_m:=0.
var kind:=""
var snapshot_at:=0
var snapshot_max_gap_ms:=0.
var snapshot_count:=0
var snapshot_previous:=0
var snapshot_gaps: Array[Dictionary]=[]
var camera_previous:=Vector3.ZERO
var camera_previous_direction:=Vector3.ZERO
var world_snapshot_max_age_ms:=0.
var world_stale_frames:=0
var world_stale_camera_turns:=0
var camera_known:=false
var moving_frames:=0
var repeated_camera_frames:=0
var over_33_frames:=0
var over_100_frames:=0
var largest_tick_catchup:=0
var pipeline_last: Dictionary={}
var pipeline_totals: Dictionary={}
var pipeline_coincident_long_frames:=0

func _init() -> void:
	durations.resize(CAPACITY);process_times.resize(CAPACITY);physics_times.resize(CAPACITY)

func reset(now: int=0) -> void:
	cursor=0;count=0;started=now;previous=0;previous_tick=0
	pauses.clear();pause_count=0;no_tick_frames=0;multiple_tick_frames=0
	correction_count=0;correction_max_m=0.;last_pause=0
	snapshot_at=0;snapshot_previous=0;snapshot_max_gap_ms=0.;snapshot_count=0
	snapshot_gaps.clear()
	camera_known=false;moving_frames=0;repeated_camera_frames=0
	world_snapshot_max_age_ms=0.;world_stale_frames=0;world_stale_camera_turns=0
	over_33_frames=0;over_100_frames=0;largest_tick_catchup=0
	pipeline_last.clear();pipeline_totals.clear();pipeline_coincident_long_frames=0

func correction(distance_m: float) -> void:
	correction_count+=1;correction_max_m=maxf(correction_max_m,distance_m)

func snapshot(now: int,moving: bool=false) -> void:
	if snapshot_previous>0 and now-snapshot_previous>100000 and snapshot_gaps.size()<48:
		snapshot_gaps.append({"at_usec":now,"gap_ms":(now-snapshot_previous)*.001,"moving_on_receive":moving})
	if snapshot_previous>0:snapshot_max_gap_ms=maxf(snapshot_max_gap_ms,(now-snapshot_previous)*.001)
	snapshot_previous=now;snapshot_at=now;snapshot_count+=1

func sample(now: int,tick: int,process_ms: float,physics_ms: float) -> void:
	if started==0:started=now
	if previous>0:
		var ms:=(now-previous)*.001
		var steps:=tick-previous_tick
		durations[cursor]=ms;process_times[cursor]=process_ms;physics_times[cursor]=physics_ms
		cursor=(cursor+1)%CAPACITY;count+=1
		if steps==0:no_tick_frames+=1
		elif steps>1:multiple_tick_frames+=1
		largest_tick_catchup=maxi(largest_tick_catchup,steps)
		if ms>33.:over_33_frames+=1
		if ms>100.:over_100_frames+=1
		# 25 ms catches a missed 60 Hz refresh. Relative filtering in report()
		# separates those from the ordinary frame budget of a slower machine.
		if ms>=25.:
			pause_count+=1
			if pauses.size()<48:pauses.append({"at_ms":(now-started)*.001,"frame_ms":ms,"physics_steps":steps,"process_ms":process_ms,"physics_ms":physics_ms,"since_previous_ms":(now-last_pause)*.001 if last_pause>0 else 0.})
			last_pause=now
	previous=now;previous_tick=tick

func stats(values: PackedFloat32Array) -> Dictionary:
	var retained:=mini(count,CAPACITY)
	if retained==0:return {}
	var sorted:=values.slice(0,retained);sorted.sort()
	var total:=0.
	for value in sorted:total+=value
	return {"samples":retained,"mean_ms":total/retained,"p50_ms":sorted[(retained-1)/2],"p95_ms":sorted[ceili(retained*.95)-1],"p99_ms":sorted[ceili(retained*.99)-1],"max_ms":sorted[retained-1]}

func report(now: int) -> Dictionary:
	var frame:=stats(durations)
	var outliers: Array[Dictionary]=[]
	var threshold:=maxf(25.,float(frame.get("p50_ms",0.))*1.5)
	for pause: Dictionary in pauses:
		if float(pause.frame_ms)>=threshold:outliers.append(pause)
	return {"kind":kind,"duration_ms":(now-started)*.001,"frames":count,"frame":frame,"process":stats(process_times),"physics":stats(physics_times),"frames_over_25ms":pause_count,"frames_over_33ms":over_33_frames,"frames_over_100ms":over_100_frames,"max_physics_steps_per_rendered_frame":largest_tick_catchup,"pipeline_compilations":pipeline_totals.duplicate(),"long_frames_coincident_with_pipeline_compilation":pipeline_coincident_long_frames,"outlier_threshold_ms":threshold,"outliers":outliers,"no_physics_step_frames":no_tick_frames,"multiple_physics_step_frames":multiple_tick_frames,"position_corrections":correction_count,"maximum_correction_m":correction_max_m,"vehicle_snapshot_gaps":snapshot_gaps.duplicate(true),"vehicle_snapshots":snapshot_count,"maximum_vehicle_snapshot_gap_ms":snapshot_max_gap_ms,"vehicle_snapshot_age_ms":(now-snapshot_at)*.001 if snapshot_at>0 else -1.,"moving_camera_frames":moving_frames,"repeated_moving_camera_frames":repeated_camera_frames,"note":"Wall frame intervals; engine monitors may lag up to one second and are context, not exact attribution of individual spikes. Camera samples use node positions, not interpolated renderer transforms. Physics step counts alone do not prove a visible pause. Up to 1200 recent samples and the first 48 frames over 25 ms per window."}

# Pipeline counters are cumulative and may be reported a frame late.
# Record temporal correlations, not an unproven causal attribution.
func track_pipeline_counts(counters: Dictionary,frame_ms: float) -> void:
	if pipeline_last.is_empty():
		pipeline_last=counters.duplicate()
		return
	var new_pipeline_count:=0
	for key: String in counters:
		var change:=maxi(0,int(counters[key])-int(pipeline_last.get(key,0)))
		pipeline_totals[key]=int(pipeline_totals.get(key,0))+change
		if key in ["mesh","surface","draw"]:new_pipeline_count+=change
	if frame_ms>33. and new_pipeline_count>0:pipeline_coincident_long_frames+=1
	pipeline_last=counters.duplicate()

func tick(game: Node,now: int=-1) -> void:
	if DisplayServer.get_name()=="headless":return
	if not game.join_ready or game.closing or game.offline_frozen or game.ui_focus.blocked() or not is_instance_valid(game.local_player) or not game.local_player.deployed or game.local_player.hp<=0:
		reset();kind="";return
	if now<0:now=Time.get_ticks_usec()
	var next_kind:="foot"
	var moving: bool=game.local_player.velocity.length_squared()>.25
	if not game.local_player.vehicle_id.is_empty():
		var vehicle: Node=game.vehicle_system.find_target(game.local_player.vehicle_id)
		next_kind=str(vehicle.get("kind")) if is_instance_valid(vehicle) and vehicle is WarVehicle else ("drone" if vehicle is WarDrone else "vehicle")
		moving=absf(vehicle.speed)>.5 if vehicle is WarVehicle else (vehicle.velocity.length_squared()>.25 if vehicle is WarDrone else false)
	if next_kind!=kind:reset(now);kind=next_kind
	var prior:=previous
	sample(now,Engine.get_physics_frames(),Performance.get_monitor(Performance.TIME_PROCESS)*1000.,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		track_pipeline_counts({"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)},(now-prior)*.001 if prior>0 else 0.)
	var operation_received_at: int=game.operation_received_at
	var operation_age_usec:=now-operation_received_at if game.online and not game.multiplayer.is_server() and operation_received_at>0 else -1
	if operation_age_usec>=0:
		world_snapshot_max_age_ms=maxf(world_snapshot_max_age_ms,operation_age_usec*.001)
		if operation_age_usec>=WORLD_STALE_USEC: world_stale_frames+=1
	var camera:=game.get_viewport().get_camera_3d() as Camera3D
	if is_instance_valid(camera):
		if moving and camera_known:
			moving_frames+=1
			if camera.global_position.distance_squared_to(camera_previous)<.0000000001:repeated_camera_frames+=1
		var direction:=camera.global_transform.basis.z
		if camera_known and operation_age_usec>=WORLD_STALE_USEC and direction.distance_squared_to(camera_previous_direction)>.000001:
			world_stale_camera_turns+=1
		camera_previous_direction=direction
		camera_previous=camera.global_position;camera_known=true
	if now-started<WINDOW_USEC:return
	var details:=report(now)
	details.online=game.online;details.vsync=DisplayServer.window_get_vsync_mode();details.fps_limit=Engine.max_fps;details.physics_hz=Engine.physics_ticks_per_second
	details.screen_hz=DisplayServer.screen_get_refresh_rate();details.focused=DisplayServer.window_is_focused()
	details.state_recoveries=game.state_recovery_received
	if operation_age_usec>=0:
		details.world_state={"max_age_ms":world_snapshot_max_age_ms,"stale_frames":world_stale_frames,"camera_turns_during_stale_frames":world_stale_camera_turns,"threshold_ms":WORLD_STALE_USEC*.001}
	details.population={"actors":game.players.size(),"bots":0}
	for member: Dictionary in game.members.values():
		if bool(member.get("bot",false)):details.population.bots+=1
	details.render={"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.,"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
	for controller in game.get_tree().get_nodes_in_group("war_vegetation_visuals"):
		if not game.is_ancestor_of(controller):continue
		var streamer: Node=controller.get("streamer")
		if is_instance_valid(streamer):details.grass_stream={"updates":streamer.updates,"far_updates":streamer.far_updates,"maximum_update_ms":streamer.max_build_ms,"last_update_ms":streamer.last_update_ms,"last_update_cells":streamer.last_update_cells,"visible_instances":streamer.visible_instances,"pending_near":streamer.pending.size(),"pending_far":streamer.far_pending.size(),"max_bindings_per_frame":streamer.max_bindings_per_frame,"active_cells":streamer.cells.size(),"pool_size":streamer.pool.size(),"far_pool_size":streamer.far_pool.size()}
	var rendering: Node=game.world_root.get_node_or_null("ScenarioRendering") if is_instance_valid(game.world_root) else null
	if rendering:details.scenario_rendering=rendering.diagnostics()
	var legacy_grass: Dictionary={"batches":0,"instances":0,"near_instances":0,"distant_instances":0}
	for node: MultiMeshInstance3D in game.get_tree().get_nodes_in_group("war_legacy_grass"):
		if not game.is_ancestor_of(node) or not is_instance_valid(node.multimesh):continue
		var count:=node.multimesh.instance_count
		legacy_grass.batches+=1;legacy_grass.instances+=count
		if node.visibility_range_begin>0.:legacy_grass.distant_instances+=count
		else:legacy_grass.near_instances+=count
	if int(legacy_grass.batches)>0:details.legacy_grass=legacy_grass
	var transport:=game.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if game.online and transport and not game.multiplayer.is_server():
		var peer:=GameNetworkPeers.connected(transport,1)
		if peer:
			details.rtt_ms=peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
			details.rtt_variation_ms=peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE)
	GameDiagnostics.record("war_frame_pacing",details)
	reset(now)
