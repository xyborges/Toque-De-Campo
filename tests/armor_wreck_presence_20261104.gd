extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var audio:=GameExplosionAudio.new();scene.add_child(audio)
	var visuals:=WarEffects.new();scene.add_child(visuals)
	var wreck:=StaticBody3D.new();scene.add_child(wreck)
	wreck.collision_layer=1;wreck.global_position=Vector3(0,0,-50)
	var collision:=CollisionShape3D.new();wreck.add_child(collision)
	var shape:=SphereShape3D.new();shape.radius=3.5;collision.shape=shape
	await physics_frame
	await process_frame

	var hit:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3.ZERO,wreck.global_position,1))
	check(not hit.is_empty() and Vector3(hit.position).distance_to(wreck.global_position)>1,"source hull would have triggered previous blocked-muffle bug")
	check(GameExplosionAudio.contact_allowance("destroy")>=4,"destroyed vehicle collider is exempt near the source")
	check(is_equal_approx(GameExplosionAudio.near_presence_db("destroy",50.),GameExplosionAudio.HEAVY_NEAR_BOOST_DB),"50m receives full impact boost")
	check(GameExplosionAudio.near_presence_db("destroy",250.)<.01,"long-range mix is not overboosted")
	check(GameExplosionAudio.near_presence_db("grenade",50.)<GameExplosionAudio.near_presence_db("destroy",50.),"heavy explosions are stronger than grenades")

	var at:=wreck.global_position
	var voice:=audio._start("vehicle:destroy:50m",at,"destroy")
	check(is_instance_valid(voice) and voice.bus=="CombatExplosions","wreck does not block its own 50m explosion")
	check(voice.volume_db>=.75,"heavy close explosion receives measured near gain")
	check(voice.stream.resource_path==GameCombatAudioCatalog.EXPLOSIONS[1],"destruction plays the tank ammunition WAV, not a random grenade")
	var pressure:=false
	for other in audio.pressure_voices:
		if other.playing and str(other.get_meta("event_id",""))=="vehicle:destroy:50m":
			pressure=other.bus=="CombatExplosions" and other.volume_db>float(audio.event_profile("destroy").db)-5
	check(pressure,"pressure transient shares the nonmuffled location")

	visuals.explosion(at,9.,4221,"armor_wreck")
	var bright:=0
	var long_fire:=0
	for slot in visuals.slots:
		if slot.is_empty():continue
		if float(slot.total)>=1. and slot.color.r>.85 and slot.color.g>.2:long_fire+=1
		if slot.color.r>.95 and slot.color.g>.75:bright+=1
	check(long_fire>=9,"armored wreck gets a large fireball for more than one second")
	check(bright>=3,"bright flash is visually stronger than the old grey smoke")
	check(visuals.ring_events.size()==1,"50m armored wreck has visible shock ring")
	var before:=visuals.pool.visible_instance_count
	visuals._process(.3)
	check(visuals.pool.visible_instance_count>before,"new fireball is visible during the first second")
	var active:=0
	for item in visuals.slots:
		if not item.is_empty():active+=1
	check(active<WarEffects.LIMIT,"visual budget remains below 256 pooled effects for single wreck")
	print("ARMOR_WRECK_PRESENCE ",JSON.stringify({"checks":checks,"failures":failures,"bright":bright,"fireball":long_fire,"active_cards":active}))
	scene.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
