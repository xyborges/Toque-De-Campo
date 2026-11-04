extends SceneTree
# Regression test for the supplied v2 explosion recordings.
var failed: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failed.append(label)
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	for path in GameCombatAudioCatalog.EXPLOSIONS+GameCombatAudioCatalog.EXPLOSIONS_FAR:
		var stream:=GameCombatAudioCatalog.stream(path) as AudioStreamWAV
		check(stream!=null and stream.get_length()>1. and not stream.stereo, "supplied v2 mono explosion: "+path.get_file())
	var a:=GameExplosionAudio.new()
	var b:=GameExplosionAudio.new()
	scene.add_child(a);scene.add_child(b)
	await process_frame
	var first:=a._start("simultaneous:1",Vector3(-20,2,-20),"grenade")
	var second:=a._start("simultaneous:2",Vector3(20,2,-20),"tank")
	var remote:=b._start("simultaneous:1",Vector3(-20,2,-20),"grenade")
	check(is_instance_valid(first) and is_instance_valid(second) and first!=second, "overlapping explosion types have independent fixed 3D voices")
	check(first.stream==remote.stream and first.get_meta("variant")==remote.get_meta("variant"),"same event kind chooses matching client sound")
	check(first.global_position==Vector3(-20,2,-20) and second.global_position==Vector3(20,2,-20),"simultaneous explosions preserve world origins")
	var near_event:=a.play_event("dedup",Vector3(1,0,0),"drone")
	check(is_instance_valid(near_event) and a.play_event("dedup",Vector3(1,0,0),"drone")==null,"duplicate network explosion cannot play twice")
	check(a.play_event("invalid",Vector3(INF,0,0),"grenade")==null,"invalid coordinates are ignored")
	check(a.voices.size()==GameExplosionAudio.LIMIT and b.voices.size()==GameExplosionAudio.LIMIT,"explosion voice limit stays 24 per manager")
	check(AudioServer.get_bus_effect(AudioServer.get_bus_index(a.bus_name),0) is AudioEffectLimiter,"explosion mix remains peak limited")
	var cross:=a._start("cross",Vector3(0,0,-250),"drone")
	var cross_count:=0
	var weight:=0.
	for v in a.voices:
		if v.playing and str(v.get_meta("event_id",""))=="cross":
			cross_count+=1
			weight+=float(v.get_meta("mix_weight",0))
	check(is_instance_valid(cross) and cross_count==2 and absf(weight-1)<.001,"close and distant samples blend without doubling volume")
	print("SUPPLIED_AUDIO_V2 ",JSON.stringify({"checks":checks,"failures":failed}))
	scene.queue_free();await process_frame
	quit(0 if failed.is_empty() else 1)
