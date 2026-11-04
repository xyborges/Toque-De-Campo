extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func measure(capture: AudioEffectCapture,feedback: GameCombatFeedback,x: float,speed: float) -> Vector2:
	for voice in feedback.voices: voice.stop()
	await create_timer(.2).timeout;capture.clear_buffer()
	feedback.near_listener(Vector3(x,0,-8),Vector3(x,0,8),Vector3.ZERO,Vector3(0,0,speed),"sniper")
	await create_timer(.45).timeout
	var samples:=capture.get_buffer(capture.get_frames_available());var energy:=Vector2.ZERO
	for sample: Vector2 in samples: energy+=Vector2(sample.x*sample.x,sample.y*sample.y)
	return energy/maxi(1,samples.size())
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var capture:=AudioEffectCapture.new();capture.buffer_length=2.;var master:=AudioServer.get_bus_index("Master");AudioServer.add_bus_effect(master,capture)
	var feedback:=GameCombatFeedback.new();scene.add_child(feedback);await create_timer(.3).timeout
	var left:=await measure(capture,feedback,-2.,450.)
	var right:=await measure(capture,feedback,2.,450.)
	check(left.x>left.y*1.3 and left.x>.00000001,"supersonic near miss is audible on the left")
	check(right.y>right.x*1.3 and right.y>.00000001,"supersonic near miss is audible on the right")
	check(feedback.last_passage=="crack","supersonic passage uses crack")
	feedback.near_listener(Vector3(4,0,-8),Vector3(4,0,8),Vector3.ZERO,Vector3(0,0,100),"glock")
	check(feedback.last_passage=="near","slower passage uses near-miss sound")
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1);scene.queue_free();await process_frame
	print("AUDIO_NEAR ",left," ",right," ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
