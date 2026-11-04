extends RefCounted
class_name CameraObstruction
static var spheres: Dictionary = {}

# A swept volume protects the near plane at corners. A single centre ray lets
# the camera's edges enter walls even when that ray is unobstructed.
static func resolve(world: World3D,anchor: Vector3,desired: Vector3,excludes: Array[RID],radius := .16,mask := 1) -> Dictionary:
	if not spheres.has(radius):
		var shape := SphereShape3D.new()
		shape.radius = radius
		spheres[radius] = shape
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = spheres[radius]
	query.collision_mask = mask
	query.exclude = excludes
	query.collide_with_areas = false
	query.margin = .015
	query.transform = Transform3D(Basis.IDENTITY,anchor)
	var space := world.direct_space_state
	if not space.intersect_shape(query,1).is_empty():
		# Crouching under a lintel can leave the eye volume above the capsule.
		# Search only toward the body's centre, never through the obstacle.
		for drop in [.12,.24,.36,.48]:
			query.transform.origin = anchor-Vector3.UP*drop
			if space.intersect_shape(query,1).is_empty():
				anchor = query.transform.origin
				break
	query.transform.origin = anchor
	var motion := desired-anchor
	if motion.length()<.001: return {"position":anchor,"fraction":1.0,"blocked":false}
	query.motion = motion
	var sweep := space.cast_motion(query)
	var fraction := clampf(float(sweep[0])-.04/motion.length(),0.0,1.0) if sweep[0]<1.0 else 1.0
	return {"position":anchor+motion*fraction,"fraction":fraction,"blocked":fraction<.999}
