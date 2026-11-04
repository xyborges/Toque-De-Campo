extends Node
class_name GameCombatFeedback

var voices: Array[AudioStreamPlayer3D] = []
var cursor := 0
var empty_at := -10.0
var hurt_at := -10.0
var near_at := -10.0
var impact_at:=-10.0
const NEAR_DISTANCE:=6.0
const PATHS := {"hurt":"res://audio/hurt_generated.wav","near":"res://audio/near_miss_generated.wav","empty":"res://audio/empty_generated.wav","earth":"res://audio/earth_impact_generated.wav"}
var streams: Dictionary = {}
var propagation:=GameSoundPropagation.new()
var recent: Dictionary={}
var impact_events:=0
var last_passage:=""
var last_passage_point:=Vector3.ZERO
var last_approach_point:=Vector3.ZERO
var passage_pending: Array[Dictionary]=[]
var approach_events:=0
var passage_events:=0
const PASSAGE_GAP:=0.04
const PASSAGE_QUEUE_LIMIT:=16

func _ready() -> void:
	add_to_group("acoustic_schedulers")
	if DisplayServer.get_name()=="headless": set_process(false);return
	GameAudioSettings.ensure()
	for id in PATHS: streams[id]=load(PATHS[id])
	for id in GameImpactSurface.SOUNDS+["crack"]: streams[id]=load("res://audio/ballistics/"+id+".wav")
	for pair in [["ImpactFar",2600.],["ImpactBlocked",1200.]]:
		var index:=GameWeaponAudio._bus(str(pair[0]),"Efeitos")
		if AudioServer.get_bus_effect_count(index)==0:
			var filter:=AudioEffectLowPassFilter.new();filter.cutoff_hz=float(pair[1]);AudioServer.add_bus_effect(index,filter)
	# Rear coloration is a constant-cost bus, not a per-projectile filter.
	for entry in [["BallisticRear","Efeitos",4200.],["ImpactRear","Efeitos",4100.],["ImpactFarRear","ImpactRear",1850.],["ImpactBlockedRear","ImpactRear",1050.]]:
		var channel:=GameWeaponAudio._bus(str(entry[0]),str(entry[1]))
		if AudioServer.get_bus_effect_count(channel)==0:
			var rear_low:=AudioEffectLowPassFilter.new()
			rear_low.cutoff_hz=float(entry[2])
			AudioServer.add_bus_effect(channel,rear_low)
	for index in 12:
		var voice:=AudioStreamPlayer3D.new()
		voice.panning_strength=1.6
		voice.bus="Efeitos"
		voice.add_to_group("spatial_sfx")
		voice.max_distance=35
		voice.unit_size=3
		add_child(voice)
		voices.append(voice)

func play(kind: String, position: Vector3, speed:=250.0,phase:="") -> void:
	if voices.is_empty() or not streams.has(kind): return
	var now:=Time.get_ticks_msec()*.001
	if kind=="empty":
		if now-empty_at<.35: return
		empty_at=now
	elif kind=="hurt":
		if now-hurt_at<.12: return
		hurt_at=now
	elif kind in ["near","crack"]:
		if now-near_at<.10: return
		if phase!="approach": near_at=now
	elif kind in GameImpactSurface.SOUNDS:
		if now-impact_at<.045: return
		impact_at=now
	var priority:=4.0 if phase=="approach" else (5.0 if kind in ["near","crack","hurt","empty"] else 3.0)
	var voice: AudioStreamPlayer3D
	for candidate in voices:
		if not candidate.playing: voice=candidate;break
	if not voice:
		for candidate in voices:
			if not voice or float(candidate.get_meta("priority",0))<float(voice.get_meta("priority",0)): voice=candidate
	if voice.playing and float(voice.get_meta("priority",0))>priority: return
	voice.stop();voice.set_meta("priority",priority);voice.bus="Efeitos"
	voice.stream=streams[kind]
	voice.volume_db=-13.0 if phase=="approach" else (-4 if kind in ["near","crack"] else (-9 if kind in GameImpactSurface.SOUNDS else -4))
	voice.max_distance=800 if kind in GameImpactSurface.SOUNDS else (28 if phase=="approach" else 35)
	voice.unit_size=12 if kind in GameImpactSurface.SOUNDS else (4 if phase=="approach" else 3)
	voice.global_position=position
	voice.pitch_scale=(clampf(speed/300,.75,1.3) if kind=="near" else 1.0)*GameWeaponAudio.elevation_pitch(get_viewport(),position)
	var rear:=GameWeaponAudio.source_behind(get_viewport(),position)
	if kind in ["near","crack"]:
		voice.bus="BallisticRear" if rear else "Efeitos"
		voice.set_meta("ballistic_phase",phase if phase=="approach" else "passage")
		if phase=="approach": approach_events+=1
		else: passage_events+=1
	if kind in GameImpactSurface.SOUNDS:
		var listener:=GameWeaponAudio.listener_position(get_viewport());var distance:=listener.distance_to(position)
		voice.volume_db+=2.5 if distance<30 else 0.0
		if distance>180: voice.bus="ImpactFarRear" if rear else "ImpactFar"
		elif rear: voice.bus="ImpactRear"
		if distance>2:
			var ray:=PhysicsRayQueryParameters3D.create(listener,position,1);ray.hit_from_inside=false
			var hit:=get_viewport().get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and Vector3(hit.position).distance_to(position)>1: voice.bus="ImpactBlockedRear" if rear else "ImpactBlocked";voice.volume_db-=6
		voice.set_meta("surface",kind);impact_events+=1
	voice.play()

func impact(event_id: String,point: Vector3,surface: String) -> void:
	if DisplayServer.get_name()=="headless": return
	if surface not in GameImpactSurface.SOUNDS or recent.has(event_id) or not point.is_finite(): return
	recent[event_id]=true
	if recent.size()>512: recent.erase(recent.keys()[0])
	propagation.schedule({"point":point,"surface":surface},GameWeaponAudio.listener_position(get_viewport()),800,3)

func _process(delta: float) -> void:
	for event in propagation.take_due(delta): play(str(event.surface),event.point)
	# A passing bullet occupies two different world positions: approach and
	# crossing. Queued peaks share the existing 12-voice pool.
	var now:=Time.get_ticks_msec()*.001
	for index in range(passage_pending.size()-1,-1,-1):
		var event: Dictionary=passage_pending[index]
		if float(event.due)>now: continue
		passage_pending.remove_at(index)
		play(str(event.kind),event.point,float(event.speed))

func _exit_tree() -> void:
	propagation.clear();passage_pending.clear()
	for voice in voices: voice.stop()

func near_miss(start: Vector3, end: Vector3, actor: Node3D, owner_id: int,velocity:=Vector3.ZERO,weapon:="") -> bool:
	if not is_instance_valid(actor) or actor.hp<=0 or actor.peer_id==owner_id: return false
	var listener: Vector3=actor.camera_pivot.global_position
	return near_listener(start,end,listener,velocity,weapon)

func near_listener(start: Vector3,end: Vector3,listener: Vector3,velocity: Vector3,weapon: String) -> bool:
	var segment:=end-start
	if segment.length_squared()<.00001: return false
	var t:=clampf((listener-start).dot(segment)/segment.length_squared(),0,1)
	var closest:=start+segment*t
	var distance:=listener.distance_to(closest)
	if distance<.45 or distance>(12.0 if weapon in ["tank","autocannon","rpg","tv"] else NEAR_DISTANCE): return false
	last_passage="crack" if velocity.length()>GameSoundPropagation.SPEED else "near"
	# The projectile's incoming side and crossing point are distinct, fixed
	# positions. The shot itself still comes from the true muzzle emitter.
	var travel:=velocity.normalized() if velocity.length_squared()>.0001 else segment.normalized()
	var approach:=closest-travel*minf(5.5,maxf(2.5,distance*.8))
	var crossing:=closest-travel*minf(.8,distance*.20)
	last_approach_point=approach
	last_passage_point=crossing
	if passage_pending.size()<PASSAGE_QUEUE_LIMIT:
		play("near",approach,velocity.length(),"approach")
		passage_pending.append({"due":Time.get_ticks_msec()*.001+PASSAGE_GAP,"kind":last_passage,"point":crossing,"speed":velocity.length()})
	else:
		play(last_passage,crossing,velocity.length())
	return true

func cancel() -> void:
	propagation.clear();passage_pending.clear();set_process(false)
	for voice in voices: voice.stop()
