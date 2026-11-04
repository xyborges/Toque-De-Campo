extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func collision_digest(world: Node3D) -> String:
	var data: Array = []
	for shape_node in world.find_children("*","CollisionShape3D",true,false):
		var shape: Shape3D = shape_node.shape
		var points := PackedVector3Array()
		if shape is ConcavePolygonShape3D: points = shape.get_faces()
		elif shape is ConvexPolygonShape3D: points = shape.points
		var dimensions := Vector3.ZERO
		if shape is BoxShape3D: dimensions = shape.size
		elif shape is CylinderShape3D: dimensions = Vector3(shape.radius,shape.height,0)
		data.append([shape_node.global_transform,shape.get_class(),points,dimensions])
	return var_to_bytes(data).hex_encode().sha256_text()
func run() -> void:
	var server := NavalWorld.new()
	root.add_child(server)
	server.build(false,17391)
	var client := NavalWorld.new()
	# Own physics space for a realistic independent rendering client.
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(client)
	client.build(true,17391)
	check(collision_digest(server)==collision_digest(client),"server and visual client build identical scenery colliders")
	check(NavalCatalog.MAP_LIMIT==980.0,"naval navigation size is preserved")
	for index in range(5): check(server.get_node("Island_%d" % index).get_meta("identity")==NavalIslands.NAMES[index],"distinct island identity "+NavalIslands.NAMES[index])
	await physics_frame
	await physics_frame
	for index in range(5):
		var center: Vector3 = NavalCatalog.ISLANDS[index]
		var hit := server.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*180,center-Vector3.UP*30,1))
		check(not hit.is_empty() and hit.position.y>1,"projectile ray strikes real island geometry "+str(index))
	var floor_hit := server.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(750,-2,750),Vector3(750,-160,750),1))
	check(not floor_hit.is_empty() and floor_hit.position.y< -30,"physical seabed has depth below open water")
	var random := RandomNumberGenerator.new()
	random.seed = 1234
	var safe := true
	var accepted := 0
	for i in range(180):
		var p := Vector3(random.randf_range(-850,850),0,random.randf_range(-850,850))
		if not NavalCatalog.safe_point(p,NavalCatalog.ship_radius("heavy")): continue
		accepted += 1
		var shape := SphereShape3D.new()
		shape.radius = 1.6
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,p+Vector3.UP*.8)
		query.collision_mask = 1
		safe = safe and server.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	check(safe and accepted>120,"spawn-safe open water is not obstructed by new coastal props")
	client.update_time(450)
	check(client.coastal_lights.size()>0 and client.sun.light_energy>=.1,"night has navigable ambient light and coastal beacon")
	for weapon: String in NavalCatalog.WEAPONS:
		var origin := Vector3(700,3,700)
		var moving := Vector3(8,0,-13)
		var shot := {"origin":origin,"velocity":NavalBallistics.velocity(Vector3(0,.002,-1),weapon,moving),"gravity":NavalCatalog.WEAPONS[weapon].gravity,"life":NavalCatalog.WEAPONS[weapon].life,"range":NavalCatalog.WEAPONS[weapon].range,"weapon":weapon,"time":8.0,"age":0.0}
		var prediction := NavalBallistics.prediction(server.get_world_3d(),shot,[])
		var copy := shot.duplicate()
		var hit := {}
		for i in range(1500):
			hit = NavalBallistics.segment(server.get_world_3d(),copy,float(copy.age)+NavalCatalog.STEP,[])
			copy.age = float(copy.age)+NavalCatalog.STEP
			if not hit.is_empty(): break
		check(prediction.hit and not hit.is_empty() and prediction.impact.distance_to(hit.position)<.07,"live projectile and guide agree on new scenery "+weapon)
	server.queue_free()
	viewport.queue_free()
	await process_frame
	NavalStorage.write_json("res://tests/environment-naval-results.json",{"checks":checks,"failures":failures})
	quit(0 if failures.is_empty() else 1)
