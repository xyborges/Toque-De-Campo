extends SceneTree

# Real Godot 3D mixer QA for remote shots in the release-game audio path.
# No synthetic WAVs: read the actual firearm resources and stereo output.
var checks:=0
var failures: Array[String]=[]
var measures: Array[Dictionary]=[]
var world: Node3D
var guns: GameWeaponAudio
var capture: AudioEffectCapture
var listener: AudioListener3D

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func approx(a: float,b: float,tol:=.02) -> bool:
	return absf(a-b)<=tol

func measure(tag: String,weapon: String,point: Vector3) -> Dictionary:
	for v in guns.voices: v.stop()
	guns.propagation.clear()
	await create_timer(.14).timeout
	capture.clear_buffer()
	var voice:=guns._play_now(hash(tag),weapon,point)
	if not is_instance_valid(voice):
		var missing:= {"tag":tag,"left":0.,"right":0.,"rms":0.,"peak_db":-100.,"cutoff":0.,"volume_db":0.,"origin_error":INF}
		measures.append(missing)
		return missing
	# The first weapon transient must receive the distance filter immediately.
	var start_cutoff:=voice.attenuation_filter_cutoff_hz
	var start_volume:=voice.volume_db
	var start_origin:=voice.global_position.distance_to(point)
	await create_timer(.38).timeout
	var samples:=capture.get_buffer(capture.get_frames_available())
	var left_energy:=0.0
	var right_energy:=0.0
	var peak:=0.0
	for sample in samples:
		left_energy+=sample.x*sample.x
		right_energy+=sample.y*sample.y
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	var n:=maxi(samples.size(),1)
	var left:=sqrt(left_energy/n)
	var right:=sqrt(right_energy/n)
	var result: Dictionary={
		"tag":tag,"weapon":weapon,"distance_m":GameWeaponAudio.listener_position(root).distance_to(point),
		"left":left,"right":right,"rms":sqrt((left_energy+right_energy)/(2*n)),
		"peak_db":linear_to_db(maxf(peak,.00000001)),
		"cutoff":start_cutoff,"end_cutoff":voice.attenuation_filter_cutoff_hz,
		"volume_db":start_volume,"origin_error":start_origin,
		"bus":voice.bus,"frames":samples.size(),"stream":voice.stream.resource_path}
	measures.append(result)
	print("SHOT_SPATIAL_PCM ",JSON.stringify(result))
	return result

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Real native audio and device are required")
		quit(2)
		return
	world=Node3D.new()
	world.position=Vector3(12.,0.,7.)
	root.add_child(world)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	listener=AudioListener3D.new()
	root.add_child(listener)
	listener.make_current()
	guns=GameWeaponAudio.new()
	world.add_child(guns)
	await process_frame
	capture=AudioEffectCapture.new()
	capture.buffer_length=2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("WeaponShots"),capture)
	var source:=Vector3(0.,0.,-400.)
	verify(approx(GameWeaponAudio.distant_shot_relief_db("fal",0.),0.,.0001),
		"own muzzle keeps its original punch and gain")
	verify(approx(GameWeaponAudio.distant_shot_relief_db("g3",5.),0.,.0001),
		"very nearby teammates and own muzzle keep the original gain")
	verify(GameWeaponAudio.distant_shot_relief_db("g3",30.)<-.5 and GameWeaponAudio.distant_shot_relief_db("g3",30.)>-2.5,
		"teammates at 30m already begin to sound distinct from the listener")
	verify(approx(GameWeaponAudio.distant_shot_relief_db("fal",400.),-5.0,.02),
		"distant rifle excess presence is reduced without muting long range")
	verify(GameWeaponAudio.distant_shot_relief_db("tank",400.)==0.0
		and GameWeaponAudio.distant_shot_relief_db("rpg",400.)==0.0,
		"tank and launcher gain are untouched")
	verify(GameWeaponAudio.distant_shot_relief_db("fists",400.)==0.0,
		"unrelated tool and melee gain unchanged")
	verify(GameWeaponAudio.filter_target_hz(400.,1800.,false,false,0.,"fal")<8000.,
		"400m muzzle uses a distant timbre, not the near-field bright shot")
	verify(GameWeaponAudio.filter_target_hz(400.,1800.,false,false,0.,"tank")>10000.,
		"heavy weapons retain their distinct 3D tone")
	verify(GameWeaponAudio.filter_target_hz(50.,1800.,false,false,0.,"fal")>17000.,
		"nearby fire retains its crisp attack")
	verify(GameWeaponAudio.filter_target_hz(200.,1800.,false,false,0.,"fal")>
		GameWeaponAudio.filter_target_hz(400.,1800.,false,false,0.,"fal"),
		"small-arms distance filtering is monotonic")
	var near: Dictionary=await measure("fal_near","fal",Vector3(0.,0.,-50.))
	var far: Dictionary=await measure("fal_far","fal",source)
	verify(int(near.frames)>1000 and int(far.frames)>1000 and float(far.rms)>.000001,
		"real FAL samples are rendered at 50 and 400 meters")
	verify(float(near.rms)>float(far.rms)*1.5,
		"real mixed FAL at 400m stays distinctly quieter than nearby fire")
	verify(float(far.origin_error)<.0001 and float(near.origin_error)<.0001,
		"two gunshots remain at authoritative world muzzles despite translated sound manager")
	verify(approx(float(far.volume_db),
		float(GameWeaponAudio.profile("fal").db)+GameSoundPropagation.combat_presence_db(400.)
		+GameSoundPropagation.distant_gain_db(400.)
		+GameWeaponAudio.distant_shot_relief_db("fal",400.),.03),
		"400m FAL uses reduced source gain instead of full global combat amplification")
	verify(float(far.cutoff)<8000. and float(near.cutoff)>17000.,
		"real remote audio begins with the correct distance-dependent filter")
	var left: Dictionary=await measure("left_120","fal",Vector3(-105.,0.,-35.))
	var right: Dictionary=await measure("right_120","fal",Vector3(105.,0.,-35.))
	verify(float(left.left)>float(left.right)*1.2 and float(right.right)>float(right.left)*1.2,
		"remote FAL originates at its true left/right muzzle, never at the listener")
	var g3_near: Dictionary=await measure("g3_near","g3",Vector3(0,0,-50))
	var g3_far: Dictionary=await measure("g3_far","g3",Vector3(0,0,-400))
	verify(float(g3_near.rms)>float(g3_far.rms) and float(g3_far.rms)>.000001,
		"actual G3 near/far resources remain audible with a clear range cue")
	verify(g3_far.stream=="res://audio/g3_far.mp3",
		"G3 distant sample is correctly selected in-game")
	var glock: Dictionary=await measure("glock_far","glock",Vector3(0,0,-400))
	verify(float(glock.rms)>.000001 and float(glock.cutoff)<8000.,
		"remote Glock remains audible and properly distant")
	# Compare the direct firearm transient with a real collision wall.
	# This must not rely on a late reverberation-only window.
	var clear_wall: Dictionary=await measure("wall_clear_50","fal",Vector3(0,0,-50))
	var wall:=StaticBody3D.new()
	root.add_child(wall)
	wall.global_position=Vector3(0,0,-25)
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(12,12,.8)
	collision.shape=box
	wall.add_child(collision)
	await physics_frame
	await physics_frame
	guns.acoustic_cache.clear()
	var blocked_wall: Dictionary=await measure("wall_blocked_50","fal",Vector3(0,0,-50))
	verify(blocked_wall.bus=="WeaponBlocked" and float(blocked_wall.rms)<float(clear_wall.rms)*.86,
		"real wall blocks and reduces remote 50m gunshots in the direct PCM mix")
	print("SHOT_SPATIAL_WALL_RATIO ",float(blocked_wall.rms)/maxf(.00000001,float(clear_wall.rms)))
	wall.queue_free()
	await physics_frame
	guns.acoustic_cache.clear()
	var own: Dictionary=await measure("own_5","fal",Vector3(0,0,-5))
	verify(float(own.rms)>.000001 and approx(float(own.cutoff),GameWeaponAudio.FILTER_OPEN_HZ,.001),
		"own gun remains bright and unaltered")
	verify(float(near.rms)<float(own.rms)*.85,
		"real FAL at 50m is clearly quieter than the same FAL at the local muzzle")
	var tank: Dictionary=await measure("tank_400","tank",Vector3(0,0,-400))
	verify(float(tank.rms)>.000001 and approx(float(tank.volume_db),
		float(GameWeaponAudio.profile("tank").db)+GameSoundPropagation.combat_presence_db(400.)
		+GameSoundPropagation.distant_gain_db(400.),.03),
		"tank fire retains original long-range presence")
	verify(guns.voices.size()==GameWeaponAudio.LIMIT,
		"fixed 96-voice pool remains bounded")
	var bus:=AudioServer.get_bus_index("WeaponShots")
	capture=null
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus,i) is AudioEffectCapture:
			AudioServer.remove_bus_effect(bus,i)
			break
	print("SHOT_LOCALIZATION_QA ",JSON.stringify({"checks":checks,"failures":failures,"pcm":measures,
		"method":"Godot native AudioStreamPlayer3D, actual weapon files, two-axis stereo PCM"}))
	world.queue_free()
	camera.queue_free()
	listener.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
