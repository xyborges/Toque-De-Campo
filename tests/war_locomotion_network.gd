extends SceneTree

const START:=Vector3(-566,0,32)
const OBSERVER:=Vector3(-552,0,38)
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
var samples: Dictionary={}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func wait_for(condition: Callable,label_text: String,seconds:=20.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if condition.call(): return true
		await process_frame
	failures.append("timeout: "+label_text);return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func place(actor: WarPlayer,point: Vector3,yaw_value: float) -> void:
	var feet:=WarTerrain.point(point.x,point.z)+Vector3.UP*.08
	actor.position=feet;actor.velocity=Vector3.ZERO;actor.yaw=yaw_value;actor.rotation.y=yaw_value;actor.pitch=0
	actor.locomotion.reset(actor)
	game._broadcast("qa_pose",[actor.peer_id,feet,yaw_value,0.])
func run() -> void:
	Engine.max_fps=60
	game=load("res://tests/war_locomotion_network_fixture.gd").new()
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	elif await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.local_player.deployed,"client deployment",30):
		game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		game.local_player.set_physics_process(false)
		if role=="mover":
			# The fixture sends legal positions through the ordinary player-state
			# RPC at 50 ms intervals. It does not replace the server validator.
			game.set_physics_process(false)
		else:
			game.third_person=true;game.local_player._update_view()
		game.rpc_id(1,"qa_report",role+"-ready")
		if role=="mover": await mover_flow()
		else: await observer_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures,"samples":samples,"fixture":"Real ENet server, headless legal-position mover and native observer. The mover sends 8.4 m/s positions through server_player_state every 50 ms; after motion the fixture pauses periodic server snapshots to test stale velocity without disconnecting transport."}
	NavalStorage.write_json("res://tests/war-locomotion-network-"+role+".json",report);print(JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2,"two ENet players",35): return
	check(game.multiplayer.multiplayer_peer is ENetMultiplayerPeer and game.multiplayer.get_peers().size()==2,"isolated authority has two real ENet peers")
	var actors: Dictionary={}
	for actor: WarPlayer in game.players.values(): actors[str(actor.name)]=actor
	var mover:=actors.mover as WarPlayer;var observer:=actors.observer as WarPlayer
	check(game._deploy(mover.peer_id,0,"soldier","fal","rpg","base"),"moving player deploys through normal team/class validation")
	check(game._deploy(observer.peer_id,1,"soldier","fal","rpg","base"),"native observer deploys on the opposing team")
	if not await wait_for(func():return game.reports.has("mover-ready") and game.reports.has("observer-ready"),"both clients ready"): return
	place(mover,START,0);place(observer,OBSERVER,1.15)
	await create_timer(.4).timeout
	phase("run")
	if not await wait_for(func():return game.reports.has("motion-done"),"legal replicated sprint",8): return
	var distance:=Vector2(mover.position.x-START.x,mover.position.z-START.z).length()
	samples.server_distance=distance
	check(distance>31 and distance<36,"authoritative movement validator accepts the four-second 8.4 m/s trajectory")
	# Keep ENet connected but withhold subsequent player snapshots, preserving
	# the observer's last moving velocity. This reproduces stale state safely.
	game.set_physics_process(false)
	phase("stopped")
	if not await wait_for(func():return game.reports.has("observer-done"),"native observer motion and stop checks",8): return
	check(game.players.size()==2 and game.multiplayer.get_peers().size()==2,"both players remain connected throughout the stale-snapshot check")
	phase("finish");await create_timer(.5).timeout
func mover_flow() -> void:
	var actor:=game.local_player as WarPlayer
	if not await wait_for(func():return game.phase=="run","run phase"): return
	var origin:=actor.position;var clock:=Time.get_ticks_msec();var sent_at:=0
	while Time.get_ticks_msec()-clock<4000:
		await process_frame
		var elapsed:=Time.get_ticks_msec()-clock
		if elapsed-sent_at<50: continue
		sent_at=elapsed
		var z:=origin.z-float(elapsed)*.001*8.4
		actor.position=WarTerrain.point(origin.x,z)+Vector3.UP*.08
		game.rpc_id(1,"server_player_state",actor.position,0.,0.,"fal",false,0,actor.life_id)
	check(game.corrections==0,"ordinary server state validation does not correct the legal sprint")
	game.rpc_id(1,"qa_report","motion-done")
	await wait_for(func():return game.phase=="finish","finish phase",10)
func observer_flow() -> void:
	if not await wait_for(func():return game.phase=="run","run phase"): return
	var mover: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="mover": mover=actor
	check(is_instance_valid(mover) and mover!=game.local_player and mover.deployed,"observer receives a distinct deployed remote WarPlayer")
	if not is_instance_valid(mover): return
	var first:=mover.position;var count_before:=game.soundscape.footstep_count;var step_before:=mover.locomotion.step_sequence
	var camera_rotation:=game.local_player.camera.rotation
	var peak_sprint:=0.;var peak_stride:=0.;var native_voices:=false
	while game.phase=="run":
		await process_frame
		peak_sprint=maxf(peak_sprint,mover.locomotion.sprint)
		peak_stride=maxf(peak_stride,absf(mover.avatar_parts.leg_l.rotation.x))
		for voice: AudioStreamPlayer3D in game.soundscape.foley:
			if voice.playing and int(voice.get_meta("footstep_actor",0))==mover.peer_id:
				native_voices=true
				if voice.global_position.distance_to(mover.global_position)<2.0: samples.foot_anchor=true
	check(mover.global_position.distance_to(first)>29,"native observer sees movement replicated from the validated server state")
	check(peak_sprint>.9 and peak_stride>.5,"replicated movement drives remote sprint weight and visible leg stride")
	check(mover.locomotion.step_sequence-step_before>=10 and game.soundscape.footstep_count-count_before>=10,"remote ground contacts produce audible steps on the observing client")
	check(native_voices and bool(samples.get("foot_anchor",false)),"actual observer PCM voices use remote foot-contact world positions")
	check(mover.weapon_root.visible and mover.body_root.visible,"remote body and held world weapon stay visible during sprint")
	check(game.local_player.camera.rotation.is_equal_approx(camera_rotation),"remote sprint does not rotate or shake the observer camera")
	await create_timer(.9).timeout
	var stopped_steps:=mover.locomotion.step_sequence;var stopped_audio:=game.soundscape.footstep_count
	var before:=mover.global_position;var stale_speed:=Vector2(mover.velocity.x,mover.velocity.z).length()
	await create_timer(1.4).timeout
	samples.merge({"peak_sprint":peak_sprint,"peak_stride":peak_stride,"moving_steps":stopped_steps-step_before,"stale_speed":stale_speed,"stop_drift":mover.global_position.distance_to(before),"voices":game.soundscape.foley.size()})
	check(stale_speed>5,"snapshot pause preserves a nonzero last remote velocity")
	check(mover.global_position.distance_to(before)<.01 and mover.locomotion.step_sequence==stopped_steps,"remote gait stops at its final replicated position despite stale velocity")
	check(game.soundscape.footstep_count==stopped_audio and mover.locomotion.moving<.01 and mover.locomotion.sprint<.01,"no phantom remote footsteps or sprint animation continue after stopping")
	check(mover.avatar_parts.leg_l.rotation.is_zero_approx() and mover.avatar_parts.leg_r.rotation.is_zero_approx(),"actual remote leg joints stay neutral with the previous moving packet's velocity")
	check(game.soundscape.foley.size()==24,"real multiplayer playback reuses the existing bounded 24-voice pool")
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/war-locomotion-network-observer.png")
	game.rpc_id(1,"qa_report","observer-done")
	await wait_for(func():return game.phase=="finish","finish phase",5)
