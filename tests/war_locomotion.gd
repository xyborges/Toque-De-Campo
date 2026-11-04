extends SceneTree

var game: WarGame
var checks:=0
var failures: Array[String]=[]
var samples: Dictionary={}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func wait_for(condition: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())
func key(code: int,pressed:=true) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func capture(label_text: String) -> void:
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/war-locomotion-"+label_text+".png")
func move_for(actor: WarPlayer,seconds: float,sprinting: bool) -> Dictionary:
	var before:=actor.global_position;var step_before:=actor.locomotion.step_sequence
	Input.action_press("move_forward");key(KEY_SHIFT,sprinting)
	var peak:=0.;var run_peak:=0.;var view_delta:=0.
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await physics_frame
		peak=maxf(peak,absf(actor.avatar_parts.leg_l.rotation.x))
		run_peak=maxf(run_peak,actor.locomotion.sprint)
		view_delta=maxf(view_delta,actor.view_root.position.distance_to(actor._weapon_offset()))
	var result: Dictionary={"distance":actor.global_position.distance_to(before),"steps":actor.locomotion.step_sequence-step_before,"leg_peak":peak,"sprint":run_peak,"view_offset":view_delta}
	Input.action_release("move_forward");key(KEY_SHIFT,false)
	return result
func sample_rms(effect: AudioEffectCapture) -> float:
	var count:=effect.get_frames_available()
	if count<1: return 0
	var frames:=effect.get_buffer(count);var sum:=0.
	for frame: Vector2 in frames: sum+=frame.length_squared()*.5
	return sqrt(sum/maxi(1,frames.size()))
func run() -> void:
	Engine.max_fps=60
	game=WarGame.new();game.offline_operation=true
	game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	check(await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),25),"native local War starts through normal operation setup")
	game.request_deploy(0,"soldier","fal","rpg","base")
	check(await wait_for(func():return game.players.size()==12,15),"locomotion exists in the ordinary twelve-actor War operation")
	game.bot_director.stop()
	var actor:=game.local_player as WarPlayer
	# An explicit static platform provides reproducible ground contacts, without
	# changing production terrain, gravity, player movement or network code.
	var floor_body:=StaticBody3D.new();floor_body.collision_layer=1
	var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(90,.3,90);floor_shape.shape=box
	floor_body.add_child(floor_shape);game.world_root.add_child(floor_body)
	floor_body.position=WarTerrain.point(-450,280)+Vector3.UP*10
	var start:=floor_body.position+Vector3(0,.25,20)
	actor.position=start;actor.yaw=0;actor.rotation.y=0;actor.pitch=0;actor.velocity=Vector3.ZERO
	for id in game.bot_director.bots:
		var bot:=game.players[id] as WarPlayer
		bot.position=Vector3(800+int(id)%10,60,800);bot.velocity=Vector3.ZERO;bot.set_physics_process(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(await wait_for(func():return actor.is_on_floor(),3),"real CharacterBody reaches the reproducible physical floor")
	check(game.gameplay_input_allowed(),"focused native War accepts normal movement input")
	game.third_person=false;actor._update_view()
	var camera_rest:=actor.camera.transform
	samples.walk=await move_for(actor,1.6,false)
	check(float(samples.walk.distance)>7 and float(samples.walk.sprint)<.1,"normal W movement walks without enabling the sprint pose")
	check(int(samples.walk.steps)>=3 and float(samples.walk.leg_peak)>.25,"walking drives leg cadence and alternating physical step events")
	check(actor.view_root.visible and float(samples.walk.view_offset)>.003,"first-person walking moves hands and weapon presentation")
	check(actor.camera.transform.is_equal_approx(camera_rest),"locomotion leaves the first-person camera transform unchanged")
	samples.sprint=await move_for(actor,1.6,true)
	check(float(samples.sprint.distance)>float(samples.walk.distance)*1.25,"Shift retains the existing faster movement speed")
	check(float(samples.sprint.sprint)>.95 and float(samples.sprint.leg_peak)>float(samples.walk.leg_peak)*1.4,"sprint has a distinct stronger stride and torso-ready pose")
	check(float(samples.sprint.view_offset)>.07,"first-person sprint visibly lowers and sways the weapon")
	await capture("fpp-sprint")
	game.third_person=true;actor._update_view()
	samples.tpp=await move_for(actor,1.0,true)
	check(actor.body_root.visible and actor.weapon_root.visible and not actor.view_root.visible,"third person retains the complete running actor and actual world weapon")
	check(float(samples.tpp.leg_peak)>.55 and float(samples.tpp.sprint)>.95,"third-person sprint uses the same gait state as first person")
	check(absf(actor.camera.position.x)<.001 and absf(actor.camera.position.y)<.001 and actor.camera.rotation.is_zero_approx(),"third-person locomotion adds no camera bob or local rotation offset")
	# Hold movement while capturing the real gait; motion is stopped afterward.
	Input.action_press("move_forward");key(KEY_SHIFT,true)
	await create_timer(.20).timeout;await capture("tpp-sprint")
	var hand_point: Vector3=actor.avatar_parts.arm_r.get_node("HandR").global_position
	check(hand_point.distance_to(actor.weapon_root.global_position)<.12 and actor.get_muzzle_position().distance_to(actor.weapon_root.global_position)>.25,"running preserves the hand on the world weapon grip and the physical muzzle marker")
	actor.aiming=true;actor.iron_sights=true;actor._update_view();actor._update_weapon_pose()
	check(actor.view_root.position.is_equal_approx(actor._weapon_offset()) and actor.view_root.rotation.is_zero_approx(),"iron sights immediately retain exact weapon alignment during a sprint transition")
	await create_timer(.35).timeout
	check(actor.locomotion.sprint<.05,"aiming suppresses the sprint animation while movement continues")
	actor.clear_aim();Input.action_release("move_forward");key(KEY_SHIFT,false)
	await create_timer(.4).timeout
	var still_steps:=actor.locomotion.step_sequence
	await create_timer(.7).timeout
	check(actor.locomotion.step_sequence==still_steps and actor.locomotion.moving<.01,"idle actors stop both stride animation and footsteps")
	actor.reload_left=2;actor.reload_total=6;actor._update_weapon_pose()
	check(actor.view_root.position.is_equal_approx(actor._weapon_offset()),"reload pose is not displaced by locomotion")
	actor.reload_left=0;actor.reload_total=0
	actor.position+=Vector3.UP*3;actor.velocity=Vector3.UP*2
	Input.action_press("move_forward");key(KEY_SHIFT,true)
	await physics_frame;await physics_frame;await physics_frame
	var airborne_steps:=actor.locomotion.step_sequence
	await create_timer(.35).timeout
	check(not actor.locomotion.grounded and actor.locomotion.step_sequence==airborne_steps,"airborne movement uses a jump pose and makes no foot contacts")
	Input.action_release("move_forward");key(KEY_SHIFT,false)
	check(await wait_for(func():return actor.is_on_floor(),3),"jump/fall fixture lands through normal gravity")
	actor.vehicle_id="v_guarani";actor.velocity=Vector3(8,0,0)
	var before_vehicle:=actor.locomotion.step_sequence
	for index in 12:
		actor.position.x+=.12;await physics_frame
	check(actor.locomotion.sprint==0 and actor.locomotion.step_sequence==before_vehicle,"vehicle occupants cannot continue running or emit infantry footsteps")
	actor.vehicle_id="";actor.hp=0
	var before_dead:=actor.locomotion.step_sequence
	for index in 12:
		actor.position.x+=.12;await physics_frame
	check(actor.locomotion.moving==0 and actor.locomotion.step_sequence==before_dead,"dead actors cannot animate gait or emit footsteps")
	actor.hp=100;actor.position=start;actor.velocity=Vector3.ZERO
	await create_timer(.35).timeout
	var remote:=game.players[10001] as WarPlayer
	remote.position=start+Vector3(4,0,-3);remote.hp=100;remote.deployed=true;remote.velocity=Vector3.ZERO
	remote.remove_meta("war_bot")
	remote.set_physics_process(true);remote.locomotion.reset(remote)
	var remote_step:=remote.locomotion.step_sequence
	# Use the existing authoritative snapshot receiver: no new sprint/step RPC
	# exists. Every observer derives contacts from replicated displacement.
	for index in 90:
		remote.receive_network_state(remote.position+Vector3(0,0,-8.68/60),0,0)
		await physics_frame
	samples.remote={"sprint":remote.locomotion.sprint,"steps":remote.locomotion.step_sequence-remote_step,"grounded":remote.locomotion.grounded}
	check(remote.locomotion.sprint>.9 and remote.locomotion.step_sequence>remote_step,"replicated high-speed movement animates remote sprint and spatial steps")
	var stopped_remote:=remote.locomotion.step_sequence
	remote.velocity=Vector3(0,0,-8.68)
	await create_timer(.7).timeout
	check(remote.locomotion.step_sequence==stopped_remote and remote.locomotion.moving<.01,"a stationary remote produces no steps even when its last replicated velocity is nonzero")
	check(remote.avatar_parts.leg_l.rotation.is_zero_approx() and remote.avatar_parts.leg_r.rotation.is_zero_approx(),"idle optimization leaves the actual remote leg joints neutral despite stale velocity")
	remote.has_network_state=false;remote.set_physics_process(false)
	# Actual pooled PCM playback is routed through the footsteps bus. Muting
	# unrelated ambience gives a reproducible check of sound, source and range.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambiente"),true)
	var bus:=AudioServer.get_bus_index("Passos");var capture_effect:=AudioEffectCapture.new();capture_effect.buffer_length=.5
	AudioServer.add_bus_effect(bus,capture_effect)
	var soundscape:=game.soundscape
	var count_before:=soundscape.footstep_count
	var feet:=actor.global_position+Vector3.UP*.04
	check(soundscape.play_step(999,1,1,feet,true,false),"a grounded nearby foot contact starts a spatial PCM step voice")
	var voice:=soundscape.foley[(soundscape.foley_cursor+soundscape.foley.size()-1)%soundscape.foley.size()]
	check(voice.playing and voice.global_position.is_equal_approx(feet) and voice.bus=="Passos","footstep audio is attached to its immutable world foot contact")
	check(not soundscape.play_step(999,1,1,feet,true,false) and soundscape.footstep_count==count_before+1,"repeated presentation of the same actor/life/contact does not double its audio")
	await create_timer(.22).timeout
	var rms:=sample_rms(capture_effect);samples.step_rms=rms
	check(rms>.00001,"real audio capture receives non-silent footstep output")
	check(not soundscape.play_step(999,1,2,feet+Vector3(100,0,0),true,false),"distant foot contacts are culled before using an audio voice")
	for index in 150: soundscape.play_step(999,2,index+1,feet,false,false)
	check(soundscape.foley.size()==24,"a heavy twelve-player contact burst stays within the existing 24-voice fixed pool")
	check(soundscape.step_streams.size()==21,"seven ground materials reuse three preloaded samples each")
	var base_actor:=GamePlayer.new()
	check(not "locomotion" in base_actor,"War gait is scoped to WarPlayer and leaves other game modes unchanged")
	base_actor.free()
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambiente"),false)
	game.show_menu();game.queue_free();await process_frame;await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var report: Dictionary={"checks":checks,"failures":failures,"samples":samples,"fixture":"Native normal input on a reproducible physical platform. Remote movement uses the existing snapshot receiver, without a transport. Audio is real PCM captured from the spatial footsteps bus."}
	NavalStorage.write_json("res://tests/war-locomotion-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
