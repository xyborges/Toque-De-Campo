extends RefCounted
class_name WarOperation

const UKRAINE := "ukraine"
const AFGHAN := "afghan"

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
		"bases":[Vector3(380,0,-880),Vector3(-420,0,900)],
		"objectives":{
			"A":{"position":Vector3(-720,0,440),"name":"Qala norte","active":true},
			"B":{"position":Vector3(-340,0,570),"name":"Povoado norte","active":true},
			"C":{"position":Vector3(-260,0,70),"name":"Vila central","active":true},
			"D":{"position":Vector3(280,0,-240),"name":"Encruzilhada sul","active":true},
			"E":{"position":Vector3(450,0,-510),"name":"Povoado sul","active":true}},
		"transport":{
			"bike_0":[Vector3(400,0,-850),Vector3(610,0,-340),Vector3(280,0,-240)],
			"bike_1":[Vector3(-400,0,870),Vector3(-430,0,515),Vector3(-260,0,70)]}}
}

static func normalize(id: String) -> String:
	return AFGHAN if id.to_lower() in ["afghan","afghanistan","afeganistao","afeganistão"] else UKRAINE

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
