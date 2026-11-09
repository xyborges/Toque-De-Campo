extends SceneTree

# Real WarPlayer/WarHumanRig avatars, 28 bots, visual pose & attached hit regions.
# CPU microfixture; not a full authority/ENet/FPS game benchmark.
var errors: Array[String]=[]
var times: Array[float]=[]
var actors: Array[WarPlayer]=[]
var physical_checksum:=0.0
var max_grip_error:=0.0
var phase_count:=0

func _initialize() -> void:
	Engine.max_fps=0
	_run.call_deferred()

func _stats(v: Array[float]) -> Dictionary:
	var a:=v.duplicate()
	a.sort()
	var sum:=0.0
	for x in a: sum+=x
	return {"mean_ms":sum/a.size(),"p50_ms":a[int((a.size()-1)*.5)],
		"p95_ms":a[int((a.size()-1)*.95)],"p99_ms":a[int((a.size()-1)*.99)],
		"max_ms":a[-1],"count":a.size()}

func _run() -> void:
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	var first:=game.players[2] as WarPlayer
	actors.append(first)
	for i in 27:
		actors.append(game.make_actor(3+i,false,i%2,"soldier",Vector3(float(i%7)*5.,0,-22.-float(i/7)*6.)))
	for actor in actors:
		actor.set_meta("war_bot",true)
		actor.set_process(false);actor.set_physics_process(false)
		actor.owned=["fal","ak","g3","glock"]
		actor.loadout=actor.owned.duplicate()
		actor.weapon_id="fal"
		actor._refresh_weapon()
		actor._update_view()
		actor.hp=100;actor.deployed=true
	await process_frame
	await process_frame
	if actors.size()!=28: errors.append("not 28 actors")
	for step in 620:
		var t=float(step)*0.036
		for index in actors.size():
			var a:=actors[index]
			a.next_pose_usec=0
			a.pitch=0.21+0.32*sin(t+float(index)*.13) if index%3==2 else .14
			a.lean=0.32*sin(t*.4+index*.18) if index%3==2 else 0.
			a.locomotion.initialized=true
			a.locomotion.speed=2.8 if index%3==1 else 0.
			a.locomotion.moving=.9 if index%3==1 else 0.
			a.locomotion.phase=t*2. if index%3==1 else 0.
			a.locomotion.grounded=true
			a.locomotion.local_direction=Vector3(0,0,-1) if index%3==1 else Vector3.ZERO
			a.velocity=Vector3(0,0,-2.8) if index%3==1 else Vector3.ZERO
			a.fire_cooldown=.1 if index%3==2 and step%37<5 else 0.
		var begin:=Time.get_ticks_usec()
		for a in actors: a._animate_walk()
		if step>=20: times.append(float(Time.get_ticks_usec()-begin)*.001)
		if step%155==0 or step==619:
			for index in actors.size():
				var a:=actors[index]
				for side in ["L","R"]:
					var arm: Node3D=a.avatar_parts["arm_"+side.to_lower()]
					var err:=float(arm.get_meta("grip_error",0))
					max_grip_error=maxf(max_grip_error,err)
					if not is_finite(err) or err>.005: errors.append("grip error")
				for area_id in ["head","chest","armL","armR","forearmL","forearmR","legL","legR"]:
					var area: Area3D=a.hit_regions.get(area_id)
					if not is_instance_valid(area) or not area.global_position.is_finite():
						errors.append("invalid hit region: "+area_id)
						continue
					# Static bots provide deterministic geometric parity; moving
					# gait is time-based and cannot be compared between processes.
					if index%3==0:
						var pos: Vector3=a.to_local(area.global_position)
						physical_checksum+=pos.x*.37+pos.y*.11+pos.z*.43
					phase_count+=1
		await process_frame
	var data={"mode":"on" if GamePlayer.r01_bot_pose_dirty_guard else "off",
		"scope":"28 WarPlayer rig+weapon+grip+attached hit regions, forced pose 620 frames; not match FPS",
		"actors":actors.size(),"pose_calls":times.size()*actors.size(),
		"batch_ms":_stats(times),"static_hitbox_checksum":physical_checksum,
		"sampled_hit_regions":phase_count,"max_grip_error":max_grip_error,
		"errors":errors,"godot":Engine.get_version_info().string}
	print("R01_BOT_POSE_DIRTY ",JSON.stringify(data))
	game.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
