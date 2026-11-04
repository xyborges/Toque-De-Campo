extends RefCounted
class_name NavalCatalog

const PROTOCOL := 9
const PORT := 3012
const SERVER := "192.168.101.24"
const LIMIT := 6
const STEP := 1.0/30.0
const MAP_LIMIT := 980.0
const SHIPS := {
	"light":{"name":"Patrulheiro leve","hp":100.0,"speed":28.0,"turn":1.25,"accel":5.2,"length":9.0,"width":3.6,"height":1.0,"price":0,"weapons":["lightMG"]},
	"combat":{"name":"Corveta","hp":160.0,"speed":22.0,"turn":0.85,"accel":3.6,"length":15.0,"width":4.6,"height":1.4,"price":1200,"weapons":["lightMG","heavyMG","missile"]},
	"heavy":{"name":"Destróier","hp":240.0,"speed":16.0,"turn":0.56,"accel":2.6,"length":22.0,"width":5.8,"height":1.7,"price":2600,"weapons":["lightMG","heavyMG","missile","torpedo"]},
	"assault":{"name":"Navio de assalto","hp":320.0,"speed":12.0,"turn":0.40,"accel":1.8,"length":25.0,"width":7.2,"height":1.9,"price":3900,"weapons":["lightMG","heavyMG","missile","torpedo"]},
	"submarine":{"name":"Submarino","hp":210.0,"speed":18.0,"turn":0.65,"accel":2.5,"length":29.0,"width":5.4,"height":1.0,"price":5200,"weapons":["lightMG","heavyMG","missile","torpedo"]}}
const WEAPONS := {
	"lightMG":{"name":"Metralhadora leve","damage":4.0,"cadence":0.105,"speed":620.0,"gravity":12.0,"ammo":600,"reload":3.0,"range":1450.0,"life":7.0,"yaw":PI,"min_pitch":-0.15,"max_pitch":0.58,"turn":2.6,"barrel":1.2,"color":Color("ffd66b")},
	"heavyMG":{"name":"Metralhadora pesada","damage":9.0,"cadence":0.34,"speed":470.0,"gravity":16.0,"ammo":240,"reload":5.0,"range":1250.0,"life":7.0,"yaw":PI,"min_pitch":-0.12,"max_pitch":0.52,"turn":1.8,"barrel":1.5,"color":Color("ff9e52")},
	"missile":{"name":"Míssil","damage":55.0,"cadence":10.0,"speed":90.846,"gravity":0.8,"ammo":6,"reload":10.0,"range":2400.0,"life":30.0,"yaw":PI,"min_pitch":-0.10,"max_pitch":0.40,"turn":1.3,"barrel":1.7,"color":Color("ffc67a")},
	"torpedo":{"name":"Torpedo","damage":70.0,"cadence":8.0,"speed":44.1,"gravity":0.0,"ammo":8,"reload":8.0,"range":1800.0,"life":45.0,"yaw":0.60,"min_pitch":0.0,"max_pitch":0.0,"turn":0.9,"barrel":1.4,"color":Color("9cdae6")}}
const ISLANDS := [Vector3(-260,0,-180),Vector3(290,0,230),Vector3(100,0,-340),Vector3(-390,0,390),Vector3(430,0,-410)]
const RADII := [52.0,65.0,42.0,78.0,50.0]

static func uid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func finite(vector: Vector3) -> bool:
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)

static func wave(point: Vector3, time: float) -> float:
	return sin(point.x*0.025+time*0.85)*0.22 + sin(point.z*0.037-time*0.65)*0.11

static func ship_radius(kind: String) -> float:
	return float(SHIPS[kind].length)*0.62

static func safe_point(pos: Vector3, radius: float) -> bool:
	if absf(pos.x)+radius > MAP_LIMIT or absf(pos.z)+radius > MAP_LIMIT: return false
	for i in range(ISLANDS.size()):
		if Vector2(pos.x-ISLANDS[i].x,pos.z-ISLANDS[i].z).length() < RADII[i]+radius+6.0: return false
	return true

static func mounts(kind: String) -> Dictionary:
	var data: Dictionary = SHIPS[kind]
	var length := float(data.length)
	var deck := 1.7 if kind == "submarine" else float(data.height)*0.55
	var result := {"lightMG":Vector3(0,deck+0.35,-length*0.31)}
	if "heavyMG" in data.weapons: result.heavyMG = Vector3(0,deck+0.40,length*0.32)
	if "missile" in data.weapons: result.missile = Vector3(-float(data.width)*0.30,deck+0.50,length*0.19)
	if "torpedo" in data.weapons: result.torpedo = Vector3(0,-0.32,-length*0.55)
	return result
