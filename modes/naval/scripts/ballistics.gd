extends RefCounted
class_name NavalBallistics

static func position(origin: Vector3, velocity: Vector3, gravity: float, age: float, weapon: String, launch_time: float) -> Vector3:
	var point: Vector3 = GameBulletPhysics.advance(origin,velocity,gravity,drag_for(weapon),age).position
	if weapon == "torpedo": point.y = origin.y + NavalCatalog.wave(point,launch_time+age)-NavalCatalog.wave(origin,launch_time)
	return point

static func drag_for(weapon: String) -> float:
	return float({"lightMG":.018,"heavyMG":.025,"missile":.006,"torpedo":.008}.get(weapon,0))

static func instantaneous_velocity(initial: Vector3,gravity: float,age: float,weapon: String) -> Vector3:
	return GameBulletPhysics.advance(Vector3.ZERO,initial,gravity,drag_for(weapon),age).velocity

static func duration(speed: float,range_value: float,life: float,weapon: String) -> float:
	var drag:=drag_for(weapon)
	var ratio:=range_value*drag/maxf(speed,.01)
	return minf(life,-log(maxf(.000001,1-ratio))/drag) if drag>.000001 else minf(life,range_value/maxf(speed,.01))

static func velocity(direction: Vector3, weapon: String, hull_velocity: Vector3) -> Vector3:
	return direction.normalized()*float(NavalCatalog.WEAPONS[weapon].speed)+hull_velocity

static func solve(origin: Vector3, target: Vector3, weapon: String, hull_velocity: Vector3) -> Dictionary:
	var data: Dictionary = NavalCatalog.WEAPONS[weapon]
	var destination := target
	if weapon == "torpedo": destination.y = origin.y
	var offset := destination-origin
	var speed := float(data.speed)
	var gravity := float(data.gravity)
	var max_time := duration(speed,float(data.range),float(data.life),weapon)
	var previous := 0.0001
	var high := -1.0
	var low := previous
	for i in range(1,161):
		var time := max_time*float(i)/160.0
		var weights:=GameBulletPhysics.coefficients(drag_for(weapon),time)
		var required := offset-hull_velocity*weights.y+Vector3.UP*gravity*weights.z
		if required.length_squared() <= speed*speed*weights.y*weights.y:
			low = previous
			high = time
			break
		previous = time
	if high < 0.0:
		return {"direction":offset.normalized(),"valid":false,"time":max_time}
	for i in range(28):
		var time := (low+high)*0.5
		var weights:=GameBulletPhysics.coefficients(drag_for(weapon),time)
		var required := offset-hull_velocity*weights.y+Vector3.UP*gravity*weights.z
		if required.length_squared() > speed*speed*weights.y*weights.y: low = time
		else: high = time
	var time := (low+high)*0.5
	var weights:=GameBulletPhysics.coefficients(drag_for(weapon),time)
	var direction := (offset-hull_velocity*weights.y+Vector3.UP*gravity*weights.z).normalized()
	return {"direction":direction,"valid":true,"time":time}

# The live simulation and trajectory guide call this exact segment function.
static func segment(world: World3D, shot: Dictionary, to_age: float, excludes: Array[RID]) -> Dictionary:
	var a := position(shot.origin,shot.velocity,shot.gravity,shot.age,shot.weapon,shot.time)
	var b := position(shot.origin,shot.velocity,shot.gravity,to_age,shot.weapon,shot.time)
	var ray := PhysicsRayQueryParameters3D.create(a,b,3,excludes)
	ray.hit_from_inside = true
	var hit := world.direct_space_state.intersect_ray(ray)
	if shot.weapon != "torpedo" and b.y <= 0.0:
		var low := float(shot.age)
		var high := to_age
		for i in range(20):
			var middle := (low+high)*0.5
			var point := position(shot.origin,shot.velocity,shot.gravity,middle,shot.weapon,shot.time)
			if point.y > 0.0: low = middle
			else: high = middle
		var water := position(shot.origin,shot.velocity,shot.gravity,high,shot.weapon,shot.time)
		if hit.is_empty() or a.distance_squared_to(water) < a.distance_squared_to(hit.position):
			return {"position":water,"collider":null,"water":true,"normal":Vector3.UP}
	return hit

static func prediction(world: World3D, shot: Dictionary, excludes: Array[RID]) -> Dictionary:
	var copy := shot.duplicate()
	copy.age = 0.0
	var points := PackedVector3Array([shot.origin])
	var impact := Vector3.ZERO
	var hit_something := false
	var end := duration(shot.velocity.length(),float(shot.range),float(shot.life),str(shot.weapon))
	var index := 0
	while float(copy.age) < end:
		var next := minf(float(copy.age)+NavalCatalog.STEP*3.0,end)
		var hit := segment(world,copy,next,excludes)
		if not hit.is_empty():
			impact = hit.position
			points.append(impact)
			hit_something = true
			break
		copy.age = next
		index += 1
		if index % 1 == 0 or next == end:
			points.append(position(copy.origin,copy.velocity,copy.gravity,next,copy.weapon,copy.time))
	return {"points":points,"impact":impact,"hit":hit_something}
