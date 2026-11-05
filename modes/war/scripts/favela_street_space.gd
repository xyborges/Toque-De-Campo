extends RefCounted
## The same road envelopes supply the terrain's paint mask and reserve space
## around corners and crossings before roadside scenery is placed.
const EDGE_MARGIN := .20
const CELL := 24.0
const MASK_SIZE := 3072

var roads: Array[Dictionary]
var segments: Array[Dictionary] = []
var occupied: Dictionary = {}

func _init(envelopes: Array[Dictionary]) -> void:
	roads = envelopes
	for road: Dictionary in roads:
		var route: Array = road.points
		var radius := float(road.width) * .5 + EDGE_MARGIN
		for i in route.size() - 1:
			var a: Vector2 = route[i]
			var b: Vector2 = route[i + 1]
			var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(radius)
			segments.append({"a": a, "b": b, "bounds": bounds, "radius_sq": radius * radius})

static func footprint(center: Vector2, half_size: Vector2, yaw := 0.0) -> Rect2:
	# Project the complete rotated footprint, including overhangs such as tires.
	var axes := Vector2(absf(cos(yaw)), absf(sin(yaw)))
	var half := Vector2(half_size.dot(axes), half_size.dot(Vector2(axes.y, axes.x)))
	return Rect2(center - half, half * 2.0)

func touches_road(rect: Rect2) -> bool:
	var corners := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)
	])
	for segment: Dictionary in segments:
		if not rect.intersects(segment.bounds): continue
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		if rect.has_point(a) or rect.has_point(b): return true
		for i in 4:
			var pair := Geometry2D.get_closest_points_between_segments(
				a, b, corners[i], corners[(i + 1) % 4])
			if pair[0].distance_squared_to(pair[1]) < float(segment.radius_sq): return true
	return false

func _cells(rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var low := Vector2i((rect.position / CELL).floor())
	var high := Vector2i((rect.end / CELL).floor())
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			cells.append(Vector2i(x, z))
	return cells

func protect(rect: Rect2) -> void:
	for cell: Vector2i in _cells(rect):
		if not occupied.has(cell): occupied[cell] = []
		occupied[cell].append(rect)

func claim(rect: Rect2) -> bool:
	if touches_road(rect): return false
	for cell: Vector2i in _cells(rect):
		for other: Rect2 in occupied.get(cell, []):
			if rect.intersects(other): return false
	protect(rect)
	return true

func pavement_mask(half_map: float, areas: Array[Dictionary]) -> Image:
	# Red is asphalt, green is concrete, blue is worn paint on asphalt.
	# Each pixel belongs to the terrain mesh, including at road intersections.
	var size := half_map * 2.0
	var svg := PackedStringArray([
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%f %f %f %f">' %
			[MASK_SIZE, MASK_SIZE, -half_map, -half_map, size, size],
		'<rect x="%f" y="%f" width="%f" height="%f" fill="#000000"/>' %
			[-half_map, -half_map, size, size]
	])
	for area: Dictionary in areas:
		var rect: Rect2 = area.rect
		var color := "#ff0000" if area.asphalt else "#00ff00"
		svg.append('<rect x="%f" y="%f" width="%f" height="%f" fill="%s"/>' %
			[rect.position.x, rect.position.y, rect.size.x, rect.size.y, color])
	# Concrete alleys meet asphalt with a material boundary, not two faces.
	for asphalt: bool in [false, true]:
		for road: Dictionary in roads:
			if bool(road.get("asphalt", true)) != asphalt: continue
			var color := "#ff0000" if asphalt else "#00ff00"
			var positions := PackedStringArray()
			for p: Vector2 in road.points: positions.append("%f,%f" % [p.x, p.y])
			svg.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%f" stroke-linejoin="round" stroke-linecap="round"/>' %
				[" ".join(positions), color, float(road.width)])
	var avenue: Array = roads[0].points
	for i in 2:
		var start: Vector2 = avenue[i]
		var end: Vector2 = avenue[i + 1]
		var direction := start.direction_to(end)
		for j in range(1, int(start.distance_to(end) / 18.0)):
			var p := start + direction * j * 18.0
			var a := p - direction
			var b := p + direction
			svg.append('<path d="M %f %f L %f %f" stroke="#ff00ff" stroke-width=".16"/>' %
				[a.x, a.y, b.x, b.y])
	svg.append("</svg>")
	var image := Image.new()
	if image.load_svg_from_string("".join(svg)) != OK: return null
	image.convert(Image.FORMAT_RGB8)
	image.generate_mipmaps()
	return image
