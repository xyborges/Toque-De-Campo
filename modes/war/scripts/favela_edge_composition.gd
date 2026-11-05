extends RefCounted
class_name WarFavelaEdgeComposition
## Deterministic grammar for the transition between Favela streets and buildings.
## Produces placement records only. Rendering remains the caller's responsibility,
## so the map can batch every module through EnvironmentKit instead of live Nodes.

const CELL := 32.0
const SAMPLE_STEP := 13.5
const ROAD_CLEARANCE := 0.48
const DEFINITIONS := {
	"favela_canaleta_drenagem":{"along":4.8,"depth":1.2,"solid":false,"axis":"z"},
	"favela_muro_contencao":{"along":6.3,"depth":1.0,"solid":true,"axis":"x"},
	"favela_corrimao_beco":{"along":3.8,"depth":0.18,"solid":false,"axis":"z"},
	"favela_tubulacao_externa":{"along":0.45,"depth":0.45,"solid":false,"axis":"x"},
	"favela_portao_grade":{"along":2.9,"depth":0.25,"solid":false,"axis":"x"},
	"favela_tanque_lavanderia":{"along":1.5,"depth":0.9,"solid":false,"axis":"x"},
	"favela_barraca_rua":{"along":3.1,"depth":1.9,"solid":false,"axis":"x"},
	"favela_antena_parabolica":{"along":1.4,"depth":1.4,"solid":false,"axis":"x"},
}

var roads: Array = []
var lots: Array = []
var bases: Array = []
var objectives: Array = []
var height_fn: Callable
var cells: Dictionary = {}
var lot_rects: Array[Rect2] = []

static func generate(
	road_data: Array,
	lot_data: Array,
	base_data: Array,
	objective_data: Array,
	terrain_height: Callable
) -> Array[Dictionary]:
	var planner := new()
	planner.roads = road_data
	planner.lots = lot_data
	planner.bases = base_data
	planner.objectives = objective_data
	planner.height_fn = terrain_height
	return planner._plan()

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.y/CELL))

func _register(index: int, rect: Rect2) -> void:
	var lo := _cell(rect.position)
	var hi := _cell(rect.end)
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var key:=Vector2i(x,z)
			if not cells.has(key): cells[key]=[]
			cells[key].append(index)

func _index_lots() -> void:
	cells.clear()
	lot_rects.clear()
	for lot: Dictionary in lots:
		var center: Vector2=lot.position
		var size: Vector2=lot.size
		var rect:=Rect2(center-size*.5,size)
		lot_rects.append(rect)
		_register(lot_rects.size()-1,rect)

func _near_indices(p: Vector2,radius:=2) -> Array:
	var result: Dictionary={}
	var c:=_cell(p)
	for z in range(c.y-radius,c.y+radius+1):
		for x in range(c.x-radius,c.x+radius+1):
			for index: int in cells.get(Vector2i(x,z),[]):result[index]=true
	return result.keys()

func _rect_distance(p: Vector2,rect: Rect2) -> float:
	var dx:=maxf(maxf(rect.position.x-p.x,0.0),p.x-rect.end.x)
	var dz:=maxf(maxf(rect.position.y-p.y,0.0),p.y-rect.end.y)
	return Vector2(dx,dz).length()

func _nearest_house(p: Vector2) -> Dictionary:
	var best:=INF
	var closest:=p
	var best_index:=-1
	for index in _near_indices(p):
		var rect:=lot_rects[int(index)]
		var q:=Vector2(
			clampf(p.x,rect.position.x,rect.end.x),
			clampf(p.y,rect.position.y,rect.end.y)
		)
		var distance:=p.distance_to(q)
		if distance<best:
			best=distance
			closest=q
			best_index=int(index)
	return {"distance":best,"point":closest,"index":best_index}

func _house_distance(p: Vector2) -> float:
	return float(_nearest_house(p).distance)

func _protected(p: Vector2) -> bool:
	for base: Vector2 in bases:
		if p.distance_to(base)<78.0:return true
	for target: Vector2 in objectives:
		# Keep the actual capture core open, but allow retaining walls, drainage
		# and pedestrian infrastructure on the surrounding slopes. Housing keeps
		# its larger independent objective reserve in favela_layout.gd.
		if p.distance_to(target)<18.0:return true
	return false

func _height(p: Vector2) -> float:
	return float(height_fn.call(p.x,p.y))

func _seed(road_id: int,segment: int,side: int,step: int) -> int:
	return absi(road_id*92821+segment*6899+side*1931+step*421+7919)

func _yaw_for(tangent: Vector2,axis: String) -> float:
	var yaw_x:=-atan2(tangent.y,tangent.x)
	return yaw_x+(PI*.5 if axis=="z" else 0.0)

func _record(
	kind: String,
	center: Vector2,
	tangent: Vector2,
	normal: Vector2,
	side: float,
	road_id: int,
	segment: int,
	sample: int,
	context: String
) -> Dictionary:
	var spec: Dictionary=DEFINITIONS[kind]
	var depth:=float(spec.depth)
	return {
		"kind":kind,
		"position":Vector3(center.x,_height(center),center.y),
		"yaw":_yaw_for(tangent,str(spec.axis)),
		"solid":bool(spec.solid),
		"road":road_id,
		"segment":segment,
		"sample":sample,
		"context":context,
		"road_clearance":ROAD_CLEARANCE,
		"footprint":Vector2(float(spec.along),depth),
	}

func _edge_center(center: Vector2,normal: Vector2,side: float,radius: float,depth: float,extra:=0.0) -> Vector2:
	return center+normal*side*(radius+ROAD_CLEARANCE+depth*.5+extra)

func _append(
	output: Array[Dictionary],
	kind: String,
	road_center: Vector2,
	tangent: Vector2,
	normal: Vector2,
	side: float,
	radius: float,
	road_id: int,
	segment: int,
	sample: int,
	context: String,
	extra:=0.0
) -> void:
	var depth:=float(DEFINITIONS[kind].depth)
	var center:=_edge_center(road_center,normal,side,radius,depth,extra)
	if _protected(center):return
	var record:=_record(kind,center,tangent,normal,side,road_id,segment,sample,context)
	output.append(record)

func _append_facade(
	output: Array[Dictionary],
	kind: String,
	facade: Vector2,
	road_center: Vector2,
	tangent: Vector2,
	normal: Vector2,
	side: float,
	radius: float,
	road_id: int,
	segment: int,
	sample: int,
	context: String
) -> void:
	var depth:=float(DEFINITIONS[kind].depth)
	var outward:=normal*side
	var center:=facade-outward*(depth*.5+.035)
	var clearance:=(center-road_center).dot(outward)-radius-depth*.5
	if clearance<ROAD_CLEARANCE:
		center=_edge_center(road_center,normal,side,radius,depth)
		clearance=ROAD_CLEARANCE
	if _protected(center):return
	var record:=_record(kind,center,tangent,normal,side,road_id,segment,sample,context)
	record.road_clearance=clearance
	record.facade_snapped=true
	output.append(record)

func _roadside(output: Array[Dictionary]) -> void:
	for road: Dictionary in roads:
		var road_id:=int(road.id)
		var route: Array=road.points
		var radius:=float(road.width)*.5
		for segment in route.size()-1:
			var a: Vector2=route[segment]
			var b: Vector2=route[segment+1]
			var axis:=b-a
			var length:=axis.length()
			if length<7.0:continue
			var tangent:=axis/length
			var normal:=Vector2(-tangent.y,tangent.x)
			var count:=maxi(1,floori(length/SAMPLE_STEP))
			for sample in count:
				var t:=(float(sample)+.5)/float(count)
				if t<.055 or t>.945:continue
				var road_center:=a.lerp(b,t)
				for side_index in 2:
					var side: float=-1.0 if side_index==0 else 1.0
					var edge:=road_center+normal*side*(radius+ROAD_CLEARANCE)
					if _protected(edge):continue
					var outward:=normal*side
					var house_info:=_nearest_house(edge)
					var house_gap:=float(house_info.distance)
					var h0:=_height(edge)
					var h2:=_height(edge+outward*2.2)
					var h45:=_height(edge+outward*4.5)
					var rise:=h45-h0
					var local_grade:=absf(rise)/4.5
					var seed:=_seed(road_id,segment,side_index,sample)

					# Steep road shoulders must read as constructed terrain, not
					# as a smooth grey slab: containment first, drainage second.
					if local_grade>.30 and house_gap>2.1:
						if seed%3!=0:
							_append(output,"favela_muro_contencao",road_center,tangent,normal,side,radius,
								road_id,segment,sample,"retaining",.12)
						if seed%2==0:
							_append(output,"favela_canaleta_drenagem",road_center,tangent,normal,side,radius,
								road_id,segment,sample,"drainage",1.05)
						if absf(h2-h0)>.48 and seed%4==0:
							_append(output,"favela_corrimao_beco",road_center,tangent,normal,side,radius,
								road_id,segment,sample,"pedestrian_grade",2.05)
						continue

					# Tight frontage: use facade-scale infrastructure. These are
					# non-solid and later get snapped to the actual facade plane.
					if house_gap<3.2:
						var facade: Vector2=house_info.point
						if seed%4==0:
							_append_facade(output,"favela_portao_grade",facade,road_center,tangent,normal,side,radius,
								road_id,segment,sample,"residential_front")
						elif seed%4==1:
							_append_facade(output,"favela_tubulacao_externa",facade,road_center,tangent,normal,side,radius,
								road_id,segment,sample,"service_front")
						elif seed%11==0 and house_gap>1.1:
							_append_facade(output,"favela_tanque_lavanderia",facade,road_center,tangent,normal,side,radius,
								road_id,segment,sample,"domestic_front")
						continue

					# Medium gap: drainage defines the road edge and handrails
					# identify pedestrian shortcuts on sloped sections.
					if house_gap<7.5:
						if seed%3==0:
							_append(output,"favela_canaleta_drenagem",road_center,tangent,normal,side,radius,
								road_id,segment,sample,"edge_drainage")
						if local_grade>.12 and seed%5==0:
							_append(output,"favela_corrimao_beco",road_center,tangent,normal,side,radius,
								road_id,segment,sample,"alley_access",1.10)
						continue

					# A wider pocket can support informal commerce, but only on
					# roads where a stall will not make a vehicle canyon.
					if house_gap<13.5 and float(road.width)>=6.0 and seed%5==0:
						_append(output,"favela_barraca_rua",road_center,tangent,normal,side,radius,
							road_id,segment,sample,"commercial_pocket",.75)
					elif local_grade>.14 and seed%3==0:
						_append(output,"favela_canaleta_drenagem",road_center,tangent,normal,side,radius,
							road_id,segment,sample,"open_edge")

func _rooftops(output: Array[Dictionary]) -> void:
	for index in lots.size():
		var lot: Dictionary=lots[index]
		var seed:=absi(int(lot.id)*131+index*17+233)
		if seed%23!=0:continue
		var p: Vector2=lot.position
		if _protected(p):continue
		var storeys:=int(lot.get("storeys",2))
		var roof_y:=_height(p)+float(storeys)*2.9+.24
		output.append({
			"kind":"favela_antena_parabolica",
			"position":Vector3(p.x+float(seed%5-2)*.55,roof_y,p.y+float((seed/5)%5-2)*.45),
			"yaw":float(seed%360)*PI/180.0,
			"solid":false,
			"road":-1,
			"segment":-1,
			"sample":index,
			"context":"roof_silhouette",
			"road_clearance":INF,
			"footprint":Vector2(1.4,1.4),
		})

func _plan() -> Array[Dictionary]:
	_index_lots()
	var output: Array[Dictionary]=[]
	_roadside(output)
	_rooftops(output)
	output.sort_custom(func(a: Dictionary,b: Dictionary):
		if int(a.road)!=int(b.road):return int(a.road)<int(b.road)
		if int(a.segment)!=int(b.segment):return int(a.segment)<int(b.segment)
		if int(a.sample)!=int(b.sample):return int(a.sample)<int(b.sample)
		return str(a.kind)<str(b.kind))
	return output
