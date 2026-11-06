extends SceneTree
# Full Favela, 28 production bots, real ENet/DTLS. Suppress selected outgoing
# snapshots only; simulation, input, reliable transport and rendering continue.
class FaultVehicles extends WarVehicles:
	var repairs:=0
	func _broadcast(method: String,args: Array) -> void:
		if game.phase.ends_with("-fault") and method in ["vehicle_state","drone_state"]:return
		super._broadcast(method,args)
	func send_state_recovery(id: int) -> void:
		if "--without-vehicle-recovery" not in OS.get_cmdline_user_args():super.send_state_recovery(id)
	@rpc("authority","call_remote","reliable")
	func baseline_vehicles(states: Array) -> void:
		if game.join_ready:repairs+=1
		super.baseline_vehicles(states)
	@rpc("authority","call_remote","reliable")
	func baseline_drone(state: Dictionary) -> void:
		if game.join_ready:repairs+=1
		super.baseline_drone(state)

class FaultGame extends "res://tests/war_frame_pacing_game.gd":
	var dropped:=0
	var request_rows: Array=[]
	func _enter_match_world() -> void:
		if world_prebuilt and is_instance_valid(world_root):return
		super._enter_match_world()
		# The real manager attaches two controls outside its own subtree.
		# Remove those QA replacements too, before freeing their manager.
		for node in hud_layer.find_children("*","",true,false):
			if is_instance_valid(node) and node.get("manager")==vehicle_system:node.free()
		vehicle_system.free()
		vehicle_system=FaultVehicles.new();vehicle_system.game=self;world_root.add_child(vehicle_system)
		# Deterministic, collision-enabled driving lane above the authored map.
		var floor_body:=StaticBody3D.new();world_root.add_child(floor_body)
		floor_body.position=Vector3(-300,110,550)
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(600,1,50)
		shape.shape=box;floor_body.add_child(shape)
	func _broadcast(method: String,args: Array) -> void:
		if phase=="retry-fault" and method in ["war_snapshot","war_bot_states"]:return
		if phase=="foot-world-fault" and method in ["war_snapshot","war_bot_states"]:return
		if phase=="foot-clock-fault" and method=="war_snapshot":return
		if phase=="foot-poses-fault" and method=="war_bot_states":return
		super._broadcast(method,args)
	func _state_recovery_payload(id: int,token: String,serial: int,ids: Array) -> Array:
		var payload:=super._state_recovery_payload(id,token,serial,ids)
		request_rows.append({"phase":phase,"at_usec":Time.get_ticks_usec(),"sequence":serial,"accepted":not payload.is_empty(),"quota":network_guard.rates.get(str(id)+":state_recovery",{}).duplicate()})
		if phase=="retry-fault" and dropped==0 and not payload.is_empty():
			dropped+=1;return []
		return payload

var game: FaultGame
var role:="client"
var failures: Array[String]=[]
var phases: Array=[]
var checks:=0
var bot_count:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func wait_for(condition: Callable,label: String,seconds:=100.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while not condition.call() and Time.get_ticks_msec()<deadline:await process_frame
	check(condition.call(),label)
	return condition.call()
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value]);print("PHASE ",value)
func run() -> void:
	game=FaultGame.new();game.operation_id=WarOperation.FAVELA
	preload("res://scripts/maps/definition.gd").checked["favela"]=true
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	game.set_meta("war_visual_preview",role=="client");game.set_meta("online_bots_test",role=="server")
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1";Engine.max_fps=60
	if role=="server":await server_flow()
	else:await client_flow()
	Input.action_release("move_forward");Input.action_release("jump")
	var report:={"role":role,"checks":checks,"failures":failures,"phases":phases,"bots":bot_count,"dropped_replies":game.dropped,"recovery_responses":game.state_recovery_sent,"vehicle_replies":game.vehicle_system.repairs,"control":"--without-vehicle-recovery" in OS.get_cmdline_user_args(),"scope":"Local ENet/DTLS full Favela and 28 active production bots. Fault withholds outgoing snapshots, not UDP or reliable packets. Separate elevated driving lane; not a live official room or Internet loss test."}
	report.requests=game.request_rows
	NavalStorage.write_json(OS.get_environment("CAMPO_RECOVERY_DIR").path_join(role+".json"),report)
	print("RECOVERY_NETWORK ",JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.multiplayer.get_peers().size()==1,"client connects"):return
	var id:=int(game.multiplayer.get_peers()[0])
	if not await wait_for(func():return game.players.has(id) and game.loading_baselines.is_empty() and game.reports.has("ready"),"admitted client"):return
	if not game._deploy(id,0,"soldier","fal","","base"):check(false,"deploy");return
	if not await wait_for(func():return game.bot_director.bots.size()==28 and game.reports.has("deployed"),"28 bots and deployed client"):return
	bot_count=game.bot_director.bots.size()
	var actor:=game.players[id] as WarPlayer
	var bike: WarVehicle
	for candidate: WarVehicle in game.vehicle_system.vehicles.values():
		if candidate.team==0 and bool(candidate.spec.get("transport",false)):bike=candidate;break
	if not is_instance_valid(bike):check(false,"bike exists");return
	for occupant in bike.occupant_ids():game.vehicle_system.release(occupant,true,false)
	bike.position=Vector3(-550,111,550);bike.heading=-PI*.5;bike.rotation.y=bike.heading;bike.speed=0.;bike.resting=false
	game.qa_pose(id,bike.position+Vector3(0,0,3),-PI*.5,0.)
	game._broadcast("qa_pose",[id,actor.position,-PI*.5,0.])
	game.vehicle_system.command_for(id,"enter",{"id":bike.vehicle_id})
	if not await wait_for(func():return bike.driver==id,"bike occupied",3.):return
	phase("bike-drive")
	if not await wait_for(func():return absf(bike.speed)>5 and game.reports.has("bike-drive"),"bike moving",8.):return
	for trial in 3:
		await create_timer(1.).timeout
		phase("bike-"+str(trial)+"-fault");await create_timer(.65).timeout;phase("bike-drive")
	await create_timer(1.).timeout
	game.vehicle_system.release(id,true)
	game.qa_pose(id,Vector3(-500,111,550),0.,0.)
	game._broadcast("qa_pose",[id,actor.position,0.,0.])
	game.vehicle_system.launch_drone(id)
	if not await wait_for(func():return actor.vehicle_id.begins_with("drone_"),"drone occupied",3.):return
	phase("drone-drive")
	if not await wait_for(func():return game.reports.has("drone-drive"),"drone controlled",5.):return
	for trial in 3:
		await create_timer(1.).timeout
		phase("drone-"+str(trial)+"-fault");await create_timer(.65).timeout;phase("drone-drive")
	await create_timer(1.).timeout
	phase("retry-fault");await create_timer(2.5).timeout;phase("drone-drive")
	await create_timer(.8).timeout
	game.vehicle_system.release(id,true)
	phase("foot-walk")
	if not await wait_for(func():return game.reports.has("foot-walk"),"client on foot",5.):return
	for label in ["world","clock","poses"]:
		await create_timer(1.).timeout
		phase("foot-"+label+"-fault");await create_timer(1.2).timeout;phase("foot-walk")
	await create_timer(.8).timeout;phase("finish");await create_timer(1.).timeout
	check(game.dropped==1,"one legitimate initial response deliberately omitted")
func client_flow() -> void:
	game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.world_prebuilt=true
	await create_timer(.5).timeout;await game.join_game("pvp")
	if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"baseline ready"):return
	game.rpc_id(1,"qa_report","ready")
	if not await wait_for(func():return game.local_player.deployed and game.players.size()==29,"deployed with bots"):return
	bot_count=28;game.ui_focus.close_all();game.rpc_id(1,"qa_report","deployed")
	if DisplayServer.get_name()!="headless":DisplayServer.window_move_to_foreground()
	var active:="";var entry: Dictionary={};var last_frame:=Time.get_ticks_usec()
	var previous_forward:=Vector3.ZERO
	var deadline:=Time.get_ticks_msec()+50000
	while game.online and game.phase!="finish" and Time.get_ticks_msec()<deadline:
		await process_frame
		var now:=Time.get_ticks_usec()
		if game.phase!=active:
			if active.ends_with("-fault"):phases.append(entry)
			active=game.phase
			if active.ends_with("-fault"):
				entry={"name":active,"start":now,"first_repair_ms":-1.,"replies_at_start":game.state_recovery_received if active.begins_with("foot-") else game.vehicle_system.repairs,"replies":0,"max_silence_ms":0.,"max_clock_silence_ms":0.,"max_pose_silence_ms":0.,"max_frame_ms":0.,"frames":0,"camera_degrees":0.,"clock_start":game.war_clock,"clock_advance":0.}
			elif active in ["bike-drive","drone-drive","foot-walk"]:game.rpc_id(1,"qa_report",active)
		Input.action_press("move_forward")
		Input.action_release("jump")
		var target: Node3D=game.vehicle_system.find_target(game.local_player.vehicle_id)
		var cam:=root.get_camera_3d()
		var forward: Vector3=-cam.global_basis.z if cam else Vector3.ZERO
		game.vehicle_system.orbit_yaw+=.002
		if active.begins_with("foot-"):game.local_player.apply_look(Vector2(1.,0.))
		if active.ends_with("-fault"):
			entry.frames+=1
			if forward!=Vector3.ZERO and previous_forward!=Vector3.ZERO:entry.camera_degrees+=rad_to_deg(previous_forward.angle_to(forward))
			entry.max_frame_ms=maxf(entry.max_frame_ms,(now-last_frame)*.001)
			if is_instance_valid(target):entry.max_silence_ms=maxf(entry.max_silence_ms,(now-int(target.received_state_usec))*.001)
			entry.max_clock_silence_ms=maxf(entry.max_clock_silence_ms,(now-game.operation_received_at)*.001)
			var newest_pose:=0.
			for actor: WarPlayer in game.players.values():
				if not actor.is_local and actor.deployed and actor.hp>0:newest_pose=maxf(newest_pose,actor.last_snapshot_time)
			entry.max_pose_silence_ms=maxf(entry.max_pose_silence_ms,now*.001-newest_pose*1000.)
			entry.replies=(game.state_recovery_received if active.begins_with("foot-") else int(game.vehicle_system.repairs))-int(entry.replies_at_start)
			entry.clock_advance=game.war_clock-float(entry.clock_start)
			if entry.replies>0 and float(entry.first_repair_ms)<0:entry.first_repair_ms=(now-int(entry.start))*.001
		last_frame=now;previous_forward=forward
	check(game.phase=="finish","all scenarios finish")
	check(phases.size()==10,"all fault windows observed")
	var control:="--without-vehicle-recovery" in OS.get_cmdline_user_args()
	for row: Dictionary in phases:
		check(int(row.frames)>8,str(row.name)+" frames continue during network gap")
		if DisplayServer.get_name()!="headless":check(row.camera_degrees>1.,str(row.name)+" camera remains responsive")
		if str(row.name).begins_with("foot-"):
			check(row.replies>=1 and row.first_repair_ms>=0. and row.first_repair_ms<800.,str(row.name)+" world state repaired without a vehicle")
			check(row.max_clock_silence_ms<800. and row.max_pose_silence_ms<800.,str(row.name)+" clock and remote actors keep receiving current state")
		elif row.name=="retry-fault":
			if not control:check(row.first_repair_ms>800. and row.first_repair_ms<2000.,"missing reply expires and recovery resumes")
		elif control:
			check(row.replies==0 and row.max_silence_ms>500.,str(row.name)+" exposes original unprotected vehicle stream")
		else:
			check(row.replies>=2 and row.first_repair_ms>=0. and row.first_repair_ms<400.,str(row.name)+" fresh authority state repairs moving vehicle")
			check(row.max_silence_ms<450.,str(row.name)+" bounded stale state")
