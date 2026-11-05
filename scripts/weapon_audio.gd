extends Node3D
class_name GameWeaponAudio

# Each trigger owns a fixed world-space origin. A tail is never moved with
# another shot, even when a pool is full or the emitter walks away.
const LIMIT := 96
const PATHS := {"fists":"melee_swing_generated.wav","ak":"ak-005.wav","fal":"fal-098.wav","g3":"g3_near.mp3","glock":"pistol-109.wav","sniper":"sound_026.wav","lightMG":"light-mg.wav","heavyMG":"heavy-mg.wav","hmg":"heavy-mg.wav","autocannon":"heavy-mg.wav","tank":"missile.wav","rpg":"missile.wav","stinger":"missile.wav","tv":"missile.wav","missile":"missile.wav","torpedo":"torpedo.wav","grenade":"melee_swing_generated.wav","broom":"melee_swing_generated.wav","squeegee":"melee_swing_generated.wav","axe":"melee_swing_generated.wav"}
var pools: Dictionary = {}
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var external_acoustics := false
var acoustic_clock := 0.0
var acoustic_cursor := 0
var interior := false
var propagation:=GameSoundPropagation.new()
var acoustic_cache: Dictionary={}
var ray_window:=-1
var ray_budget:=0
var started_events:=0

static func profile(weapon: String) -> Dictionary:
	match weapon:
		"fists":return {"range":12.,"unit":2.,"db":-17.,"limit":4}
		"glock": return {"range":850.0,"unit":46.0,"db":-3.0,"limit":8}
		"ak","fal","g3": return {"range":1800.0,"unit":95.0,"db":-5.5,"limit":24}
		"sniper": return {"range":3200.0,"unit":155.0,"db":-3.0,"limit":8}
		"lightMG","heavyMG","hmg": return {"range":2400.0,"unit":140.0,"db":-7.0,"limit":24}
		"tank","rpg","stinger","tv","missile","autocannon": return {"range":4000.0,"unit":210.0,"db":-5.0,"limit":12}
		"torpedo": return {"range":700.0,"unit":40.0,"db":-12.0,"limit":8}
	return {"range":45.0,"unit":3.0,"db":-9.0,"limit":6}

static func listener_position(viewport: Viewport) -> Vector3:
	var listener := viewport.get_audio_listener_3d()
	if is_instance_valid(listener): return listener.get_listener_transform().origin
	var camera := viewport.get_camera_3d()
	return camera.global_position if is_instance_valid(camera) else Vector3.ZERO

static func source_behind(viewport: Viewport, point: Vector3) -> bool:
	if not is_instance_valid(viewport): return false
	var observer: Transform3D
	var listener:=viewport.get_audio_listener_3d()
	if is_instance_valid(listener): observer=listener.get_listener_transform()
	else:
		var camera:=viewport.get_camera_3d()
		if not is_instance_valid(camera): return false
		observer=camera.global_transform
	var relative:=point-observer.origin
	# Godot faces -Z. Only the rear hemisphere gets a different timbre;
	# leave the original stereo panning and real world-space origin intact.
	return relative.length_squared()>9.0 and relative.normalized().dot(observer.basis.z)>0.25

static func elevation_pitch(viewport: Viewport,point: Vector3) -> float:
	var relative:=point-listener_position(viewport)
	var horizontal:=Vector2(relative.x,relative.z).length()
	# Stereo cannot fully encode height. A very small tonal cue helps
	# distinguish elevated/mid-level/below positions without a fake pan.
	return 1.0+clampf(atan2(relative.y,maxf(0.1,horizontal)),-0.75,0.75)*0.045

static func acoustic_bus(distance_to: float,blocked: bool,enclosed: bool,rear:=false) -> String:
	# Only one distance/occlusion path, with optional fixed rear coloration.
	var route: String="WeaponBlocked" if blocked else (("WeaponInteriorFar" if distance_to>180 else "WeaponInterior") if enclosed else ("WeaponFar" if distance_to>180.0 else ("WeaponMid" if distance_to>60 else "WeaponShots")))
	return ("WeaponRear" if rear else route) if route=="WeaponShots" else (route+"Rear" if rear else route)

static func apply_acoustics(voice: AudioStreamPlayer3D,distance_to: float,blocked: bool,enclosed: bool,smoothing:=1.0) -> void:
	voice.bus=acoustic_bus(distance_to,blocked,enclosed,source_behind(voice.get_viewport(),voice.global_position))
	var edge:=1.0-smoothstep(voice.max_distance*.78,voice.max_distance,distance_to)
	var goal:=float(voice.get_meta("base_db",-12))+GameSoundPropagation.distant_gain_db(distance_to)-(8.0 if blocked else 0.0)+linear_to_db(maxf(.001,edge))
	voice.volume_db=lerpf(voice.volume_db,goal,clampf(smoothing,0,1))

static func _bus(label: String,parent: String) -> int:
	var index := AudioServer.get_bus_index(label)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count-1
		AudioServer.set_bus_name(index,label)
		AudioServer.set_bus_send(index,parent)
	return index

func _ready() -> void:
	add_to_group("acoustic_schedulers")
	if DisplayServer.get_name()=="headless": set_process(false);return
	GameAudioSettings.ensure()
	var shots := _bus("WeaponShots","Armas")
	if AudioServer.get_bus_effect_count(shots)==0:
		AudioServer.add_bus_effect(shots,AudioEffectLimiter.new())
	for entry in [["WeaponMid",5500.0],["WeaponFar",3300.0],["WeaponBlocked",1100.0],["WeaponInterior",4800.0],["WeaponInteriorFar",2200.0]]:
		var index := _bus(entry[0],"WeaponShots")
		if AudioServer.get_bus_effect_count(index)>0: continue
		var low := AudioEffectLowPassFilter.new()
		low.cutoff_hz=float(entry[1])
		AudioServer.add_bus_effect(index,low)
		var room := AudioEffectReverb.new()
		room.wet=.012 if entry[0]=="WeaponFar" else (0.0 if entry[0] in ["WeaponMid","WeaponBlocked"] else (.10 if entry[0]=="WeaponInterior" else .08))
		room.dry=1.0
		room.room_size=.65
		AudioServer.add_bus_effect(index,room)
	# Rear sounds receive a light shared spectral cue. These effects are
	# fixed buses, never allocated for each player, bullet or shot.
	var rear_index:=_bus("WeaponRear","WeaponShots")
	if AudioServer.get_bus_effect_count(rear_index)==0:
		var rear_low:=AudioEffectLowPassFilter.new();rear_low.cutoff_hz=4100.
		AudioServer.add_bus_effect(rear_index,rear_low)
	for entry in [["WeaponMid",5500.0],["WeaponFar",3300.0],["WeaponBlocked",1100.0],["WeaponInterior",4800.0],["WeaponInteriorFar",2200.0]]:
		var rear_route:=_bus(str(entry[0])+"Rear","WeaponRear")
		if AudioServer.get_bus_effect_count(rear_route)>0: continue
		var rear_filter:=AudioEffectLowPassFilter.new()
		rear_filter.cutoff_hz=float(entry[1])*(.72 if entry[0] in ["WeaponFar","WeaponInteriorFar"] else 1.0)
		AudioServer.add_bus_effect(rear_route,rear_filter)
		var tail:=AudioEffectReverb.new()
		tail.wet=.012 if entry[0]=="WeaponFar" else (0.0 if entry[0] in ["WeaponMid","WeaponBlocked"] else (.10 if entry[0]=="WeaponInterior" else .08))
		tail.dry=1.0
		tail.room_size=.65
		AudioServer.add_bus_effect(rear_route,tail)
	# Import/decode before the first trigger, avoiding a synchronous file load
	# in the middle of a burst. Resources stay shared across scene changes.
	for file in PATHS.values() + ["g3_far.mp3"]:
		var path: String="res://audio/"+file
		if not streams.has(path): streams[path]=GameCombatAudioCatalog.stream(path)

	for index in LIMIT: _new_voice()

func play(emitter: int,weapon: String,point: Vector3,elapsed:=0.0) -> AudioStreamPlayer3D:
	weapon=GameWeapons.canonical(weapon)
	if DisplayServer.get_name()=="headless" or not point.is_finite() or not PATHS.has(weapon): return null
	var settings:=profile(weapon)
	var priority:=3.0 if weapon in ["tank","rpg","stinger","tv","missile","autocannon"] else 2.0
	var listener:=listener_position(get_viewport())
	if point.distance_to(listener)>=float(settings.range): return null
	# Queue the event, not an audio player. Long propagation delays cannot
	# reserve the voices needed by a nearby crack or a new close-range burst.
	if GameSoundPropagation.delay(point.distance_to(listener),elapsed)>.008:
		propagation.schedule({"point":point,"weapon":weapon,"emitter":emitter},listener,float(settings.range),priority,elapsed)
		return null
	return _play_now(emitter,weapon,point)

func _new_voice() -> AudioStreamPlayer3D:
	var voice:=AudioStreamPlayer3D.new();voice.name="WeaponVoice"+str(voices.size());voice.max_polyphony=1;voice.max_db=-3
	# Preserve the real 3D origin while making lateral direction easier to hear.
	voice.panning_strength=1.5
	voice.add_to_group("spatial_sfx");voice.set_meta("category","Armas")
	if external_acoustics: voice.add_to_group("war_spatial_audio")
	add_child(voice);voices.append(voice);return voice

func occlusion_excludes() -> Array[RID]: return []

func _blocked(point: Vector3,listener: Vector3) -> bool:
	var window:=floori(propagation.clock*10)
	if window!=ray_window: ray_window=window;ray_budget=8
	var key:=Vector3i(point/3);var ear:=Vector3i(listener/3)
	var cached: Dictionary=acoustic_cache.get(key,{})
	if cached.get("ear") == ear and propagation.clock-float(cached.get("at",-100))<.25: return bool(cached.blocked)
	if ray_budget<=0 or listener.distance_to(point)<2: return false
	ray_budget-=1
	var ray:=PhysicsRayQueryParameters3D.create(listener,point,1,occlusion_excludes());ray.hit_from_inside=false
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	var blocked:=not hit.is_empty() and Vector3(hit.position).distance_to(point)>1
	if acoustic_cache.size()>128: acoustic_cache.clear()
	acoustic_cache[key]={"ear":ear,"at":propagation.clock,"blocked":blocked};return blocked

func _play_now(emitter: int,weapon: String,point: Vector3) -> AudioStreamPlayer3D:
	if point.distance_to(listener_position(get_viewport()))>=float(profile(weapon).range): return null
	var settings := profile(weapon)
	if point.distance_to(listener_position(get_viewport()))>=float(settings.range): return null
	var distance_to_listener:=point.distance_to(listener_position(get_viewport()))
	var path: String="res://audio/"+("g3_far.mp3" if weapon=="g3" and distance_to_listener>=160.0 else PATHS[weapon])
	var stream: AudioStream=streams.get(path)
	if not stream: return null
	var key := "%d:%s"%[emitter,weapon]
	var pool: Array=pools.get(key,[])
	var voice: AudioStreamPlayer3D
	for candidate: AudioStreamPlayer3D in pool:
		if not candidate.playing: voice=candidate;break
	if not voice and pool.size()<int(settings.limit):
		for candidate in voices:
			if not candidate.playing: voice=candidate;break
	if not voice:
		# An emitter at its quota recycles its own tail. Global saturation
		# favors nearby voices; distance is never replaced by extra node creation.
		var candidates: Array=pool if pool.size()>=int(settings.limit) else voices
		for candidate: AudioStreamPlayer3D in candidates:
			if not voice or float(candidate.get_meta("priority",0))<float(voice.get_meta("priority",0)) or (is_equal_approx(float(candidate.get_meta("priority",0)),float(voice.get_meta("priority",0))) and int(candidate.get_meta("started",0))<int(voice.get_meta("started",0))): voice=candidate
	if not voice: return null
	var listener:=listener_position(get_viewport())
	var rank:=2.0/(1+point.distance_to(listener)/120)
	if voice.playing and float(voice.get_meta("priority",0))>rank and str(voice.get_meta("pool",""))!=key: return null
	var old_key := str(voice.get_meta("pool",""))
	if old_key!=key:
		if pools.has(old_key):
			pools[old_key].erase(voice)
			if pools[old_key].is_empty(): pools.erase(old_key)
		pool.append(voice)
		pools[key]=pool
	voice.stop()
	voice.set_meta("priority",rank)
	voice.stream=stream
	voice.global_position=point
	# Short samples must not wait for the next budgeted acoustic scan before
	# receiving their distance character. Wall/interior routing follows in
	# the existing controller; the first route uses a bounded, cached query.
	voice.bus=acoustic_bus(point.distance_to(listener),_blocked(point,listener),interior,source_behind(get_viewport(),point))
	voice.pitch_scale=elevation_pitch(get_viewport(),point)
	voice.volume_db=float(settings.db)
	voice.unit_size=float(settings.unit)
	voice.max_distance=float(settings.range)
	voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.attenuation_filter_cutoff_hz=7500
	voice.set_meta("base_db",float(settings.db))
	voice.set_meta("pool",key)
	voice.set_meta("weapon",weapon)
	voice.set_meta("started",Time.get_ticks_usec())
	apply_acoustics(voice,point.distance_to(listener),_blocked(point,listener),interior)
	voice.play();started_events+=1
	return voice

func _process(delta: float) -> void:
	for event in propagation.take_due(delta): _play_now(int(event.emitter),str(event.weapon),event.point)
	if external_acoustics or voices.is_empty(): return
	acoustic_clock+=delta
	if acoustic_clock<.1: return
	acoustic_clock=0
	var listener := listener_position(get_viewport())
	var space := get_world_3d().direct_space_state
	interior=not space.intersect_ray(PhysicsRayQueryParameters3D.create(listener,listener+Vector3.UP*5,1)).is_empty()
	# Eight rays per tenth of a second, independent of player count/cadence.
	var scanned:=0;var updated:=0
	while scanned<voices.size() and updated<8:
		scanned+=1
		acoustic_cursor=(acoustic_cursor+1)%voices.size()
		var voice := voices[acoustic_cursor]
		if not voice.playing: continue
		updated+=1
		var distance_to := listener.distance_to(voice.global_position)
		var blocked := false
		if distance_to>2 and distance_to<voice.max_distance:
			var ray := PhysicsRayQueryParameters3D.create(listener,voice.global_position,1)
			ray.hit_from_inside=false
			var hit := space.intersect_ray(ray)
			blocked=not hit.is_empty() and Vector3(hit.position).distance_to(voice.global_position)>1
		apply_acoustics(voice,distance_to,blocked,interior)

func _exit_tree() -> void:
	set_process(false);propagation.clear();acoustic_cache.clear()
	for voice in voices: voice.stop()

func cancel() -> void:
	propagation.clear();set_process(false)
	for voice in voices: voice.stop()
