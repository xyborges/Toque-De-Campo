extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize()->void: run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func run()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var grenades:=GameGrenades.new();scene.add_child(grenades);await process_frame
	grenades.set_process(false)
	grenades.guide=null # Disable aiming preview, test explosion visuals in isolation.
	grenades.present_explosion("qa:near",Vector3(0,0,-20))
	check(grenades.bursts.size()==10,"near grenade uses 10 bounded visual puffs")
	var initial_pos:=Vector3(grenades.bursts[1].node.global_position)
	var initial_size:=float(grenades.bursts[1].size)
	grenades._process(.14)
	check(grenades.bursts.size()==9,"short initial flash ends quickly")
	check(grenades.bursts[0].node.global_position.distance_to(initial_pos)>.01,"blast dust moves outward rather than sitting as a static sphere")
	check(float(grenades.bursts[0].node.scale.x)>initial_size,"dust cloud expands over time")
	grenades.present_explosion("qa:far",Vector3(0,0,-500))
	check(grenades.bursts.size()==13,"distant grenade adds four reduced-cost puffs")
	grenades._process(6.0)
	check(grenades.bursts.is_empty(),"all visual puffs expire and return to pool")
	check(grenades.effects_available.size()<=14 and grenades.effects_available.size()>=13,"grenade FX reuse previously pooled meshes without growing the allocation")
	print("GRENADE_VISUAL_RESUME ",JSON.stringify({"checks":checks,"failures":failures}))
	scene.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
