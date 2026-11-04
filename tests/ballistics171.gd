extends SceneTree
var checks:=0
var failures: Array[String]=[]
var samples: Dictionary={}
var game: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func rms(data: PackedVector2Array) -> float:
	var power:=0.0
	for frame in data: power+=frame.length_squared()
	return sqrt(power/maxi(1,data.size()))
func dark_opacity(pool: MultiMesh) -> float:
	var peak:=0.0
	for i in pool.visible_instance_count:
		var color:=pool.get_instance_color(i)
		if color.r<.4: peak=maxf(peak,color.a)
	return peak
func run() -> void:
	check(is_equal_approx(GameWeapons.ITEMS.sniper.speed,620*.98),"sniper muzzle velocity is exactly two percent slower")
	check(GameTracerStyle.color_for("sniper").get_luminance()>Color("9d3cc3").get_luminance()*1.4 and GameTracerStyle.energy_for("sniper")>GameTracerStyle.ENERGY,"sniper has brighter daylight contrast without changing other weapon colors")
	check(GameDayNight.PERIOD==840 and WarDayNight.PERIOD==840 and absf(float(GameDayNight.sample(840).hour)-float(GameDayNight.sample(0).hour))<.001,"the shared full day/night cycle lasts fourteen minutes")
	for id in ["glock","fal","sniper","rpg","stinger"]:
		var item:=CombatRules.weapon(id);var initial:=Vector3(0,.15,-1).normalized()*float(item.speed)
		var whole:=GameBulletPhysics.advance(Vector3.ZERO,initial,item.gravity,item.drag,2)
		var point:=Vector3.ZERO;var velocity:=initial
		for tick in 240:
			var step:=GameBulletPhysics.advance(point,velocity,item.gravity,item.drag,1./120);point=step.position;velocity=step.velocity
		check(point.distance_to(whole.position)<.012 and velocity.distance_to(whole.velocity)<.012,id+" drag/gravity replay is independent of step size")
		check(Vector2(whole.velocity.x,whole.velocity.z).length()<Vector2(initial.x,initial.z).length(),id+" continuously loses horizontal speed without distance thresholds")
	for id in NavalCatalog.WEAPONS:
		var item: Dictionary=NavalCatalog.WEAPONS[id];var origin:=Vector3(90,3,-40);var hull:=Vector3(7,0,-12)
		var initial:=NavalBallistics.velocity(Vector3(.4,.03,-1),id,hull)
		var state:=GameBulletPhysics.advance(origin,initial,item.gravity,NavalBallistics.drag_for(id),2)
		var point:=NavalBallistics.position(origin,initial,item.gravity,2,id,10)
		if id=="torpedo": state.position.y=point.y
		check(point.distance_to(state.position)<.001 and NavalBallistics.instantaneous_velocity(initial,item.gravity,2,id).distance_to(state.velocity)<.001,id+" guide and simulation include the same drag and hull velocity on both axes")
		var target:=Vector3(250,0,-380)
		if id=="torpedo": target.y=origin.y
		var solution:=NavalBallistics.solve(origin,target,id,hull)
		point=NavalBallistics.position(origin,NavalBallistics.velocity(solution.direction,id,hull),item.gravity,solution.time,id,0)
		if id=="torpedo": point.y=target.y
		check(solution.valid and point.distance_to(target)<.03,id+" turret solution still reaches its intended target with drag")
	for distance in [100.,300.,500.,1000.]: check(absf(GameSoundPropagation.delay(distance)-distance/343)<.00001,"sound delay follows343m/s at"+str(distance)+"m")
	game=load("res://tests/ballistics171_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game);game.mode="training";game.map_kind="desert";game._enter_match_world();game.set_physics_process(false)
	var actor:=game._spawn_player(1,true,false,Vector3(4,12,-1000)) as GamePlayer;actor.set_physics_process(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=false;actor._update_view()
	var source:=Vector3(0,30,0)
	game._static_box(game.world_root,"Target",Vector3(0,13,-1000),Vector3(1,12,.2),Color.GRAY)
	await physics_frame;await physics_frame;await create_timer(.3).timeout
	var audio:=game.weapon_audio as GameWeaponAudio
	var capture:=AudioEffectCapture.new();capture.buffer_length=4;var bus:=AudioServer.get_bus_index("WeaponShots");AudioServer.add_bus_effect(bus,capture)
	var nodes:=get_node_count();var begin:=Time.get_ticks_msec()*.001
	audio.play(2,"sniper",source);game._spawn_projectile(2,source,Vector3.FORWARD,"sniper",false,true,"range171")
	var first_hit:=-1.0;var first_sound:=-1.0;var hit_before_sound:=false
	while Time.get_ticks_msec()*.001-begin<3.5:
		await physics_frame;game._step_projectiles(1./60)
		if game.impact_time>0 and first_hit<0: first_hit=game.impact_time-begin;hit_before_sound=audio.started_events==0
		if audio.started_events>0 and first_sound<0: first_sound=Time.get_ticks_msec()*.001-begin
	samples.flight=first_hit;samples.gun_sound=first_sound;samples.actual_impact=game.impact_position
	check(first_hit>1.5 and first_hit<1.9 and hit_before_sound,"real swept1000m sniper projectile reaches its target before the distant gun sound")
	check(first_sound>2.8 and first_sound<3.15,"the actual pooled gun voice starts after acoustic propagation")
	var mix_level:=rms(capture.get_buffer(capture.get_frames_available()));samples.distant_rms=mix_level
	check(mix_level>.000001,"the native audio mixer contains the distant filtered sniper recording")
	check(game.combat_feedback.last_passage=="crack","actual supersonic passage selects its separate crack sample")
	var old:=GameWeaponAudio.listener_position(root);game.third_person=true;actor._update_view()
	check(GameWeaponAudio.listener_position(root).distance_to(old)<.001,"FPP and TPP share the same physical listener")
	for voice in audio.voices: voice.stop()
	audio.propagation.clear();var before:=audio.started_events
	for i in 600: audio.play(500+i,"fal",old+Vector3(0,0,-1000))
	check(audio.propagation.pending.size()<=GameSoundPropagation.LIMIT and audio.propagation.dropped>0,"distant automatic bursts have a bounded prioritized queue")
	check(audio.voices.size()==96 and get_node_count()<=nodes+2,"automatic fire allocates no new audio player per shot")
	audio.play(4,"fal",old+Vector3(0,0,-1));check(audio.started_events>before,"nearby fire remains audible while the far queue is saturated")
	audio.propagation.clear()
	var effects:=WarEffects.new();game.world_root.add_child(effects);effects.set_process(false);effects.explosion(old+Vector3(0,0,-12),4,171)
	effects._process(.04);var early:=dark_opacity(effects.pool);effects._process(.65);var peak:=dark_opacity(effects.pool)
	check(early<.02 and peak>.2,"real heavy-impact smoke grows from transparent instead of appearing all at once")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/ballistics171-smoke.png")
	effects._process(4.5);check(dark_opacity(effects.pool)<peak*.6,"heavy smoke dissipates smoothly over a longer release")
	var kit:=EnvironmentKit.new(game.world_root,true);kit.box("MetalPanel",old+Vector3(-5,0,-8),Vector3(2,4,.5),"steel",true);kit.box("WoodPanel",old+Vector3(5,0,-8),Vector3(2,4,.5),"wood",true)
	await physics_frame;await physics_frame
	for entry in [[-5.,"metal"],[5.,"wood"]]:
		var query:=PhysicsRayQueryParameters3D.create(old+Vector3(entry[0],0,0),old+Vector3(entry[0],0,-12),1)
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and GameImpactSurface.detect(hit,"desert")==entry[1],str(entry[1])+" impact comes from the actual batched collision shape material")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	audio.play(22,"sniper",old+Vector3(0,0,-900));check(not audio.propagation.pending.is_empty(),"a far shot is pending before exit")
	game.show_menu();check(audio.propagation.pending.is_empty(),"leaving the match cancels queued sounds")
	game.queue_free();await process_frame
	var result:={"checks":checks,"failures":failures,"samples":samples};NavalStorage.write_json("res://tests/ballistics171-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
