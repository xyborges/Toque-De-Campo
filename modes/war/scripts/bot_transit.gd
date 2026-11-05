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
var rooftop_graph:=AStar3D.new()
var rooftop_entries: Array[int]=[]
var rooftop_posts:=PackedVector3Array()

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
	rooftop_graph.clear();rooftop_entries.clear();rooftop_posts.clear()
	if wanted==WarOperation.AFGHAN:
		for record: Dictionary in BRAfghanMap.LAND.roads():
			var route: Array=[]
			for position: Vector3 in record.points:
				route.append(Vector2(position.x,position.z))
			if route.size()<2: continue
			add_route(route)
			if float(record.get("width",0.))>=6.: add_route(route,true)
	elif wanted==WarOperation.FAVELA:
		_add_favela_roads()
	else:
		for source: Array in WarRoads.ROUTES:add_route(WarRoads.rounded(source))
		add_route([Vector2(-560,0),Vector2(-260,-115),Vector2(0,0),Vector2(260,-115),Vector2(560,0)])
		add_route([Vector2(0,0),Vector2(0,85)])

func _add_favela_roads() -> void:
	var roads:=WarFavelaMap.road_envelopes()
	for road: Dictionary in roads:
		var route: Array=road.points
		var split: Array=[route[0]]
		for i in route.size()-1:
			var a: Vector2=route[i]
			var b: Vector2=route[i+1]
			var junctions: Array[Vector2]=[]
			for other: Dictionary in roads:
				if road.id==other.id:continue
				var other_route: Array=other.points
				for j in other_route.size()-1:
					var hit: Variant=Geometry2D.segment_intersects_segment(a,b,other_route[j],other_route[j+1])
					if hit is Vector2 and hit.distance_squared_to(a)>.01 and hit.distance_squared_to(b)>.01:
						junctions.append(hit)
			junctions.sort_custom(func(p: Vector2,q: Vector2):return p.distance_squared_to(a)<q.distance_squared_to(a))
			for hit: Vector2 in junctions:
				if hit.distance_squared_to(split[-1])>.01:split.append(hit)
			split.append(b)
		add_route(split)
		if float(road.width)>=6.0:
			# Recalculate intersections against drivable roads only by using
			# shared points along the two roads, never a shortcut across a lot.
			add_route(split,true)

func install_rooftops(paths: Array[PackedVector3Array]) -> void:
	if operation_id!=WarOperation.FAVELA:return
	rooftop_graph.clear()
	rooftop_entries.clear()
	rooftop_posts.clear()
	var ids: Dictionary={}
	for route: PackedVector3Array in paths:
		if route.size()>4:rooftop_posts.append(route[-1])
		var previous:=-1
		for i in route.size():
			var point:=route[i]
			var key:=Vector3i(roundi(point.x*20),roundi(point.y*20),roundi(point.z*20))
			if not ids.has(key):
				var next:=rooftop_graph.get_available_point_id()
				rooftop_graph.add_point(next,point)
				ids[key]=next
			var id: int=ids[key]
			if previous>=0 and previous!=id:
				rooftop_graph.connect_points(previous,id)
			if i==0 and point.y-WarTerrain.height_at(point.x,point.z)<.18:
				rooftop_entries.append(id)
			previous=id

func rooftop_overwatch(from: Vector3, objective: Vector3) -> Vector3:
	var best:=INF
	var position:=objective
	for roof: Vector3 in rooftop_posts:
		var approach:=from.distance_squared_to(roof)
		var offset:=objective.distance_squared_to(roof)
		if approach>58.0*58.0 or offset>43.0*43.0:continue
		var score:=offset+approach*.5
		if score<best:
			position=roof
			best=score
	return position

func _roof_node(point: Vector3) -> int:
	if rooftop_graph.get_point_count()==0 or point.y-WarTerrain.height_at(point.x,point.z)<.85:return -1
	var id:=rooftop_graph.get_closest_point(point)
	var near:=rooftop_graph.get_point_position(id)
	return id if absf(near.y-point.y)<.65 and near.distance_squared_to(point)<20.25 else -1

func roof_path(start: Vector3,goal: Vector3) -> PackedVector3Array:
	var start_id:=_roof_node(start)
	var goal_id:=_roof_node(goal)
	if start_id<0 and goal_id<0:return PackedVector3Array()
	if start_id>=0 and goal_id>=0:
		var direct:=rooftop_graph.get_point_path(start_id,goal_id)
		if not direct.is_empty():return direct
		# Two disjoint roofs use their separate entrances and street travel.
		goal_id=-1
	var elevated_id:=goal_id if goal_id>=0 else start_id
	var street_target:=start if goal_id>=0 else goal
	var best:=INF
	var selected:=PackedVector3Array()
	for entry in rooftop_entries:
		var distance:=street_target.distance_squared_to(rooftop_graph.get_point_position(entry))
		if distance>=best:continue
		var route:=rooftop_graph.get_point_path(entry,elevated_id)
		if route.is_empty():continue
		best=distance
		selected=route
	if goal_id<0:selected.reverse()
	return selected

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
	# Favela roads are split at real crossings and joined by matching nodes.
	if operation_id==WarOperation.FAVELA:return id
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

func path(start: Vector3,goal: Vector3,drivable:=false) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	var network:=vehicle_graph if drivable and operation_id in [WarOperation.AFGHAN,WarOperation.FAVELA] else graph
	if network.get_point_count()>0:
		var from_id:=network.get_closest_point(Vector2(start.x,start.z))
		var to_id:=network.get_closest_point(Vector2(goal.x,goal.z))
		var route:=network.get_point_path(from_id,to_id)
		for p: Vector2 in route: result.append(WarTerrain.point(p.x,p.y))
	# Do not append a cross-country straight line to vehicle routes:
	# stop at the last road node and let infantry finish the approach.
	if not drivable or operation_id not in [WarOperation.AFGHAN,WarOperation.FAVELA]: result.append(goal)
	return result
