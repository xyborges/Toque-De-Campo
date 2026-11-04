extends SceneTree

var failures: Array[String]=[]
var checks:=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func effects(bus: String) -> Dictionary:
	var index:=AudioServer.get_bus_index(bus)
	if index<0: return {}
	var result: Dictionary={}
	for i in AudioServer.get_bus_effect_count(index):
		var effect:=AudioServer.get_bus_effect(index,i)
		if effect is AudioEffectLowPassFilter: result["cutoff"]=effect.cutoff_hz
		elif effect is AudioEffectReverb:
			result["wet"]=effect.wet
			result["dry"]=effect.dry
	return result

func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("Native 3D mix required")
		quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var guns:=GameWeaponAudio.new();scene.add_child(guns)
	var blasts:=GameExplosionAudio.new();scene.add_child(blasts)
	await process_frame
	var mid:=effects("WeaponMid")
	var far:=effects("WeaponFar")
	var blocked:=effects("WeaponBlocked")
	var interior:=effects("WeaponInterior")
	var rear_far:=effects("WeaponFarRear")
	var explosion_far:=effects("CombatExplosionsFar")
	var explosion_blocked:=effects("CombatExplosionsBlocked")
	check(float(mid.get("wet",1.))==0., "outside middle range has no room echo")
	check(float(far.get("wet",1.))<=.015 and float(far.get("dry",0.))==1.,"distant exterior gun remains almost dry")
	check(float(far.get("cutoff",0.))==3300., "exterior shot loses less high frequency abruptly")
	check(float(blocked.get("wet",1.))==0., "occlusion muffles without inventing a room")
	check(float(interior.get("wet",0.))>=.09,"indoor gun continues to reflect")
	check(float(rear_far.get("wet",1.))<=.015, "rear exterior avoids artificial room tone")
	check(float(explosion_far.get("cutoff",0.))==5500., "distant outdoor WAV keeps detail without aggressive re-filtering")
	check(not explosion_far.has("wet"),"outdoor explosion plays its recorded natural tail with no room reverb")
	check(not explosion_blocked.has("wet"),"blocked blast is muffled without artificial room reverb")
	check(guns.voices.size()==96 and blasts.voices.size()==24,"voice budget unchanged")
	var near_voice:=guns._play_now(12,"fal",Vector3(2,0,-10))
	check(is_instance_valid(near_voice) and near_voice.bus=="WeaponShots", "close gun uses unfiltered attack")
	var distant:=guns._play_now(13,"fal",Vector3(2,0,-350))
	check(is_instance_valid(distant) and distant.bus=="WeaponFar","far gun still spatial and attenuated")
	print("AUDIO_OPEN_AIR ",JSON.stringify({"checks":checks,"failures":failures,"far":far,"explosion":explosion_far}))
	scene.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
