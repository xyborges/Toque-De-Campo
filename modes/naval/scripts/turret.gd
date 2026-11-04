extends Node3D
class_name NavalTurret

var weapon := "lightMG"
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var visual: Node3D
var muzzle: Marker3D
var yaw := 0.0
var elevation := 0.0
var desired_yaw := 0.0
var desired_elevation := 0.0
var reachable := true
var blocked := false
var recoil := 0.0

func build(id: String) -> void:
	weapon = id
	name = id
	var data: Dictionary = NavalCatalog.WEAPONS[id]
	yaw_pivot = Node3D.new()
	add_child(yaw_pivot)
	NavalGeometry.cylinder(yaw_pivot,"Pedestal",Vector3.ZERO,0.34 if id != "torpedo" else 0.12,0.32,Color("495d62"))
	pitch_pivot = Node3D.new()
	pitch_pivot.position.y = 0.24 if id != "torpedo" else 0.0
	yaw_pivot.add_child(pitch_pivot)
	visual = Node3D.new()
	pitch_pivot.add_child(visual)
	var length := float(data.barrel)
	if id in ["lightMG","heavyMG"]:
		NavalGeometry.box(visual,"Receiver",Vector3(0,0,-0.15),Vector3(0.35,0.27,0.55),Color("28383a"))
		NavalGeometry.box(visual,"AmmoBox",Vector3(-0.26,-0.02,-0.12),Vector3(0.25,0.30,0.30),Color("657251"))
		var barrel := NavalGeometry.cylinder(visual,"Barrel",Vector3(0,0,-length*0.5),0.045 if id == "lightMG" else 0.075,length,Color("1c292c"))
		barrel.rotation.x = -PI/2
		NavalGeometry.box(visual,"GunShield",Vector3(0,-0.07,-0.30),Vector3(0.85,0.70,0.08),Color("556b6e"))
	elif id == "missile":
		NavalGeometry.box(visual,"LauncherCradle",Vector3(0,-0.15,-0.45),Vector3(0.72,0.22,1.25),Color("536357"))
		for side in [-1.0,1.0]:
			var tube := NavalGeometry.cylinder(visual,"MissileTube",Vector3(side*0.24,0,-length*0.45),0.20,length,Color("65735c"))
			tube.rotation.x = -PI/2
	else:
		for side in [-1.0,1.0]:
			var tube := NavalGeometry.cylinder(visual,"TorpedoTube",Vector3(side*0.23,0,-length*0.5),0.22,length,Color("3c5156"))
			tube.rotation.x = -PI/2
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(-0.24 if id == "missile" else (-0.23 if id == "torpedo" else 0.0),0,-length)
	visual.add_child(muzzle)

func step(target: Vector3, hull_velocity: Vector3, delta: float) -> void:
	var data: Dictionary = NavalCatalog.WEAPONS[weapon]
	var origin := muzzle.global_position
	var solution := NavalBallistics.solve(origin,target,weapon,hull_velocity)
	var direction: Vector3 = solution.direction
	# Compensate the complete parent basis (heading and the authoritative wave tilt).
	var local_direction := global_basis.inverse()*direction
	var raw_yaw := atan2(-local_direction.x,-local_direction.z)
	var raw_pitch := atan2(local_direction.y,Vector2(local_direction.x,local_direction.z).length())
	desired_yaw = clampf(raw_yaw,-float(data.yaw),float(data.yaw))
	desired_elevation = clampf(raw_pitch,float(data.min_pitch),float(data.max_pitch))
	reachable = bool(solution.valid) and absf(raw_yaw-desired_yaw)<0.03 and (weapon == "torpedo" or absf(raw_pitch-desired_elevation)<0.035)
	var difference := wrapf(desired_yaw-yaw,-PI,PI)
	yaw = wrapf(yaw+clampf(difference,-float(data.turn)*delta,float(data.turn)*delta),-PI,PI)
	elevation = move_toward(elevation,desired_elevation,float(data.turn)*delta)
	yaw_pivot.rotation.y = yaw
	pitch_pivot.rotation.x = elevation
	recoil = move_toward(recoil,0.0,delta*0.6)
	visual.position.z = recoil
	var forward := -muzzle.global_basis.z.normalized()
	var ray := PhysicsRayQueryParameters3D.create(muzzle.global_position,muzzle.global_position+forward*float(get_parent().spec.length)*1.5,2)
	ray.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	blocked = not hit.is_empty() and hit.collider == get_parent()

func launch(hull_velocity: Vector3, time: float) -> Dictionary:
	var data: Dictionary = NavalCatalog.WEAPONS[weapon]
	var direction := -muzzle.global_basis.z.normalized()
	return {"origin":muzzle.global_position,"velocity":NavalBallistics.velocity(direction,weapon,hull_velocity),"gravity":float(data.gravity),"age":0.0,"weapon":weapon,"time":time,"life":float(data.life),"range":float(data.range)}

func show_recoil() -> void:
	recoil = 0.05 if weapon == "lightMG" else 0.11

func apply_snapshot(data: Dictionary, delta: float) -> void:
	yaw = lerp_angle(yaw,float(data.yaw),1.0-exp(-delta*22.0))
	elevation = lerpf(elevation,float(data.pitch),1.0-exp(-delta*22.0))
	yaw_pivot.rotation.y = yaw
	pitch_pivot.rotation.x = elevation
	reachable = bool(data.valid)
	blocked = bool(data.blocked)
	recoil = move_toward(recoil,0.0,delta*0.6)
	visual.position.z = recoil
