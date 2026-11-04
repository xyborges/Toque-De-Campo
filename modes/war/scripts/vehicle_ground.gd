extends RefCounted
class_name WarVehicleGround
const MAX_SUPPORT_RISE:=preload("res://modes/war/scripts/vehicle_step.gd").MAX_RISE
var tilt:=Basis.IDENTITY
var previous:=Vector3.INF
var previous_heading:=INF
var timer:=0.0
var contacts: Array[Vector3]=[]
var collision_shapes: Array[CollisionShape3D]=[]
var shape_query:=PhysicsShapeQueryParameters3D.new()
var support_ray:=PhysicsRayQueryParameters3D.new()

func _prepare_queries(vehicle: WarVehicle) -> void:
	if not collision_shapes.is_empty(): return
	for node in vehicle.get_children():
		if node is CollisionShape3D: collision_shapes.append(node)
	shape_query.exclude=[vehicle.get_rid()];shape_query.margin=.001
	support_ray.exclude=[vehicle.get_rid()];support_ray.collision_mask=1

func _clear_orientation(vehicle: WarVehicle,pose: Transform3D) -> bool:
	var space:=vehicle.get_world_3d().direct_space_state
	shape_query.motion=Vector3.ZERO;shape_query.collision_mask=vehicle.collision_mask;shape_query.margin=.001
	for node in collision_shapes:
		if node.disabled or node.shape==null: continue
		shape_query.shape=node.shape;shape_query.transform=pose*node.transform
		if not space.intersect_shape(shape_query,1).is_empty(): return false
	return true

func _move_support_height(vehicle: WarVehicle,change: float) -> void:
	var space:=vehicle.get_world_3d().direct_space_state
	var motion:=Vector3.UP*change
	var safe:=1.0
	shape_query.collision_mask=vehicle.collision_mask
	for node in collision_shapes:
		if node.disabled or node.shape==null: continue
		shape_query.shape=node.shape;shape_query.transform=node.global_transform
		# Shape casts ignore initial overlaps. A spawn/teleport on an incline
		# needs the engine's complete recovery, including all hull contacts.
		# Use that expensive path only when an overlap actually exists.
		shape_query.motion=Vector3.ZERO;shape_query.margin=.0001
		if not space.intersect_shape(shape_query,1).is_empty():
			vehicle.move_and_collide(motion)
			return
		shape_query.motion=motion;shape_query.margin=.001
		var fractions:=space.cast_motion(shape_query)
		if fractions.size()!=2: return
		safe=minf(safe,fractions[0])
		if safe<=0: return
	var pose:=vehicle.global_transform
	pose.origin+=motion*safe
	# Every enabled hull shape started clear and was swept continuously.
	# The minimum safe fraction already bounds the shared translation.
	vehicle.global_position=pose.origin

func align(vehicle: WarVehicle,delta: float) -> void:
	_prepare_queries(vehicle)
	timer-=delta
	var yaw:=Basis(Vector3.UP,vehicle.heading)
	var width:=float(vehicle.spec.size.x)*.41
	var length:=float(vehicle.spec.size.z)*.35
	if timer<=0 or previous.distance_to(vehicle.global_position)>.15 or absf(angle_difference(previous_heading,vehicle.heading))>.015:
		timer=.1;previous=vehicle.global_position;previous_heading=vehicle.heading;contacts.clear()
		for offset in [Vector3(-width,0,-length),Vector3(width,0,-length),Vector3(-width,0,length),Vector3(width,0,length)]:
			var p: Vector3=vehicle.global_position+yaw*offset
			support_ray.from=p+Vector3.UP*3;support_ray.to=p-Vector3.UP*4
			var hit:=vehicle.get_world_3d().direct_space_state.intersect_ray(support_ray)
			if hit.is_empty() or not hit.collider is StaticBody3D or Vector3(hit.normal).y<cos(vehicle.floor_max_angle): contacts.clear();return
			# A ray reaching the top of a wall/roof must not ratchet the
			# suspension upwards. Compare the support plane at the centre,
			# not the uphill corner: a continuous incline can rise much more
			# than a curb across the length of a tank's footprint.
			var support_normal: Vector3=hit.normal
			var plane_y: float=Vector3(hit.position).y+(support_normal.x*(p.x-vehicle.global_position.x)+support_normal.z*(p.z-vehicle.global_position.z))/support_normal.y
			if plane_y-(vehicle.global_position.y+.09)>MAX_SUPPORT_RISE+.005: contacts.clear();return
			contacts.append(Vector3(offset.x,Vector3(hit.position).y,offset.z))
	if contacts.size()!=4: return
	var front: float=(contacts[0].y+contacts[1].y)*.5
	var rear: float=(contacts[2].y+contacts[3].y)*.5
	var left: float=(contacts[0].y+contacts[2].y)*.5
	var right: float=(contacts[1].y+contacts[3].y)*.5
	var normal:=Vector3(-(right-left)/(2*width),1,-(rear-front)/(2*length)).normalized()
	if normal.y<cos(vehicle.floor_max_angle): return
	var back:=Vector3.BACK.slide(normal).normalized()
	var side:=normal.cross(back).normalized();back=side.cross(normal).normalized()
	var desired_tilt:=tilt.slerp(Basis(side,normal,back),1-exp(-delta*12)).orthonormalized()
	# Fit the actual track/wheel footprint, including cross slope. Ground
	# rays also respect piers and bridges above the procedural terrain.
	var goal:=-INF
	var centre_height: float=(front+rear)*.5
	var slope_x: float=(right-left)/(2*width)
	var slope_z: float=(rear-front)/(2*length)
	var uneven:=0.0
	for contact in contacts: uneven=maxf(uneven,contact.y-(centre_height+slope_x*contact.x+slope_z*contact.z))
	for contact in contacts:
		var local_foot: Vector3=desired_tilt*Vector3(contact.x,.09,contact.z)
		goal=maxf(goal,centre_height+slope_x*local_foot.x+slope_z*local_foot.z-local_foot.y+.025+uneven)
	# An unresolved side collision is not suspension travel. Only the step
	# helper may recover it after checking headroom and the full route.
	if goal>vehicle.global_position.y and vehicle.step_motion.blocked_motion: return
	if goal>=vehicle.global_position.y or absf(goal-vehicle.global_position.y)<1.2:
		# Rays estimate suspension support, not permission to move through a
		# slab, wall or another hull. Sweep the whole body for the correction.
		var change:=move_toward(vehicle.global_position.y,goal,delta*5)-vehicle.global_position.y
		if absf(change)>.00001: _move_support_height(vehicle,change)
	# Test intermediate orientations as well: a clear final tilt alone can
	# miss a thin ceiling crossed by the turret during the rotation.
	var turn:=tilt.get_rotation_quaternion().angle_to(desired_tilt.get_rotation_quaternion())
	if turn>.00005 and not tilt.is_equal_approx(desired_tilt):
		var slices:=clampi(ceili(turn*maxf(width,length)/.04),1,12)
		for index in slices:
			var pose:=vehicle.global_transform
			pose.basis=yaw*tilt.slerp(desired_tilt,float(index+1)/slices)
			# Overlap is sufficient for a proposed orientation. Kinematic
			# recovery builds every contact manifold against large terrain
			# meshes even though no recovery motion will be consumed here.
			if not _clear_orientation(vehicle,pose): return
		tilt=desired_tilt
	var aligned:=yaw*tilt
	if vehicle.basis!=aligned: vehicle.basis=aligned
