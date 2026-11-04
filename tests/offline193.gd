extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func block(at: Vector3,size: Vector3,angles:=Vector3.ZERO) -> StaticBody3D:
	var body:=StaticBody3D.new();body.position=at;body.rotation=angles
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;collision.shape=box;body.add_child(collision);game.world_root.add_child(body);return body
func member(id: int,team: int,local:=false) -> WarPlayer:
	var actor:=game._spawn_player(id,local,false,Vector3.ZERO) as WarPlayer
	game.members[id]={"team":team,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"respawn_pending":false,"shield":0.,"gadget":WarRules.launcher_for_team(team),"pending":{},"last_gadget":-100.}
	game._deploy(id,team,"soldier",WarRules.TEAM_RIFLES[team],WarRules.launcher_for_team(team),"base")
	actor.set_physics_process(false);game.members[id].shield=0;return actor
func run() -> void:
	game=load("res://tests/review192_game.gd").new();game.offline_operation=true;game.set_meta("test_mode",true);game.set_meta("war_test",true);game.set_meta("war_visual_preview",true);root.add_child(game)
	game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.join_ready=true;game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	var actor:=member(1,0,true);actor.position=Vector3(0,.04,0)
	var remote_actor:=member(2,0)
	check(remote_actor.weapon_id=="fal" and remote_actor.weapon_root.has_node("Imported_fal"),"authority builds the selected FAL for a nonlocal deployment")
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for v: WarVehicle in game.vehicle_system.vehicles.values(): v.position=Vector3(500,0,500);v.collision_layer=0
	await physics_frame;await physics_frame
	check(actor.set_posture(1),"crouch uses a real low capsule")
	for i in 35: actor.stance.advance(actor,1./60.);actor._animate_walk()
	check(actor.body_root.scale==Vector3.ONE and actor.stance.leg_parts.size()==2,"crouch bends two articulated knees without squashing the body")
	check(actor.camera_pivot.position.y<1.2 and actor.stance.leg_parts.L.knee.rotation.x< -1.5,"crouch lowers eye and bends knees forward")
	check(actor.to_local(actor.stance.leg_parts.L.knee.global_position).z<actor.avatar_parts.leg_l.position.z-.2 and actor.stance.leg_parts.L.shoe.global_position.y>.05 and actor.stance.leg_parts.L.shoe.global_position.y<.16,"crouch knees bend forward and boot rests at ground height")
	check(actor.set_posture(2),"prone changes the actual collision orientation")
	for i in 50: actor.stance.advance(actor,1./60.);actor._animate_walk()
	check(actor.prone and actor.camera_pivot.position.y<.52 and absf(actor.body_collision.rotation.x-PI*.5)<.01,"prone has low eye and a horizontal collision capsule")
	check(actor.camera_pivot.position.z<-.85,"prone eye advances with the head instead of remaining inside the hips")
	check(actor.hit_regions.shinL.global_position.y<.9 and actor.hit_regions.head.global_position.y<.9,"prone regions follow the low posed body")
	check(actor.to_local(actor.stance.leg_parts.L.shoe.global_position).z>actor.avatar_parts.leg_l.position.z+.5,"prone legs extend behind the pelvis instead of toward the head")
	check(absf(actor.stance.leg_parts.L.shoe.rotation.x)<.01,"prone boots follow their shin instead of standing upright")
	var muzzle:=actor.to_local(actor.get_muzzle_position())
	print("PRONE_MUZZLE ",muzzle)
	check(muzzle.y>.15 and muzzle.y<1.1 and muzzle.z<-.2,"prone muzzle remains in front of the low body")
	check(not actor.can_jump(),"prone cannot jump through its low posture")
	for i in 45:
		actor.velocity=Vector3(0,-9.81/60.,0);GameStepMotion.move(actor,1./60.);await physics_frame
	check(actor.is_on_floor() and actor.set_posture(0),"can stand after the prone capsule has physically settled on the floor")
	actor.set_posture(2)
	var ceiling:=block(Vector3(0,1.15,0),Vector3(4,.3,4));await physics_frame;await physics_frame
	check(not actor.set_posture(0) and actor.prone,"cannot stand through low concrete")
	ceiling.queue_free();await physics_frame;await physics_frame
	check(actor.set_posture(0),"can stand when clearance returns")
	actor.stance.reset(actor);actor._set_crouched(false)
	for i in 40: actor.stance.advance(actor,1./60.);actor._animate_walk()
	var nav:=WarBotTransit.new()
	for destination: Vector3 in [WarRules.OBJECTIVES.D.position,WarRules.OBJECTIVES.E.position,WarRules.OBJECTIVES.B.position]:
		check(nav.path(WarRules.BASES[0],destination).size()>5,"shared road graph reaches "+str(destination))
	for kind in ["tank","autocannon"]:
		var velocity:=Vector3(700,0,0);var point:=Vector3(0,100,0);var distance:=0.;var early:=0.;var late:=0.
		for tick in 150:
			var drag:=WarArmorBallistics.drag_for(kind,.035,distance,velocity.length())
			var next:=GameBulletPhysics.advance(point,velocity,17,drag,1./60.)
			distance+=point.distance_to(next.position);point=next.position;velocity=next.velocity
			if tick==3: early=velocity.x
			if tick==90: late=velocity.x
		check(early>690 and late<500 and late>150,kind+": fast near muzzle, progressive distance-dependent slowdown")
		# Compare at equal range: drag opposes falling too, so equal elapsed
		# time is not a valid measurement of drop per metre travelled.
		var old_point:=Vector3(0,100,0);var old_velocity:=Vector3(700,0,0)
		for tick in 600:
			var old_next:=GameBulletPhysics.advance(old_point,old_velocity,17,.035,1./120.)
			if old_next.position.x>=point.x:
				old_point=old_point.lerp(old_next.position,(point.x-old_point.x)/(old_next.position.x-old_point.x));break
			old_point=old_next.position;old_velocity=old_next.velocity
		print("DROP ",kind," range=",point.x," new=",100-point.y," old=",100-old_point.y)
		check(point.y<old_point.y-3,kind+": more accumulated gravity drop at the same range")
	# Real collision slopes: verify smooth progress without a stored upward
	# speed, then verify that a deliberate jump still leaves the ground.
	var slope:=block(Vector3(35,1.5,0),Vector3(30,.4,12),Vector3(0,0,.12))
	actor.position=Vector3(25,2,0);actor.velocity=Vector3.ZERO;await physics_frame;await physics_frame
	for i in 90: actor.velocity=Vector3(0,actor.velocity.y-9.81/60.,0);GameStepMotion.move(actor,1./60.);await physics_frame
	var positive:=0;var air:=0;var previous:=actor.position.y;var worst_delta:=0.
	for i in 180:
		actor.velocity=Vector3(3,actor.velocity.y-9.81/60.,0);GameStepMotion.move(actor,1./60.)
		if actor.velocity.y>.05: positive+=1
		if not actor.is_on_floor(): air+=1
		worst_delta=maxf(worst_delta,absf(actor.position.y-previous));previous=actor.position.y;await physics_frame
	check(positive==0 and air<4 and worst_delta<.035,"uphill traversal has stable floor contact and no alternating launch/snap")
	var y:=actor.position.y;actor.velocity=Vector3(0,4.4,0);GameStepMotion.move(actor,1./60.)
	check(actor.position.y>y+.04 and actor.velocity.y>4.,"slope fix preserves deliberate jumping")
	for step in 4: block(Vector3(65,.09*(step+1),-step*.6),Vector3(3,.18*(step+1),.6))
	block(Vector3(65,.36,-4),Vector3(3,.72,3.8))
	actor.position=Vector3(65,.05,1.2);actor.velocity=Vector3.ZERO
	await physics_frame;await physics_frame
	var extra_speed:=false
	for i in 150:
		var before:=actor.position
		actor.velocity=Vector3(0,-9.81/60.,-2.5);GameStepMotion.move(actor,1./60.)
		if absf(actor.position.z-before.z)>2.5/60.+.003: extra_speed=true
		if i%30==0: print("STAIR ",i," ",actor.position," floor=",actor.is_on_floor()," contact=",actor.get_slide_collision(0).get_normal() if actor.get_slide_collision_count()>0 else Vector3.ZERO)
		await physics_frame
	check(actor.position.z< -1.8 and actor.position.y>.6,"infantry climbs four actual 18 cm stair treads")
	check(not extra_speed,"stair helper adds no horizontal speed")
	block(Vector3(75,.4,0),Vector3(3,.8,1));actor.position=Vector3(75,.05,2);actor.velocity=Vector3.ZERO
	await physics_frame;await physics_frame
	for i in 100:
		actor.velocity=Vector3(0,-9.81/60.,-2.5);GameStepMotion.move(actor,1./60.);await physics_frame
	check(actor.position.z>.7,"step helper cannot climb a wall above its permitted height")
	actor.position=Vector3(0,.05,0);actor.velocity=Vector3.ZERO;actor.set_posture(2)
	for i in 60: actor.stance.advance(actor,1./60.);actor._animate_walk()
	var torso:=DeathRagdoll.create(game.world_root,actor,actor.position)
	var corpse:=torso.get_parent()
	check(corpse.has_node("ShinL") and corpse.has_node("ShinR") and corpse.has_node("ShoeL") and corpse.has_node("ShoeR"),"death preserves the articulated calves and both boots")
	var corpse_speed:=0.
	for i in 120:
		await physics_frame
		for body in corpse.get_children():
			if body is RigidBody3D: corpse_speed=maxf(corpse_speed,body.linear_velocity.length())
	check(corpse_speed<10,"prone ragdoll stays stable on death")
	actor.stance.reset(actor)
	check(actor.body_collision.shape.height==1.75 and actor.body_collision.position.y>.87 and actor.camera_pivot.position.z==0,"respawn/boarding reset restores the standing collision and eye")
	var map:=game.war_ui.minimap
	game.objective_states.A.side=0;game.objective_states.A.progress=.10;map.refresh()
	var territory:=map.territory_texture
	game.objective_states.A.progress=.80;map.refresh()
	check(map.territory_texture==territory,"capture percentages reuse identical territory pixels instead of uploading a new map")
	game.objective_states.A.owner=0;game.objective_states.A.progress=0;game.objective_states.A.side=-1;map.refresh()
	check(map.territory_texture!=territory,"territory texture still updates when sector ownership changes")
	NavalStorage.write_json("res://work/offline193-checks.json",{"checks":checks,"failures":failures,"uphill_air_ticks":air,"uphill_positive_velocity_ticks":positive,"max_uphill_delta":worst_delta})
	game.show_menu();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
