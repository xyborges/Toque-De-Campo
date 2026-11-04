extends SceneTree
var scene: Node3D
var audio: GameExplosionAudio
var capture: AudioEffectCapture
var failed: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func pcm(frames: PackedVector2Array) -> Dictionary:
	var total:=0.0
	var peak:=0.0
	var low:=0.0
	for i in frames.size():
		var x: Vector2=frames[i]
		total+=x.length_squared()*.5
		peak=maxf(peak,maxf(absf(x.x),absf(x.y)))
		if i>0 and i%12==0:low+=x.length_squared()*.5
	return {"rms_db":linear_to_db(sqrt(total/maxf(1,frames.size()))),"peak_db":linear_to_db(maxf(1e-9,peak)),"samples":frames.size()}
func measure(distance: float,kind: String) -> Dictionary:
	for v in audio.voices: v.stop()
	for v in audio.pressure_voices: v.stop()
	await create_timer(.2).timeout
	capture.clear_buffer()
	var event: String="qa:"+kind+":"+str(distance)
	var pos:=Vector3(2.,0.,-distance)
	var voice:=audio._start(event,pos,kind)
	if not is_instance_valid(voice): return {"error":"no voice"}
	var base_db:=voice.volume_db
	var unit_size:=voice.unit_size
	await create_timer(1.35).timeout
	var results:=pcm(capture.get_buffer(capture.get_frames_available()))
	results["voice_db"]=base_db
	results["unit"]=unit_size
	results["bus"]=voice.bus
	results["pressure"]=audio.pressure_started
	return results
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	scene=Node3D.new();root.add_child(scene)
	var cam:=Camera3D.new();scene.add_child(cam);cam.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	audio=GameExplosionAudio.new();scene.add_child(audio)
	await process_frame
	var master:=AudioServer.get_bus_index("Master")
	capture=AudioEffectCapture.new();capture.buffer_length=3.
	AudioServer.add_bus_effect(master,capture)
	var settings: Dictionary={}
	for bus in ["Master","Efeitos","Armas","CombatExplosions"]:
		var index:=AudioServer.get_bus_index(bus)
		settings[bus]={"volume_db":AudioServer.get_bus_volume_db(index),"mute":AudioServer.is_bus_mute(index)}
	print("PCM_BUS_LEVELS ",JSON.stringify(settings))
	for d in [10.,25.,50.,100.,250.,550.]:
		var v: Dictionary=await measure(d,"destroy")
		print("PCM_DISTANCE ",JSON.stringify({"distance":d,"kind":"destroy","result":v}))
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	scene.queue_free();await process_frame;quit(0)
