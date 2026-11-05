extends RefCounted
class_name WarBotTransit

# Same routes for infantry and vehicles, but the road network depends on the
# operation. A spatial junction index avoids scanning every graph vertex when
# preparing long Afghan roads.
const JOIN_RADIUS:=18.0
var graph:=AStar2D.new()
var points: Dictionary={}
var junction_cells: Dictionary={}
# Vehicles use only wide, graded roadways; infantry may still use foot trails.
var vehicle_graph:=AStar2D.new()
var vehicle_points: Dictionary={}
var vehicle_junction_cells: Dictionary={}
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
	vehicle_graph.clear();vehicle_points.clear();vehicle_junction_cells.clear()
	if wanted==WarOperation.AFGHAN:
		for record: Dictionary in BRAfghanMap.LAND.roads():
			var route: Array=[]
			for position: Vector3 in record.points:
				route.append(Vector2(position.x,position.z))
			if route.size()<2: continue
			add_route(route)
			if float(record.get("width",0.))>=6.: add_route(route,true)
	else:
		for source: Array in WarRoads.ROUTES:add_route(WarRoads.rounded(source))
		add_route([Vector2(-560,0),Vector2(-260,-115),Vector2(0,0),Vector2(260,-115),Vector2(560,0)])
		add_route([Vector2(0,0),Vector2(0,85)])

func _junction_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/JOIN_RADIUS),floori(p.y/JOIN_RADIUS))

func point_id(p: Vector2,drivable:=false) -> int:
	var network:=vehicle_graph if drivable else graph
	var registry: Dictionary=vehicle_points if drivable else points
	var cells: Dictionary=vehicle_junction_cells if drivable else junction_cells
	var key:=Vector2i(roundi(p.x),roundi(p.y))
	if registry.has(key):return int(registry[key])
	var id:=network.get_available_point_id()
	network.add_point(id,p);registry[key]=id
	var cell:=_junction_cell(p)
	for x in range(cell.x-1,cell.x+2):
		for y in range(cell.y-1,cell.y+2):
			for other: int in cells.get(Vector2i(x,y),[]):
				var other_p:=network.get_point_position(other)
				if other_p.distance_to(p)>=JOIN_RADIUS: continue
				# Do not create shortcut intersections across separated banks.
				if drivable and absf(WarTerrain.height_at(p.x,p.y)-WarTerrain.height_at(other_p.x,other_p.y))>other_p.distance_to(p)*.24: continue
				network.connect_points(id,other)
	if not cells.has(cell):cells[cell]=[]
	cells[cell].append(id)
	return id

func add_route(route: Array,drivable:=false) -> void:
	var network:=vehicle_graph if drivable else graph
	for i in route.size()-1:
		var a: Vector2=route[i];var b: Vector2=route[i+1]
		var count:=maxi(1,ceili(a.distance_to(b)/35.))
		var previous:=point_id(a,drivable)
		for step in range(1,count+1):
			var next:=point_id(a.lerp(b,step/float(count)),drivable)
			if previous!=next:network.connect_points(previous,next)
			previous=next

# Check local road clearance before a motorcycle is allowed to overtake.
# The spatial road index lives in the same generator as the physical road.
func motorcycle_lane_clear(point: Vector3,half_width: float) -> bool:
	if operation_id!=WarOperation.AFGHAN: return true
	var nearby: Dictionary=BRAfghanMap.LAND._near_road(Vector2(point.x,point.z))
	return float(nearby.get("distance",INF))+half_width+.35<=float(nearby.get("width",0.))*.5

func path(start: Vector3,goal: Vector3,drivable:=false) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	var network:=vehicle_graph if drivable and operation_id==WarOperation.AFGHAN else graph
	if network.get_point_count()>0:
		var from_id:=network.get_closest_point(Vector2(start.x,start.z))
		var to_id:=network.get_closest_point(Vector2(goal.x,goal.z))
		var route:=network.get_point_path(from_id,to_id)
		for p: Vector2 in route: result.append(WarTerrain.point(p.x,p.y))
	# Do not append a cross-country straight line to vehicle routes:
	# stop at the last road node and let infantry finish the approach.
	if not drivable or operation_id!=WarOperation.AFGHAN: result.append(goal)
	return result
