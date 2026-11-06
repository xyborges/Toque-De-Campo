extends SceneTree
## Identify physical obstructions on the existing fifth mini-street near the baile.
var collisions: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var world := Node3D.new()
	root.add_child(world)
	WarWorld.build(world, false)
	await physics_frame
	await physics_frame
	var route: Array = WarFavelaMap.MINI_STREETS[4]
	var space := root.world_3d.direct_space_state
	for i in route.size() - 1:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var side: Vector2 = (b - a).normalized().orthogonal()
		var sample_count := ceili(a.distance_to(b))
		for step in sample_count + 1:
			for lateral: float in [-0.36, 0.0, 0.36]:
				var p := a.lerp(b, float(step) / float(sample_count)) + side * lateral
				var ground := WarTerrain.point(p.x, p.y)
				var ray := PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 2.5,
					ground + Vector3.UP * 0.35, 1)
				ray.hit_from_inside = true
				var hit := space.intersect_ray(ray)
				if hit.is_empty():
					continue
				var body := hit.collider as CollisionObject3D
				var origin := body.global_position if is_instance_valid(body) else Vector3.ZERO
				var entry := {"segment":i, "step":step, "offset":lateral, "point":str(p),
					"ground":str(ground), "collider":str(body.get_path()) if body else "null",
					"origin":str(origin), "shape":int(hit.shape), "hit_position":str(hit.position)}
				collisions.append(entry)
	print("FAVELA_ROAD_COLLISION_1138 ", JSON.stringify({
		"ok": collisions.is_empty(), "blocked": collisions.size(), "hits":collisions.slice(0, 16)}))
	world.queue_free()
	await process_frame
	quit.call_deferred(0 if collisions.is_empty() else 1)
