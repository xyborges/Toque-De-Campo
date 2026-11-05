extends SceneTree
var checks:=0
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
var capture: AudioEffectCapture
var game: Node3D
var audio: GameWeaponAudio
var actor: GamePlayer
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func tone() -> AudioStreamWAV:
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=48000;stream.stereo=false
	var bytes:=PackedByteArray();bytes.resize(48000/2*2)
	for i in 24000:
		var value:=.12*(sin(TAU*440*i/48000.)+sin(TAU*2200*i/48000.)+sin(TAU*8000*i/48000.))/3
		bytes.encode_s16(i*2,int(value*32767))
	stream.data=bytes
	return stream
func measure(weapon: String,point: Vector3) -> Vector3:
	for voice in audio.voices: voice.stop()
	await create_timer(.18).timeout
	capture.clear_buffer()
	var propagation_delay:=GameSoundPropagation.delay(GameWeaponAudio.listener_position(root.get_viewport()).distance_to(point))
	var voice:=audio.play(41,weapon,point)
	if voice: audio._process(.11)
	await create_timer(propagation_delay+.04).timeout
	capture.clear_buffer()
	await create_timer(.32).timeout
	var frames:=capture.get_buffer(capture.get_frames_available())
	var left:=0.;var right:=0.
	for frame in frames: left+=frame.x*frame.x;right+=frame.y*frame.y
	var count:=maxi(1,frames.size())
	return Vector3(sqrt(left/count),sqrt(right/count),float(frames.size()))
func run() -> void:
	game=load("res://tests/late_join_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="sandbox";game._enter_match_world()
	actor=game._spawn_player(1,true,false,Vector3.ZERO);actor.set_physics_process(false)
	audio=game.weapon_audio
	check(is_instance_valid(actor.audio_listener) and actor.audio_listener.is_current(),"local head owns the audio listener")
	var remote: GamePlayer=game._spawn_player(2,false,false,Vector3(4,0,0));remote.set_physics_process(false)
	check(not is_instance_valid(remote.audio_listener) and actor.audio_listener.is_current(),"remote spawn cannot take local hearing")
	var origin:=GameWeaponAudio.listener_position(root)
	var source:=origin+Vector3(0,0,-60)
	game.third_person=false;actor._update_view()
	check(GameWeaponAudio.listener_position(root).distance_to(origin)<.001,"FPP leaves the hearing origin at the head")
	game.third_person=true;actor._update_view()
	check(GameWeaponAudio.listener_position(root).distance_to(origin)<.001 and actor.camera.global_position.distance_to(origin)>1,"TPP camera distance does not move hearing")
	capture=AudioEffectCapture.new();capture.buffer_length=1
	var bus:=AudioServer.get_bus_index("WeaponShots");AudioServer.add_bus_effect(bus,capture)
	var probe:=tone()
	for weapon in ["glock","fal","sniper"]: audio.streams["res://audio/"+GameWeaponAudio.PATHS[weapon]]=probe
	for weapon in ["glock","fal","sniper"]:
		var previous:=INF
		for distance in [50.,100.,200.,300.]:
			var signal_level: Vector3=await measure(weapon,origin+Vector3(0,0,-distance))
			var level:=Vector2(signal_level.x,signal_level.y).length()
			check(signal_level.z>0 and level>.000001 and level<previous,"%s real audio mix is audible and decreases at %.0f m"%[weapon,distance])
			measurements.append({"weapon":weapon,"distance":distance,"rms":level,"frames":signal_level.z})
			previous=level
		check(audio.play(41,weapon,origin+Vector3.FORWARD*(float(GameWeaponAudio.profile(weapon).range)+1))==null,weapon+" beyond range is culled before allocating a voice")
	game.third_person=false;actor._update_view();var first: Vector3=await measure("fal",source)
	game.third_person=true;actor._update_view();var third: Vector3=await measure("fal",source)
	check(absf(first.x-third.x)/maxf(first.x,.000001)<.10,"FPP/TPP retain the same measured sound level")
	var left: Vector3=await measure("fal",origin+Vector3(-40,0,-10))
	var right: Vector3=await measure("fal",origin+Vector3(40,0,-10))
	check(left.x>left.y and right.y>right.x,"source direction is correctly panned left/right")
	var clear: Vector3=await measure("fal",origin+Vector3(0,0,-40))
	game._static_box(game.world_root,"AcousticWall",Vector3(0,2,-20),Vector3(8,4,.5),Color.GRAY)
	await physics_frame;await physics_frame
	var blocked: Vector3=await measure("fal",origin+Vector3(0,0,-40))
	check(blocked.x>0 and blocked.x<clear.x*.7 and audio.pools["41:fal"][0].bus=="WeaponBlocked","wall muffles the real mix without silencing the shot")
	for i in 130: audio._play_now(100+i,"fal",origin+Vector3(2,0,-10))
	check(audio.voices.size()==GameWeaponAudio.LIMIT,"130 simultaneous emitters remain bounded at 96 voices")
	var unique: Dictionary={}
	for key in audio.pools:
		for voice in audio.pools[key]:
			unique[voice.get_instance_id()]=int(unique.get(voice.get_instance_id(),0))+1
	var no_alias:=unique.size()==audio.voices.size()
	for count in unique.values(): no_alias=no_alias and int(count)==1
	check(no_alias,"recycled voices belong to exactly one emitter pool")
	var shot:=audio._play_now(999,"glock",origin+Vector3(1,0,-5))
	var glock_profile:=GameWeaponAudio.profile("glock")
	check(shot.max_distance==float(glock_profile.range) and shot.unit_size==float(glock_profile.unit) and shot.max_polyphony==1,"recycled pistol voice receives its own acoustic profile")
	var fixed:=shot.global_position
	audio._play_now(999,"glock",origin+Vector3(10,0,-5))
	check(shot.global_position==fixed,"a later shot does not move an earlier audio tail")
	var war:=WarAudio.new();game.world_root.add_child(war)
	var war_shot:=war._play_now(5,"fal",origin+Vector3(0,0,-30))
	check(war.external_acoustics and war_shot.is_in_group("war_spatial_audio") and war_shot.max_distance==float(GameWeaponAudio.profile("fal").range),"War shares shot profiles and retains its existing acoustic controller")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	game.show_menu();await process_frame
	check(game.sound_pools.is_empty() and game.weapon_audio==null,"menu exit clears all match audio references")
	game.queue_free();await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"measurements":measurements,"method":"Rendered Godot audio mix captured from WeaponShots; deterministic multi-frequency probe, not a subjective listening test"}
	NavalStorage.write_json("res://tests/spatial-weapon-audio-results.json",report);print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
