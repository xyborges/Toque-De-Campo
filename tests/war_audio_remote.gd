extends SceneTree

var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
var capture: AudioEffectCapture
var source_received:=0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func wait_for(condition: Callable,label_text: String,seconds:=10.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if condition.call(): return true
		await process_frame
	failures.append("timeout: "+label_text);return false
func stop_audio() -> void:
	for manager: GameWeaponAudio in [game.combat_audio,game.desert_audio]:
		manager.propagation.clear()
		for voice in manager.voices: voice.stop()
func signal_metrics(frames: PackedVector2Array,skip:=0.,max_window:=INF) -> Dictionary:
	var left:=0.;var right:=0.;var difference:=0.;var previous:=Vector2.ZERO;var used:=0
	var start:=mini(frames.size(),int(skip*AudioServer.get_mix_rate()))
	# Native frame hitches can make a 700ms timer capture 1.2s of audio;
	# comparing that RMS against a 700ms clip would count extra silence.
	# Keep the intended analysis window fixed after physical propagation.
	var end:=frames.size()
	if is_finite(max_window): end=mini(end,start+maxi(1,int(max_window*AudioServer.get_mix_rate())))
	for index in range(start,end):
		var frame:=frames[index]
		left+=frame.x*frame.x;right+=frame.y*frame.y
		if used>0: difference+=(frame-previous).length_squared()
		previous=frame;used+=1
	var divisor:=maxi(1,used)
	return {"left":sqrt(left/divisor),"right":sqrt(right/divisor),"rms":sqrt((left+right)/divisor),"brightness":sqrt(difference/maxf(.0000000001,left+right)),"frames":used}
func measure(mode: String,weapon: String,point: Vector3,view: String,window:=.70,skip:=0.) -> Dictionary:
	stop_audio()
	# Clear preceding reverberation without replacing the real bus effects.
	await create_timer(.60).timeout
	game.acoustic_mode=mode
	game.third_person=view=="tpp";game.local_player._update_view()
	await process_frame
	capture.clear_buffer()
	var before: int=game.received
	game.rpc_id(1,"qa_fire",weapon,point)
	if not await wait_for(func():return game.received>before,"validated remote "+weapon+" event",4): return {"rms":0.,"left":0.,"right":0.,"brightness":0.,"frames":0,"bus":""}
	var propagation_delay:=GameSoundPropagation.delay(point.distance_to(GameWeaponAudio.listener_position(root)))
	await create_timer(window+propagation_delay).timeout
	var frames:=capture.get_buffer(capture.get_frames_available())
	var manager: GameWeaponAudio=game.combat_audio if mode=="war" else game.desert_audio
	var voice: AudioStreamPlayer3D=manager.pools["1:"+weapon].back()
	var result:=signal_metrics(frames,skip+propagation_delay,window)
	result.merge({"mode":mode,"weapon":weapon,"distance":voice.global_position.distance_to(GameWeaponAudio.listener_position(root)),"view":view,"bus":voice.bus,"volume_db":voice.volume_db,"resource":voice.stream.resource_path,"source_cutoff_hz":voice.attenuation_filter_cutoff_hz,"origin_error":voice.global_position.distance_to(point)})
	if window>1:
		var rate:=AudioServer.get_mix_rate()
		result.tail=signal_metrics(frames.slice(int((.78+propagation_delay)*rate),mini(frames.size(),int((1.20+propagation_delay)*rate)))).rms
	measurements.append(result)
	return result
func run() -> void:
	Engine.max_fps=60
	game=load("res://tests/war_audio_remote_fixture.gd").new();root.add_child(game)
	if role=="server":
		if await wait_for(func():return game.qa_done,"native observer acoustic matrix",245):
			check(game.multiplayer.multiplayer_peer is ENetMultiplayerPeer,"source events traveled through a real ENet authority")
			check(game.emitted>=48,"normal server shot validator accepted the real firearm events")
			check(int(game.shot_sequences.get(1,0))==int(game.event_sequence),"each acoustic event passed ordinary life/sequence/ammunition validation")
			source_received=game.emitted
	else:
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"native observer joins ENet arena",15): await observer_flow()
	var report: Dictionary={"role":role,"checks":checks,"failures":failures,"source_events":source_received,"measurements":measurements,"method":"Two independent ENet processes. Headless source uses the ordinary War server shot validator and reliable remote_shot_packet. Native observer waits for343m/s propagation and captures PCM from WeaponShots using unmodified Glock/FAL/sniper WAVs. A small flat acoustic arena and diagnostic all-three-weapon inventory isolate sound; full-map combat, human listening is not asserted; native propagation timing is covered by ballistics171."}
	NavalStorage.write_json("res://tests/war-audio-remote-"+role+".json",report);print(JSON.stringify(report))
	stop_audio();game.online=false;game.multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();game.queue_free()
	await process_frame;await process_frame;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;quit(0 if failures.is_empty() else 1)
func observer_flow() -> void:
	check(game.combat_audio is WarAudio and game.combat_audio.external_acoustics and is_instance_valid(game.soundscape),"WarAudio is integrated with its single external WarSoundscape controller")
	check(game.local_player.audio_listener.is_current() and not is_instance_valid(game.players[1].audio_listener),"only the local player's head owns the 3D listener")
	var bus:=AudioServer.get_bus_index("WeaponShots")
	capture=AudioEffectCapture.new();capture.buffer_length=4.;AudioServer.add_bus_effect(bus,capture)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Armas"),0)
	var far_bus:=AudioServer.get_bus_index("WeaponFar")
	var far_filter:=AudioServer.get_bus_effect(far_bus,0) as AudioEffectLowPassFilter
	var far_reverb:=AudioServer.get_bus_effect(far_bus,1) as AudioEffectReverb
	check(is_instance_valid(far_filter) and far_filter.cutoff_hz==19500 and is_instance_valid(far_reverb) and far_reverb.wet<=.015,"distant exterior shots use per-voice filtering and minimal artificial reverb")
	check(AudioServer.get_bus_send(far_bus)=="WeaponShots" and AudioServer.get_bus_effect(bus,0) is AudioEffectLimiter,"all shot routes share the bounded peak limiter")
	var listener:=GameWeaponAudio.listener_position(root)
	var levels: Dictionary={}
	for mode in ["desert","war"]:
		for weapon in ["glock","fal","sniper"]:
			for view in ["fpp","tpp"]:
				var previous:=INF
				for distance in [50.,100.,200.,300.,400.,600.]:
					var result: Dictionary=await measure(mode,weapon,listener+Vector3(0,0,-distance),view)
					levels["%s:%s:%s:%d"%[mode,weapon,view,int(distance)]]=result
					check(float(result.rms)>.000001 and float(result.rms)<previous,"%s %s %s real WAV remains audible with physical falloff at %.0f m"%[mode,weapon,view,distance])
					check(result.resource=="res://audio/"+GameWeaponAudio.PATHS[weapon] and float(result.origin_error)<.02,"%s %s %s %.0f m uses its supplied WAV at the validated world muzzle"%[mode,weapon,view,distance])
					check(result.bus==GameWeaponAudio.acoustic_bus(float(result.distance),false,false),"%s %s %s %.0f m selects the correct single distance path"%[mode,weapon,view,distance])
					previous=float(result.rms)
			if weapon=="sniper":
				for view in ["fpp","tpp"]:
					var close: Dictionary=levels["%s:%s:%s:50"%[mode,weapon,view]]
					var distant: Dictionary=levels["%s:%s:%s:300"%[mode,weapon,view]]
					check(float(distant.rms)<float(close.rms)*.85,"%s sniper %s retains clear real-PCM falloff between 50 and 300 m"%[mode,view])
			for distance in [50,100,200,300,400,600]:
				var first: Dictionary=levels["%s:%s:fpp:%d"%[mode,weapon,distance]]
				var third: Dictionary=levels["%s:%s:tpp:%d"%[mode,weapon,distance]]
				check(absf(float(first.rms)-float(third.rms))/maxf(float(first.rms),.000001)<.12,"%s %s FPP/TPP keep head-listener RMS within 12%% at %d m"%[mode,weapon,distance])
	for weapon in ["glock","fal","sniper"]:
		for distance in [50,100,200,300,400,600]:
			var desert: Dictionary=levels["desert:%s:fpp:%d"%[weapon,distance]]
			var war: Dictionary=levels["war:%s:fpp:%d"%[weapon,distance]]
			check(absf(float(desert.rms)-float(war.rms))/maxf(float(desert.rms),.000001)<.12,"shared %s distance path matches Desert/War RMS within 12%% at %d m"%[weapon,distance])
	for mode in ["desert","war"]:
		var left: Dictionary=await measure(mode,"fal",listener+Vector3(-40,0,-10),"fpp")
		var right: Dictionary=await measure(mode,"fal",listener+Vector3(40,0,-10),"tpp")
		check(float(left.left)>float(left.right)*1.2 and float(right.right)>float(right.left)*1.2,mode+" remote WAV pans correctly to the source's left and right")
		# Capture the direct muzzle transient after propagation, not mostly the
		# reverb tail. The old 250ms skip could invert the wall ratio when
		# distance filtering changed the spectral content of late reflections.
		var clear: Dictionary=await measure(mode,"fal",listener+Vector3(0,0,-50),"fpp",.70,.05)
		game.configure_wall(true);await physics_frame;await physics_frame
		var blocked: Dictionary=await measure(mode,"fal",listener+Vector3(0,0,-50),"tpp",.70,.05)
		var wall_ratio:=float(blocked.rms)/maxf(float(clear.rms),.000001)
		print("REMOTE_WALL_DIRECT_PCM ",JSON.stringify({"mode":mode,"clear_rms":clear.rms,"blocked_rms":blocked.rms,"ratio":wall_ratio}))
		# The global combat presence update intentionally reduced wall attenuation:
		# this must be audibly quieter but not as muffled as the old 8 dB profile.
		check(float(blocked.rms)>.000001 and wall_ratio<.86 and wall_ratio>.45 and blocked.bus=="WeaponBlocked",mode+" wall noticeably muffles direct remote PCM with original 4.5dB occlusion")
		var expected_wall_db:=float(blocked.get("base_db",-5.5))+GameSoundPropagation.combat_presence_db(float(blocked.distance))+GameSoundPropagation.distant_gain_db(float(blocked.distance))+GameWeaponAudio.distant_shot_relief_db("fal",float(blocked.distance))-4.5
		check(absf(float(blocked.volume_db)-expected_wall_db)<3.5,mode+" wall muffling is applied only once after combat presence boost")
		game.configure_wall(false);await physics_frame;await physics_frame
	AudioServer.set_bus_effect_enabled(far_bus,0,false);AudioServer.set_bus_effect_enabled(far_bus,1,false)
	var unfiltered: Dictionary=await measure("war","sniper",listener+Vector3(0,0,-200),"fpp",1.35)
	AudioServer.set_bus_effect_enabled(far_bus,0,true);AudioServer.set_bus_effect_enabled(far_bus,1,true)
	var filtered: Dictionary=await measure("war","sniper",listener+Vector3(0,0,-200),"tpp",1.35)
	check(float(filtered.source_cutoff_hz)<GameWeaponAudio.FILTER_OPEN_HZ and float(filtered.source_cutoff_hz)>GameWeaponAudio.FILTER_DISTANT_HZ,"distant WAV keeps a continuous per-voice source filter")
	check(is_instance_valid(far_reverb) and far_reverb.wet<=.015,"open-air sniper keeps minimal artificial far reverberation rather than a large room tail")
	var before: int=game.received
	game.rpc_id(1,"qa_duplicate_last");await create_timer(.2).timeout
	check(game.received==before,"duplicate authoritative shot packets do not replay remote audio")
	var bus_count:=AudioServer.bus_count
	for index in 130: game.combat_audio.play(400+index,"fal",listener+Vector3(1,0,-1))
	game.soundscape._update_acoustics(listener,.1)
	check(game.combat_audio.voices.size()==GameWeaponAudio.LIMIT and AudioServer.bus_count==bus_count,"130 sound emitters remain within 96 voices and allocate no effects or buses per voice")
	check(game.soundscape.foley.size()==24,"weapon routing preserves the existing bounded footsteps/foley pool")
	source_received=game.received
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	game.rpc_id(1,"qa_finish");await create_timer(.4).timeout
