extends RefCounted
## A street envelope and block grammar precede every building placement.
## Facade rows are placed first. Rear lots retain their footprint if moving
## them forward would occupy an already reserved frontage or pedestrian gap.
var routes: Array=[]
var bases: Array=[]
var objectives: Array=[]
var occupied: Dictionary={}

const SIZES := [Vector2(12.8,12.3),Vector2(11.8,13.5),Vector2(13.4,11.8),
	Vector2(12.2,12.8),Vector2(13.2,13.0)]
const BAILE_CENTER := Vector2(430.0, -275.0)
const BAILE_CLEARANCE := Rect2(BAILE_CENTER - Vector2(47.0, 34.0), Vector2(94.0, 68.0))
const PALETTES := [
	["plaster:688d91","plaster:b3a179","brick:9d5947","plaster:9c6358"],
	["plaster:8e9c7b","brick:985846","plaster:c1b390","plaster:718b9c"],
	["brick:9d5947","plaster:af9365","concrete:89857b","plaster:7b999c"],
	["plaster:b19d81","plaster:a96f61","brick:885346","plaster:82967c"]]

static func generate(road_data: Array,base_data: Array,objective_data: Array) -> Array[Dictionary]:
	var planner:=new()
	planner.routes=road_data
	planner.bases=base_data
	planner.objectives=objective_data
	return planner._plan()

func frontage(p: Vector2,half: Vector2) -> Dictionary:
	var best: Dictionary={"gap":INF,"normal":Vector2.ZERO,"road":-1,"width":0.0}
	for road: Dictionary in routes:
		var points: Array=road.points
		for i in points.size()-1:
			var a: Vector2=points[i]
			var b: Vector2=points[i+1]
			var nearest:=Geometry2D.get_closest_point_to_segment(p,a,b)
			var delta:=p-nearest
			var normal:=delta.normalized()
			var extent:=half.dot(normal.abs())
			var gap:=delta.length()-extent-float(road.width)*.5
			if gap<float(best.gap):
				best={"gap":gap,"normal":normal,"road":int(road.id),"width":float(road.width)}
	return best

func clear(p: Vector2,half: Vector2) -> bool:
	if p.x< -650 or p.x>650 or p.y< -550 or p.y>505:return false
	if p.x>510 and p.y>420:return false
	if BAILE_CLEARANCE.intersects(Rect2(p-half,half*2.0).grow(1.0)):return false
	if float(frontage(p,half).gap)<.38:return false
	var radius:=half.length()
	for base: Vector2 in bases:
		if p.distance_to(base)<61.0+radius:return false
	for objective: Vector2 in objectives:
		if p.distance_to(objective)<30.0+radius:return false
	return true

func overlaps(rect: Rect2,ignore:=Vector2.INF) -> bool:
	var low:=Vector2i(floori(rect.position.x/32),floori(rect.position.y/32))
	var high:=Vector2i(floori(rect.end.x/32),floori(rect.end.y/32))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for other: Rect2 in occupied.get(Vector2i(x,z),[]):
				if not other.get_center().is_equal_approx(ignore) and rect.intersects(other):return true
	return false

func occupy(rect: Rect2) -> void:
	var low:=Vector2i(floori(rect.position.x/32),floori(rect.position.y/32))
	var high:=Vector2i(floori(rect.end.x/32),floori(rect.end.y/32))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell:=Vector2i(x,z)
			if not occupied.has(cell):occupied[cell]=[]
			occupied[cell].append(rect)

func _plan() -> Array[Dictionary]:
	var candidates: Array[Dictionary]=[]
	# Denser candidate grid with gentle block-level drift. Houses remain in
	# coherent clusters, while streets, stairs, and intentional pockets stay
	# protected by the footprint checks below.
	for row in 80:
		var z: float=-535.0+row*13.0
		var block_row:=floori(row/4.0)
		var shift:=sin(block_row*.84)*2.25+sin(row*.43)*.48
		var fringe:=512.0+70*sin(z*.011)+36*cos(z*.026)
		for column in 100:
			var block_column:=floori(column/5.0)
			var x: float=-643.0+column*13.0+shift+sin(block_column*.91)*1.7
			var sparse:=z>400 or absf(x-22*sin(z*.02))>fringe
			if sparse and (row%2!=0 or column%3==0):continue
			var block:=posmod(block_column+block_row*3,4)
			var profile:=posmod(column+row*2+block,5)
			var size: Vector2=SIZES[profile]
			# Related homes share floor heights, palette and extension direction.
			# The small repeating setbacks belong to a block, not a random house.
			var cluster_x:=sin(block_column*1.71+block_row*.43)*.82
			var cluster_z:=cos(block_row*1.37+block_column*.58)*.72
			var p:=Vector2(x+cluster_x+float((column+block)%3-1)*.34,
				z+cluster_z+float((row+profile)%3-1)*.38)
			# A few houses in each cluster start as smaller footprints; their
			# raised additions make visible construction phases and narrow gaps.
			var extension_stage:=posmod(column*2+row+block,7)
			if extension_stage in [1,4]: size*=Vector2(.91,.94)
			var edge:=frontage(p,size*.5)
			if float(edge.gap)<.4:continue
			var storeys: int=[2,3,4,2,3][profile]
			if block==2 and profile==2:storeys=5
			if sparse:storeys=mini(storeys,2)
			var palette: Array=PALETTES[block]
			var extension_side:=posmod(block+floori(column/2.0)+floori(row/3.0),4)
			if extension_stage==6: extension_side=posmod(extension_side+1,4)
			candidates.append({"id":row*100+column,"row":row,"column":column,
				"position":p,"size":size,"profile":profile,"block":block,
				"storeys":storeys,"finish":palette[(column+row)%palette.size()],
				"extension_side":extension_side,"extension_stage":extension_stage,
				"sparse":sparse,"gap":edge.gap,"edge":edge,"moved":false})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary):
		return int(a.id)<int(b.id) if float(a.gap)==float(b.gap) else float(a.gap)<float(b.gap))
	var lots: Array[Dictionary]=[]
	for lot: Dictionary in candidates:
		var p: Vector2=lot.position
		var half: Vector2=lot.size*.5
		var edge: Dictionary=lot.edge
		var gap: float=edge.gap
		# About one stretch in six keeps a forecourt for repair work or parking.
		var pocket:=posmod(floori(p.x/70.0)+floori(p.y/64.0)*3,6)==0
		var setback:=2.8 if pocket else .55+float(int(lot.profile)%3)*.13
		if not lot.sparse and gap>setback and gap<18.0:
			var candidate: Vector2=p-Vector2(edge.normal)*(gap-setback)
			var footprint:=Rect2(candidate-half,half*2).grow(.34)
			if clear(candidate,half) and not overlaps(footprint):
				p=candidate
				lot.moved=true
		var rect:=Rect2(p-half,half*2).grow(.34)
		if not clear(p,half) or overlaps(rect):continue
		occupy(rect)
		lot.position=p
		lot.edge=frontage(p,half)
		lot.pocket=pocket
		lots.append(lot)
	for lot: Dictionary in lots:
		var p: Vector2=lot.position
		var half: Vector2=lot.size*.5
		var stair:=Rect2(p-Vector2(half.x+1.22,half.y-.45),Vector2(1.22,half.y*2-.9))
		lot.stair_clear=not overlaps(stair,p)
	lots.sort_custom(func(a: Dictionary,b: Dictionary):return int(a.id)<int(b.id))
	return lots
