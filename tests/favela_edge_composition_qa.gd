extends SceneTree
const Map = preload("res://modes/war/scripts/favela_map.gd")
const Edge = preload("res://modes/war/scripts/favela_edge_composition.gd")
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func require(ok: bool,label: String) -> void:
	if not ok:failures.append(label)

func _run() -> void:
	var placements: Array[Dictionary]=Edge.generate(
		Map.road_envelopes(),Map.housing_plan(),Map.BASES_2D,Map.OBJECTIVES_2D,
		func(x: float,z: float)->float:return Map.height_at(x,z)
	)
	var counts: Dictionary={}
	var contexts: Dictionary={}
	var solid:=0
	var roadside:=0
	var min_clearance:=INF
	var max_clearance:=0.0
	var fingerprints:=PackedStringArray()
	for record: Dictionary in placements:
		var kind:=str(record.kind)
		counts[kind]=int(counts.get(kind,0))+1
		contexts[str(record.context)]=int(contexts.get(str(record.context),0))+1
		if bool(record.solid):solid+=1
		if int(record.road)>=0:
			roadside+=1
			var clearance:=float(record.road_clearance)
			min_clearance=minf(min_clearance,clearance)
			max_clearance=maxf(max_clearance,clearance)
		var p: Vector3=record.position
		fingerprints.append("%s:%.2f:%.2f:%.2f"%[kind,p.x,p.y,p.z])
	var again: Array[Dictionary]=Edge.generate(
		Map.road_envelopes(),Map.housing_plan(),Map.BASES_2D,Map.OBJECTIVES_2D,
		func(x: float,z: float)->float:return Map.height_at(x,z)
	)
	var fingerprints_again:=PackedStringArray()
	for record: Dictionary in again:
		var p: Vector3=record.position
		fingerprints_again.append("%s:%.2f:%.2f:%.2f"%[str(record.kind),p.x,p.y,p.z])

	require(placements.size()>=250,"edge composition too sparse")
	require(placements.size()<=1800,"edge composition exceeds visual budget")
	require(roadside>=200,"too few functional roadside modules")
	require(solid<=220,"too many new structural colliders")
	require(min_clearance>=.47,"road reserve below 47 cm")
	require(max_clearance<=3.5,"facade snap moved detail implausibly far from road edge")
	require(counts.get("favela_canaleta_drenagem",0)>=45,"drainage coverage too low")
	require(counts.get("favela_muro_contencao",0)>=15,"retaining wall coverage too low")
	require(counts.get("favela_portao_grade",0)>=25,"residential edge coverage too low")
	require(counts.get("favela_tubulacao_externa",0)>=25,"service facade coverage too low")
	require(counts.get("favela_corrimao_beco",0)>=8,"pedestrian slope coverage too low")
	require(counts.get("favela_barraca_rua",0)>=3,"commercial pocket coverage too low")
	require(counts.get("favela_antena_parabolica",0)>=100,"roof silhouette coverage too low")
	require(fingerprints==fingerprints_again,"composition is not deterministic")
	require(contexts.size()>=7,"urban grammar contexts collapsed")
	print("FAVELA_EDGE_COMPOSITION ",JSON.stringify({
		"placements":placements.size(),"roadside":roadside,"solid":solid,
		"min_road_clearance":min_clearance,"max_road_clearance":max_clearance,
		"counts":counts,"contexts":contexts
	}))
	if failures.is_empty():
		print("FAVELA_EDGE_COMPOSITION PASS")
		quit(0)
	else:
		for problem in failures:printerr("FAVELA_EDGE_COMPOSITION FAIL: "+problem)
		quit(1)
