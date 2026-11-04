extends RefCounted
class_name GameBulletPhysics
static var cached: Dictionary={}

static func coefficients(drag: float,seconds: float) -> Vector3:
	var key:=Vector2(drag,seconds)
	if cached.has(key): return cached[key]
	var result: Vector3
	if drag<=.000001: result=Vector3(1,seconds,seconds*seconds*.5)
	else:
		var attenuation:=exp(-drag*seconds)
		var integral: float=(1-attenuation)/drag
		result=Vector3(attenuation,integral,(seconds-integral)/drag)
	if cached.size()>=1024: cached.clear()
	cached[key]=result;return result

# Exact integration of gravity and linear air drag. Used by every rendered
# and authoritative infantry projectile, independent of frame size.
static func advance(position: Vector3,velocity: Vector3,gravity: float,drag: float,seconds: float) -> Dictionary:
	var acceleration:=Vector3.DOWN*gravity
	var weights:=coefficients(drag,seconds)
	return {"position":position+velocity*weights.y+acceleration*weights.z,"velocity":velocity*weights.x+acceleration*weights.y}
