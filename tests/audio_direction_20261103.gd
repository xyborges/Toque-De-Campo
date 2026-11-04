extends SceneTree

var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("Requires the native 3D audio mixer");quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var weapons:=GameWeaponAudio.new();scene.add_child(weapons)
	var feedback:=GameCombatFeedback.new();scene.add_child(feedback)
	await process_frame
	await create_timer(.2).timeout

	check(not GameWeaponAudio.source_behind(root,Vector3(0,1,-25)), "shot in front is not rear colored")
	check(GameWeaponAudio.source_behind(root,Vector3(0,1,25)), "shot behind selects rear cue")
	check(not GameWeaponAudio.source_behind(root,Vector3(1,2,0)), "close side source is not mislabeled")
	check(GameWeaponAudio.elevation_pitch(root,Vector3(0,20,-20))>1.02,"high shooter has a slight high tonal cue")
	check(GameWeaponAudio.elevation_pitch(root,Vector3(0,-20,-20))<.98,"low shooter has a slight low tonal cue")
	check(GameWeaponAudio.acoustic_bus(10.,false,false,true)=="WeaponRear","near rear has unique routing")
	check(GameWeaponAudio.acoustic_bus(300.,false,false,true)=="WeaponFarRear","far rear keeps distance EQ")
	check(GameWeaponAudio.acoustic_bus(300.,true,false,true)=="WeaponBlockedRear","occluded rear keeps occlusion EQ")
	check(AudioServer.get_bus_effect(AudioServer.get_bus_index("WeaponRear"),0) is AudioEffectLowPassFilter,"rear gun filter is shared")

	var front:=weapons._play_now(100,"fal",Vector3(-2,0,-30))
	var behind:=weapons._play_now(101,"fal",Vector3(2,0,30))
	check(is_instance_valid(front) and front.bus=="WeaponShots" and front.global_position.z==-30,"front muzzle retains real 3D position and shot bus")
	check(is_instance_valid(behind) and behind.bus=="WeaponRear" and behind.global_position.z==30,"rear muzzle retains real 3D position with rear EQ")

	var passed:=feedback.near_listener(Vector3(2,0,9),Vector3(2,0,-9),Vector3.ZERO,Vector3(0,0,-550),"fal")
	check(passed and feedback.last_passage=="crack","supersonic incoming bullet has a separate crack")
	check(feedback.last_approach_point.z>feedback.last_passage_point.z,"approach starts on the incoming side of the bullet")
	check(feedback.passage_pending.size()==1,"only one delayed crossing per bullet")
	var approach_ok:=false
	for voice in feedback.voices:
		if voice.playing and str(voice.get_meta("ballistic_phase",""))=="approach":
			approach_ok=voice.bus=="BallisticRear" and voice.global_position.z>0
	check(approach_ok,"approach is spatialized behind the player with distinct timbre")
	await create_timer(.15).timeout
	check(feedback.passage_events>0,"crossing crack plays after the approach")
	var peak_ok:=false
	for voice in feedback.voices:
		if voice.playing and str(voice.get_meta("ballistic_phase",""))=="passage":
			peak_ok=voice.global_position.distance_to(feedback.last_passage_point)<.001
	check(peak_ok,"crossing crack comes from the real closest-path point")
	feedback.play("metal",Vector3(0,0,8))
	var rear_impact:=false
	for voice in feedback.voices:
		if voice.playing and str(voice.get_meta("surface",""))=="metal":
			rear_impact=voice.bus=="ImpactRear"
	check(rear_impact,"rear material impact has its own 3D route")
	check(weapons.voices.size()==96 and feedback.voices.size()==12,"voice pools remain bounded")

	for voice in weapons.voices:voice.stop()
	for voice in feedback.voices:voice.stop()
	scene.queue_free()
	await process_frame
	print("AUDIO_DIRECTION ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
