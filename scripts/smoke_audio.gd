extends Node3D
class_name GameSmokeAudio

# Event-driven 3D smoke sound; runs only on clients and reuses fixed voices.
# Gameplay, network messages and smoke rendering remain unaffected.
const TANK_START := "res://audio/smoke/tank_smoke_launch.mp3"
const HAND_START := "res://audio/smoke/hand_smoke_start.mp3"
const HISS_LOOP := "res://audio/smoke/smoke_hiss_loop.mp3"
const START_VOICES := 5
const LOOP_VOICES := 4
const LOOP_UPDATE := 0.12

var source: Node
var tank_stream: AudioStream
var hand_stream: AudioStream
var hiss_stream: AudioStreamMP3
var starts: Array[AudioStreamPlayer3D]=[]
var loops: Array[Dictionary]=[]
var update_clock:=0.0

static func start_range(kind: String) -> float:
	return 255.0 if kind=="vehicle" else 145.0

static func loop_range(kind: String) -> float:
	return 150.0 if kind=="vehicle" else 95.0

static func loop_delay(kind: String) -> float:
	return 3.3 if kind=="vehicle" else 2.0

static func loop_gain(kind: String,age: float,duration: float,distance: float) -> float:
	if kind not in ["hand","vehicle"] or age<0.0 or age>=duration or not is_finite(distance): return 0.0
	var start:=loop_delay(kind)
	if age<start: return 0.0
	var fade_in:=smoothstep(start,start+2.6,age)
	var fade_out:=1.0-smoothstep(duration-17.,duration,age)
	var range_value:=loop_range(kind)
	var far:=1.0-smoothstep(range_value*.70,range_value,distance)
	return clampf(fade_in*fade_out*far,0.,1.)

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	tank_stream=load(TANK_START)
	hand_stream=load(HAND_START)
	hiss_stream=(load(HISS_LOOP) as AudioStreamMP3).duplicate() as AudioStreamMP3
	hiss_stream.loop=true
	for i in START_VOICES:
		var player:=_voice("Efeitos",255.,9.)
		player.name="SmokeStart"+str(i)
		starts.append(player)
	for i in LOOP_VOICES:
		var player:=_voice("Ambiente",150.,6.)
		player.name="SmokeHiss"+str(i)
		player.stream=hiss_stream
		loops.append({"player":player,"id":"","kind":"","gain":0.0})

func _voice(bus_name: String,max_range: float,unit: float) -> AudioStreamPlayer3D:
	var player:=AudioStreamPlayer3D.new()
	player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.max_distance=max_range
	player.unit_size=unit
	player.max_polyphony=1
	player.volume_db=-60.
	player.bus=bus_name if AudioServer.get_bus_index(bus_name)>=0 else "Master"
	# Keep menu/world cleanup, but do not join WarSoundscape acoustic updates:
	# that subsystem overrides our distance-based hiss envelope and volume.
	player.add_to_group("spatial_sfx")
	add_child(player)
	return player

func play_start(id: String,origin: Vector3,kind: String,elapsed: float) -> void:
	if starts.is_empty() or not origin.is_finite() or elapsed>.35: return
	if kind not in ["hand","vehicle"]: return
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or camera.global_position.distance_to(origin)>start_range(kind): return
	for voice in starts:
		if voice.playing: continue
		voice.stream=tank_stream if kind=="vehicle" else hand_stream
		voice.global_position=origin+Vector3.UP*(1.5 if kind=="vehicle" else .30)
		var bus_name:="Veiculos" if kind=="vehicle" else "Efeitos"
		voice.bus=bus_name if AudioServer.get_bus_index(bus_name)>=0 else "Master"
		voice.max_distance=start_range(kind)
		voice.unit_size=11. if kind=="vehicle" else 5.
		voice.volume_db=-3.0 if kind=="vehicle" else -5.0
		voice.play()
		return

func _process(delta: float) -> void:
	if loops.is_empty() or not is_instance_valid(source): return
	update_clock+=delta
	if update_clock<LOOP_UPDATE: return
	var step:=update_clock
	update_clock=0.0
	_refresh_loops(step)

func _refresh_loops(step: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		stop_all()
		return
	var ear:=camera.global_position
	var candidates: Array[Dictionary]=[]
	for id in source.cloud_order:
		if not source.clouds.has(id): continue
		var cloud: Dictionary=source.clouds[id]
		var kind: String=str(cloud.get("kind","hand"))
		var point: Vector3=cloud.origin
		var distance:=ear.distance_to(point)
		var age: float=float(cloud.age)
		var duration: float=float(cloud.duration)
		var gain:=loop_gain(kind,age,duration,distance)
		if gain<=.0001: continue
		candidates.append({"id":id,"kind":kind,"point":point,"age":age,"gain":gain,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.distance)<float(b.distance))
	var selected: Dictionary={}
	for i in mini(LOOP_VOICES,candidates.size()):
		var candidate: Dictionary=candidates[i]
		selected[str(candidate.id)]=candidate
	# Retain playing nearby loops; fade out evicted sources before reusing voices.
	for row in loops:
		var voice: AudioStreamPlayer3D=row.player
		var id: String=str(row.id)
		if id.is_empty(): continue
		var item: Dictionary=selected.get(id,{})
		var wanted: float=float(item.get("gain",0.0))
		var level: float=move_toward(float(row.gain),wanted,step*(.75 if wanted>0. else 2.5))
		row.gain=level
		if wanted==0. and level<.008:
			voice.stop();row.id="";row.kind="";row.gain=0.0
			continue
		if not item.is_empty(): voice.global_position=item.point+Vector3.UP*.8
		voice.volume_db=(-17.0 if str(row.kind)=="hand" else -14.0)+linear_to_db(maxf(level,.001))
	# Only the nearest four emitters are ever audible.
	for candidate in candidates.slice(0,mini(LOOP_VOICES,candidates.size())):
		var id: String=str(candidate.id)
		var present:=false
		for row in loops:
			if str(row.id)==id: present=true;break
		if present: continue
		for row in loops:
			if not str(row.id).is_empty(): continue
			var voice: AudioStreamPlayer3D=row.player
			row.id=id;row.kind=candidate.kind;row.gain=.002
			voice.global_position=candidate.point+Vector3.UP*.8
			voice.max_distance=loop_range(str(candidate.kind))
			voice.unit_size=7. if str(candidate.kind)=="vehicle" else 4.5
			voice.volume_db=-58.
			var offset:=fposmod(maxf(0.,float(candidate.age)-loop_delay(str(candidate.kind))),maxf(.01,hiss_stream.get_length()))
			voice.play(offset)
			break

func stop_all() -> void:
	for voice in starts: voice.stop()
	for row in loops:
		var voice: AudioStreamPlayer3D=row.player
		voice.stop()
		row.id="";row.kind="";row.gain=0.0
