extends RefCounted
class_name WarBotTransit

# Same routes for infantry and vehicles, but the road network depends on the
# operation. A spatial junction index avoids scanning every graph vertex when
# preparing long Afghan roads.
const JOIN_RADIUS:=18.0
var graph:=AStar2D.new()
var points: Dictionary={}
var junction_cells: Dictionary={}
var operation_id:=""

func _init() -> void:
	# WarRules is configured by WarGame before this helper is constructed.
	# Avoid building Ukraine's 247-point graph only to discard it for Afghan.
	configure(WarRules.CURRENT_OPERATION)

func configure(map_id: String) -> void:
	var wanted:=WarOperation.normalize(map_id)
	if operation_id==wanted:return
	operation_id=wanted
	graph.clear();points.clear();junction_cells.clear()
	if wanted==WarOperation.AFGHAN:
		for record: Dictionary in BRAfghanMap.LAND.roads():
			var route: Array=[]
			for position: Vector3 in record.points:
				route.append(Vector2(position.x,position.z))
			if route.size()>1:add_route(route)
	else:
		for source: Array in WarRoads.ROUTES:add_route(WarRoads.rounded(source))
		add_route([Vector2(-560,0),Vector2(-260,-115),Vector2(0,0),Vector2(260,-115),Vector2(560,0)])
		add_route([Vector2(0,0),Vector2(0,85)])

func _junction_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/JOIN_RADIUS),floori(p.y/JOIN_RADIUS))

func point_id(p: Vector2) -> int:
	var key:=Vector2i(roundi(p.x),roundi(p.y))
	if points.has(key):return int(points[key])
	var id:=graph.get_available_point_id()
	graph.add_point(id,p);points[key]=id
	var cell:=_junction_cell(p)
	for x in range(cell.x-1,cell.x+2):
		for y in range(cell.y-1,cell.y+2):
			for other: int in junction_cells.get(Vector2i(x,y),[]):
				if graph.get_point_position(other).distance_to(p)<JOIN_RADIUS:
					graph.connect_points(id,other)
	if not junction_cells.has(cell):junction_cells[cell]=[]
	junction_cells[cell].append(id)
	return id

func add_route(route: Array) -> void:
	for i in route.size()-1:
		var a: Vector2=route[i];var b: Vector2=route[i+1]
		var count:=maxi(1,ceili(a.distance_to(b)/35.))
		var previous:=point_id(a)
		for step in range(1,count+1):
			var next:=point_id(a.lerp(b,step/float(count)))
			if previous!=next:graph.connect_points(previous,next)
			previous=next

func path(start: Vector3,goal: Vector3) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if graph.get_point_count()>0:
		var route:=graph.get_point_path(graph.get_closest_point(Vector2(start.x,start.z)),graph.get_closest_point(Vector2(goal.x,goal.z)))
		for p: Vector2 in route:result.append(WarTerrain.point(p.x,p.y))
	result.append(goal)
	return result
