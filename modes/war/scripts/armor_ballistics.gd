extends RefCounted
class_name WarArmorBallistics
static func drag_for(weapon: String,base: float,distance: float,speed: float) -> float:
	if weapon not in ["tank","autocannon"]: return base
	var start:=80. if weapon=="tank" else 55.
	var spatial_rate:=.00115 if weapon=="tank" else .00145
	# Spatial drag grows smoothly beyond the near field. Initial muzzle
	# speed is untouched; later loss is integrated by the shared solver.
	return base+spatial_rate*speed*smoothstep(start,start+150.,distance)
