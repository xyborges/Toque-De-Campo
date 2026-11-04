extends Camera3D
class_name NavalCamera
var orbit_yaw := 0.0
var orbit_pitch := -0.12
var zoom := false
var sensitivity := 0.0016
var initialized := false

func mouse(delta: Vector2,kind:="light",weapon:="lightMG") -> void:
	var factor := sensitivity*(0.5 if zoom else 1.0)*GameAimSensitivity.factor("naval:"+kind,zoom)*GameAimSensitivity.factor("navalweapon:"+weapon,zoom)
	orbit_yaw = wrapf(orbit_yaw-delta.x*factor,-PI,PI)
	orbit_pitch = clampf(orbit_pitch-delta.y*factor,-0.75,0.65)

func follow(ship: NavalShip, delta: float) -> void:
	if not initialized:
		orbit_yaw = float(ship.target_state.get("heading",ship.heading))
		initialized = true
	follow_body(ship,ship.spec,delta,3)

func follow_body(ship: Node3D,spec: Dictionary,delta: float,mask:=3,excludes: Array[RID]=[]) -> void:
	var forward := Basis(Vector3.UP,orbit_yaw)*Basis(Vector3.RIGHT,orbit_pitch)*Vector3.FORWARD
	var length := float(spec.length)
	var anchor := Vector3(ship.global_position.x,2.0,ship.global_position.z)
	var desired := anchor-forward*(length*0.9+10.0)+Vector3.UP*(4.0+length*0.24+2.5)
	# Surface ships cannot send the camera below the sea when looking up.
	desired.y = maxf(desired.y,NavalCatalog.wave(desired,0.0)+1.15)
	var candidate := desired if delta == 0.0 else global_position.lerp(desired,1.0-exp(-delta*9.0))
	candidate.y = maxf(candidate.y,1.15)
	var ignored: Array[RID]=excludes.duplicate()
	if ship is CollisionObject3D and not ship.get_rid() in ignored: ignored.append(ship.get_rid())
	var safe := CameraObstruction.resolve(get_world_3d(),anchor,candidate,ignored,.45,mask)
	global_position = safe.position
	look_at(anchor+forward*700.0,Vector3.UP)
	fov = lerpf(fov,14.0 if zoom else 70.0,1.0-exp(-maxf(delta,0.01)*15.0))

func aim_point(ship: NavalShip, clock: float) -> Vector3:
	return target_point(float(NavalCatalog.WEAPONS[ship.selected].range),3,[ship.get_rid()])

func target_point(distance: float,mask: int,excludes: Array[RID]) -> Vector3:
	var screen := get_viewport().get_visible_rect().size*0.5
	var from := project_ray_origin(screen)
	var direction := project_ray_normal(screen)
	var ray := PhysicsRayQueryParameters3D.create(from,from+direction*distance,mask,excludes)
	ray.collide_with_areas=true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var world_distance := distance
	var point := from+direction*minf(distance*0.7,900.0)
	if direction.y < -0.0001:
		var time := -from.y/direction.y
		if time > 0.0 and time <= distance:
			point = from+direction*time
			world_distance = time
	if not hit.is_empty() and from.distance_to(hit.position)<world_distance: point = hit.position
	return point
