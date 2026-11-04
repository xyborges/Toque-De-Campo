extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func measure(capture: AudioEffectCapture,audio: GameWeaponAudio,point: Vector3) -> Vector2:
	for voice in audio.voices: voice.stop()
	await create_timer(.15).timeout;capture.clear_buffer()
	var voice:=audio._play_now(2,"fal",point)
	if not voice: return Vector2.ZERO
	await create_timer(.42).timeout
	var samples:=capture.get_buffer(capture.get_frames_available())
	var sum:=Vector2.ZERO
	for sample: Vector2 in samples: sum+=Vector2(sample.x*sample.x,sample.y*sample.y)
	return sum/maxi(1,samples.size())
func run() -> void:
	if DisplayServer.get_name()=="headless": print("requires native audio mixer");quit(1);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var capture:=AudioEffectCapture.new();capture.buffer_length=2.
	var master:=AudioServer.get_bus_index("Master");AudioServer.add_bus_effect(master,capture)
	var audio:=GameWeaponAudio.new();scene.add_child(audio)
	await create_timer(.3).timeout
	var left:=await measure(capture,audio,Vector3(-25,0,-3))
	var right:=await measure(capture,audio,Vector3(25,0,-3))
	listener.rotation.y=PI
	var turned:=await measure(capture,audio,Vector3(-25,0,-3))
	print("STEREO left=",left," right=",right," turned=",turned)
	check(left.x>left.y*2 and left.x>.00000001,"left shot is louder in left channel")
	check(right.y>right.x*2 and right.y>.00000001,"right shot is louder in right channel")
	check(turned.y>turned.x*2 and turned.y>.00000001,"turning listener reverses the stereo direction")
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	scene.queue_free();await process_frame
	var result: Dictionary={"checks":checks,"failures":failures,"left":str(left),"right":str(right),"turned":str(turned)}
	NavalStorage.write_json("res://tests/stereo194-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
