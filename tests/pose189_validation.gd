extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var minimum_clearance:=INF
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)
func capture(label: String,camera: Camera3D,point: Vector3,target: Vector3) -> void:
	if DisplayServer.get_name()=="headless": return
	camera.position=point;camera.look_at(target);camera.make_current()
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/pose189-"+label+".png")
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game)
	game.vehicle_system.set_process(false);game.third_person=true
	var actor:=game.local_player as WarPlayer
	var observer:=Camera3D.new();observer.fov=54;game.world_root.add_child(observer)
	for weapon in ["fal","glock","ak","sniper"]:
		actor.weapon_id=weapon;actor._refresh_weapon()
		for lean_value in [-1.,0.,1.]:
			actor.lean=lean_value
			for angle in [-1.30,-.80,0.,.80,1.25]:
				actor.pitch=angle;actor.camera_pivot.rotation=Vector3(angle,0,-lean_value*GameInfantryPose.LEAN_ROLL)
				actor._animate_walk()
				var torso: Node3D=actor.avatar_parts.torso
				check(signf(torso.rotation.x)==signf(angle) or angle==0.,"chest follows pitch "+weapon)
				check(absf(actor.avatar_parts.head.rotation.x)>absf(torso.rotation.x) or angle==0.,"neck shares pitch "+weapon)
				check(actor.get_muzzle_position().is_finite(),"finite muzzle")
				check((-actor.weapon_root.global_basis.z).normalized().dot(actor.global_basis*Basis(Vector3.RIGHT,angle)*Vector3.FORWARD)>.9999,"lean does not steer the pitched barrel sideways")
				var pelvis:=actor.body_root.get_node("Pelvis") as Node3D
				var waist:=torso.to_global(Vector3(0,-.28,0))
				check(absf(pelvis.to_local(waist).x)<.10,"waist stays over pelvis")
				for leg_key in ["leg_l","leg_r"]:
					var leg: Node3D=actor.avatar_parts[leg_key]
					var foot:=actor.body_root.to_local(leg.to_global(Vector3(0,-.78,0)))
					var rest: Dictionary=actor.get_meta("upper_body_rest")
					check(absf(foot.x-Vector3(rest[leg_key]).x)<.004,"planted foot does not slide while leaning")
				for side in ["L","R"]:
					var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
					var upper:=arm.get_node("Arm"+side+"Mesh") as Node3D
					var lower:=arm.get_node("Forearm"+side+"Mesh") as Node3D
					check(float(arm.get_meta("grip_error",1.))<.002,"grip contact "+weapon+side)
					# Sample both articulated centre lines in the torso's own frame.
					for segment in [[arm.global_position,upper.to_global(Vector3(0,-WarHumanRig.UPPER*.5,0))],[lower.to_global(Vector3(0,WarHumanRig.LOWER*.5,0)),lower.to_global(Vector3(0,-WarHumanRig.LOWER*.5,0))]]:
						for step in range(1,10):
							var p:=torso.to_local(Vector3(segment[0]).lerp(segment[1],step/10.))
							if p.y<-.27 or p.y>.27: continue
							var ellipse:=pow(p.x/.245,2)+pow(p.z/.15,2)
							minimum_clearance=minf(minimum_clearance,ellipse)
							check(ellipse>=1.,"arm penetrates torso: %s %s pitch %.2f lean %.1f p %s"%[weapon,side,angle,lean_value,p])
				if weapon=="fal" and lean_value==0. and angle in [-1.30,0.,1.25]:
					await capture("fal-pitch-"+str(angle),observer,Vector3(-2.2,1.8,-2.3),Vector3(0,1.2,-.25))
				if weapon=="fal" and lean_value!=0. and angle==0.:
					await capture("lean-"+str(lean_value),observer,Vector3(.2,1.8,3.2),Vector3(0,1.2,-.25))
	actor.lean=0;actor.pitch=0;actor._animate_walk()
	actor.camera_pivot.rotation=Vector3.ZERO
	for weapon in ["fal","glock"]:
		actor.weapon_id=weapon;actor._refresh_weapon();actor.aiming=true;actor.iron_sights=true;game.third_person=false
		for amount in [-1.,0.,1.]:
			actor.lean=amount;actor.camera_pivot.position.x=amount*GameInfantryPose.LEAN_DISTANCE;actor.camera_pivot.rotation.z=-amount*GameInfantryPose.LEAN_ROLL
			actor._update_view();actor._animate_walk()
			var model:=actor.view_root.get_node("Imported_"+weapon) as Node3D
			for label in (["RearAperture","FrontPost"] if weapon=="fal" else ["RearSight","FrontSight"]):
				check(actor.camera.unproject_position(model.get_node(label).global_position).distance_to(root.get_visible_rect().size*.5)<2.,"lean keeps iron sight centered "+weapon)
	actor.aiming=false;actor.iron_sights=false;game.third_person=true;actor._update_view();GameInfantryPose.reset(actor)
	actor._set_hitboxes_enabled(true)
	for amount in [-1.,1.]:
		for angle in [-1.,0.,1.]:
			actor.lean=amount;actor.pitch=angle;actor._animate_walk()
			await physics_frame;await physics_frame
			var head_point: Vector3=actor.hit_regions.head.global_position
			var ray:=PhysicsRayQueryParameters3D.create(head_point+Vector3(0,0,-3),head_point,2)
			ray.collide_with_areas=true
			# Isolate the head for this attachment check. A raised forearm can
			# legitimately shield the face in a full unfiltered combat ray.
			var excluded: Array[RID]=[]
			for area: Area3D in actor.hit_regions.values():
				if area!=actor.hit_regions.head: excluded.append(area.get_rid())
			ray.exclude=excluded
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider.get_meta("hit_region","")=="head","physical headshot region follows aim and lean")
	actor.pitch=0;actor.lean=0;actor._animate_walk()
	actor.is_local=false;actor.network_lean=1.
	for frame in 40: GameInfantryPose.advance(actor,1./60.)
	check(actor.lean>.99,"replicated lean interpolates to right")
	var wall_shape:=BoxShape3D.new();wall_shape.size=Vector3(.15,3,3)
	var wall:=WarPrefabFactory.body(game.world_root,"LeanWall",wall_shape,Transform3D(Basis.IDENTITY,Vector3(.39,1,0)),"concrete")
	await physics_frame;await physics_frame
	GameInfantryPose.advance(actor,1./60.)
	check(actor.lean<.45,"head sweep immediately retracts before wall")
	check(actor.camera_pivot.position.x<.18,"camera remains this side of wall")
	wall.queue_free();actor.network_lean=0.
	for frame in 50: GameInfantryPose.advance(actor,1./60.)
	check(actor.lean<.001,"release returns to neutral")
	actor.hp=0;actor.lean=1;GameInfantryPose.advance(actor,1./60.);check(actor.lean==0.,"dead player cannot lean")
	actor.hp=100;actor.vehicle_id="v_guarani";actor.network_lean=1;GameInfantryPose.advance(actor,1./60.);check(actor.lean==0.,"vehicle occupant cannot lean")
	actor.vehicle_id="";actor.is_local=true;GameInfantryPose.reset(actor)
	check(InputMap.action_get_events("lean_left")[0].physical_keycode==KEY_Q and InputMap.action_get_events("lean_right")[0].physical_keycode==KEY_E,"Q/E input actions")
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	var result: Dictionary={"checks":checks,"failures":failures,"minimum_torso_ellipse":minimum_clearance}
	NavalStorage.write_json("res://tests/pose189-validation-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
