extends RefCounted
## Favela V2 / fase 1 — desenho de circulacao, sem alterar a Favela publica.
## Coordenadas em metros no plano X/Z. Curvas sao vias; morros sao limites,
## NUNCA atalhos. Morro oeste comunica-se SOMENTE com o miolo central.
const BOUNDS := Rect2(Vector2(-425,-300),Vector2(850,600))
## Mode Guerra team base anchors (future spawn integration):
## Team 1 POLICIA starts at the bottom, Team 2 TRAFICANTES at the summit.
const TEAM_BASES := {1:"base_sul",2:"base_norte"}
const TEAM_LABELS := {1:"Policia",2:"Traficantes"}
const SECTOR_LEFT := "morro_esquerdo"
const SECTOR_CORE := "miolo"
const SECTOR_RIGHT := "leste"
const NODES := {
	"base_sul": {"p":Vector2(-320,240),"zone":"base"},
	"rua_baixa": {"p":Vector2(-235,205),"zone":"baixada"},
	"curva_entrada": {"p":Vector2(-195,135),"zone":"baixada"},
	"praca": {"p":Vector2(-110,105),"zone":"miolo","feature":"praca"},
	"central_hub": {"p":Vector2(-65,30),"zone":"miolo"},
	"mercadinho": {"p":Vector2(10,-55),"zone":"miolo","feature":"comercio"},
	"escada_central": {"p":Vector2(-90,-115),"zone":"miolo","feature":"escada"},
	"retorno_alto": {"p":Vector2(80,-155),"zone":"miolo"},
	"rua_norte": {"p":Vector2(-90,-190),"zone":"miolo"},
	"acesso_norte": {"p":Vector2(-185,-175),"zone":"miolo"},
	"base_norte": {"p":Vector2(-300,-248),"zone":"base"},
	"campinho": {"p":Vector2(130,100),"zone":"leste","feature":"campo"},
	"curva_leste": {"p":Vector2(265,60),"zone":"leste"},
	"beco_leste": {"p":Vector2(280,-35),"zone":"leste"},
	"praceta_leste": {"p":Vector2(205,-120),"zone":"leste","feature":"praceta"},
	"portal_oeste": {"p":Vector2(-165,15),"zone":"morro_esquerdo"},
	"beco_baixo": {"p":Vector2(-225,45),"zone":"morro_esquerdo"},
	"escada_sul": {"p":Vector2(-300,55),"zone":"morro_esquerdo","feature":"escada"},
	"patio_oeste": {"p":Vector2(-338,-5),"zone":"morro_esquerdo","feature":"patio"},
	"escada_longa": {"p":Vector2(-310,-68),"zone":"morro_esquerdo","feature":"escada"},
	"plato_casas": {"p":Vector2(-270,-115),"zone":"morro_esquerdo","feature":"plato"},
	"mirante": {"p":Vector2(-350,-140),"zone":"morro_esquerdo","feature":"mirante"},
	"beco_meio": {"p":Vector2(-217,-55),"zone":"morro_esquerdo"},
	"escada_curta": {"p":Vector2(-238,-103),"zone":"morro_esquerdo","feature":"escada"},
	"plato_telha": {"p":Vector2(-315,-165),"zone":"morro_esquerdo","feature":"plato"}
}
## Rotas de pedestres sao conexoes EXPLICITAS. O AStar nunca deve converter
## a silhueta dos morros em vias nem ligar dois caminhos apenas por proximidade.
const LINKS := [
	{"id":"s01","a":"base_sul","b":"rua_baixa","kind":"rua","width":6.0,"via":[Vector2(-280,224)]},
	{"id":"s02","a":"rua_baixa","b":"curva_entrada","kind":"rua","width":6.0,"via":[Vector2(-220,166)]},
	{"id":"s03","a":"curva_entrada","b":"praca","kind":"rua","width":5.5,"via":[Vector2(-158,138)]},
	{"id":"c01","a":"praca","b":"central_hub","kind":"beco","width":3.8,"via":[Vector2(-100,65)]},
	{"id":"c02","a":"central_hub","b":"mercadinho","kind":"beco","width":3.2,"via":[Vector2(-10,10),Vector2(23,-23)]},
	{"id":"c03","a":"mercadinho","b":"retorno_alto","kind":"rua","width":5.2,"via":[Vector2(35,-102)]},
	{"id":"c04","a":"retorno_alto","b":"rua_norte","kind":"rua","width":5.0,"via":[Vector2(26,-198),Vector2(-37,-205)]},
	{"id":"c05","a":"rua_norte","b":"acesso_norte","kind":"beco","width":3.7,"via":[Vector2(-144,-192)]},
	{"id":"c06","a":"acesso_norte","b":"base_norte","kind":"rua","width":5.5,"via":[Vector2(-232,-201),Vector2(-268,-226)]},
	{"id":"c07","a":"central_hub","b":"escada_central","kind":"escada","width":2.6,"via":[Vector2(-57,-25),Vector2(-90,-72)]},
	{"id":"c08","a":"escada_central","b":"rua_norte","kind":"beco","width":2.6,"via":[Vector2(-69,-154)]},
	{"id":"r01","a":"praca","b":"campinho","kind":"rua","width":6.0,"via":[Vector2(-50,130),Vector2(24,149),Vector2(86,130)]},
	{"id":"r02","a":"campinho","b":"curva_leste","kind":"rua","width":5.7,"via":[Vector2(186,140),Vector2(254,112)]},
	{"id":"r03","a":"curva_leste","b":"beco_leste","kind":"rua","width":5.1,"via":[Vector2(294,21)]},
	{"id":"r04","a":"beco_leste","b":"praceta_leste","kind":"beco","width":3.8,"via":[Vector2(261,-83)]},
	{"id":"r05","a":"praceta_leste","b":"retorno_alto","kind":"rua","width":5.1,"via":[Vector2(154,-111)]},
	{"id":"r06","a":"campinho","b":"mercadinho","kind":"escada","width":3.0,"via":[Vector2(100,39),Vector2(53,-17)]},
	{"id":"l00","a":"central_hub","b":"portal_oeste","kind":"beco","width":2.7,"via":[Vector2(-112,9)]},
	{"id":"l01","a":"portal_oeste","b":"beco_baixo","kind":"beco","width":2.4,"via":[Vector2(-188,35)]},
	{"id":"l02","a":"beco_baixo","b":"escada_sul","kind":"escada","width":2.3,"via":[Vector2(-264,70)]},
	{"id":"l03","a":"escada_sul","b":"patio_oeste","kind":"escada","width":2.7,"via":[Vector2(-327,25)]},
	{"id":"l04","a":"patio_oeste","b":"escada_longa","kind":"escada","width":2.4,"via":[Vector2(-322,-36)]},
	{"id":"l05","a":"escada_longa","b":"plato_casas","kind":"beco","width":2.3,"via":[Vector2(-279,-91)]},
	{"id":"l06","a":"plato_casas","b":"mirante","kind":"beco","width":2.2,"via":[Vector2(-314,-131)]},
	{"id":"l07","a":"plato_casas","b":"plato_telha","kind":"escada","width":2.2,"via":[Vector2(-294,-145)]},
	{"id":"l08","a":"portal_oeste","b":"beco_meio","kind":"beco","width":2.0,"via":[Vector2(-189,-14)]},
	{"id":"l09","a":"beco_meio","b":"escada_curta","kind":"escada","width":2.2,"via":[Vector2(-245,-78)]},
	{"id":"l10","a":"escada_curta","b":"plato_casas","kind":"beco","width":2.0,"via":[Vector2(-253,-104)]},
	{"id":"l11","a":"beco_meio","b":"beco_baixo","kind":"beco","width":2.0,"via":[Vector2(-246,-4)]}
]
## Orange contours in the sketch are LANDSCAPE, not a graph connection.
const HILL_CONTOURS := [
	{"center":Vector2(-427,18),"radius":Vector2(78,185)},
	{"center":Vector2(-366,-257),"radius":Vector2(150,74)},
	{"center":Vector2(12,-291),"radius":Vector2(234,58)},
	{"center":Vector2(394,-112),"radius":Vector2(87,151)},
	{"center":Vector2(342,256),"radius":Vector2(196,83)},
	{"center":Vector2(-18,307),"radius":Vector2(165,52)}
]
## Areas are suggestions until final capture/respawn rules are approved.
const FEATURE_CANDIDATES := [
	{"node":"praca","label":"Praça improvisada"},
	{"node":"campinho","label":"Campinho"},
	{"node":"mercadinho","label":"Comércio / esquina"},
	{"node":"patio_oeste","label":"Pátio do morro"},
	{"node":"mirante","label":"Mirante e platôs"}
]

static func polyline(link: Dictionary) -> PackedVector2Array:
	var points:=PackedVector2Array()
	points.append(NODES[str(link["a"])]["p"])
	for point: Vector2 in link.get("via",[]):
		points.append(point)
	points.append(NODES[str(link["b"])]["p"])
	return points

static func length_of(link: Dictionary) -> float:
	var points:=polyline(link)
	var meters:=0.0
	for i in points.size()-1:meters+=points[i].distance_to(points[i+1])
	return meters

static func left_gate_links() -> Array[Dictionary]:
	var exits: Array[Dictionary]=[]
	for link: Dictionary in LINKS:
		var from_left:=str(NODES[str(link["a"])]["zone"])==SECTOR_LEFT
		var to_left:=str(NODES[str(link["b"])]["zone"])==SECTOR_LEFT
		if from_left!=to_left:exits.append(link)
	return exits

static func reachable(start: String,goal: String,removed_node: String="") -> bool:
	if not NODES.has(start) or not NODES.has(goal):return false
	if start==removed_node or goal==removed_node:return false
	var queue: Array[String]=[start]
	var visited: Dictionary={start:true}
	var index:=0
	while index<queue.size():
		var current: String=queue[index]
		index+=1
		if current==goal:return true
		for link: Dictionary in LINKS:
			var other: String=""
			if str(link["a"])==current:other=str(link["b"])
			elif str(link["b"])==current:other=str(link["a"])
			if other.is_empty() or other==removed_node or visited.has(other):continue
			visited[other]=true
			queue.append(other)
	return false

static func shortest_path(start: String,goal: String,removed_node: String="") -> PackedStringArray:
	var path:=PackedStringArray()
	if not NODES.has(start) or not NODES.has(goal):return path
	if start==removed_node or goal==removed_node:return path
	var parents: Dictionary={start:""}
	var distance: Dictionary={start:0.0}
	var pending: Array[String]=[start]
	while not pending.is_empty():
		pending.sort_custom(func(a:String,b:String)->bool:return float(distance[a])<float(distance[b]))
		var current: String=pending.pop_front()
		if current==goal:break
		for link: Dictionary in LINKS:
			var other: String=""
			if str(link["a"])==current:other=str(link["b"])
			elif str(link["b"])==current:other=str(link["a"])
			if other.is_empty() or other==removed_node:continue
			var alt: float=float(distance[current])+length_of(link)
			if not distance.has(other) or alt<float(distance[other]):
				distance[other]=alt
				parents[other]=current
				if not pending.has(other):pending.append(other)
	if not parents.has(goal):return path
	var current:=goal
	while not current.is_empty():
		path.insert(0,current)
		current=str(parents[current])
	return path

static func path_meters(route: PackedStringArray) -> float:
	var total:=0.0
	for i in route.size()-1:
		for link: Dictionary in LINKS:
			if (str(link["a"])==route[i] and str(link["b"])==route[i+1]) or (str(link["b"])==route[i] and str(link["a"])==route[i+1]):
				total+=length_of(link)
				break
	return total
