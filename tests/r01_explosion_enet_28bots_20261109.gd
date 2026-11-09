extends "res://tests/ia2_enet_28bots_benchmark.gd"

# R01 end-to-end explosion audio QA:
# real headless 28-bot War authority, native 1080p GTX1650 client,
# authoritative WarVehicles._broadcast -> explosion_event RPC ->
# WarAudio -> GameExplosionAudio -> spatial propagation and Master PCM.
# Does NOT alter projectile damage, inventory, map, bots or networking.

var audio_checks:=0
var source_events:=0
var source_min_bots:=100
var client_min_bots:=100
var event_reports: Array[Dictionary]=[]
var mix_capture: AudioEffectCapture
var master_capture: AudioEffectCapture
var started_at:=0
var client_audio: GameExplosionAudio

func _cases() -> Array[Dictionary]:
	return [
		{"tag":"tank50","kind":"destroy","distance":50.0,"count":1,"weapon":"tank_wreck","surface":"","radius":9.0},
		{"tag":"tank50pair","kind":"destroy","distance":50.0,"count":2,"weapon":"tank_wreck","surface":"","radius":9.0},
		{"tag":"tank50quad","kind":"destroy","distance":50.0,"count":4,"weapon":"tank_wreck","surface":"","radius":9.0},
		{"tag":"tank400","kind":"destroy","distance":400.0,"count":1,"weapon":"tank_wreck","surface":"","radius":9.0},
		{"tag":"tank600","kind":"destroy","distance":600.0,"count":1,"weapon":"tank_wreck","surface":"","radius":9.0},
		{"tag":"grenade35","kind":"grenade","distance":35.0,"count":1,"weapon":"grenade","surface":"","radius":4.0},
		{"tag":"drone160","kind":"drone","distance":160.0,"count":1,"weapon":"drone_wreck","surface":"","radius":5.0},
		{"tag":"apc150","kind":"autocannon","distance":150.0,"count":1,"weapon":"autocannon","surface":"metal","radius":2.0},
		{"tag":"tank50duplicate","kind":"destroy","distance":50.0,"count":1,"weapon":"tank_wreck","surface":"","radius":9.0,"duplicate":true}
	]

func _event_id(spec: Dictionary,index: int) -> String:
	return ("destroy:" if str(spec.kind) in ["destroy","drone"] else "")+"r01-enet-qa:"+str(spec.tag)+":"+str(index)

func _request(tag: String) -> String:
	for key in game.reports:
		if str(key).begins_with("blast:"+tag+"|"): return str(key)
	return ""

func _measure(samples: PackedVector2Array) -> Dictionary:
	var peak:=0.0
	var energy:=0.0
	var at_ceiling:=0
	var clips:=0
	for sample in samples:
		var p:=maxf(absf(sample.x),absf(sample.y))
		peak=maxf(peak,p)
		energy+=sample.length_squared()*.5
		if p>.885: at_ceiling+=1
		if p>=.999:clips+=1
	return {"frames":samples.size(),"peak_db":linear_to_db(maxf(0.00000001,peak)),
		"rms_db":linear_to_db(maxf(.00000001,sqrt(energy/maxf(1.,float(samples.size()))))),
		"high_pct":100.0*at_ceiling/maxi(1,samples.size()),"clipped":clips}

func _run() -> void:
	started_at=Time.get_ticks_usec()
	if role=="client":
		GameOptions.ensure()
		GameOptions.values.merge(GameOptions.PRESETS["Médio"],true)
		GameOptions.values["scale"]=1.0
		GameOptions.values["fps"]=60
		GameOptions.values["vsync"]=false
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size=Vector2i(1920,1080)
		root.scaling_3d_scale=1.0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=load("res://tests/war_frame_pacing_game.gd").new()
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	game.set_meta("war_host",role=="server")
	if role=="server":game.set_meta("online_bots_test",true)
	else:game.set_meta("war_visual_preview",true)
	root.add_child(game)
	game.nickname_input.text="R01ExplosionQA_"+role
	game.address_input.text=server_ip
	if role=="server":await _server_explosions()
	else:await _client_explosions()
	var result: Dictionary={
		"role":role,"checks":audio_checks,"failures":failures,
		"events":event_reports,"source_events":source_events,
		"server_min_bots":source_min_bots,"client_min_remote_bots":client_min_bots,
		"elapsed_sec":(Time.get_ticks_usec()-started_at)*0.000001,
		"gpu":RenderingServer.get_video_adapter_name() if role=="client" else "headless",
		"renderer":RenderingServer.get_current_rendering_method(),
		"replicated_players":game.players.size(),
		"mixer":"CombatExplosions/limiter + Master/limiter; native AudioEffectCapture",
		"network":"real DTLS/ENet with authoritative WarVehicles.explosion_event reliable RPC"}
	if role=="client":result["resolution"]=root.get_texture().get_size()
	NavalStorage.write_json("res://work/r01-explosion-enet-20261109-"+WarOperation.from_args()+"/"+role+".json",result)
	print("R01_EXPLOSION_ENET_RESULT ",JSON.stringify(result))
	if is_instance_valid(game):
		game.show_menu()
		game.queue_free()
	await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)

func _server_explosions() -> void:
	if not await _wait_for(func()->bool:return game.multiplayer.get_peers().size()==1,"real ENet connection",260):return
	var peer: int=game.multiplayer.get_peers()[0]
	if not await _wait_for(func()->bool:return game.players.has(peer) and game.loading_baselines.is_empty() and game.reports.has("baseline-ready"),"DTLS baseline ready",250):return
	_check(game._deploy(peer,0,"soldier","fal","rpg","base"),"server deploys real player")
	audio_checks+=1
	if not await _wait_for(func()->bool:return is_instance_valid(game.bot_director) and game.bot_director.bots.size()==28 and game.reports.has("client-ready"),"28 live War bots with prepared client",170):return
	_check(is_instance_valid(game.vehicle_system) and is_instance_valid(game.war_fx),"production vehicles and projectile components are mounted")
	audio_checks+=1
	source_min_bots=28
	game.phase="ready"
	game._broadcast("qa_phase",["ready"])
	for spec in _cases():
		var tag: String=str(spec.tag)
		if not await _wait_for(func()->bool:return not _request(tag).is_empty(),"client requests "+tag,35):break
		var msg:=_request(tag)
		game.reports.erase(msg)
		var fields: PackedStringArray=msg.split("|")
		if fields.size()!=4:
			_check(false,"invalid QA point request "+tag)
			break
		var point:=Vector3(float(fields[1]),float(fields[2]),float(fields[3]))
		if not point.is_finite():
			_check(false,"invalid finite point "+tag)
			break
		for index in int(spec.count):
			var event_id:=_event_id(spec,index)
			game.vehicle_system._broadcast("explosion_event",[
				event_id,point+Vector3(float(index)*1.5,0.,0.),
				float(spec.radius),str(spec.surface),str(spec.weapon)])
			source_events+=1
		if bool(spec.get("duplicate",false)):
			game.vehicle_system._broadcast("explosion_event",[
				_event_id(spec,0),point,float(spec.radius),str(spec.surface),str(spec.weapon)])
		print("R01_EXPLOSION_SENT ",tag," logical=",spec.count," real_bots=",game.bot_director.bots.size())
		if not await _wait_for(func()->bool:return game.reports.has("ack:"+tag),"client acknowledged "+tag,34):break
		source_min_bots=mini(source_min_bots,game.bot_director.bots.size())
		_check(game.bot_director.bots.size()==28,"authority remains at 28 live bots after "+tag)
		audio_checks+=1
	if await _wait_for(func()->bool:return game.reports.has("done"),"client completed explosion matrix",20):
		game.phase="finish"
		game._broadcast("qa_phase",["finish"])
		_check(source_events==13,"authority dispatched all 13 original explosion events")
		audio_checks+=1
		_check(source_min_bots==28,"bot population stayed 28 throughout audio tests")
		audio_checks+=1
	await create_timer(.8).timeout

func _client_explosions() -> void:
	game.mode="pvp"
	game.map_kind="desert"
	game._enter_match_world()
	game.world_prebuilt=true
	await create_timer(.8).timeout
	game.ui_focus.close_all()
	game.loading_screen.hide()
	await game.join_game("pvp")
	if not await _wait_for(func()->bool:return game.join_ready and is_instance_valid(game.local_player),"client admitted through real DTLS",240):return
	game.rpc_id(1,"qa_report","baseline-ready")
	if not await _wait_for(func()->bool:return game.local_player.deployed and game.players.size()==29,"28 bots replicated and player deployed",240):return
	game.ui_focus.close_all()
	game.third_person=true
	game.local_player._update_view()
	game.vehicle_system.set_process_input(false)
	game.rpc_id(1,"qa_report","client-ready")
	if not await _wait_for(func()->bool:return game.phase=="ready","server ready with 28 live bots",170):return
	client_min_bots=28
	var display:=RenderingServer.get_video_adapter_name()
	_check(display.contains("GTX 1650"),"real R01 GTX 1650 renderer")
	audio_checks+=1
	_check(root.get_texture().get_size()==Vector2(1920,1080),"real 1080p render target")
	audio_checks+=1
	_check(RenderingServer.get_current_rendering_method()!="gl_compatibility","Forward+ render method")
	audio_checks+=1
	_check(game.players.size()==29 and _remote_actors().size()==28,"exactly 28 replicated bot players")
	audio_checks+=1
	_check(is_instance_valid(game.vehicle_system) and is_instance_valid(game.war_fx),"client built real production vehicles and projectile system")
	audio_checks+=1
	client_audio=game.combat_audio.explosion_audio
	_check(is_instance_valid(client_audio),"client uses WarAudio's live GameExplosionAudio")
	audio_checks+=1
	if not is_instance_valid(client_audio):return
	var bus:=AudioServer.get_bus_index("CombatExplosions")
	var master:=AudioServer.get_bus_index("Master")
	_check(bus>=0 and master>=0,"explosion and master buses available")
	audio_checks+=1
	var has_compressor:=false
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus,i) is AudioEffectCompressor:has_compressor=true
	_check(has_compressor,"explosion transient compressor is active in the multiplayer client")
	audio_checks+=1
	mix_capture=AudioEffectCapture.new()
	mix_capture.buffer_length=6.0
	AudioServer.add_bus_effect(bus,mix_capture)
	master_capture=AudioEffectCapture.new()
	master_capture.buffer_length=6.0
	AudioServer.add_bus_effect(master,master_capture)

	for spec in _cases():
		var tag: String=str(spec.tag)
		for voice in client_audio.voices:voice.stop()
		for voice in client_audio.pressure_voices:voice.stop()
		client_audio.propagation.clear()
		await create_timer(.40).timeout
		mix_capture.clear_buffer()
		master_capture.clear_buffer()
		var point:=GameWeaponAudio.listener_position(root)+Vector3(0.,0.,-float(spec.distance))
		var prior_events:=client_audio.started_events
		var prior_seen:=game.seen_impacts.size()
		var request: String="blast:"+tag+"|"+str(point.x)+"|"+str(point.y)+"|"+str(point.z)
		game.rpc_id(1,"qa_report",request)
		var ids: Array[String]=[]
		for index in int(spec.count):ids.append(_event_id(spec,index))
		if not await _wait_for(func()->bool:
			for id in ids:
				if not game.seen_impacts.has(id):return false
			return true,
			"replicated explosion_event(s) "+tag,25):
			break
		var travel:=GameSoundPropagation.delay(float(spec.distance))
		await create_timer(travel+1.2).timeout
		var mix:=_measure(mix_capture.get_buffer(mix_capture.get_frames_available()))
		var output:=_measure(master_capture.get_buffer(master_capture.get_frames_available()))
		var layers:=client_audio.started_events-prior_events
		var dedup:=game.seen_impacts.size()-prior_seen
		var report: Dictionary={
			"case":tag,"distance_m":spec.distance,"kind":spec.kind,
			"events":spec.count,"started_layers":layers,"received_ids":dedup,
			"travel_delay_sec":travel,"mixer":mix,"master":output,
			"bot_count":_remote_actors().size()}
		event_reports.append(report)
		print("R01_EXPLOSION_RECEIVED ",JSON.stringify(report))
		_check(dedup==int(spec.count),"reliable explosion RPC delivered correct unique event count: "+tag)
		audio_checks+=1
		_check(layers>=int(spec.count),"live 3D explosion voices started after propagation: "+tag)
		audio_checks+=1
		_check(mix.frames>0 and float(mix.rms_db)>-80.0,"explosion bus outputs actual PCM: "+tag)
		audio_checks+=1
		_check(output.frames>0 and int(output.clipped)==0 and float(output.peak_db)<-.5,
			"live 28-bot Master stays below digital clipping: "+tag)
		audio_checks+=1
		client_min_bots=mini(client_min_bots,_remote_actors().size())
		_check(_remote_actors().size()==28,"28 bot avatars remain replicated: "+tag)
		audio_checks+=1
		if tag=="tank50pair" or tag=="tank50quad":
			_check(float(mix.high_pct)<8.0,"near-field heavy explosions avoid sustained peak saturation: "+tag)
			audio_checks+=1
		game.rpc_id(1,"qa_report","ack:"+tag)
		await create_timer(.18).timeout
	game.rpc_id(1,"qa_report","done")
	if not await _wait_for(func()->bool:return game.phase=="finish","authority processed all explosion checks",25):return
	_check(event_reports.size()==_cases().size(),"all 9 explosion scenarios completed")
	audio_checks+=1
	if event_reports.size()==_cases().size():
		var near: Dictionary=event_reports[0]
		var far: Dictionary=event_reports[3]
		var farther: Dictionary=event_reports[4]
		_check(float(near.mixer.rms_db)>float(far.mixer.rms_db),"50m heavy event is more intense than 400m")
		audio_checks+=1
		_check(float(far.mixer.rms_db)>float(farther.mixer.rms_db),"400m heavy event is more intense than 600m")
		audio_checks+=1
		_check(client_min_bots==28,"28 bot count remained stable during entire audio matrix")
		audio_checks+=1
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
