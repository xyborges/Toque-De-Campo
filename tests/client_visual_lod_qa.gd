extends SceneTree
## Real WarPlayer fixture plus deterministic camera/cadence tests.
var checks:=0
var failures: Array[String]=[]

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var current_mode:=WarClientVisualLOD.pilot_enabled
	var stats_mode:=WarClientVisualLOD.stats_enabled
	check(current_mode==not OS.get_cmdline_user_args().has("--war-client-visual-lod-legacy"),"native client visual scheduler defaults on, legacy flag restores original cadence")
	WarClientVisualLOD.pilot_enabled=true
	WarClientVisualLOD.stats_enabled=true
	for distance in [0.,8.,24.99,25.,38.,79.99,80.,249.99,250.,700.]:
		var distance_sq: float=distance*distance
		var legacy:=WarClientVisualLOD.legacy_interval_usec(distance_sq)
		var front:=WarClientVisualLOD.interval_usec(distance_sq,false)
		var rear:=WarClientVisualLOD.interval_usec(distance_sq,true)
		check(front==legacy,"visible tier changed "+str(distance))
		check(rear>=front,"rear faster than front "+str(distance))
		if distance<25.0:check(rear==legacy,"close combat tier changed")
		if distance>=250.:check(rear==250000,"far rear rate")
		check(rear<=250000,"rear pose freeze or delayed update")
	for distance_sq in [0.,624.,625.,3600.,10000.,63000.]:
		check(not WarClientVisualLOD.behind_camera(distance_sq,-sqrt(distance_sq),false) if distance_sq<625. else WarClientVisualLOD.behind_camera(distance_sq,-sqrt(distance_sq),false),"rear classification "+str(distance_sq))
		check(not WarClientVisualLOD.behind_camera(distance_sq,sqrt(distance_sq),true),"forward reacquisition "+str(distance_sq))
	for forward_dot in [-90.,-20.,-3.,0.,3.,20.,90.]:
		check(WarClientVisualLOD.behind_camera(10000.,forward_dot,false)==(forward_dot<-14.),"enter rear hysteresis")
		check(WarClientVisualLOD.behind_camera(10000.,forward_dot,true)==(forward_dot<8.),"exit rear hysteresis")
	var fixture: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(fixture)
	await process_frame
	var observer:=fixture.local_player as WarPlayer
	var remote:=fixture.players.get(2) as WarPlayer
	check(is_instance_valid(observer) and is_instance_valid(remote),"two real WarPlayers in fixture")
	if not is_instance_valid(observer) or not is_instance_valid(remote):
		_finish(fixture,current_mode,stats_mode);return
	check(not WarClientVisualLOD.active_for(fixture),"no LOD on offline server authority")
	var camera: Camera3D=observer.camera
	camera.make_current()
	# Place actor behind the local observer at 60m.
	var forward: Vector3=-camera.global_basis.z
	remote.global_position=camera.global_position-forward*60.
	remote.next_pose_usec=0
	remote.client_lod_behind=false
	remote.client_lod_last_weapon=""
	var start_usec:=Time.get_ticks_usec()
	check(WarClientVisualLOD.should_update(remote,fixture,start_usec),"first remote pose must execute")
	check(remote.client_lod_behind,"actual remote player classified behind")
	check(remote.next_pose_usec-start_usec==100000,"near rear uses 10Hz")
	check(not WarClientVisualLOD.should_update(remote,fixture,start_usec+20000),"rear intermediate pose skipped")
	# Weapon changes are never delayed, even when the actor remains behind.
	remote.weapon_id="g3"
	check(WarClientVisualLOD.should_update(remote,fixture,start_usec+20001),"weapon swap forces pose")
	check(remote.client_lod_last_weapon=="g3","weapon state retained")
	check(not WarClientVisualLOD.should_update(remote,fixture,start_usec+20002),"no unnecessary duplicate after swap")
	# Turning camera toward the actor forces pose on the FIRST physics tick,
	# regardless of the 100ms rear interval that has not yet elapsed.
	observer.rotation.y+=PI
	await physics_frame
	var second_usec:=start_usec+40000
	check(WarClientVisualLOD.should_update(remote,fixture,second_usec),"re-entering camera should instantly pose")
	check(not remote.client_lod_behind,"now front, no rear flag")
	check(remote.next_pose_usec-second_usec==33333,"front legacy near 30Hz")
	check(not WarClientVisualLOD.should_update(remote,fixture,second_usec+1000),"front skip does not refetch camera")
	check(WarClientVisualLOD.should_update(remote,fixture,second_usec+33334),"front next pose at 30Hz")
	# Close combat must remain at its original LOD even behind camera.
	remote.global_position=camera.global_position+camera.global_basis.z*8.
	remote.next_pose_usec=0
	await physics_frame
	var third_usec:=Time.get_ticks_usec()
	check(WarClientVisualLOD.should_update(remote,fixture,third_usec),"close body poses")
	check(not remote.client_lod_behind,"close actor never rear-throttled")
	check(remote.next_pose_usec-third_usec==33333,"close actor original cadence")
	var diagnostics:=WarClientVisualLOD.diagnostics()
	check(int(diagnostics.camera_reacquired)>=1,"camera reacquisition was recorded")
	check(int(diagnostics.skipped_rear)>=1,"rear optimization exercised")
	_finish(fixture,current_mode,stats_mode)

func _finish(fixture: WarGame,previous_mode: bool,previous_stats: bool) -> void:
	print("WAR_CLIENT_VISUAL_LOD_QA ",JSON.stringify({"checks":checks,
		"failures":failures,"diagnostics":WarClientVisualLOD.diagnostics()}))
	WarClientVisualLOD.pilot_enabled=previous_mode
	WarClientVisualLOD.stats_enabled=previous_stats
	if is_instance_valid(fixture):fixture.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
