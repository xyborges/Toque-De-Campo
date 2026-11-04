extends SceneTree
func _initialize() -> void: run.call_deferred()
func analyze(buffer: PackedVector2Array) -> Dictionary:
	var power:=0.0
	var peak:=0.0
	for frame in buffer:
		power+=frame.length_squared()*.5
		peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	return {"rms_db":linear_to_db(sqrt(power/maxf(1,buffer.size()))),"peak_db":linear_to_db(maxf(1e-9,peak)),"frames":buffer.size()}
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var cam:=Camera3D.new();scene.add_child(cam);cam.current=true
	var ear:=AudioListener3D.new();scene.add_child(ear);ear.make_current()
	var audio:=GameExplosionAudio.new();scene.add_child(audio)
	await process_frame
	var index:=AudioServer.get_bus_index("Master")
	var capture:=AudioEffectCapture.new();capture.buffer_length=2.
	AudioServer.add_bus_effect(index,capture)
	for cap_db in [-3.,0.,3.,6.]:
		for v in audio.voices:
			v.stop()
			v.max_db=cap_db
		for v in audio.pressure_voices:
			v.stop()
			v.max_db=cap_db
		await create_timer(.2).timeout
		capture.clear_buffer()
		var v:=audio._start("ceiling:"+str(cap_db),Vector3(0,0,-50),"destroy")
		await create_timer(1.25).timeout
		var val:=analyze(capture.get_buffer(capture.get_frames_available()))
		val["max_db"]=v.max_db
		val["voice_db"]=v.volume_db
		print("CEILING_PCM ",JSON.stringify(val))
	AudioServer.remove_bus_effect(index,AudioServer.get_bus_effect_count(index)-1)
	scene.queue_free()
	await process_frame
	quit(0)
