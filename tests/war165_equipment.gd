extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/war165-"+label+".png")
func key(code: int) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	var release:=event.duplicate();release.pressed=false;Input.parse_input_event(release)
	Input.flush_buffered_events()
func right_click() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;Input.parse_input_event(event)
	var release:=event.duplicate();release.pressed=false;Input.parse_input_event(release)
	Input.flush_buffered_events()
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	game.combat_effects=WarEffects.new();game.world_root.add_child(game.combat_effects)
	var actor:=game.local_player as WarPlayer;var manager:=game.vehicle_system as WarVehicles
	manager.set_process(false);game.war_ui._process(.2)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for team in [0,1]:
		actor.apply_identity(team,"antitank");game.members[1].team=team
		game.members[2].team=1-team;game.players[2].apply_identity(1-team,"soldier")
		var weapon:=WarRules.launcher_for_team(team);var forbidden:="rpg" if weapon=="stinger" else "stinger"
		check(actor.active_weapons().has(weapon) and not actor.active_weapons().has(forbidden),"team %d grants exactly its launcher"%(team+1))
		actor.set_gadget(true,forbidden)
		check(actor.weapon_id!=forbidden,"local equip cannot display the other team's launcher")
		manager.command_for(1,"select",{"gadget":forbidden,"enabled":true})
		check(actor.weapon_id!=forbidden,"server rejects a forged opposite-team launcher command")
		actor.set_gadget(true,weapon);actor._animate_walk();game.third_person=true;actor._update_view()
		for index in game.combat_effects.slots.size():
			game.combat_effects.slots[index]={};game.combat_effects.pool.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
		check(actor.weapon_id==weapon and actor.launcher_model.get_meta("model_details").version==3,"team launcher uses the new photographic-reference model")
		check(int(actor.launcher_model.get_meta("model_details").parts)>35 and actor.launcher_model.get_child_count()<20,"detailed rigid meshes are batched while retaining markers")
		check(actor.launcher_model.get_node("GripLeft").global_position.distance_to(actor.avatar_parts.arm_l.get_node("HandL").global_position)<.15,"left hand remains on the new launcher grip")
		game.war_ui._refresh_equipment(game.infantry_hud);game.infantry_hud.refresh()
		check(game.infantry_hud.equipment_buttons[weapon].visible and not game.infantry_hud.equipment_buttons[forbidden].visible,"HUD exposes only this team's launcher")
		await capture(weapon+"-tpp")
		game.third_person=false;actor._update_view();await capture(weapon+"-fpp")
		var position:=actor.launcher_muzzle.global_position;var direction: Vector3=-actor.weapon_root.global_basis.z.normalized()
		var counter: int=game.war_fx.counter;game.war_clock+=10;game.members[1].last_gadget=-100.;game.members[1].charges=3;actor.recoil=0
		var drone: WarDrone
		if weapon=="stinger":
			drone=WarDrone.new();drone.drone_id="optic_target";drone.team=1;game.world_root.add_child(drone);drone.position=position+direction*50;drone.set_physics_process(false);manager.drones[drone.drone_id]=drone
			manager._update_gadgets(.1);manager._update_gadgets(1.4)
		manager.use_gadget(1)
		check(game.war_fx.counter==counter+1 and game.members[1].charges==2,"authority accepts one valid launcher shot and one charge")
		if game.war_fx.counter>counter:
			var shot: Dictionary=game.war_fx.rounds[game.war_fx.active_slots[-1]]
			check(Vector3(shot.position).distance_to(position)<.001 and Vector3(shot.velocity).normalized().dot(direction)>.9999,"recoil begins after the physical shot is created at the barrel")
		check(actor.recoil>=.09 and actor.launcher_recoil==1,"accepted launcher shot gives a strong camera and weapon kick")
		var old_recoil:=actor.recoil
		var id:=str(game.war_fx.rounds[game.war_fx.active_slots[-1]].shot_id)
		manager._present_shot(1,position,direction,weapon,id)
		check(actor.recoil==old_recoil,"duplicate event cannot add recoil twice")
		actor._update_weapon_pose();actor._animate_walk();await capture(weapon+"-recoil")
		if is_instance_valid(drone): manager.drones.erase(drone.drone_id);drone.queue_free()
		actor.set_gadget(false,weapon);actor.recoil=0;actor.launcher_recoil=0
	actor.apply_identity(0,"soldier");game.members[1].team=0;game.members[1].role="soldier"
	game.third_person=true;actor._update_view()
	var floor_body:=StaticBody3D.new();var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,.1,200);floor_shape.shape=box;floor_body.position.y=-.15;floor_body.add_child(floor_shape);game.world_root.add_child(floor_body)
	for kind in WarRules.VEHICLES:
		var vehicle:=manager.vehicles["v_"+str(kind)] as WarVehicle
		for index in game.combat_effects.slots.size():
			game.combat_effects.slots[index]={};game.combat_effects.pool.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
		vehicle.position=Vector3.ZERO;vehicle.collision_layer=1|16;vehicle.rotation=Vector3.ZERO;vehicle.heading=0;vehicle.turret_yaw=0;vehicle.gun_pitch=0;vehicle.turret.rotation=Vector3.ZERO;vehicle.elevation.rotation=Vector3.ZERO;vehicle.show()
		vehicle.allocate_seat(1);actor.vehicle_id=vehicle.vehicle_id;actor.apply_identity(vehicle.team,"soldier");game.members[1].team=vehicle.team;game.members[1].vehicle=vehicle.vehicle_id
		game.members[2].team=1-vehicle.team;game.players[2].apply_identity(1-vehicle.team,"soldier")
		manager.last_controlled="";manager._process(1./60.)
		check(manager.camera.current and not manager.vehicle_view.external and manager.camera.global_position.distance_to(vehicle.optic.global_position)<.001,"operator enters through its actual turret optic: "+str(kind))
		check(not game.infantry_hud.visible and not actor.body_root.visible and not actor.view_root.visible,"vehicle entry hides personal body, weapon and HUD: "+str(kind))
		key(KEY_C);await create_timer(.05).timeout;manager._process(.2)
		print("EXTERNAL_CAMERA ",kind,{"external":manager.vehicle_view.external,"distance":manager.camera.global_position.distance_to(vehicle.position),"position":manager.camera.position,"yaw":manager.orbit_yaw,"pitch":manager.orbit_pitch,"role":manager._local_is_operator(),"excluded":manager.owner_excludes(1).size()})
		check(manager.vehicle_view.external and manager.camera.global_position.distance_to(vehicle.position)>5,"C selects an external above/behind camera: "+str(kind))
		await capture(str(kind)+"-external")
		key(KEY_C);await create_timer(.05).timeout;manager._process(.2)
		var base_fov:=manager.camera.fov
		right_click();await process_frame;manager._process(.6)
		check(manager.vehicle_view.zoom_level==1 and manager.camera.fov<base_fov,"first right click selects persistent2x zoom: "+str(kind))
		right_click();await process_frame;manager._process(.6)
		check(manager.vehicle_view.zoom_level==2 and manager.camera.fov<25,"second right click selects4x: "+str(kind))
		right_click();await process_frame;manager._process(.6)
		check(manager.vehicle_view.zoom_level==0,"third right click returns to1x: "+str(kind))
		key(KEY_T);await process_frame
		check(manager.thermal,"T activates the operator's thermal system: "+str(kind))
		key(KEY_C);await process_frame;manager._process(.1)
		check(manager.vehicle_view.external and not manager.thermal,"switching to external camera disables thermal: "+str(kind))
		key(KEY_T);await process_frame
		check(not manager.thermal,"external camera cannot reactivate thermal: "+str(kind))
		key(KEY_C);await process_frame;manager._process(.1)
		var command_yaw:=manager.orbit_yaw;manager.look(Vector2(120,-35));manager._process(.1)
		var desired:=manager.aim_point
		for tick in 120: vehicle.aim(1./60.,desired)
		check(absf(vehicle.turret_yaw)>.1 and absf(vehicle.heading)<.001 and manager.orbit_yaw!=command_yaw,"mouse rotates the gun independently of the hull: "+str(kind))
		vehicle.heading=.5;vehicle.rotation.y=.5
		for tick in 120: vehicle.aim(1./60.,desired)
		check((-vehicle.muzzle.global_basis.z).dot((desired-vehicle.muzzle.global_position).normalized())>.995,"turret compensates hull rotation toward the same world target: "+str(kind))
		manager._process(.1);await capture(str(kind)+"-optic")
		vehicle.fire_wait=0;vehicle.reload_left=0
		var count: int=game.war_fx.counter;var rounds:=vehicle.ammo
		manager._fire_vehicle(vehicle)
		check(game.war_fx.counter==count+1 and vehicle.ammo==rounds-1,"valid vehicle shot consumes one round at the actual muzzle: "+str(kind))
		var barrier:=StaticBody3D.new();barrier.collision_layer=1;var shape:=CollisionShape3D.new();var size:=BoxShape3D.new();size.size=Vector3(.4,.4,.15);shape.shape=size;barrier.add_child(shape);game.world_root.add_child(barrier)
		barrier.global_transform=vehicle.elevation.global_transform;barrier.position=vehicle.elevation.global_position.lerp(vehicle.muzzle.global_position,.5)
		await physics_frame;await physics_frame
		vehicle.fire_wait=0;vehicle.reload_left=0;vehicle.ammo=maxi(1,vehicle.ammo);count=game.war_fx.counter;rounds=vehicle.ammo
		manager._fire_vehicle(vehicle)
		check(vehicle.gun_blocked and game.war_fx.counter==count and vehicle.ammo==rounds,"an obstacle between breech and muzzle prevents shooting through scenery: "+str(kind))
		barrier.queue_free();vehicle.clear_seats();vehicle.hide();vehicle.collision_layer=0;actor.vehicle_id="";game.members[1].vehicle=""
	# Passenger looking is local and must never write the operator's target.
	var carrier:=manager.vehicles.v_guarani as WarVehicle
	carrier.show();carrier.allocate_seat(2);carrier.allocate_seat(1)
	actor.vehicle_id=carrier.vehicle_id;game.members[1].vehicle=carrier.vehicle_id
	var authoritative_aim:=Vector3(50,4,-150);manager.aim_point=authoritative_aim;manager.last_controlled="";manager._process(.1)
	var prior_camera:=manager.camera.global_transform;var prior_turret:=carrier.turret_yaw
	manager.look(Vector2(200,20));manager._process(.1)
	check(manager.vehicle_view.external and not manager._local_is_operator(),"passenger receives an independent external camera")
	check(manager.aim_point==authoritative_aim and carrier.turret_yaw==prior_turret and not manager.camera.global_transform.is_equal_approx(prior_camera),"passenger can look around without steering the turret or its aim target")
	key(KEY_C);right_click();key(KEY_T)
	check(manager.vehicle_view.external and manager.vehicle_view.zoom_level==0 and not manager.thermal,"passenger cannot switch to gun optics, gun zoom or thermal")
	var obstruction:=StaticBody3D.new();obstruction.collision_layer=1
	var oc:=CollisionShape3D.new();var ob:=BoxShape3D.new();ob.size=Vector3(5,5,.25);oc.shape=ob;obstruction.add_child(oc);game.world_root.add_child(obstruction)
	var command_dir:=Basis.from_euler(Vector3(manager.orbit_pitch,manager.orbit_yaw,0))*Vector3.FORWARD
	obstruction.position=carrier.position+Vector3.UP*(float(carrier.spec.size.y)+1.2)-command_dir*2;obstruction.rotation.y=manager.orbit_yaw
	await physics_frame;await physics_frame;manager._process(.1)
	check(manager.vehicle_view.distance_now<3,"passenger/external sphere sweep retracts before a real wall")
	obstruction.queue_free();carrier.clear_seats();carrier.hide();carrier.collision_layer=0;actor.vehicle_id="";game.members[1].vehicle=""
	# Real rendering test: a thermal target remains occluded by an opaque wall.
	var thermal:=manager.get_node("Thermal") as WarThermal
	var hot:=MeshInstance3D.new();var hot_shape:=BoxMesh.new();hot_shape.size=Vector3(2,2,2);hot.mesh=hot_shape;game.world_root.add_child(hot);hot.position=Vector3(0,10,-8)
	var cover:=MeshInstance3D.new();var cover_shape:=BoxMesh.new();cover_shape.size=Vector3(4,4,.25);cover.mesh=cover_shape
	var dark:=StandardMaterial3D.new();dark.albedo_color=Color(.04,.04,.04);cover.material_override=dark;game.world_root.add_child(cover);cover.position=Vector3(0,10,-4)
	manager.camera.position=Vector3(0,10,5);manager.camera.look_at(Vector3(0,10,-8));manager.camera.fov=65;manager.camera.make_current();game.aim_dot.hide()
	thermal.set_enabled(true);thermal._register_mesh(hot,1.0)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var covered:=root.get_texture().get_image();var centre:=Vector2i(covered.get_size()/2);var covered_luma:=covered.get_pixelv(centre).get_luminance()
	covered.save_png("res://work/war166-thermal-covered.png")
	cover.hide()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var exposed:=root.get_texture().get_image();exposed.save_png("res://work/war166-thermal-exposed.png")
	var exposed_luma:=exposed.get_pixelv(centre).get_luminance()
	print("THERMAL_CONTRAST ",{"covered":covered_luma,"exposed":exposed_luma})
	check(exposed_luma>covered_luma+.3,"thermal heat is rendered behind depth-tested cover, never through the wall")
	thermal.set_enabled(false);hot.queue_free();cover.queue_free()
	if game.combat_effects.pool:
		var puffs:=0
		for entry: Dictionary in game.combat_effects.slots:
			if not entry.is_empty(): puffs+=1
		check(puffs>=3 and game.combat_effects.slots.size()==WarEffects.LIMIT,"vehicle and launcher smoke stays inside the fixed effect pool")
	game.show_menu();game.queue_free();await process_frame;await process_frame;await create_timer(.4).timeout
	var report: Dictionary={"checks":checks,"failures":failures,"native":DisplayServer.get_name()!="headless"}
	NavalStorage.write_json("res://tests/war165-equipment-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
