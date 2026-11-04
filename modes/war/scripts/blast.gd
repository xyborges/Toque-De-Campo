extends RefCounted
class_name WarBlast

static func exposed_point(space: PhysicsDirectSpaceState3D,origin: Vector3,normal: Vector3,actor: GamePlayer,direct: Object=null) -> Dictionary:
	# Sample the actual body, not its feet. A terrain impact starts outside
	# the surface; unchanged world collision still blocks walls and ridges.
	var start:=origin+normal.normalized()*.08
	var candidates: Array[Vector3]=[actor.hit_regions.chest.global_position,actor.hit_regions.head.global_position,actor.global_position+Vector3.UP*.45]
	for point in candidates:
		var query:=PhysicsRayQueryParameters3D.create(start,point,1|16)
		var obstruction:=space.intersect_ray(query)
		if obstruction.is_empty(): return {"point":point,"distance":point.distance_to(origin)}
	# A direct body hit cannot be lost to its feet being behind a small ledge.
	if is_instance_valid(direct) and actor.is_ancestor_of(direct): return {"point":origin,"distance":0.0}
	return {}
