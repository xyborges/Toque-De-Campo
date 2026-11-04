extends RefCounted
class_name GameWeaponZeroing

const STEP_METERS:=50
const MAX_ZERO_METERS:=1200
const _EPS:=0.000001
static var _angle_cache: Dictionary={}

static func supported(item: Dictionary) -> bool:
	return str(item.get("simulation",""))=="projectile" and float(item.get("speed",0.))>0. and float(item.get("gravity",0.))>0. and float(item.get("range",0.))>=STEP_METERS

static func maximum(item: Dictionary) -> int:
	if not supported(item): return 0
	var distance:=minf(float(item.get("range",0.)),float(MAX_ZERO_METERS))
	return maxi(0,int(floor(distance/STEP_METERS))*STEP_METERS)

static func sanitize(distance: int,item: Dictionary) -> int:
	var limit:=maximum(item)
	if limit<=0:return 0
	var snapped:=int(round(float(distance)/STEP_METERS))*STEP_METERS
	return clampi(snapped,0,limit)

static func step(current: int,amount: int,item: Dictionary) -> int:
	if amount==0:return sanitize(current,item)
	return sanitize(current+signi(amount)*STEP_METERS,item)

static func elevation_angle(item: Dictionary,distance: int) -> float:
	var zero:=sanitize(distance,item)
	if zero<=0:return 0.
	var speed:=float(item.get("speed",0.))
	var gravity:=float(item.get("gravity",0.))
	var drag:=maxf(0.,float(item.get("drag",0.)))
	var key:="%0.5f|%0.5f|%0.5f|%d"%[speed,gravity,drag,zero]
	if _angle_cache.has(key):return float(_angle_cache[key])
	var angle:=_solve_level_angle(speed,gravity,drag,float(zero))
	_angle_cache[key]=angle
	return angle

static func compensate(direction: Vector3,item: Dictionary,distance: int) -> Vector3:
	if not direction.is_finite() or direction.length_squared()<_EPS:return direction
	var angle:=elevation_angle(item,distance)
	if angle<=0.:return direction.normalized()
	var sight:=direction.normalized()
	var side:=sight.cross(Vector3.UP)
	if side.length_squared()<_EPS:return sight
	return sight.rotated(side.normalized(),angle).normalized()

static func _coefficients(drag: float,seconds: float) -> Vector2:
	if drag<=_EPS:return Vector2(seconds,seconds*seconds*.5)
	var attenuation:=exp(-drag*seconds)
	var integral:=(1.-attenuation)/drag
	return Vector2(integral,(seconds-integral)/drag)

static func _required_speed_sq(speed: float,gravity: float,drag: float,distance: float,seconds: float) -> float:
	var weights:=_coefficients(drag,maxf(seconds,.0001))
	var integral:=maxf(weights.x,.000001)
	var horizontal:=distance/integral
	var vertical:=gravity*weights.y/integral
	return horizontal*horizontal+vertical*vertical-speed*speed

static func _solve_level_angle(speed: float,gravity: float,drag: float,distance: float) -> float:
	if speed<=0. or gravity<=0. or distance<=0.:return 0.
	# Find the first (low-arc) solution of the exact linear-drag model used
	# by GameBulletPhysics. This runs once per weapon/range pair and is cached.
	var lower:=maxf(.0001,distance/speed*.75)
	var upper:=maxf(lower+.001,distance/speed)
	var f_lower:=_required_speed_sq(speed,gravity,drag,distance,lower)
	var f_upper:=_required_speed_sq(speed,gravity,drag,distance,upper)
	var ceiling:=maxf(4.,distance/speed*8.+2.)
	for _i in 96:
		if f_lower>=0. and f_upper<=0.:break
		lower=upper;f_lower=f_upper
		upper=minf(ceiling,upper*1.08+.001)
		f_upper=_required_speed_sq(speed,gravity,drag,distance,upper)
		if upper>=ceiling-.0001:break
	if not (f_lower>=0. and f_upper<=0.):return 0.
	for _i in 28:
		var middle:=(lower+upper)*.5
		var f_middle:=_required_speed_sq(speed,gravity,drag,distance,middle)
		if f_middle>0.:lower=middle
		else:upper=middle
	var flight:=(lower+upper)*.5
	var weights:=_coefficients(drag,flight)
	var horizontal:=distance/maxf(weights.x,.000001)
	var vertical:=gravity*weights.y/maxf(weights.x,.000001)
	return atan2(vertical,horizontal)
