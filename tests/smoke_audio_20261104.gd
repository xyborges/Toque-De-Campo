extends SceneTree

var failures: Array[String]=[]
var count:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	count+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func run() -> void:
	check(GameSmokeAudio.START_VOICES==5,"Initial sound uses five pooled voices")
	check(GameSmokeAudio.LOOP_VOICES==4,"Hiss uses four pooled voices")
	check(GameSmokeAudio.loop_range("vehicle")>GameSmokeAudio.loop_range("hand"),"Tank hiss has longer audible radius")
	check(GameSmokeAudio.start_range("vehicle")>GameSmokeAudio.start_range("hand"),"Tank launch carries further than M18 start")
	for kind in ["vehicle","hand"]:
		var duration: float=GameSmokeClouds.VEHICLE_DURATION if kind=="vehicle" else GameSmokeClouds.HAND_DURATION
		check(GameSmokeAudio.loop_gain(kind,0.,duration,0.)==0.,"No premature hiss: "+kind)
		check(GameSmokeAudio.loop_gain(kind,GameSmokeAudio.loop_delay(kind)-.01,duration,0.)==0.,"Cue precedes hiss: "+kind)
		check(GameSmokeAudio.loop_gain(kind,12.,duration,0.)>.90,"Dense smoke keeps audible hiss: "+kind)
		check(GameSmokeAudio.loop_gain(kind,duration-1.,duration,0.)<.03,"Dissipation attenuates hiss: "+kind)
		check(GameSmokeAudio.loop_gain(kind,20.,duration,GameSmokeAudio.loop_range(kind)+1.)==0.,"Out-of-range emitter culled: "+kind)
		check(GameSmokeAudio.loop_gain(kind,20.,duration,30.)>0.,"Near emitter audible: "+kind)
	var files: Array[String]=[GameSmokeAudio.TANK_START,GameSmokeAudio.HAND_START,GameSmokeAudio.HISS_LOOP]
	for path in files:
		check(ResourceLoader.exists(path),"Imported original audio exists: "+path)
		var stream:=load(path) as AudioStreamMP3
		check(is_instance_valid(stream),"Original MP3 loads directly in Godot: "+path)
		if is_instance_valid(stream):
			check(stream.get_length()>2.5 and stream.get_length()<6.5,"Clip duration valid: "+path)
	var loop_stream: AudioStreamMP3=load(GameSmokeAudio.HISS_LOOP).duplicate() as AudioStreamMP3
	loop_stream.loop=true
	check(loop_stream.loop,"Hiss stream supports native looping")
	var clouds:=GameSmokeClouds.new()
	root.add_child(clouds)
	check(not is_instance_valid(clouds.smoke_audio),"Headless server does not instantiate audio playback")
	clouds.add_hand("test-hand",Vector3.ZERO)
	clouds.add_vehicle("test-armor",Vector3(10.,0.,0.),Vector3.FORWARD)
	check(clouds.clouds.size()==2,"Cloud events remain independent from audio engine")
	check(str(clouds.clouds["test-hand"].kind)=="hand" and str(clouds.clouds["test-armor"].kind)=="vehicle","Audio distinguishes event kind")
	clouds.clear_clouds()
	check(clouds.clouds.is_empty(),"Round cleanup clears events without sound")
	clouds.queue_free()
	await process_frame
	print("SMOKE_AUDIO_QA ",JSON.stringify({"checks":count,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
