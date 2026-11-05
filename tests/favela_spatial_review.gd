extends SceneTree
## Auditoria deterministica da planta urbana, independente do rendering.
## Rodar: godot --headless --path <worktree> --script res://tests/favela_spatial_review.gd
## Mede frentes vazias e intersecoes reais entre footprints e vias.
const CELL := 32.0
const STEP := 5.0
const BASE_EXCLUSION := 85.0
var failures: Array[String] = []
var lots: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var spatial: Dictionary = {}
var footprints: Array[Rect2] = []

func _initialize() -> void:
	_run.call_deferred()

func require(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/CELL), floori(p.y/CELL))

func _register(i: int, rect: Rect2) -> void:
	var low:=_cell(rect.position)
	var high:=_cell(rect.end)
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var key:=Vector2i(x,y)
			if not spatial.has(key):spatial[key]=[]
			spatial[key].append(i)

func _nearby(p: Vector2,rings: int) -> Dictionary:
	var results: Dictionary={}
	var center:=_cell(p)
	for y in range(center.y-rings,center.y+rings+1):
		for x in range(center.x-rings,center.x+rings+1):
			for i: int in spatial.get(Vector2i(x,y),[]):results[i]=true
	return results

func _dist_rect(p: Vector2,rect: Rect2) -> float:
	var dx:=maxf(maxf(rect.position.x-p.x,0.0),p.x-rect.end.x)
	var dy:=maxf(maxf(rect.position.y-p.y,0.0),p.y-rect.end.y)
	return Vector2(dx,dy).length()

func _distance_to_houses(p: Vector2) -> float:
	var best:=INF
	for id in _nearby(p,2):
		best=minf(best,_dist_rect(p,footprints[int(id)]))
	return best

func _excluded(p: Vector2) -> bool:
	if p.x< -624.0 or p.x>624.0 or p.y< -535.0 or p.y>488.0:return true
	for base: Vector2 in WarFavelaMap.BASES_2D:
		if p.distance_to(base)<BASE_EXCLUSION:return true
	for objective: Vector2 in WarFavelaMap.OBJECTIVES_2D:
		if p.distance_to(objective)<36.0:return true
	return false

func _surface_report(road: Dictionary) -> Dictionary:
	var data: Dictionary={"samples":0,"lt2":0,"lt5":0,"lt9":0,"gt15":0,"max_gap":0.0,
		"max_at":Vector2.ZERO,"grade_max":0.0,"steep_segments":0}
	var route: Array=road.points
	var radius:=float(road.width)*.5
	for section in route.size()-1:
		var a: Vector2=route[section]
		var b: Vector2=route[section+1]
		var axis: Vector2=b-a
		if axis.length_squared()<.01:continue
		var tangent:=axis.normalized()
		var normal:=Vector2(-tangent.y,tangent.x)
		var n:=maxi(1,ceili(axis.length()/STEP))
		for i in n+1:
			var mid:=a.lerp(b,float(i)/float(n))
			if i>0:
				var before:=a.lerp(b,float(i-1)/float(n))
				var grade:=absf(WarFavelaMap.height_at(mid.x,mid.y)-WarFavelaMap.height_at(before.x,before.y))/maxf(mid.distance_to(before),.01)
				data.grade_max=maxf(float(data.grade_max),grade)
				if grade>.25:data.steep_segments=int(data.steep_segments)+1
			for side in [-1.0,1.0]:
				var p: Vector2=mid+normal*float(side)*(radius+1.50)
				if _excluded(p):continue
				var dist:=_distance_to_houses(p)
				data.samples=int(data.samples)+1
				if dist<2.0:data.lt2=int(data.lt2)+1
				if dist<5.0:data.lt5=int(data.lt5)+1
				if dist<9.0:data.lt9=int(data.lt9)+1
				if dist>15.0:data.gt15=int(data.gt15)+1
				if dist>float(data.max_gap):
					data.max_gap=dist
					data.max_at=p
	return data

func _run() -> void:
	routes=WarFavelaMap.road_envelopes()
	lots=WarFavelaMap.housing_plan()
	require(lots.size()>1200,"Poucos lotes encontrados")
	require(routes.size()>=12,"Rede viaria incompleta")
	var builder=load("res://modes/war/scripts/favela_layout.gd").new()
	builder.routes=routes
	builder.bases=WarFavelaMap.BASES_2D
	builder.objectives=WarFavelaMap.OBJECTIVES_2D
	var overlaps:=0
	var intrusions:=0
	var overhangs:=0
	var min_gap:=INF
	var high_foundation:=0
	var steep_foundation:=0
	var worst: Array=[]
	for lot: Dictionary in lots:
		var at: Vector2=lot.position
		var half: Vector2=lot.size*.5
		var rect:=Rect2(at-half,lot.size)
		for other in _nearby(at,1):
			if rect.intersects(footprints[int(other)]):
				overlaps+=1
				if worst.size()<8:worst.append({"type":"overlap","position":at,"id":lot.id})
		var edge: Dictionary=builder.frontage(at,half)
		min_gap=minf(min_gap,float(edge.gap))
		if float(edge.gap)<-.02:
			intrusions+=1
			if worst.size()<8:worst.append({"type":"street","position":at,"gap":edge.gap})
		elif float(edge.gap)<.35:overhangs+=1
		var center_height:=WarFavelaMap.height_at(at.x,at.y)
		var max_delta:=0.0
		for corner in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
			var q: Vector2=at+half*corner
			max_delta=maxf(max_delta,absf(WarFavelaMap.height_at(q.x,q.y)-center_height))
		if max_delta>3.0:high_foundation+=1
		if max_delta>7.0:steep_foundation+=1
		footprints.append(rect)
		_register(footprints.size()-1,rect)
	require(overlaps==0,"Casas com footprints sobrepostos: "+str(overlaps))
	require(intrusions==0,"Casas invadindo a pista: "+str(intrusions))
	var reports: Array[Dictionary]=[]
	var total:=0
	var close:=0
	var vacant:=0
	for road: Dictionary in routes:
		var report:=_surface_report(road)
		report.id=road.id
		report.width=road.width
		total+=int(report.samples)
		close+=int(report.lt5)
		vacant+=int(report.gt15)
		reports.append(report)
		print("FAVELA_ROAD_EDGE ",JSON.stringify(report))
	var share:float=float(close)/float(maxi(1,total))
	var vacant_share:float=float(vacant)/float(maxi(1,total))
	# Pisos/coberturas e objetos de rua exigem auditoria física separada.
	# Estes limites detectam regressão da composição urbana, não aprovam render ou FPS.
	require(total>=5000,"Amostragem das bordas insuficiente")
	require(share>=.60,"Afastamentos aumentaram: menos de 60% das bordas com casas a até 5 m")
	require(vacant_share<=.09,"Bordas vazias acima de 9%")
	require(min_gap>=.35,"Edificações invadem a reserva mínima da via")
	print("FAVELA_SPATIAL_REVIEW ",JSON.stringify({
		"lots":lots.size(),"roads":routes.size(),"overlap_lots":overlaps,
		"road_intrusions":intrusions,"gap_under_035":overhangs,
		"minimum_gap_m":min_gap,"slope_over_3m":high_foundation,
		"slope_over_7m":steep_foundation,"edge_samples":total,
		"edge_within_5m_percent":snappedf(share*100.0,.1),
		"edge_empty_over_15m_percent":snappedf(vacant_share*100.0,.1),
		"examples":worst,"failures":failures
	}))
	quit(0 if failures.is_empty() else 1)
