extends RefCounted
class_name WarFavelaRim

## Distant physical mountain amphitheater around the 1.5 km Favela.
## Raise only the outer 100 m so existing housing foundations, roads,
## football ground, combat objectives and vehicle routes stay untouched.
const START_X := 640.0
const START_Z := 640.0
const EDGE := 750.0

static func influence(x: float, z: float) -> float:
	var left_right := smoothstep(START_X, EDGE, absf(x))
	var north_south := smoothstep(START_Z, EDGE, absf(z))
	return maxf(left_right, north_south)

static func height_offset(x: float, z: float) -> float:
	var weight := influence(x, z)
	if weight <= 0.0:
		return 0.0
	# Three broad summits per rim rather than a constant flat wall.
	var undulation := 0.62 + 0.23 * sin(x * 0.009 + z * 0.003) \
		+ 0.15 * cos(z * 0.014 - x * 0.005)
	var crest := 92.0 * clampf(undulation, 0.36, 1.0)
	return weight * crest
