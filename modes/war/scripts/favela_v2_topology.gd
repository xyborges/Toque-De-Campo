extends RefCounted
## Favela V2 / fase 1 — desenho de circulacao, sem alterar a Favela publica.
## Coordenadas em metros no plano X/Z. Curvas sao vias; morros sao limites,
## NUNCA atalhos. Morro oeste comunica-se SOMENTE com o miolo central.
const BOUNDS := Rect2(Vector2(-310,-335),Vector2(640,670))
## Mode Guerra team base anchors (future spawn integration):
## Team 1 POLICIA starts at the bottom, Team 2 TRAFICANTES at the summit.
const TEAM_BASES := {1:"base_sul",2:"base_norte"}
const TEAM_LABELS := {1:"Policia",2:"Traficantes"}
const SECTOR_LEFT := "morro_esquerdo"
const SECTOR_CORE := "miolo"
const SECTOR_RIGHT := "leste"
const NODES := {
	"base_sul": {"p":Vector2(-223.2,254.4),"zone":"base"},
	"rua_baixa": {"p":Vector2(-162.05,217.3),"zone":"baixada"},
	"curva_entrada": {"p":Vector2(-126.85,143.1),"zone":"baixada"},
	"praca": {"p":Vector2(-66.3,111.3),"zone":"miolo","feature":"praca"},
	"central_hub": {"p":Vector2(-27.15,31.8),"zone":"miolo"},
	"mercadinho": {"p":Vector2(33.3,-58.3),"zone":"miolo","feature":"comercio"},
	"escada_central": {"p":Vector2(-26.5,-121.9),"zone":"miolo","feature":"escada"},
	"retorno_alto": {"p":Vector2(92.2,-164.3),"zone":"miolo"},
	"rua_norte": {"p":Vector2(-17.5,-201.4),"zone":"miolo"},
	"acesso_norte": {"p":Vector2(-78.75,-222.6),"zone":"miolo"},
	"base_norte": {"p":Vector2(-147.88,-292.56),"zone":"base"},
	"campinho": {"p":Vector2(95.1,106),"zone":"leste","feature":"campo"},
	"curva_leste": {"p":Vector2(190.35,63.6),"zone":"leste"},
	"beco_leste": {"p":Vector2(211.8,-37.1),"zone":"leste"},
	"praceta_leste": {"p":Vector2(171.75,-127.2),"zone":"leste","feature":"praceta"},
	"portal_oeste": {"p":Vector2(-92.35,15.9),"zone":"morro_esquerdo"},
	"beco_baixo": {"p":Vector2(-136.15,47.7),"zone":"morro_esquerdo"},
	"escada_sul": {"p":Vector2(-187.6,58.3),"zone":"morro_esquerdo","feature":"escada"},
	"patio_oeste": {"p":Vector2(-205.86,-5.3),"zone":"morro_esquerdo","feature":"patio"},
	"escada_longa": {"p":Vector2(-179.54,-72.08),"zone":"morro_esquerdo","feature":"escada"},
	"plato_casas": {"p":Vector2(-147.1,-121.9),"zone":"morro_esquerdo","feature":"plato"},
	"mirante": {"p":Vector2(-197.7,-148.4),"zone":"morro_esquerdo","feature":"mirante"},
	"beco_meio": {"p":Vector2(-118.79,-58.3),"zone":"morro_esquerdo"},
	"escada_curta": {"p":Vector2(-127.1,-109.18),"zone":"morro_esquerdo","feature":"escada"},
	"plato_telha": {"p":Vector2(-171.25,-174.9),"zone":"morro_esquerdo","feature":"plato"}
}
## Rotas de pedestres sao conexoes EXPLICITAS. O AStar nunca deve converter
## a silhueta dos morros em vias nem ligar dois caminhos apenas por proximidade.
const LINKS := [
	{"id":"s01","a":"base_sul","b":"rua_baixa","kind":"rua","width":6.0,"via":[Vector2(-194.48,237.44)]},
	{"id":"s02","a":"rua_baixa","b":"curva_entrada","kind":"rua","width":6.0,"via":[Vector2(-147.32,175.96)]},
	{"id":"s03","a":"curva_entrada","b":"praca","kind":"rua","width":5.5,"via":[Vector2(-102.42,146.28)]},
	{"id":"c01","a":"praca","b":"central_hub","kind":"beco","width":3.8,"via":[Vector2(-54.8,68.9)]},
	{"id":"c02","a":"central_hub","b":"mercadinho","kind":"beco","width":3.2,"via":[Vector2(12.1,10.6),Vector2(38.17,-24.38)]},
	{"id":"c03","a":"mercadinho","b":"retorno_alto","kind":"rua","width":5.2,"via":[Vector2(55.69,-108.12)]},
	{"id":"c04","a":"retorno_alto","b":"rua_norte","kind":"rua","width":5.0,"via":[Vector2(61.18,-209.88),Vector2(19.81,-217.3)]},
	{"id":"c05","a":"rua_norte","b":"acesso_norte","kind":"beco","width":3.7,"via":[Vector2(-52.36,-213.06)]},
	{"id":"c06","a":"acesso_norte","b":"base_norte","kind":"rua","width":5.5,"via":[Vector2(-107.24,-249.1),Vector2(-129.2,-268.18)]},
	{"id":"c07","a":"central_hub","b":"escada_central","kind":"escada","width":2.6,"via":[Vector2(-15.19,-26.5),Vector2(-31.66,-76.32)]},
	{"id":"c08","a":"escada_central","b":"rua_norte","kind":"beco","width":2.6,"via":[Vector2(-7.75,-163.24)]},
	{"id":"r01","a":"praca","b":"campinho","kind":"rua","width":6.0,"via":[Vector2(-29.1,137.8),Vector2(18.2,157.94),Vector2(62.02,137.8)]},
	{"id":"r02","a":"campinho","b":"curva_leste","kind":"rua","width":5.7,"via":[Vector2(127.82,148.4),Vector2(176.74,118.72)]},
	{"id":"r03","a":"curva_leste","b":"beco_leste","kind":"rua","width":5.1,"via":[Vector2(214.46,22.26)]},
	{"id":"r04","a":"beco_leste","b":"praceta_leste","kind":"beco","width":3.8,"via":[Vector2(204.83,-87.98)]},
	{"id":"r05","a":"praceta_leste","b":"retorno_alto","kind":"rua","width":5.1,"via":[Vector2(136.5,-117.66)]},
	{"id":"r06","a":"campinho","b":"mercadinho","kind":"escada","width":3.0,"via":[Vector2(82.32,41.34),Vector2(57.55,-18.02)]},
	{"id":"l00","a":"central_hub","b":"portal_oeste","kind":"beco","width":2.7,"via":[Vector2(-56.12,9.54)]},
	{"id":"l01","a":"portal_oeste","b":"beco_baixo","kind":"beco","width":2.4,"via":[Vector2(-110.16,37.1)]},
	{"id":"l02","a":"beco_baixo","b":"escada_sul","kind":"escada","width":2.3,"via":[Vector2(-165.28,74.2)]},
	{"id":"l03","a":"escada_sul","b":"patio_oeste","kind":"escada","width":2.7,"via":[Vector2(-202.09,26.5)]},
	{"id":"l04","a":"patio_oeste","b":"escada_longa","kind":"escada","width":2.4,"via":[Vector2(-191.42,-38.16)]},
	{"id":"l05","a":"escada_longa","b":"plato_casas","kind":"beco","width":2.3,"via":[Vector2(-156.01,-96.46)]},
	{"id":"l06","a":"plato_casas","b":"mirante","kind":"beco","width":2.2,"via":[Vector2(-174.66,-138.86)]},
	{"id":"l07","a":"plato_casas","b":"plato_telha","kind":"escada","width":2.2,"via":[Vector2(-159.58,-153.7)]},
	{"id":"l08","a":"portal_oeste","b":"beco_meio","kind":"beco","width":2.0,"via":[Vector2(-104.95,-14.84)]},
	{"id":"l09","a":"beco_meio","b":"escada_curta","kind":"escada","width":2.2,"via":[Vector2(-134.79,-82.68)]},
	{"id":"l10","a":"escada_curta","b":"plato_casas","kind":"beco","width":2.0,"via":[Vector2(-137.03,-110.24)]},
	{"id":"l11","a":"beco_meio","b":"beco_baixo","kind":"beco","width":2.0,"via":[Vector2(-144.34,-4.24)]}
]
## Orange contours in the sketch are LANDSCAPE, not a graph connection.
# Hills are continuous physical slopes, never enclosing contour rings.
const HILL_CONTOURS := []
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
