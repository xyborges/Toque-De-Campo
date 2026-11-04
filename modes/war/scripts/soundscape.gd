extends Node3D
class_name WarSoundscape

var game: Node3D
var footsteps_only:=false
var update_clock:=0.0
var loops: Dictionary={}
var steps: Dictionary={}
var foley: Array[AudioStreamPlayer3D]=[]
var foley_cursor:=0
var ambient_at:=0.0
var acoustic_cursor:=0
var inside:=false
var cabin:=false
var operator_optic:=false
var vehicle_motion: Dictionary={}
var settings: Dictionary={}
var footstep_count:=0
var step_streams: Dictionary={}
const CATEGORIES := ["Armas","Veiculos","Ambiente","Passos","Interface"]

func _ready() -> void:
	name="WarSoundscape"
	if DisplayServer.get_name()=="headless": set_process(false);return
	GameAudioSettings.ensure()
	settings=NavalStorage.read_json(NavalStorage.settings_folder().path_join("war-audio.json"))
	for category in CATEGORIES:
		_bus(category,"Efeitos" if category!="Interface" else "Master")
		var blocked:=_bus("WarBlocked"+category,category)
		if AudioServer.get_bus_effect_count(blocked)==0:
			var low:=AudioEffectLowPassFilter.new();low.cutoff_hz=1400
			AudioServer.add_bus_effect(blocked,low)
		var interior:=_bus("WarInterior"+category,category)
		if AudioServer.get_bus_effect_count(interior)==0:
			var low:=AudioEffectLowPassFilter.new();low.cutoff_hz=4200
			AudioServer.add_bus_effect(interior,low)
			var room:=AudioEffectReverb.new();room.room_size=.55;room.wet=.12;room.dry=.95
			AudioServer.add_bus_effect(interior,room)
	var vehicles_bus:=AudioServer.get_bus_index("Veiculos")
	if AudioServer.get_bus_effect_count(vehicles_bus)==0: AudioServer.add_bus_effect(vehicles_bus,AudioEffectLimiter.new())
	for item in [["WarCabinWeapons","WeaponShots",1800.],["WarCabinVehicles","Veiculos",1600.]]:
		var bus:=_bus(str(item[0]),str(item[1]))
		if AudioServer.get_bus_effect_count(bus)==0:
			var filter:=AudioEffectLowPassFilter.new();filter.cutoff_hz=float(item[2]);AudioServer.add_bus_effect(bus,filter)
	if not footsteps_only:
		for kind in ["guarani","bmp2","abrams","t90"]:
			for sound in ["engine","rolling","servo"]: _sound(sound+"-"+str(kind),true)
		_sound("engine-bike",true);_sound("tyres",true)
	for index in 24:
		var voice:=AudioStreamPlayer3D.new()
		voice.add_to_group("war_spatial_audio");voice.add_to_group("spatial_sfx")
		voice.set_meta("category","Passos");voice.set_meta("base_db",-11.0)
		voice.bus="Passos";voice.max_distance=55;voice.unit_size=3
		add_child(voice);foley.append(voice)
	for surface in ["wood","gravel","concrete","dirt","mud","metal","water","grass","asphalt","stone"]:
		for index in 3:
			var id: String="step-"+surface+"-"+str(index)
			step_streams[id]=_sound(id,false)
	if footsteps_only:return
	var wind:=_loop("wind","wind",Vector3.ZERO,"Ambiente",-29,170)
	wind.unit_size=70
	_loop("wreck-fire-west","fire",WarTerrain.point(-230,125)+Vector3.UP,"Ambiente",-22,85)
	_loop("wreck-fire-east","fire",WarTerrain.point(210,125)+Vector3.UP,"Ambiente",-22,85)
	_loop("broken-power","electric",WarTerrain.point(15,118)+Vector3.UP*3,"Ambiente",-35,18)
	ambient_at=game.war_clock+4

func _bus(label: String,parent: String) -> int:
	var index:=AudioServer.get_bus_index(label)
	if index<0:
		AudioServer.add_bus();index=AudioServer.bus_count-1
		AudioServer.set_bus_name(index,label);AudioServer.set_bus_send(index,parent)
	return index

func set_volume(category: String,db: float) -> void:
	if category not in CATEGORIES: return
	GameAudioSettings.set_volume(category,0.0 if db<=-60 else db_to_linear(clampf(db,-60,0)))
	GameAudioSettings.flush()

func _sound(id: String,looped: bool) -> AudioStream:
	var stream:=GameCombatAudioCatalog.stream("res://audio/war/"+id+".wav")
	if looped and stream is AudioStreamWAV and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=int(stream.get_length()*stream.mix_rate)
	return stream

func _loop(id: String,sound: String,point: Vector3,category: String,db: float,range_value: float) -> AudioStreamPlayer3D:
	if loops.has(id): return loops[id]
	var voice:=AudioStreamPlayer3D.new()
	voice.stream=_sound(sound,true)
	voice.bus=category;voice.set_meta("category",category);voice.set_meta("base_db",db)
	voice.max_distance=range_value;voice.unit_size=8;voice.volume_db=db
	voice.add_to_group("war_spatial_audio");voice.add_to_group("spatial_sfx")
	add_child(voice);voice.global_position=point
	loops[id]=voice
	voice.play()
	return voice

func one_shot(id: String,point: Vector3,category: String,db: float,range_value:=55.0) -> void:
	if foley.is_empty(): return
	var voice:=foley[foley_cursor];foley_cursor=(foley_cursor+1)%foley.size()
	voice.stream=step_streams[id] if step_streams.has(id) else _sound(id,false);voice.global_position=point
	voice.bus=category;voice.set_meta("category",category);voice.set_meta("base_db",db)
	voice.volume_db=db;voice.max_distance=range_value
	voice.pitch_scale=1.0
	voice.play()

func _process(delta: float) -> void:
	if footsteps_only:return
	update_clock+=delta
	if update_clock<.1: return
	var step:=update_clock;update_clock=0
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	var listener:=GameWeaponAudio.listener_position(get_viewport())
	var operator:=game.local_player as WarPlayer
	var manager:=game.vehicle_system as WarVehicles
	var vehicle: Node3D=manager.find_target(operator.vehicle_id) if is_instance_valid(operator) and manager else null
	var is_operator: bool=manager and manager._local_is_operator()
	operator_optic=vehicle is WarVehicle and is_operator and not manager.vehicle_view.external and not manager.tv.viewing()
	cabin=vehicle is WarVehicle and (not is_operator or operator_optic)
	var roof:=PhysicsRayQueryParameters3D.create(listener,listener+Vector3.UP*5,1,manager.owner_excludes(operator.peer_id) if is_instance_valid(operator) and manager else [])
	inside=cabin or not get_world_3d().direct_space_state.intersect_ray(roof).is_empty()
	var wind: AudioStreamPlayer3D=loops.get("wind")
	if wind:
		wind.global_position=listener+Vector3(20,6,10)
		wind.set_meta("base_db",-41.0 if inside else -29.0)
	_update_vehicles(listener,step)
	_update_acoustics(listener,step)
	if game.war_clock>ambient_at:
		ambient_at=game.war_clock+22.0+fmod(game.war_clock,13)
		# Sparse sources belong to wooded locations; no moving creak in the ear.
		for source in [Vector3(-340,0,490),Vector3(350,0,-500)]:
			var point:=WarTerrain.point(source.x,source.z)+Vector3.UP*4
			if not inside and listener.distance_to(point)<110: one_shot("bird",point,"Ambiente",-32,110)

func _update_vehicles(listener: Vector3,delta: float) -> void:
	if not game.vehicle_system: return
	var live: Dictionary={}
	for vehicle: WarVehicle in game.vehicle_system.vehicles.values():
		var key: String=vehicle.vehicle_id
		live[key]=true
		var distance_to:=vehicle.global_position.distance_to(listener)
		var normalized_speed:=clampf(absf(vehicle.speed)/float(vehicle.spec.speed),0,1)
		var motion: Dictionary=vehicle_motion.get(key,{"speed":absf(vehicle.speed),"rpm":.90})
		var load:=clampf((absf(vehicle.speed)-float(motion.speed))/maxf(.01,delta)/float(vehicle.spec.acceleration),0,1)
		motion.speed=absf(vehicle.speed)
		motion.rpm=lerpf(float(motion.rpm),.90+normalized_speed*.22+load*.07,1-exp(-delta*5))
		vehicle_motion[key]=motion
		var running: bool=not vehicle.destroyed and (vehicle.driver>0 or absf(vehicle.speed)>.2) and distance_to<350
		for suffix in ["engine","rolling","servo"]:
			if bool(vehicle.spec.get("transport",false)) and suffix=="servo": continue
			var id: String=key+":"+suffix
			if not running:
				if loops.has(id):
					loops[id].set_meta("base_db",-60.0)
					loops[id].volume_db=move_toward(loops[id].volume_db,-60,delta*30)
				continue
			var sound: String=suffix+"-"+("guarani" if vehicle is WarShip or bool(vehicle.spec.get("transport",false)) else vehicle.kind)
			if bool(vehicle.spec.get("transport",false)): sound="engine-bike" if suffix=="engine" else "tyres"
			var point: Vector3=vehicle.turret.global_position if suffix=="servo" else vehicle.to_global(Vector3(0,1,2))
			var voice:=_loop(id,sound,point,"Veiculos",-60,340 if suffix=="engine" else (90 if suffix=="servo" else 140))
			if not voice.playing: voice.play()
			voice.global_position=point
			var pitch_target:=float(motion.rpm) if suffix=="engine" else .94+normalized_speed*.18
			var gain: float=-21+normalized_speed*5+load*2
			if bool(vehicle.spec.get("transport",false)):
				gain=-26+normalized_speed*4+load*2
				pitch_target=.85+normalized_speed*.65+load*.08
			if suffix=="rolling":
				gain=-60 if absf(vehicle.speed)<.50 else (-40+normalized_speed*7 if not vehicle.spec.tracked else -35+normalized_speed*8)
			if suffix=="servo":
				var yaw_change:=absf(angle_difference(float(voice.get_meta("yaw",vehicle.turret_yaw)),vehicle.turret_yaw))
				var pitch_change:=absf(vehicle.gun_pitch-float(voice.get_meta("pitch",vehicle.gun_pitch)))
				var rate: float=(yaw_change+pitch_change)/maxf(.01,delta)
				gain=-60 if rate<.025 else -38+minf(6,rate*5)
				pitch_target=.96+minf(.12,rate*.06)
			voice.pitch_scale=lerpf(voice.pitch_scale,pitch_target,1-exp(-delta*4))
			voice.set_meta("yaw",vehicle.turret_yaw);voice.set_meta("pitch",vehicle.gun_pitch);voice.set_meta("base_db",gain)

	for drone: WarDrone in game.vehicle_system.drones.values():
		var key: String=drone.drone_id
		live[key]=true
		if listener.distance_to(drone.global_position)>220: continue
		var voice:=_loop(key+":rotor","drone",drone.global_position,"Veiculos",-19,220)
		voice.global_position=drone.global_position;voice.pitch_scale=1.0+drone.velocity.length()*.025
		voice.set_meta("base_db",lerpf(-19.,-15.,clampf(drone.velocity.length()/10.,0.,1.)))
	for key in vehicle_motion.keys():
		if not live.has(key): vehicle_motion.erase(key)
	for key in loops.keys():
		if ":" in str(key) and not live.has(str(key).get_slice(":",0)):
			loops[key].stop();loops[key].queue_free();loops.erase(key)

func play_step(id: int,life: int,sequence: int,point: Vector3,running: bool,crouched: bool) -> bool:
	if foley.is_empty() or not point.is_finite(): return false
	var previous: Dictionary=steps.get(id,{})
	if int(previous.get("life",-1))==life and sequence<=int(previous.get("sequence",-1)): return false
	steps[id]={"life":life,"sequence":sequence}
	var range_value:=26.0 if crouched else (60.0 if running else 45.0)
	if GameWeaponAudio.listener_position(get_viewport()).distance_to(point)>range_value: return false
	var surface:=contact_surface(point)
	var gain: float=-25 if crouched else (-13 if running else -18)
	if is_instance_valid(game.local_player) and game.local_player.peer_id==id:gain+=4.
	one_shot("step-"+surface+"-"+str(sequence%3),point,"Passos",gain,range_value)
	var voice:=foley[(foley_cursor+foley.size()-1)%foley.size()]
	voice.pitch_scale=1.0+float(posmod(id*7+sequence*11,9)-4)*.015
	voice.set_meta("footstep_actor",id);voice.set_meta("footstep_sequence",sequence)
	footstep_count+=1
	return true

func contact_surface(point: Vector3) -> String:
	var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.28,point-Vector3.UP*.45,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var collider:=hit.collider as Node
		if is_instance_valid(collider):
			var surface:=str(collider.get_meta("surface",""))
			if collider is CollisionObject3D and hit.has("shape"):
				var shape_owner:=collider.shape_owner_get_owner(collider.shape_find_owner(int(hit.shape))) as Node
				if is_instance_valid(shape_owner): surface=str(shape_owner.get_meta("surface",surface))
			if surface in ["steel","screen"]: return "metal"
			if surface in ["wood","metal","water","mud","grass","asphalt","stone"]: return surface
			if surface in ["rock","gravel"]: return "stone"
			if surface in ["concrete","brick","plaster","floor"]: return "concrete"
	if footsteps_only:return "dirt" if game.map_kind in ["afghan","desert"] else "concrete"
	return surface_at(point,game.war_clock)

static func surface_at(point: Vector3,clock:=0.0) -> String:
	if WarTerrain.trench_distance(Vector2(point.x,point.z))<2.0 and point.z<65: return "wood"
	var road:=WarRoads.foot_surface(Vector2(point.x,point.z),WarWeather.intensity(clock)>.25)
	if not road.is_empty(): return road
	if absf(point.z-25*sin(point.x*.009))<7: return "asphalt"
	if point.z>35 and point.z<180 and absf(point.x)<85 and point.y>WarTerrain.height_at(point.x,point.z)+.15: return "concrete"
	if WarWeather.intensity(clock)>.25 and WarRoads.distance(Vector2(point.x,point.z))<12: return "mud"
	return "grass" if absf(point.z)>340 else "mud"

func _update_acoustics(listener: Vector3,delta: float) -> void:
	var voices:=get_tree().get_nodes_in_group("war_spatial_audio")
	if voices.is_empty(): return
	# At most eight occlusion rays per 100 ms, spread across active sources.
	var scanned:=0
	var updated:=0
	while scanned<voices.size() and updated<8:
		scanned+=1
		acoustic_cursor=(acoustic_cursor+1)%voices.size()
		var voice:=voices[acoustic_cursor] as AudioStreamPlayer3D
		if not is_instance_valid(voice) or not voice.playing: continue
		updated+=1
		var point:=voice.global_position
		var distance_to:=listener.distance_to(point)
		var blocked:=false
		if distance_to>2 and distance_to<voice.max_distance:
			var excluded: Array[RID]=[]
			if is_instance_valid(game.local_player) and game.vehicle_system: excluded=game.vehicle_system.owner_excludes(game.local_player.peer_id)
			var ray:=PhysicsRayQueryParameters3D.create(listener,point,1,excluded)
			ray.hit_from_inside=false
			var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
			# A large exploding hull is often the first geometry hit by the ray.
			# Do not treat the source vehicle as a wall that silences itself.
			var source_clearance:=GameExplosionAudio.contact_allowance(str(voice.get_meta("kind","standard"))) if str(voice.get_meta("acoustic_kind",""))=="explosion" else 2.0
			blocked=not hit.is_empty() and Vector3(hit.position).distance_to(point)>source_clearance
		var category: String=str(voice.get_meta("category","Armas"))
		if operator_optic and category in ["Armas","Veiculos"]:
			voice.bus="WarCabinWeapons" if category=="Armas" else "WarCabinVehicles"
			var level: float=float(voice.get_meta("base_db",-15))-(17.0 if str(voice.get_meta("acoustic_kind",""))=="explosion" else (6.0 if category=="Armas" else 3.0))-(6.0 if blocked else 0.0)
			voice.volume_db=lerpf(voice.volume_db,level,1.0-exp(-delta*9))
			continue
		if str(voice.get_meta("acoustic_kind",""))=="explosion":
			# Explosions have their own EQ and tail buses. Do not reroute
			# them through the weapon-shot effects.
			var base: float=float(voice.get_meta("base_db",-8.))
			voice.bus="CombatExplosions"+("Blocked" if blocked else ("Far" if distance_to>180 else ""))
			voice.volume_db=lerpf(voice.volume_db,base-(5.0 if blocked else 0.0),1.0-exp(-delta*9))
			continue
		if category=="Armas":
			# War owns the occlusion query, while the shared shot buses provide
			# the same distant filter/reverb and limiter as infantry elsewhere.
			# Routing is exclusive: a blocked source is not also sent through
			# the far/interior effects or attenuated by two acoustic managers.
			GameWeaponAudio.apply_acoustics(voice,distance_to,blocked,inside,1.0-exp(-delta*9))
			continue
		voice.bus=("WarBlocked" if blocked else ("WarInterior" if inside else ""))+category
		var goal:=float(voice.get_meta("base_db",-15))-(12.0 if blocked else (4.0 if cabin and category!="Veiculos" else 0.0))
		voice.volume_db=lerpf(voice.volume_db,goal,1.0-exp(-delta*9))

func forget_owner(id: int) -> void:
	steps.erase(id)

func _exit_tree() -> void:
	for voice in loops.values():
		if is_instance_valid(voice): voice.stop()
