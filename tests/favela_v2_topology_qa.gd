extends SceneTree
## Etapa 1: primeiro valida fluxo e limites, depois cria casas/terreno.
const TOPO := preload("res://modes/war/scripts/favela_v2_topology.gd")
var checks:=0
var errors: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func check(valid: bool,label: String) -> void:
	checks+=1
	if not valid:errors.append(label)

func _run() -> void:
	check(TOPO.NODES.size()>=24,"setores e pontos do esboco documentados")
	check(TOPO.LINKS.size()>=28,"rede de becos/ruas fragmentada")
	check(TOPO.BOUNDS.size.x<950 and TOPO.BOUNDS.size.y<700,"layout compacto")
	var ids: Dictionary={}
	var left_nodes: Array[String]=[]
	var right_nodes: Array[String]=[]
	var stairs:=0
	var max_span:=0.0
	for node_id: String in TOPO.NODES.keys():
		var node: Dictionary=TOPO.NODES[node_id]
		var xy: Vector2=node["p"]
		check(TOPO.BOUNDS.has_point(xy),"ponto fora do mapa: "+node_id)
		if str(node["zone"])==TOPO.SECTOR_LEFT:left_nodes.append(node_id)
		elif str(node["zone"])==TOPO.SECTOR_RIGHT:right_nodes.append(node_id)
	var width_error:=0
	var direct_motor_access_left:=0
	for edge: Dictionary in TOPO.LINKS:
		var id: String=edge["id"]
		check(not ids.has(id),"id de via unico "+id)
		ids[id]=true
		check(TOPO.NODES.has(str(edge["a"])) and TOPO.NODES.has(str(edge["b"])),
			"extremos conhecidos "+id)
		check(str(edge["a"])!=str(edge["b"]),"rota nao dobra em si "+id)
		var lane:=TOPO.polyline(edge)
		check(lane.size()>=2,"rota fisica "+id)
		for j in lane.size()-1:
			var span:=lane[j].distance_to(lane[j+1])
			max_span=maxf(max_span,span)
			check(span<=97.0,"nenhum trecho reto acima de 97 m: "+id+"/"+str(j))
		var w: float=edge["width"]
		if str(edge["kind"])=="escada":
			stairs+=1
			if w<1.8 or w>3.2:width_error+=1
		elif str(edge["kind"])=="beco":
			if w<1.8 or w>4.0:width_error+=1
		elif str(edge["kind"])=="rua":
			if w<4.5 or w>7.2:width_error+=1
		else:
			errors.append("tipo de circulacao invalido: "+id)
		var a_left:=left_nodes.has(str(edge["a"]))
		var b_left:=left_nodes.has(str(edge["b"]))
		if (a_left or b_left) and str(edge["kind"])=="rua":direct_motor_access_left+=1
	check(width_error==0,"larguras adequadas ao tipo de via")
	check(direct_motor_access_left==0,"morro esquerdo exclusivamente pedonal")
	check(stairs>=7,"escadoes em vez de retona")
	var gateways: Array[Dictionary]=TOPO.left_gate_links()
	check(gateways.size()==1,"MORRO ESQUERDO COM EXATAMENTE UMA LIGACAO EXTERNA")
	if gateways.size()==1:
		check(str(gateways[0]["id"])=="l00","unica entrada pelo miolo")
		check(str(gateways[0]["a"])=="central_hub","entrada apenas pelo centro")
		check(str(gateways[0]["b"])=="portal_oeste","entrada termina no portal oeste")
	check(TOPO.reachable("base_sul","base_norte"),"ligacao entre bases pelo miolo")
	check(TOPO.reachable("base_sul","base_norte","portal_oeste"),
		"rota entre bases independe inteiramente do morro esquerdo")
	check(TOPO.reachable("base_sul","base_norte","central_hub"),
		"rota secundaria real pelo lado direito sem cruzar o morro")
	check(TOPO.reachable("portal_oeste","mirante"),"vielas do morro conectadas internamente")
	check(TOPO.reachable("portal_oeste","plato_telha"),"platô alto acessivel")
	check(not TOPO.reachable("mirante","base_norte","central_hub"),
		"NUNCA ligar casas do morro à base superior fora do miolo")
	check(not TOPO.reachable("plato_telha","base_sul","central_hub"),
		"morro isolado se a unica entrada do miolo for removida")
	var shortest:=TOPO.shortest_path("base_sul","base_norte")
	check(shortest.size()>=6,"evitar rota reta de poucos nos")
	for node_id: String in shortest:
		check(not left_nodes.has(node_id),"shortest path nunca entra no morro esquerdo")
	var direct: float=TOPO.NODES["base_sul"]["p"].distance_to(TOPO.NODES["base_norte"]["p"])
	var route_m:=TOPO.path_meters(shortest)
	check(route_m>direct*1.15,"rota principal suficientemente sinuosa")
	check(left_nodes.size()>=9 and right_nodes.size()>=4,"densidade setorial")
	check(TOPO.FEATURE_CANDIDATES.size()>=4,"praça, campo e áreas de surpresa")
	var accidental_crossings: Array[String]=[]
	for ai in TOPO.LINKS.size():
		var ra: Dictionary=TOPO.LINKS[ai]
		var pa:=TOPO.polyline(ra)
		for bi in range(ai+1,TOPO.LINKS.size()):
			var rb: Dictionary=TOPO.LINKS[bi]
			var pb:=TOPO.polyline(rb)
			var shared: Array[String]=[]
			for endpoint in [str(ra["a"]),str(ra["b"])]:
				if endpoint in [str(rb["a"]),str(rb["b"])]:shared.append(endpoint)
			for ia in pa.size()-1:
				for ib in pb.size()-1:
					var crossing: Variant=Geometry2D.segment_intersects_segment(pa[ia],pa[ia+1],pb[ib],pb[ib+1])
					if crossing is Vector2:
						var intentional:=false
						for node_id: String in shared:
							if crossing.distance_to(TOPO.NODES[node_id]["p"])<2.0:intentional=true
						if not intentional:
							accidental_crossings.append(str(ra["id"])+"/"+str(rb["id"])+" @"+str(crossing))
	check(accidental_crossings.is_empty(),"vias nao devem cruzar sem entroncamento registrado")
	print("FAVELA_V2_TOPOLOGY_QA ",JSON.stringify({
		"pass":errors.is_empty(),"checks":checks,"nodes":TOPO.NODES.size(),
		"routes":TOPO.LINKS.size(),"left_nodes":left_nodes.size(),
		"west_gateways":gateways.size(),"stairs":stairs,"max_line_m":max_span,
		"bounds_m":TOPO.BOUNDS.size,"base_direct_m":direct,
		"base_route_m":route_m,"base_route_nodes":shortest,
		"unplanned_crossings":accidental_crossings.slice(0,16),
		"errors":errors.slice(0,18)}))
	quit(0 if errors.is_empty() else 1)
