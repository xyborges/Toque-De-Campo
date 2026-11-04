extends Node3D
class_name GameExplosionAudio

# The supplied kit has separate close and distant recordings for each event.
# Crossfade by distance while maintaining the original event's fixed 3D origin.
const LIMIT := 24
const PRESSURE_LIMIT := 8
const PRESSURE_MAX_DISTANCE := 360.0
const HEAVY_NEAR_BOOST_DB := 5.0
const LIGHT_NEAR_BOOST_DB := 2.5
const PRESSURE_PATHS := ["res://audio/explosions/grenade_pressure.wav","res://audio/explosions/tank_pressure.wav","res://audio/explosions/drone_pressure.wav"]
const CLOSE_END := 120.0
const FAR_START := 450.0
const BLEND_THRESHOLD := 0.025

var bus_name := "CombatExplosions"
var category := "Armas"
var gain_db := -6.5
var audible_distance := 3400.0
var voices: Array[AudioStreamPlayer3D] = []
var pressure_voices: Array[AudioStreamPlayer3D] = []
var pressure_started := 0
var recent: Dictionary = {}
var propagation:=GameSoundPropagation.new()
var started_events:=0

func _ready() -> void:
	add_to_group("acoustic_schedulers")
	if DisplayServer.get_name()=="headless": set_process(false);return
	GameAudioSettings.ensure()
	if AudioServer.get_bus_index(category)<0:
		AudioServer.add_bus()
		var parent_index:=AudioServer.bus_count-1
		AudioServer.set_bus_name(parent_index,category)
		AudioServer.set_bus_send(parent_index,"Efeitos")
		AudioServer.add_bus_effect(parent_index,AudioEffectLimiter.new())
	var index:=AudioServer.get_bus_index(bus_name)
	if index<0:
		AudioServer.add_bus()
		index=AudioServer.bus_count-1
		AudioServer.set_bus_name(index,bus_name)
	if AudioServer.get_bus_effect_count(index)==0:
		AudioServer.add_bus_effect(index,AudioEffectLimiter.new())
	if AudioServer.get_bus_index(category)>=0 and category!=bus_name:
		AudioServer.set_bus_send(index,category)
	for path in GameCombatAudioCatalog.EXPLOSIONS+GameCombatAudioCatalog.EXPLOSIONS_FAR+PRESSURE_PATHS:
		GameCombatAudioCatalog.stream(path)
	# Both WAV versions already contain their own outdoor reflections.
	# The far bus must not put an additional artificial room on top.
	for pair in [["Far",5500.],["Blocked",2200.]]:
		var bus:=GameWeaponAudio._bus(bus_name+str(pair[0]),bus_name)
		if AudioServer.get_bus_effect_count(bus)==0:
			var filter:=AudioEffectLowPassFilter.new()
			filter.cutoff_hz=float(pair[1])
			AudioServer.add_bus_effect(bus,filter)
	for i in LIMIT:
		var voice:=AudioStreamPlayer3D.new()
		voice.max_polyphony=1
		voice.max_db=0.0
		voice.panning_strength=1.5
		voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.add_to_group("spatial_sfx")
		voice.add_to_group("war_spatial_audio")
		voice.set_meta("category",category)
		voice.set_meta("acoustic_kind","explosion")
		add_child(voice)
		voices.append(voice)
	for i in PRESSURE_LIMIT:
		var pressure:=AudioStreamPlayer3D.new()
		pressure.name="ExplosionPressure"+str(i)
		pressure.max_polyphony=1
		pressure.max_db=-4.0
		pressure.panning_strength=1.45
		pressure.attenuation_filter_cutoff_hz=14000.0
		pressure.add_to_group("war_spatial_audio")
		pressure.add_to_group("spatial_sfx")
		pressure.set_meta("category",category)
		pressure.set_meta("acoustic_kind","explosion")
		pressure.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(pressure)
		pressure_voices.append(pressure)

func play_event(event_id: String,point: Vector3,kind:="standard") -> AudioStreamPlayer3D:
	if event_id.is_empty() or not point.is_finite() or recent.has(event_id): return null
	recent[event_id]=true
	if recent.size()>256: recent.erase(recent.keys()[0])
	if DisplayServer.get_name()=="headless": return null
	var listener:=GameWeaponAudio.listener_position(get_viewport())
	if GameSoundPropagation.delay(listener.distance_to(point))>.008:
		propagation.schedule({"id":event_id,"point":point,"kind":kind},listener,float(event_profile(kind).range),3)
		return null
	return _start(event_id,point,kind)

func event_profile(kind: String) -> Dictionary:
	if kind in ["tank","destroy"]: return {"range":4800.,"unit":240.,"db":gain_db+2.5}
	if kind in ["tv","drone","rpg","stinger","missile"]: return {"range":4000.,"unit":175.,"db":gain_db+1.5}
	if kind=="autocannon": return {"range":2500.,"unit":110.,"db":gain_db}
	if kind=="grenade": return {"range":1400.,"unit":62.,"db":gain_db-1.5}
	return {"range":audible_distance,"unit":115.,"db":gain_db}

func _process(delta: float) -> void:
	for event in propagation.take_due(delta):
		_start(str(event.id),event.point,str(event.get("kind","standard")))

func _find_voice(listener: Vector3,distance: float,optional:=false) -> AudioStreamPlayer3D:
	for voice in voices:
		if not voice.playing: return voice
	# A secondary crossfade layer must NEVER steal another explosion tail.
	if optional: return null
	var candidate: AudioStreamPlayer3D=voices[0]
	for voice in voices:
		if voice.global_position.distance_squared_to(listener)>candidate.global_position.distance_squared_to(listener): candidate=voice
	if distance>candidate.global_position.distance_to(listener): return null
	return candidate

static func near_presence_db(kind: String,distance: float) -> float:
	# Distinct from physical travel-time propagation. Maintain the destructive
	# first-hit punch near the player; fade back into the existing distance mix.
	var amount:=1.0-smoothstep(65.0,250.0,distance)
	return (HEAVY_NEAR_BOOST_DB if kind in ["tank","destroy","tank_wreck","armor_wreck"] else LIGHT_NEAR_BOOST_DB)*amount

static func contact_allowance(kind: String) -> float:
	# A destroyed hull must not acoustically occlude its own explosion.
	return 6.0 if kind in ["tank","destroy","tank_wreck","armor_wreck"] else (3.5 if kind in ["tv","drone","missile","rpg"] else 1.5)

func _play_layer(voice: AudioStreamPlayer3D,event_id: String,point: Vector3,kind: String,clip: int,distant: bool,weight: float,settings: Dictionary,distance: float,listener: Vector3) -> void:
	voice.stop()
	# Keep the major wreck peak audible even at 50m. The mix bus limiter
	# protects against combined peaks; light blasts retain more headroom.
	voice.max_db=3.0 if kind in ["tank","destroy","tank_wreck","armor_wreck"] else 0.0
	var paths: Array=GameCombatAudioCatalog.EXPLOSIONS_FAR if distant else GameCombatAudioCatalog.EXPLOSIONS
	voice.stream=GameCombatAudioCatalog.stream(paths[clip])
	voice.bus=bus_name+("Far" if distance>180 else "")
	if distance>2:
		var ray:=PhysicsRayQueryParameters3D.create(listener,point,1)
		ray.hit_from_inside=false
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and Vector3(hit.position).distance_to(point)>contact_allowance(kind): voice.bus=bus_name+"Blocked"
	var volume:=float(settings.db)+near_presence_db(kind,distance)+linear_to_db(maxf(.001,weight))
	voice.volume_db=volume
	voice.unit_size=float(settings.unit)
	voice.max_distance=float(settings.range)
	voice.set_meta("base_db",volume)
	voice.set_meta("started",Time.get_ticks_usec())
	voice.set_meta("event_id",event_id)
	voice.set_meta("variant",clip)
	voice.set_meta("kind",kind)
	voice.set_meta("distant_sample",distant)
	voice.set_meta("mix_weight",weight)
	voice.global_position=point
	voice.play()
	started_events+=1

func _start_pressure(event_id: String,point: Vector3,clip: int,settings: Dictionary,distance: float,route: String) -> void:
	if distance>PRESSURE_MAX_DISTANCE or pressure_voices.is_empty(): return
	var voice: AudioStreamPlayer3D
	for candidate in pressure_voices:
		if not candidate.playing:
			voice=candidate
			break
	if voice==null: return # Keep older impacts; no per-event allocations.
	var fade:=1.0-smoothstep(180.0,PRESSURE_MAX_DISTANCE,distance)
	var kind:=str(["grenade","tank","drone"][clip])
	var db:=float(settings.db)-2.0+near_presence_db(kind,distance)*.60+linear_to_db(maxf(.001,fade))
	voice.stream=GameCombatAudioCatalog.stream(PRESSURE_PATHS[clip])
	voice.global_position=point
	voice.bus=route
	voice.volume_db=db
	voice.unit_size=minf(95.0,float(settings.unit)*.70)
	voice.max_db=1.0 if clip==1 else 0.0
	voice.max_distance=PRESSURE_MAX_DISTANCE+25.0
	voice.set_meta("base_db",db)
	voice.set_meta("event_id",event_id)
	voice.set_meta("pressure_layer",true)
	voice.set_meta("kind",kind)
	voice.play()
	pressure_started+=1

func _start(event_id: String,point: Vector3,kind:="standard") -> AudioStreamPlayer3D:
	var listener:=GameWeaponAudio.listener_position(get_viewport())
	var distance:=listener.distance_to(point)
	var settings:=event_profile(kind)
	if distance>=float(settings.range): return null
	var clip:=GameCombatAudioCatalog.explosion_type(kind)
	var far_mix:=clampf((distance-CLOSE_END)/(FAR_START-CLOSE_END),0.,1.)
	var near_mix:=1.0-far_mix
	# Use the dominant version first. During audio saturation, preserving
	# one complete explosion is preferable to cutting off existing tails.
	var dominant_far:=far_mix>=.5
	var main_weight:=far_mix if dominant_far else near_mix
	var voice:=_find_voice(listener,distance)
	if not is_instance_valid(voice): return null
	_play_layer(voice,event_id,point,kind,clip,dominant_far,main_weight,settings,distance,listener)
	var secondary_weight:=near_mix if dominant_far else far_mix
	if secondary_weight>BLEND_THRESHOLD:
		var secondary:=_find_voice(listener,distance,true)
		if is_instance_valid(secondary):
			_play_layer(secondary,event_id,point,kind,clip,not dominant_far,secondary_weight,settings,distance,listener)
	_start_pressure(event_id,point,clip,settings,distance,voice.bus)
	return voice

func _exit_tree() -> void:
	propagation.clear()
	for voice in voices: voice.stop()
	for voice in pressure_voices: voice.stop()

func cancel() -> void:
	propagation.clear()
	set_process(false)
	for voice in voices: voice.stop()
	for voice in pressure_voices: voice.stop()
