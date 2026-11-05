extends SceneTree
## Structural QA for maximum-detail Favela density work.
## Read-only: checks deterministic lot plan and roadside occupation.
const Map = preload("res://modes/war/scripts/favela_map.gd")
const CELL := 32.0
const SAMPLE_STEP := 5.0
var failures: Array[String]=[]
var occupied: Dictionary={}
var rects: Array[Rect2]=[]

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool,label: String) -> void:
	if not ok: failures.append(label)

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.y/CELL))

func _register(index: int,rect: Rect2) -> void:
	var lo:=_cell(rect.position)
	var hi:=_cell(rect.end)
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var key:=Vector2i(x,z)
			if not occupied.has(key):occupied[key]=[]
			occupied[key].append(index)

func _near(p: Vector2,radius:=2) -> Array:
	var ids: Dictionary={}
	var c:=_cell(p)
	for z in range(c.y-radius,c.y+radius+1):
		for x in range(c.x-radius,c.x+radius+1):
			for index: int in occupied.get(Vector2i(x,z),[]):ids[index]=true
	return ids.keys()

func _rect_distance(p: Vector2,r: Rect2) -> float:
	var dx:=maxf(maxf(r.position.x-p.x,0.0),p.x-r.end.x)
	var dz:=maxf(maxf(r.position.y-p.y,0.0),p.y-r.end.y)
	return Vector2(dx,dz).length()

func _house_distance(p: Vector2) -> float:
	var best:=INF
	for index in _near(p):
		best=minf(best,_rect_distance(p,rects[int(index)]))
	return best

func _protected(p: Vector2) -> bool:
	for base: Vector2 in Map.BASES_2D:
		if p.distance_to(base)<78.0:return true
	for objective: Vector2 in Map.OBJECTIVES_2D:
		if p.distance_to(objective)<35.0:return true
	return false

func _run() -> void:
	var catalog_ids: Array[String]=["favela_caixa_dagua","favela_ar_condicionado","favela_varal","favela_kit_obra","favela_caixa_eletrica","favela_toldo"]
	for id: String in catalog_ids:
		require(WarPrefabFactory.ITEMS.has(id),"missing prefab catalog id: "+id)
		var prefab:=WarPrefabFactory.create(id)
		require(is_instance_valid(prefab),"prefab cannot instantiate: "+id)
		if is_instance_valid(prefab):
			require(str(prefab.get_meta("library_id",""))==id,"wrong library id: "+id)
			require(prefab.find_children("*","MeshInstance3D",true,false).size()>0,"prefab has no mesh: "+id)
			prefab.free()
	var lots: Array[Dictionary]=Map.housing_plan()
	var overlap:=0
	var infill:=0
	var compact:=0
	var minimum_gap:=INF
	for lot: Dictionary in lots:
		var p: Vector2=lot.position
		var half: Vector2=lot.size*.5
		var rect:=Rect2(p-half,lot.size).grow(.34)
		for index in _near(p,1):
			if rect.intersects(rects[int(index)]):overlap+=1
		rects.append(rect)
		_register(rects.size()-1,rect)
		minimum_gap=minf(minimum_gap,float(lot.edge.gap))
		if bool(lot.get("infill",false)):infill+=1
		if float(lot.edge.gap)<1.6:compact+=1
	var samples:=0
	var within2:=0
	var within5:=0
	var beyond15:=0
	var worst:=0.0
	var worst_at:=Vector2.ZERO
	for road: Dictionary in Map.road_envelopes():
		var route: Array=road.points
		var road_radius:=float(road.width)*.5
		for section in route.size()-1:
			var a: Vector2=route[section]
			var b: Vector2=route[section+1]
			var axis:=b-a
			if axis.length()<.1:continue
			var tangent:=axis.normalized()
			var normal:=Vector2(-tangent.y,tangent.x)
			var count:=maxi(1,ceili(axis.length()/SAMPLE_STEP))
			for i in count+1:
				var center:=a.lerp(b,float(i)/float(count))
				for side: float in [-1.0,1.0]:
					var at:=center+normal*side*(road_radius+1.5)
					if _protected(at):continue
					var gap:=_house_distance(at)
					samples+=1
					if gap<2.0:within2+=1
					if gap<5.0:within5+=1
					if gap>15.0:beyond15+=1
					if gap>worst:worst=gap;worst_at=at
	var report={
		"lots":lots.size(),"infill":infill,"compact":compact,"overlap":overlap,
		"minimum_road_gap":minimum_gap,"samples":samples,
		"within_2m_percent":snappedf(float(within2)/maxf(1.0,samples)*100.0,.1),
		"within_5m_percent":snappedf(float(within5)/maxf(1.0,samples)*100.0,.1),
		"beyond_15m_percent":snappedf(float(beyond15)/maxf(1.0,samples)*100.0,.1),
		"worst_gap":worst,"worst_at":worst_at,
	}
	print("FAVELA_DETAIL_DENSITY ",JSON.stringify(report))
	require(overlap==0,"lot footprints overlap")
	require(minimum_gap>=.38,"building footprint violates road reserve")
	require(lots.size()>=4100,"frontage infill density regressed")
	require(infill>=250,"too few structural infill lots")
	require(float(within5)/maxf(1.0,samples)>=.80,"less than 80% of road edges have buildings within 5 m")
	require(float(beyond15)/maxf(1.0,samples)<=.03,"more than 3% of road edges remain over 15 m from buildings")
	require(samples>=5000,"roadside sample count too small")
	if failures.is_empty():
		print("FAVELA_DETAIL_MAX PASS")
		quit(0)
	else:
		for problem in failures:printerr("FAVELA_DETAIL_MAX FAIL: "+problem)
		quit(1)
