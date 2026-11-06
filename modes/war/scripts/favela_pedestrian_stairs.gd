extends RefCounted
class_name WarFavelaPedestrianStairs

## Reusable 0.82m modular tread from favela_degrau_beco.tscn.
## Flights are assembled only on steep pedestrian lanes; the existing
## terrain collision stays authoritative for movement and navigation.
const TREAD: Vector3 = Vector3(1.05, 0.14, 0.82)
const FLIGHT_TREADS := 7
const MAX_FLIGHTS := 68
const FLIGHT_INTERVAL := 8.8
const GRADE_MIN := 0.105
const GRADE_MAX := 0.43

static func _protected(p: Vector2, bases: Array, objectives: Array) -> bool:
	for b: Vector2 in bases:
		if p.distance_to(b) < 51.0: return true
	for o: Vector2 in objectives:
		if p.distance_to(o) < 36.0: return true
	return false

static func plan(routes: Array, bases: Array, objectives: Array, height: Callable) -> Array[Dictionary]:
	var flights: Array[Dictionary] = []
	for route: Array in routes:
		for segment in route.size() - 1:
			var start: Vector2 = route[segment]
			var end: Vector2 = route[segment + 1]
			var length := start.distance_to(end)
			if length < 8.0: continue
			var delta := absf(float(height.call(start.x, start.y)) - float(height.call(end.x, end.y)))
			if delta / length < GRADE_MIN: continue
			var axis := (end - start) / length
			var local_count := maxi(1, floori((length - 5.8) / FLIGHT_INTERVAL))
			for i in local_count:
				if flights.size() >= MAX_FLIGHTS: return flights
				var middle := start.lerp(end, (float(i) + 0.5) / float(local_count))
				if _protected(middle, bases, objectives): continue
				var local_before := middle - axis * 2.5
				var local_after := middle + axis * 2.5
				var grade := absf(float(height.call(local_after.x, local_after.y)) - float(height.call(local_before.x, local_before.y))) / 5.0
				if grade < GRADE_MIN or grade > GRADE_MAX: continue
				var treads: Array[Vector3] = []
				for step in FLIGHT_TREADS:
					var along := (float(step) - 3.0) * 0.82
					var p := middle + axis * along + Vector2(-axis.y, axis.x) * 1.04
					treads.append(Vector3(p.x, float(height.call(p.x, p.y)) + 0.073, p.y))
				flights.append({"center": middle, "direction": axis, "treads": treads,
					"grade": grade})
	return flights

static func populate(kit: EnvironmentKit, flights: Array[Dictionary]) -> Dictionary:
	var count := 0
	for flight: Dictionary in flights:
		var axis: Vector2 = flight.direction
		var yaw := atan2(axis.x, axis.y)
		var treads: Array = flight.treads
		for p: Vector3 in treads:
			kit.box("DegrauBeco", p, TREAD, "concrete:b8b9b4", true,
				Vector3(0, yaw, 0), true)
			count += 1
		# Handrails are visual and non-blocking; the treads remain physical.
		if treads.size() >= 2:
			var first: Vector3 = treads.front()
			var last: Vector3 = treads.back()
			var across := Vector3(axis.y, 0, -axis.x) * .65
			for side in [-1.0, 1.0]:
				kit.pipe(first + across * side + Vector3.UP * .86,
					last + across * side + Vector3.UP * .86,
					.035, "steel:727675", false)
	return {"flights": flights.size(), "treads": count}
