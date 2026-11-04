extends SceneTree

var weapons: GameWeaponAudio
var blasts: GameExplosionAudio
var capture: AudioEffectCapture
var count:=0

func _initialize() -> void:
	run.call_deferred()

func summary(frames: PackedVector2Array) -> Dictionary:
	if frames.is_empty(): return {"error":"empty"}
	var total:=0.0
	var peak:=0.0
	var early:=0.0
	var early_count:=0
	var start_count:=mini(frames.size(),14400) # first 300 ms @ 48khz
	for i in frames.size():
		var v: Vector2=frames[i]
		var p: float=v.length_squared()*.5
		total+=p
		if i<start_count: early+=p;early_count+=1
		peak=maxf(peak,maxf(absf(v.x),absf(v.y)))
	return {"rms_db":linear_to_db(sqrt(total/frames.size())),"early_300ms_db":linear_to_db(sqrt(early/maxi(1,early_count))),"peak_db":linear_to_db(peak),"frames":frames.size()}

func measure(kind: String) -> Dictionary:
	for v in weapons.voices: v.stop()
	for v in blasts.voices: v.stop()
	for v in blasts.pressure_voices: v.stop()
	await create_timer(.15).timeout
	capture.clear_buffer()
	var shot: AudioStreamPlayer3D
	var boom: AudioStreamPlayer3D
	if kind=="g3" or kind=="both":
		shot=weapons._play_now(301,"g3",Vector3(0,0,-1.5))
	if kind=="tank" or kind=="both":
		boom=blasts._start("mix:test:"+kind,Vector3(0,0,-100.),"destroy")
	await create_timer(1.6).timeout
	var data:=summary(capture.get_buffer(capture.get_frames_available()))
	data["g3_bus"]=shot.bus if is_instance_valid(shot) else ""
	data["tank_bus"]=boom.bus if is_instance_valid(boom) else ""
	data["g3_max_db"]=shot.max_db if is_instance_valid(shot) else null
	data["tank_max_db"]=boom.max_db if is_instance_valid(boom) else null
	return data

func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var ear:=AudioListener3D.new();scene.add_child(ear);ear.make_current()
	weapons=GameWeaponAudio.new();scene.add_child(weapons)
	blasts=GameExplosionAudio.new();scene.add_child(blasts)
	await process_frame
	var master:=AudioServer.get_bus_index("Master")
	capture=AudioEffectCapture.new();capture.buffer_length=2.
	AudioServer.add_bus_effect(master,capture)
	for kind in ["g3","tank","both"]:
		print("G3_TANK_MIX ",JSON.stringify({"kind":kind,"measured":await measure(kind)}))
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	scene.queue_free();await process_frame
	quit(0)
