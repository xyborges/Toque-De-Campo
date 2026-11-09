extends RefCounted
class_name WarRpgBallistics

# Metres and seconds. Launch is fast over the first 100 m; aerodynamic
# resistance takes over smoothly afterwards, without changing other weapons.
const SPEED := 160.0
const GRAVITY := 9.81
const BASE_DRAG := 0.016
const RAMP_START := 90.0
const RAMP_END := 140.0
const SPATIAL_DECAY := 0.00125

# Range marks are calibrated against the same 120 Hz gravity/drag integrator
# used by WarProjectiles. The centre crosshair remains the close-range zero.
const MARK_RANGES := [100.0, 200.0, 300.0, 400.0, 500.0, 600.0]
const MARK_HOLD_MRAD := [19.3, 39.4, 62.8, 91.2, 126.2, 170.5]
const MARK_FLIGHT_SECONDS := [0.628, 1.293, 2.053, 2.927, 3.936, 5.106]

static func drag_for(base: float, distance: float, speed: float) -> float:
	return base + SPATIAL_DECAY * maxf(0.0, speed) * smoothstep(RAMP_START, RAMP_END, distance)

static func _interpolate_mark(distance: float, values: Array) -> float:
	if distance <= 0.0: return 0.0
	for i in MARK_RANGES.size():
		var end_distance: float = MARK_RANGES[i]
		if distance <= end_distance:
			var start_distance: float = 0.0 if i == 0 else MARK_RANGES[i - 1]
			var start_value: float = 0.0 if i == 0 else values[i - 1]
			return lerpf(start_value, float(values[i]), (distance - start_distance) / (end_distance - start_distance))
	return float(values[-1])

static func hold_mrad(distance: float) -> float:
	return _interpolate_mark(distance, MARK_HOLD_MRAD)

static func flight_seconds(distance: float) -> float:
	return _interpolate_mark(distance, MARK_FLIGHT_SECONDS)

static func reticle_near() -> Vector4:
	return Vector4(MARK_HOLD_MRAD[0], MARK_HOLD_MRAD[1], MARK_HOLD_MRAD[2], MARK_HOLD_MRAD[3])

static func reticle_far() -> Vector2:
	return Vector2(MARK_HOLD_MRAD[4], MARK_HOLD_MRAD[5])

# Deterministic offline calibration/QA; not called in the frame loop.
static func impact_height(horizontal_metres: float, launch_angle: float) -> float:
	var position := Vector3.ZERO
	var velocity := Vector3(0.0, sin(launch_angle) * SPEED, -cos(launch_angle) * SPEED)
	var distance := 0.0
	const STEP := 1.0 / 120.0
	for i in 1600:
		var coefficients := GameBulletPhysics.coefficients(drag_for(BASE_DRAG, distance, velocity.length()), STEP)
		var next: Vector3 = position + velocity * coefficients.y + Vector3.DOWN * GRAVITY * coefficients.z
		if -next.z >= horizontal_metres:
			return lerpf(position.y, next.y, clampf((-horizontal_metres - position.z) / (next.z - position.z), 0.0, 1.0))
		distance += position.distance_to(next)
		position = next
		velocity = velocity * coefficients.x + Vector3.DOWN * GRAVITY * coefficients.y
	return position.y
