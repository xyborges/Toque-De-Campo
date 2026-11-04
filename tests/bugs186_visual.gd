extends SceneTree
var checks:=0
var failures: Array[String]=[]
var game: WarGame
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(name_value: String) -> void:
	await process_frame
	# A user may minimize the QA window while continuing to use the PC.
	# Request a frame explicitly instead of waiting forever for presentation.
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/bugs186-"+name_value+".png")
func run() -> void:
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	while not game.join_ready: await process_frame
	game.war_ui.refresh_spawns()
	check(game.war_ui.spawn_select.item_count==1 and str(game.war_ui.spawn_select.get_item_metadata(0))=="base","deployment initially offers only the base")
	check(not game._valid_deployment_spawn(0,"rally") and not game._valid_deployment_spawn(0,"D"),"authority rejects a free frontline spawn and neutral ports")
	game.objective_states.D.owner=0;game.war_ui.refresh_spawns()
	check(game.war_ui.spawn_select.item_count==2 and game._valid_deployment_spawn(0,"D"),"captured sector becomes a selectable spawn")
	game.war_ui.spawn_select.select(1);game.war_ui.refresh_spawns()
	check(str(game.war_ui.spawn_select.get_item_metadata(game.war_ui.spawn_select.selected))=="D","spawn refresh preserves the selected sector by ID")
	game.objective_states.D.owner=-1;game.war_ui.refresh_spawns()
	check(game.war_ui.spawn_select.item_count==1 and game.war_ui.spawn_select.selected==0,"losing the sector safely falls back to base")
	game.request_deploy(0,"soldier","fal","stinger","base");await create_timer(.2).timeout
	game.bot_director.set_physics_process(false)
	for other in game.players.values(): other.set_physics_process(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var actor:=game.local_player as WarPlayer
	check(WarRules.BASES[0].distance_to(WarRules.BASES[1])>2300 and actor.position.distance_to(WarRules.BASES[0])<30,"bases are separated by more than 2.3 km and deployment uses the new location")
	check(actor.move_speed==4.8,"War walk speed is reduced from 6.2 to 4.8 m/s")
	# Even if an inherited scene transition temporarily says desert, it may
	# not apply the small desert arena's limits to a War character.
	var old_kind:=game.map_kind;game.map_kind="desert";actor._physics_process(.016);game.map_kind=old_kind
	check(absf(actor.position.x)>1000,"War movement cannot inherit the 149 m desert boundary")
	var camera:=Camera3D.new();game.world_root.add_child(camera);camera.global_position=actor.position+Vector3(2,2,2);camera.look_at(actor.position+Vector3.UP);camera.current=true
	var thermal:=game.vehicle_system.get_node("Thermal") as WarThermal
	thermal.set_enabled(true);var source: Material=actor.avatar_parts.torso.get_meta("thermal_source").get("material")
	var torso:=DeathRagdoll.create(game.world_root,actor,actor.position) as RigidBody3D
	var skin:=torso.get_child(0) as MeshInstance3D
	check(skin.material_override is StandardMaterial3D and skin.material_override.albedo_texture==source.albedo_texture,"ragdoll created under thermal retains its real uniform texture")
	thermal.set_enabled(false)
	check(actor.avatar_parts.torso.material_override==source,"thermal exit restores the living character material")
	game.members[1].shield=0;var life:=actor.life_id;var died:=Time.get_ticks_msec();actor.take_damage(1000,"chest",1)
	check(game.members[1].respawn_pending,"death schedules its next life before visual effects")
	await create_timer(8.6).timeout
	check(actor.hp==100 and actor.life_id==life+1 and actor.position.distance_to(WarRules.BASES[0])<30,"offline regression respawns once after eight seconds at the selected base")
	print("VISUAL_RESPAWN_SECONDS ",(Time.get_ticks_msec()-died)*.001)
	var vehicle:=game.vehicle_system.vehicles.v_guarani as WarVehicle
	camera.global_position=vehicle.position+Vector3(9,5,9);camera.look_at(vehicle.position+Vector3.UP);camera.make_current()
	game.vehicle_system.damage_from_hit(1,vehicle,10000,"rpg",Vector3.LEFT);vehicle.update_wreck(.2)
	check(vehicle.visible and vehicle.destroyed and vehicle.wreck_visible,"APC destruction keeps a visible burned wreck")
	await capture("apc-wreck")
	vehicle.respawn_left=.01;game.vehicle_system._step_vehicle_respawns(.02)
	check(not vehicle.destroyed and vehicle.visible and not vehicle.wreck_visible,"vehicle restores its normal model at the end of the one-minute respawn system")
	var pole:=game.power_grid.poles.port_1_1 as WarPowerPole
	camera.global_position=pole.position+Vector3(3,3,6);camera.look_at(pole.position+Vector3.UP*3);camera.make_current()
	await physics_frame
	var ray:=PhysicsRayQueryParameters3D.create(pole.position+Vector3(1,2,0),pole.position+Vector3(-1,2,0),1)
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(hit.get("collider")==pole and GameImpactSurface.detect(hit,"war")=="metal","physical pole collision is classified as metallic")
	var sparks:=game.metal_sparks.cursor
	game._confirm_impact(1,hit,CombatRules.weapon("glock"),"pole:186",Vector3.LEFT)
	check(game.metal_sparks.cursor!=sparks and pole.hp==90,"hitting the pole emits existing metal sparks and applies damage")
	await capture("pole-sparks")
	game.war_fx.set_physics_process(false)
	for weapon in ["fal","glock"]:
		var origin:=Vector3(80,90,0);camera.global_position=origin+Vector3(8,0,4);camera.look_at(origin+Vector3(0,0,-30));camera.current=true
		game.war_fx.spawn(1,origin,Vector3.FORWARD,weapon,false,weapon+":2",{"range":300.})
		# Inspect a known physical instant; shader compilation or a minimized
		# window must not advance the shot past its lifetime before inspection.
		for i in 6: game.war_fx._physics_process(1./60)
		var shot: Dictionary=game.war_fx.find_round(weapon+":2")
		check(not shot.is_empty() and shot.tracer and game.war_fx.cores.get_instance_transform(game.war_fx.by_id[weapon+":2"]).basis.get_scale().length()>0,weapon+" projectile and visible tracer share the same pooled shot")
		check(GameTracerStyle.infantry_radius(camera,shot.position)>=.035,weapon+" tracer keeps a minimum visible thickness")
		await capture(weapon+"-tracer")
	actor.weapon_id="fal";actor._refresh_weapon();actor.aiming=true;actor.iron_sights=true;game.third_person=false;actor.camera.current=true;actor._update_view();actor._animate_walk()
	check(actor.view_root.has_node("Imported_fal") and not actor.view_root.has_node("Imported_ak"),"respawn and same-ID rebuild refresh the matching FAL first-person model")
	for marker in ["RearAperture","FrontPost"]:
		var sight: Node3D=actor.view_root.get_node("Imported_fal/"+marker)
		check(actor.camera.unproject_position(sight.global_position).distance_to(root.get_visible_rect().size*.5)<2,"War iron sight aligns after respawn: "+marker)
	var armor_hp:=vehicle.hp;var operation:=game.operation_sequence
	var old_feedback: Dictionary=game.vehicle_system.last_damage_confirmation.duplicate()
	for weapon in ["glock","fal","ak","sniper","broom","hmg","future_rifle"]:
		check(game.vehicle_system.damage_from_hit(1,vehicle,1000,weapon,Vector3.LEFT) and vehicle.hp==armor_hp and game.operation_sequence==operation and game.vehicle_system.last_damage_confirmation==old_feedback,weapon+" cannot damage armor or emit damage feedback")
	check(game.vehicle_system.damage_from_hit(1,vehicle,100,"rpg",Vector3.LEFT) and vehicle.hp<armor_hp,"RPG still damages armor")
	await capture("fal-iron")
	NavalStorage.write_json("res://tests/bugs186-visual-results.json",{"checks":checks,"failures":failures});print(JSON.stringify({"checks":checks,"failures":failures}))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
