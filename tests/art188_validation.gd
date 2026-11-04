extends SceneTree
var checks:=0
var failures: Array[String]=[]
var game: WarGame
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/art188-"+id+".png")
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game)
	game.vehicle_system.set_process(false);game.third_person=true
	var actor:=game.local_player as WarPlayer
	for team in 2:
		actor.apply_identity(team,"soldier")
		for weapon in ["fal","glock"]:
			actor.weapon_id=weapon;actor._refresh_weapon()
			for pitch in [-.65,0.,.75]:
				actor.pitch=pitch;actor.camera_pivot.rotation.x=pitch;actor._update_weapon_pose();actor._animate_walk()
				var model:=actor.weapon_root.get_node("Imported_"+weapon) as Node3D
				check(actor.muzzle_marker.global_position.distance_to(model.get_node("Muzzle").global_position)<.001,"real muzzle: team %s %s pitch %.2f"%[team,weapon,pitch])
				for side in ["L","R"]:
					var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
					var hand:=arm.get_node("Hand"+side) as MeshInstance3D
					var marker:=model.get_node("GripRight" if side=="R" else "SupportGrip") as Node3D
					check(hand.global_position.distance_to(marker.global_position)<.002,"hand contact: %s %s pitch %.2f"%[weapon,side,pitch])
					check(arm.get_node("Forearm"+side+"Mesh").global_basis.is_finite(),"finite articulated forearm")
			actor.pitch=0;actor.camera_pivot.rotation.x=0;actor.aiming=true;actor.iron_sights=true;game.third_person=false;actor._update_view();actor._animate_walk()
			var copy:=actor.view_root.get_node("Imported_"+weapon) as Node3D
			for sight in (["RearAperture","FrontPost"] if weapon=="fal" else ["RearSight","FrontSight"]):
				var screen:=actor.camera.unproject_position(copy.get_node(sight).global_position)
				check(screen.distance_to(root.get_visible_rect().size*.5)<2.,weapon+" iron sight centred "+sight)
			if team==0:
				await capture(weapon+"-iron")
				actor.iron_sights=false;actor.aiming=false;actor._update_view();actor._update_weapon_pose();await capture(weapon+"-fpp")
			actor.iron_sights=false;actor.aiming=false;game.third_person=true;actor._update_view()
	var lower: MeshInstance3D=actor.avatar_parts.arm_r.get_node("ForearmRMesh")
	check(actor.hit_regions.forearmR.get_parent()==lower,"forearm hitbox follows its articulated mesh")
	var torso:=DeathRagdoll.create(game.world_root,actor,actor.global_position)
	var corpse:=torso.get_parent()
	check(corpse.has_node("ForearmL") and corpse.has_node("ForearmR"),"ragdoll keeps both new forearms")
	check(corpse.get_node("HandR").get_child(0).mesh==actor.avatar_parts.arm_r.get_node("HandR").mesh,"ragdoll preserves the actual held-hand geometry")
	corpse.queue_free()
	for id in WarPrefabFactory.ITEMS:
		var packed: PackedScene=load(WarPrefabFactory.PATH+id+".tscn")
		var visual:=packed.instantiate() as Node3D;game.world_root.add_child(visual);visual.position=Vector3(100+checks*15,0,100)
		var collisions:=visual.find_children("*","CollisionShape3D",true,false)
		check(not collisions.is_empty() or id=="cratera_impacto" and visual.has_meta("crater_depth"),id+" has ready collision or an authoritative terrain stamp")
		var server:=WarMapContent.instantiate(game.world_root,WarPrefabFactory.PATH+id+".tscn",visual.position,false)
		var server_collisions:=server.find_children("*","CollisionShape3D",true,false)
		check(collisions.size()==server_collisions.size() and server.find_children("*","MeshInstance3D",true,false).is_empty(),id+" retains identical server collision without drawing meshes")
		for i in collisions.size():
			check(collisions[i].global_transform.is_equal_approx(server_collisions[i].global_transform),id+" shared collision pose")
		check(visual.get_meta("asset_revision",0)==(190 if id in WarInfrastructureFactory.ITEMS or id in WarDevastationFactory.ITEMS else 188),id+" stores its authored revision")
		visual.queue_free();server.queue_free()
	var trench: Node3D=load(WarPrefabFactory.PATH+"trincheira_6m.tscn").instantiate();game.world_root.add_child(trench)
	check(trench.find_children("*","CollisionShape3D",true,false).size()==5,"detailed trench uses only five collision shapes")
	trench.queue_free()
	var stairs:=load(WarPrefabFactory.PATH+"escada_4m.tscn").instantiate() as Node3D;stairs.position=Vector3(100,0,0);game.world_root.add_child(stairs)
	var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(12,.4,12)
	var floor_body:=WarPrefabFactory.body(game.world_root,"TestFloor",floor_shape,Transform3D(Basis.IDENTITY,Vector3(100,-.2,0)),"concrete")
	var walker:=CharacterBody3D.new();walker.collision_layer=4;walker.collision_mask=1;walker.floor_snap_length=.25
	var capsule:=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.65
	var shape:=CollisionShape3D.new();shape.shape=capsule;shape.position.y=.84;walker.add_child(shape);game.world_root.add_child(walker);walker.position=Vector3(100,.02,2.8)
	await physics_frame
	var highest:=0.
	for frame in 210:
		walker.velocity=Vector3(0,-.2,-1.6);GameStepMotion.move(walker,1./60.);highest=maxf(highest,walker.position.y)
		await physics_frame
	check(highest>1.73 and walker.position.z<-1.3,"player capsule climbs the authored 18 cm stairs without jumping")
	stairs.queue_free();walker.queue_free();floor_body.queue_free()
	var vehicle: WarVehicle=game.vehicle_system.vehicles.v_guarani
	if vehicle.find_children("*","MeshInstance3D",true,false).is_empty(): vehicle.build_model()
	check(int(vehicle.get_meta("model_details").version)==3 and vehicle.wheels.size()==6,"Guarani revision 3 keeps six animated wheels")
	check(vehicle.elevation.get_meta("barrel_tip")==vehicle.muzzle.position,"Guarani model and physical barrel marker remain aligned")
	var layout:=load(WarMapContent.LAYOUT).instantiate() as Node3D;game.world_root.add_child(layout)
	check(layout.has_node("BaseOeste/AbrigoDeInstrucao") and layout.has_node("BaseLeste/AbrigoDeInstrucao"),"authored layout is instantiated in both bases")
	var packed_layout:=PackedScene.new();packed_layout.pack(layout)
	check(not packed_layout.get_state().get_node_count()>30,"runtime layout contains authored additions, not the editor reference world")
	layout.queue_free()
	game.show_menu();game.queue_free();await create_timer(.4).timeout
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/art188-validation-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
