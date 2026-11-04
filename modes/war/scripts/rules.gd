extends RefCounted
class_name WarRules

const PROTOCOL := 35
const OFFLINE_PARTICIPANTS:=18
const TEAMKILL_PENALTY := 100
const PORT := 3014
const CAPACITY := 40
const ONLINE_BOTS := 28
const HUMAN_CAPACITY := 12
const TEAM_LIMIT := 20
const START_TICKETS := 300
const DURATION := 1200.0
const CAPTURE_SECONDS := 18.0
const CAPTURE_RADIUS := 24.0
const VEHICLE_RESPAWN_SECONDS := 15.0
const TRANSPORT_ABANDON_SECONDS := 180.0
const SHIP_RESPAWN_SECONDS := 60.0
const PLAYER_RESPAWN_SECONDS := 8.0
const ROUND_BREAK_SECONDS := 60.0
const TEAM_RIFLES := ["fal","g3"]

static func primary_for(role: String,team: int) -> Array:
	return ["sniper"] if role=="marksman" else [TEAM_RIFLES[clampi(team,0,1)]]

const TEAM_LAUNCHERS := ["stinger","rpg"]
const VEHICLE_SENSORS := {
	"bike_0":{"fov":67.,"yaw_rate":0.,"pitch_rate":0.,"optic":Vector3(0,1.25,0)},
	"bike_1":{"fov":67.,"yaw_rate":0.,"pitch_rate":0.,"optic":Vector3(0,1.25,0)},
	"naval_assault_0":{"fov":65.,"yaw_rate":2.6,"pitch_rate":1.3,"optic":Vector3(0,4.2,-1.8)},
	"naval_frigate_0":{"fov":65.,"yaw_rate":2.6,"pitch_rate":1.3,"optic":Vector3(0,4.2,-1.8)},
	"naval_assault_1":{"fov":65.,"yaw_rate":2.6,"pitch_rate":1.3,"optic":Vector3(0,4.2,-1.8)},
	"naval_frigate_1":{"fov":65.,"yaw_rate":2.6,"pitch_rate":1.3,"optic":Vector3(0,4.2,-1.8)},
	"guarani":{"fov":65.,"yaw_rate":2.2,"pitch_rate":1.1,"optic":Vector3(.16,.32,.12)},
	"bmp2":{"fov":60.,"yaw_rate":1.6,"pitch_rate":.9,"optic":Vector3(.30,.36,.12)},
	"abrams":{"fov":55.,"yaw_rate":1.05,"pitch_rate":.65,"optic":Vector3(.38,.50,.22)},
	"t90":{"fov":55.,"yaw_rate":.95,"pitch_rate":.60,"optic":Vector3(.35,.48,.20)}}

static func launcher_for_team(team: int) -> String:
	return TEAM_LAUNCHERS[team] if team in [0,1] else ""

static func launcher_allowed(team: int,id: String) -> bool:
	return not id.is_empty() and id==launcher_for_team(team)
# Feet positions in the hull's local coordinates. Seat zero is the sole
# operator; seats 1..N are passengers, never a second turret controller.
const BIKE_SEATS := [Vector3(0,.07,0),Vector3(0,.07,.52)]
const VEHICLE_SEATS := {
	"bike_0":BIKE_SEATS,
	"bike_1":BIKE_SEATS,
	"naval_assault_0":[Vector3(0,1.05,-1.7),Vector3(-2.016,.60,5.5),Vector3(2.016,.60,5.5),Vector3(-2.016,.60,7.0),Vector3(2.016,.60,7.0),Vector3(-2.016,.60,8.5),Vector3(2.016,.60,8.5)],
	"naval_frigate_0":[Vector3(0,1.05,-1.7),Vector3(-1.624,.60,4.5),Vector3(1.624,.60,4.5),Vector3(-1.624,.60,6.0),Vector3(1.624,.60,6.0),Vector3(-1.624,.60,7.5),Vector3(1.624,.60,7.5)],
	"naval_assault_1":[Vector3(0,1.05,-1.7),Vector3(-2.016,.60,5.5),Vector3(2.016,.60,5.5),Vector3(-2.016,.60,7.0),Vector3(2.016,.60,7.0),Vector3(-2.016,.60,8.5),Vector3(2.016,.60,8.5)],
	"naval_frigate_1":[Vector3(0,1.05,-1.7),Vector3(-1.624,.60,4.5),Vector3(1.624,.60,4.5),Vector3(-1.624,.60,6.0),Vector3(1.624,.60,6.0),Vector3(-1.624,.60,7.5),Vector3(1.624,.60,7.5)],
	"guarani":[Vector3(-.62,.55,-1.85),Vector3(.62,.50,-.25),Vector3(-.62,.50,.70),Vector3(.62,.50,.70),Vector3(-.62,.50,1.85),Vector3(.62,.50,1.85)],
	"bmp2":[Vector3(-.62,.48,-1.85),Vector3(.62,.48,.10),Vector3(-.62,.48,.90),Vector3(.62,.48,.90),Vector3(-.62,.48,1.90),Vector3(.62,.48,1.90)],
	"abrams":[Vector3(-.62,.62,-1.05),Vector3(.65,.62,.65)],
	"t90":[Vector3(-.62,.58,-1.05),Vector3(.65,.58,.65)]}
const WALK_SPEED := 4.8
const ARMOR_DAMAGE_WEAPONS := ["tank","autocannon","rpg","stinger","tv","missile","torpedo","grenade","drone","water"]

static func can_damage_armor(weapon: String) -> bool:
	# New infantry guns default to no armor penetration. Armor-capable
	# weapons require an explicit gameplay rule, never a generic fallback.
	return weapon in ARMOR_DAMAGE_WEAPONS
static var CURRENT_OPERATION:=WarOperation.UKRAINE
static var BASES: Array=WarOperation.bases(CURRENT_OPERATION)
static var OBJECTIVES: Dictionary=WarOperation.objectives(CURRENT_OPERATION)
static var TRANSPORT_SPAWNS: Dictionary=WarOperation.transport(CURRENT_OPERATION)

static func configure(operation: String) -> void:
	CURRENT_OPERATION=WarOperation.normalize(operation)
	BASES=WarOperation.bases(CURRENT_OPERATION)
	OBJECTIVES=WarOperation.objectives(CURRENT_OPERATION)
	TRANSPORT_SPAWNS=WarOperation.transport(CURRENT_OPERATION)
	if CURRENT_OPERATION==WarOperation.AFGHAN:
		for i in BASES.size():
			var p: Vector3=BASES[i];p.y=BRAfghanMap.height_at(p.x,p.z);BASES[i]=p
		for id in OBJECTIVES:
			var p: Vector3=OBJECTIVES[id].position;p.y=BRAfghanMap.height_at(p.x,p.z);OBJECTIVES[id].position=p

static func team_name(team: int) -> String:return WarOperation.team_name(CURRENT_OPERATION,team)
static func map_name() -> String:return WarOperation.map_name(CURRENT_OPERATION)
static func map_content() -> String:return WarOperation.map_content(CURRENT_OPERATION)
static func operation_port() -> int:return WarOperation.port(CURRENT_OPERATION)

static func transport_spawn(kind: String,copy: int) -> Vector3:
	var points: Array=TRANSPORT_SPAWNS.get(kind,[])
	if not points.is_empty(): return WarTerrain.point(points[clampi(copy,0,points.size()-1)].x,points[clampi(copy,0,points.size()-1)].z)
	return BASES[int(VEHICLES[kind].team)]

const CLASSES := {
	"medic":{"name":"Médico","primary":["ak"],"description":"Cura aliados próximos com recursos limitados.","gadget":"Kit médico","charges":4},
	"soldier":{"name":"Soldado","primary":["ak"],"description":"Fuzil, granadas e apoio de munição.","gadget":"Granada / munição","charges":3},
	"antitank":{"name":"Antitanque","primary":["ak"],"description":"RPG-7 ou Javelin.","gadget":"RPG-7 / Javelin","charges":3},
	"marksman":{"name":"Atirador","primary":["sniper"],"description":"Precisão e reconhecimento com óptica de longo alcance.","gadget":"Observação","charges":4}}
const VEHICLES := {
	"bike_0":{"name":"Moto","team":0,"transport":true,"count":3,"hp":220.,"speed":25.,"reverse":4.,"acceleration":7.,"turn":1.15,"tracked":false,"size":Vector3(.70,1.30,2.20),"gun":"","ammo":0,"reload":0.,"cooldown":999.,"damage":0.,"speed_shot":0.,"gravity":0.,"blast":0.,"pitch_min":0.,"pitch_max":0.},
	"bike_1":{"name":"Moto","team":1,"transport":true,"count":3,"hp":220.,"speed":25.,"reverse":4.,"acceleration":7.,"turn":1.15,"tracked":false,"size":Vector3(.70,1.30,2.20),"gun":"","ammo":0,"reload":0.,"cooldown":999.,"damage":0.,"speed_shot":0.,"gravity":0.,"blast":0.,"pitch_min":0.,"pitch_max":0.},
	"naval_assault_0":{"name":"Navio de assalto","team":0,"naval":"assault","hp":1600.,"speed":12.0,"reverse":4.,"acceleration":2.3,"turn":.45,"tracked":false,"size":Vector3(7.2,4.,25),"gun":"lightMG","ammo":600,"reload":3.,"cooldown":.105,"damage":4.,"speed_shot":620.,"gravity":12.,"blast":0.,"pitch_min":-.15,"pitch_max":.58},
	"naval_frigate_0":{"name":"Fragata","team":0,"naval":"heavy","hp":1200.,"speed":16.0,"reverse":4.,"acceleration":2.3,"turn":.45,"tracked":false,"size":Vector3(5.8,4.,22),"gun":"lightMG","ammo":600,"reload":3.,"cooldown":.105,"damage":4.,"speed_shot":620.,"gravity":12.,"blast":0.,"pitch_min":-.15,"pitch_max":.58},
	"naval_assault_1":{"name":"Navio de assalto","team":1,"naval":"assault","hp":1600.,"speed":12.0,"reverse":4.,"acceleration":2.3,"turn":.45,"tracked":false,"size":Vector3(7.2,4.,25),"gun":"lightMG","ammo":600,"reload":3.,"cooldown":.105,"damage":4.,"speed_shot":620.,"gravity":12.,"blast":0.,"pitch_min":-.15,"pitch_max":.58},
	"naval_frigate_1":{"name":"Fragata","team":1,"naval":"heavy","hp":1200.,"speed":16.0,"reverse":4.,"acceleration":2.3,"turn":.45,"tracked":false,"size":Vector3(5.8,4.,22),"gun":"lightMG","ammo":600,"reload":3.,"cooldown":.105,"damage":4.,"speed_shot":620.,"gravity":12.,"blast":0.,"pitch_min":-.15,"pitch_max":.58},
	"guarani":{"name":"Guarani 6×6","team":0,"hp":650.0,"speed":23.0,"reverse":8.0,"acceleration":5.0,"turn":.52,"tracked":false,"size":Vector3(2.8,2.65,6.9),"gun":"autocannon","calibre":"30 mm","ammo":160,"reload":6.0,"cooldown":.24,"damage":52.0,"speed_shot":760.0,"gravity":12.0,"drag":.045,"spread":.10,"infantry_damage":150.0,"blast":4.3,"pitch_min":-.17,"pitch_max":.78},
	"bmp2":{"name":"BMP-2","team":1,"hp":580.0,"speed":19.0,"reverse":7.0,"acceleration":5.4,"turn":.82,"tracked":true,"size":Vector3(3.0,2.15,6.7),"gun":"autocannon","ammo":160,"reload":6.0,"cooldown":.24,"damage":55.0,"speed_shot":760.0,"gravity":12.0,"drag":.045,"spread":.10,"infantry_damage":155.0,"blast":4.5,"pitch_min":-.09,"pitch_max":.86},
	"abrams":{"name":"M1 Abrams","team":0,"hp":1500.0,"speed":17.0,"reverse":10.0,"acceleration":3.6,"turn":.62,"tracked":true,"size":Vector3(3.65,2.8,7.9),"gun":"tank","ammo":30,"reload":6.5,"cooldown":6.5,"damage":600.0,"speed_shot":700.0,"gravity":17.0,"drag":.035,"blast":14.0,"pitch_min":-.17,"pitch_max":.35},
	"t90":{"name":"T-90","team":1,"hp":1400.0,"speed":18.0,"reverse":6.0,"acceleration":4.0,"turn":.67,"tracked":true,"size":Vector3(3.5,2.55,6.9),"gun":"tank","ammo":30,"reload":6.0,"cooldown":6.0,"damage":570.0,"speed_shot":680.0,"gravity":17.0,"drag":.035,"blast":13.5,"pitch_min":-.10,"pitch_max":.30}}
const TV_MISSILE := {"speed":115.0,"gravity":0.6,"damage":320.0,"radius":4.5,"range":1000.0,"life":8.5,"turn_rate":1.35,"cooldown":12.0,"reload":12.0}
const SECONDARY := {
	"bike_0":{"name":"","weapon":"","capacity":0,"reserve":0,"reload":0.,"cooldown":999.},
	"bike_1":{"name":"","weapon":"","capacity":0,"reserve":0,"reload":0.,"cooldown":999.},
	"naval_assault_0":{"name":"Metralhadora pesada","weapon":"heavyMG","capacity":240,"reserve":480,"reload":5.,"cooldown":.34},
	"naval_frigate_0":{"name":"Metralhadora pesada","weapon":"heavyMG","capacity":240,"reserve":480,"reload":5.,"cooldown":.34},
	"naval_assault_1":{"name":"Metralhadora pesada","weapon":"heavyMG","capacity":240,"reserve":480,"reload":5.,"cooldown":.34},
	"naval_frigate_1":{"name":"Metralhadora pesada","weapon":"heavyMG","capacity":240,"reserve":480,"reload":5.,"cooldown":.34},
	"guarani":{"name":"MÍSSIL TV","weapon":"tv","capacity":1,"reserve":5,"reload":12.0,"cooldown":12.0},
	"bmp2":{"name":"MÍSSIL TV","weapon":"tv","capacity":1,"reserve":5,"reload":12.0,"cooldown":12.0},
	"abrams":{"name":"METRALHADORA COAXIAL","weapon":"hmg","capacity":80,"reserve":400,"reload":4.0,"cooldown":.10},
	"t90":{"name":"METRALHADORA COAXIAL","weapon":"hmg","capacity":80,"reserve":400,"reload":4.0,"cooldown":.10}}
const SPECIAL := {
	"rpg":{"speed":82.0,"gravity":5.2,"damage":430.0,"radius":7.0,"cooldown":5.5,"range":650.0,"color":Color("f49a51")},
	"stinger":{"speed":125.0,"gravity":0.0,"damage":280.0,"radius":5.0,"cooldown":6.5,"range":700.0,"color":Color("ffd8a0")},
	"grenade":{"speed":20.0,"gravity":9.81,"damage":160.0,"radius":8.0,"cooldown":1.2,"range":120.0,"color":Color("d9c990")}}

static func fresh_objectives() -> Dictionary:
	var result := {}
	for id in OBJECTIVES:
		result[id] = {"owner":-1,"side":-1,"progress":0.0,"idle":0.0,"contested":false,"count":[0,0]}
	return result

static func choose_team(wanted: int,teams: Dictionary,exclude := 0) -> int:
	if wanted not in [0,1]: return -1
	var counts := [0,0]
	for id in teams:
		if int(id)!=exclude and int(teams[id]) in [0,1]: counts[int(teams[id])] += 1
	if counts[wanted]>=TEAM_LIMIT or counts[wanted]>counts[1-wanted]: return -1
	return wanted

static func capture(state: Dictionary,counts: Array,delta: float) -> Dictionary:
	state.count = counts.duplicate()
	state.contested = counts[0]>0 and counts[0]==counts[1]
	if state.contested: state.idle = 0.0;return state
	if counts[0]==0 and counts[1]==0:
		state.idle = float(state.idle)+delta
		if float(state.idle)>5.0:
			state.progress = maxf(0,float(state.progress)-delta/30.0)
			if state.progress==0: state.side = -1
		return state
	state.idle = 0.0
	var side := 0 if counts[0]>counts[1] else 1
	var rate := minf(2.0,1.0+.25*(absi(counts[0]-counts[1])-1))*delta/CAPTURE_SECONDS
	if state.side!=side and float(state.progress)>0:
		state.progress = maxf(0,float(state.progress)-rate)
		if float(state.progress)==0: state.side = side
		return state
	if state.owner==side: state.progress = 0.0;state.side = -1;return state
	state.side = side
	state.progress = minf(1.0,float(state.progress)+rate)
	if float(state.progress)>=1.0-.000001:
		# Enemy territory must complete a neutralization cycle first.
		state.owner = -1 if int(state.owner)>=0 else side
		state.progress = 0.0
		state.side = side if int(state.owner)<0 else -1
	return state
