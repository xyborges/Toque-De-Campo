extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)
func run() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	for id in WarDevastationFactory.ITEMS:
		var visual:=WarMapContent.instantiate(scene,WarPrefabFactory.PATH+id+".tscn",Vector3(100,20,0),true)
		var server:=WarMapContent.instantiate(scene,WarPrefabFactory.PATH+id+".tscn",visual.position,false)
		var first:=visual.find_children("*","CollisionShape3D",true,false);var second:=server.find_children("*","CollisionShape3D",true,false)
		check((not first.is_empty() or id=="cratera_impacto") and first.size()==second.size(),id+" keeps its collision on the authority")
		for i in first.size(): check(first[i].global_transform.is_equal_approx(second[i].global_transform),id+" same collider pose")
		check(server.find_children("*","GeometryInstance3D",true,false).is_empty(),id+" dedicated server has no render nodes")
		visual.free();server.free()
	var a:=WarMapContent.instantiate(scene,WarPrefabFactory.PATH+"carga_portuaria.tscn",Vector3.ZERO,true)
	var b:=WarMapContent.instantiate(scene,WarPrefabFactory.PATH+"carga_portuaria.tscn",Vector3(4,0,0),true)
	var before:=scene.find_children("*","CollisionShape3D",true,false).size()
	WarSceneryBatch.build(scene)
	check(scene.get_meta("scenery_draws_saved",0)>0,"repeated objects reduce draw submissions")
	check(scene.find_children("*","CollisionShape3D",true,false).size()==before,"render instancing keeps every physical collider")
	check(not scene.find_children("*","MultiMeshInstance3D",true,false).is_empty(),"static geometry uses shared multimeshes")
	a.free();b.free();scene.free()
	WarTerrainEdits.configure([])
	var ground:=WarTerrain.height_at(350,350)
	var crater:=load(WarPrefabFactory.PATH+"cratera_impacto.tscn").instantiate() as Node3D;crater.position=Vector3(350,ground,350)
	WarTerrainEdits.configure(WarTerrainEdits.collect(crater,Transform3D.IDENTITY,[]));crater.free()
	check(absf(WarTerrain.height_at(350,350)-(ground-.65))<.01,"impact crater actually lowers the ground")
	var patch:=Node3D.new();root.add_child(patch);var tiles: Array[Vector2i]=[]
	for tile: Vector2i in WarTerrainEdits.active_tiles: tiles.append(tile)
	WarTerrain.build(patch,false,tiles);await physics_frame;await physics_frame
	for x in [0.,1.5,3.]:
		var query:=PhysicsRayQueryParameters3D.create(Vector3(350+x,ground+3,350),Vector3(350+x,ground-3,350),1)
		var hit:=patch.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(float(hit.position.y)-WarTerrain.height_at(350+x,350))<.015,"crater physics matches its displayed terrain floor and rim")
	patch.queue_free();await process_frame
	WarTerrainEdits.prepared=false;WarTerrainEdits.prepare()
	for id in ["glock","ak","fal","sniper"]:
		var spec:=CombatRules.weapon(id);var initial:=Vector3(0,0,-float(spec.speed))
		var one:=GameBulletPhysics.advance(Vector3.ZERO,initial,float(spec.gravity),float(spec.drag),1.)
		var p:=Vector3.ZERO;var v:=initial
		for i in 120:
			var state:=GameBulletPhysics.advance(p,v,float(spec.gravity),float(spec.drag),1./120.);p=state.position;v=state.velocity
		check(p.distance_to(one.position)<.012 and v.distance_to(one.velocity)<.012,id+" drag is identical at different simulation steps")
		check(absf(v.z)<absf(initial.z) and absf(v.z)>absf(initial.z)*.7,id+" starts fast and decelerates progressively")
		if id in ["ak","fal"]:
			var near:=GameBulletPhysics.advance(Vector3.ZERO,initial,spec.gravity,spec.drag,.15)
			check(absf(near.position.z)>100,id+" reaches one hundred metres in less than 150 ms")
	for id in ["guarani","bmp2","abrams","t90"]:
		var spec: Dictionary=WarRules.VEHICLES[id]
		check(float(spec.speed_shot)>=680 and float(spec.get("drag",0))>0,id+" uses fast muzzle velocity and air resistance")
		check(float(spec.blast)>=(3.6 if id in ["guarani","bmp2"] else 13.5),id+" has an expanded authoritative blast radius")
	var feedback:=GameCombatFeedback.new();root.add_child(feedback)
	check(feedback.near_listener(Vector3(-12,1.6,2),Vector3(12,1.6,2),Vector3(0,1.6,0),Vector3(800,0,0),"fal") and feedback.last_passage=="crack","fast swept bullet passage triggers a supersonic crack")
	check(not feedback.near_listener(Vector3(-12,1.6,20),Vector3(12,1.6,20),Vector3(0,1.6,0),Vector3(800,0,0),"fal"),"distant rounds do not create false near-miss sounds")
	for kind in ["near","crack","vehicle"]:
		var path: String=GameCombatFeedback.PATHS.near if kind=="near" else "res://audio/ballistics/"+kind+".wav"
		check(ResourceLoader.exists(path) and load(path).get_length()>.02,kind+" audio asset is present and nonempty")
	feedback.free()
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game);game.vehicle_system.set_process(false)
	var manager:=game.vehicle_system;var vehicle:=manager.vehicles.v_guarani as WarVehicle
	game.local_player.position=vehicle.position+Vector3(3,0,0)
	manager.command_for(1,"enter",{"id":vehicle.vehicle_id})
	manager._process(.016)
	check(vehicle.driver==1,"operator boards the armored vehicle")
	var hp:=vehicle.hp;manager.damage_from_hit(2,vehicle,120,"rpg",Vector3.FORWARD)
	check(vehicle.hp<hp and manager.hull_shock>0,"validated missile damage produces occupant camera shock")
	var orbit:=Vector2(manager.orbit_yaw,manager.orbit_pitch);manager._process(.016)
	check(Vector2(manager.orbit_yaw,manager.orbit_pitch)==orbit,"impact shake does not change turret input or aiming direction")
	var operator:=game.local_player as WarPlayer;var passenger:=game.players[2] as WarPlayer
	passenger.apply_identity(0,"soldier");game.members[2].team=0;passenger.position=vehicle.position+Vector3(-3,0,0)
	manager.command_for(2,"enter",{"id":vehicle.vehicle_id})
	check(vehicle.seat_of(2)>0 and vehicle.driver==1,"a second occupant stays a passenger")
	game.local_player=passenger;manager._process(.016);manager.hull_shock=0
	manager.damage_from_hit(3,vehicle,90,"rpg",Vector3.FORWARD)
	check(manager.hull_shock>0,"passengers receive the same authoritative hull shock")
	game.local_player=operator
	var effects:=WarEffects.new();game.world_root.add_child(effects)
	if effects.pool==null:
		effects.pool=MultiMesh.new();effects.pool.transform_format=MultiMesh.TRANSFORM_3D;effects.pool.use_colors=true;effects.pool.mesh=QuadMesh.new();effects.pool.instance_count=WarEffects.LIMIT
	effects.explosion(Vector3.ZERO,14,190)
	var smoke:=effects.slots.filter(func(slot):return not slot.is_empty() and float(slot.total)>3.)
	check(smoke.size()==6 and float(smoke[0].size)>=2.,"larger explosion smoke uses six pooled clouds")
	check(float(smoke[0].attack)>=.8 and float(smoke[0].release)>=2.,"large smoke enters and fades progressively")
	var camera:=Camera3D.new();game.world_root.add_child(camera);camera.position=Vector3(0,8,16);camera.fov=6;camera.look_at(Vector3.ZERO);camera.make_current()
	effects._process(.30)
	check(effects.pool.visible_instance_count<=5,"zoom limits oversized overlapping smoke/fire cards per explosion")
	camera.position=Vector3(0,8,500);camera.fov=67;camera.look_at(Vector3.ZERO);effects._process(.016)
	check(effects.pool.visible_instance_count>5,"distant clouds keep their full silhouette")
	game.show_menu();game.queue_free();await create_timer(.5).timeout
	var report: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/devastation190-validation-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
