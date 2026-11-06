extends RefCounted
class_name WarOperation

const UKRAINE := "ukraine"
const AFGHAN := "afghan"
const FAVELA := "favela"

const DATA := {
	UKRAINE:{
		"name":"Linha de Frente",
		"map_content":"ukraine",
		"port":3014,
		"half":1750.0,
		"teams":["Ucrânia","Rússia"],
		"bases":[Vector3(-1160,18,100),Vector3(1160,18,-100)],
		"objectives":{
			"A":{"position":Vector3(-625,0,-430),"name":"Bairro oeste","active":true},
			"B":{"position":Vector3(-260,0,-115),"name":"Passagem central","active":true},
			"C":{"position":Vector3(0,0,0),"name":"Fazenda central","active":true},
			"D":{"position":Vector3(260,0,-115),"name":"Cruzamento leste","active":true},
			"E":{"position":Vector3(795,0,435),"name":"Bairro leste","active":true}},
		"transport":{
			"bike_0":[Vector3(-1080,0,100),Vector3(-560,0,0),Vector3(-260,0,-115)],
			"bike_1":[Vector3(1080,0,-100),Vector3(560,0,0),Vector3(260,0,-115)]}},
	AFGHAN:{
		"name":"Deserto Afegão",
		"map_content":"afghan",
		"port":3015,
		"half":1000.0,
		"teams":["EUA","Mujahidins"],
		# Original base coordinates are swapped: US forces occupy the lower
		# valley; Mujahideen hold the high southern massif. The new military
		# access roads start at these exact base positions.
		"bases":[Vector3(-420,0,900),Vector3(380,0,-880)],
		"armor_bays":[
			[Vector3(-410,0,905),Vector3(-385,0,908)], # USA: tank off driving lane
			[Vector3(390,0,-872),Vector3(429,0,-826)] # Mujahideen: tank at graded shoulder
		],
		"objectives":{
			"A":{"position":Vector3(-720,0,440),"name":"Qala norte","active":true},
			"B":{"position":Vector3(-340,0,570),"name":"Povoado norte","active":true},
			"C":{"position":Vector3(-260,0,70),"name":"Vila central","active":true},
			"D":{"position":Vector3(280,0,-240),"name":"Encruzilhada sul","active":true},
			"E":{"position":Vector3(450,0,-510),"name":"Povoado sul","active":true}},
		"transport":{
			"bike_0":[Vector3(-418,0,895),Vector3(-402,0,900),Vector3(-430,0,916)],
			"bike_1":[Vector3(379,0,-873),Vector3(370,0,-887),Vector3(405,0,-871)]}},
	FAVELA:{
		"name":"Favela",
		"map_content":"favela",
		"port":3017,
		"half":750.0,
		"teams":["Polícia","Bandidos"],
		"bases":[Vector3(-470,0,590),Vector3(280,0,-500)],
		"armor_bays":[[Vector3(-469,0,580),Vector3(-455,0,580)],[]],
		"objectives":{
			"A":{"position":Vector3(-265,0,345),"name":"Portal norte","active":true},
			"B":{"position":Vector3(-170,0,155),"name":"Escadaria","active":true},
			"C":{"position":Vector3(-85,0,-20),"name":"Praça central","active":true},
			"D":{"position":Vector3(270,0,-205),"name":"Lajes do alto","active":true},
			"E":{"position":Vector3(430,0,-275),"name":"Campo de futebol","active":true}},
		"transport":{
			"bike_0":[Vector3(-445,0,594),Vector3(-447,0,608),Vector3(-463,0,607)],
			"bike_1":[Vector3(284,0,-516),Vector3(295,0,-514),Vector3(302,0,-496)]}}
}

static func normalize(id: String) -> String:
	var key:=id.to_lower()
	if key in ["afghan","afghanistan","afeganistao","afeganistão"]:return AFGHAN
	if key in ["favela","war_favela","favela_guerra"]:return FAVELA
	return UKRAINE

static func data(id: String) -> Dictionary:
	return DATA[normalize(id)]

static func from_args(fallback:=UKRAINE) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--war-map="):
			return normalize(arg.trim_prefix("--war-map="))
	return normalize(str(fallback))

static func team_name(id: String,team: int) -> String:
	return str(data(id).teams[clampi(team,0,1)])

static func map_name(id: String) -> String:
	return str(data(id).name)

static func map_content(id: String) -> String:
	return str(data(id).map_content)

static func port(id: String) -> int:
	return int(data(id).port)

static func half(id: String) -> float:
	return float(data(id).half)

static func bases(id: String) -> Array:
	return data(id).bases.duplicate(true)

static func objectives(id: String) -> Dictionary:
	return data(id).objectives.duplicate(true)

static func transport(id: String) -> Dictionary:
	return data(id).transport.duplicate(true)

static func armor_heading(id: String,team: int) -> float:
	if normalize(id)==AFGHAN: return -1.72 if team==0 else -2.72
	if normalize(id)==FAVELA: return -.28 if team==0 else PI
	return -PI*.5 if team==0 else PI*.5

static func armor_bay(id: String,team: int,heavy: bool) -> Vector3:
	var operation: Dictionary=data(id)
	var clamped:=clampi(team,0,1)
	var positions: Array=operation.get("armor_bays",[])
	if positions.size()>clamped:
		var bays: Array=positions[clamped]
		if bays.size()>int(heavy): return bays[int(heavy)]
	return operation.bases[clamped]
