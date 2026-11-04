extends RefCounted
class_name OfficeMap
const BOUNDS := Rect2(-15.0,-45.0,30.0,52.0)
const SPAWN_PADS:=[Vector3(-8.2,0,-25.0),Vector3(8.2,0,-25.0),Vector3(-8.2,0,-13.5),Vector3(8.2,0,-13.5),Vector3(-7.8,0,-1.2),Vector3(7.8,0,-1.2)]
const ROOM_CENTERS := {"reception":Vector3(-8.5,0,-33.5),"administration":Vector3(8.5,0,-33.5),"archive":Vector3(-8.5,0,-41),"maintenance":Vector3(8.5,0,-41)}

static func has_floor(x: float, z: float) -> bool:
	return (absf(x)<10.75 and z>=-29.0 and z<6.75) or (absf(x)<14.75 and z<=-29.0 and z> -44.75)

static func build(parent: Node3D, visuals := true) -> void:
	var k := EnvironmentKit.new(parent,visuals,18.0)
	parent.set_meta("map_bounds",BOUNDS)
	parent.set_meta("use_occluders",true)
	k.box("WarehouseFloor",Vector3(0,-0.15,-11),Vector3(22,0.3,36),"floor",true)
	k.box("AnnexFloor",Vector3(0,-0.15,-37),Vector3(30,0.3,16),"floor",true)
	k.box("Ceiling",Vector3(0,8,-11),Vector3(22,0.18,36),"plaster",true)
	k.box("AnnexCeiling",Vector3(0,3.6,-37),Vector3(30,0.16,16),"plaster",true)
	k.wall("FrontWall",Vector3(-11,0,7),Vector3(11,0,7),8,"concrete",[{"at":11.0,"width":2.6,"top":2.8}])
	# Front service exit is glazed but physically closed; the rear exit is open.
	k.box("FrontServiceDoor",Vector3(0,1.4,7),Vector3(2.6,2.8,0.10),"steel",true)
	k.sign_text("LOGÍSTICA  /  ACESSO CONTROLADO",Vector3(0,3.25,6.82),3.8)
	k.wall("BackWall",Vector3(-11,0,-29),Vector3(11,0,-29),8,"concrete",[{"at":11.0,"width":3.1,"top":3.0}])
	for side in [-1.0,1.0]:
		k.wall("WarehouseSide",Vector3(side*11,0,-29),Vector3(side*11,0,7),8,"plaster")
		k.box("WallSkirt",Vector3(side*10.81,0.14,-11),Vector3(0.08,0.28,36),"steel:adb2a2")
		for z in [-27.5,-19.0,-10.5,-2.0,6.3]:
			k.box("ColumnFlange",Vector3(side*10.65,4,z),Vector3(0.26,8,0.44),"steel",true)
			k.box("ColumnWeb",Vector3(side*10.50,4,z),Vector3(0.28,8,0.12),"steel")
			k.box("ColumnFoot",Vector3(side*10.5,0.12,z),Vector3(0.7,0.24,0.8),"concrete",true)
			for x in [-0.21,0.21]: k.cylinder("AnchorBolt",Vector3(side*10.5+x,0.26,z),0.035,0.08,"steel",false,1.0,Vector3.ZERO,true)
	for z in [-27.5,-19,-10.5,-2,6.3]:
		k.box("RoofGirder",Vector3(0,7.5,z),Vector3(21.5,0.4,0.24),"steel")
		for x in [-8,-4,0,4,8]:
			k.beam(Vector3(x-1.8,7.3,z),Vector3(x+1.8,7.8,z),0.05,0.05,"steel")
	for x in [-5.2,5.2]:
		k.box("VentilationDuct",Vector3(x,6.9,-10),Vector3(0.7,0.55,34),"steel:d8d9cd")
		for z in range(-25,6,5):
			k.box("DuctJoint",Vector3(x,6.9,z),Vector3(0.76,0.6,0.055),"steel")
			k.pipe(Vector3(x,7.1,z),Vector3(x,7.9,z),0.025,"steel")
			k.lamp(Vector3(x*.65,6.5,z),2.1,true,z in [-25,-15,-5,5])
	k.box("CableTray",Vector3(9.4,5.5,-11),Vector3(0.32,0.13,35),"steel")
	for x in [8.5,8.8]: k.pipe(Vector3(x,4.8,-28.8),Vector3(x,4.8,6.7),0.05,"steel:b9aa8f",false,false)
	# Familiar rack layout, rebuilt with full uprights, bracing and labeled stock.
	for z in [-23.0,-15.0,-7.0]:
		for x in [-7.2,0.0,7.2]: k.rack(Vector3(x,0,z),4.5)
	for x in [-7.5,-4.5,4.5,7.5]:
		k.desk(Vector3(x,0,1.0),0.0)
		k.chair(Vector3(x,0,2.2),0.0)
	for pos in [Vector3(-9.4,0,-26.4),Vector3(9.4,0,-11),Vector3(-9.4,0,-2)]:
		k.pallet(pos)
		k.crate(pos+Vector3.UP*.2,Vector3(1.0,0.78,0.9))
	# Painted pedestrian lanes and load-bay numbering are non-colliding details.
	for x in [-3.5,3.5]: k.box("AislePaint",Vector3(x,0.008,-14),Vector3(0.075,0.01,26),"plaster:cac08a",false,Vector3.ZERO,true)
	for z in [-27,-19,-11]: k.sign_text("SETOR "+str(posmod(int(z),3)+1)+"  /  ESTOQUE",Vector3(-10.75,3.1,z),2.1,PI/2)
	_annex(k)
	_accessories(k)
	k.flush()
	parent.set_meta("rooms",ROOM_CENTERS)
	parent.set_meta("layout_version","office-industrial-2")

static func _annex(k: EnvironmentKit) -> void:
	k.wall("AnnexNorth",Vector3(-15,0,-45),Vector3(15,0,-45),3.6,"plaster")
	for side in [-1.0,1.0]:
		k.wall("AnnexOuter",Vector3(side*15,0,-45),Vector3(side*15,0,-29),3.6,"plaster")
		k.wall("AnnexFront",Vector3(side*2,0,-29),Vector3(side*15,0,-29),3.6,"plaster")
		k.wall("ServiceCorridor",Vector3(side*2,0,-45),Vector3(side*2,0,-29),3.6,"plaster",[{"at":4.0,"width":2.1,"top":2.7},{"at":11.4,"width":2.1,"top":2.7}])
		k.wall("RoomDivider",Vector3(side*2,0,-37),Vector3(side*15,0,-37),3.6,"plaster",[{"at":6.0,"width":2.1,"top":2.7}])
		k.box("CorridorSkirt",Vector3(side*1.84,0.12,-37),Vector3(0.08,0.24,16),"steel:9da89a",false)
		k.pipe(Vector3(side*1.65,3.15,-44.8),Vector3(side*1.65,3.15,-29),0.065,"steel")
	for z in [-32.5,-38,-43.2]: k.lamp(Vector3(0,3.3,z),1.8,false)
	k.sign_text("ADMINISTRAÇÃO  ←   /   MANUTENÇÃO  →",Vector3(0,2.9,-44.82),2.9)
	k.sign_text("SERVIÇOS  /  ARMAZÉM",Vector3(0,3.4,-28.82),3.0)
	var titles := {"reception":"RECEPÇÃO / 01","administration":"ADMINISTRAÇÃO / 02","archive":"ARQUIVO / 03","maintenance":"MANUTENÇÃO / 04"}
	for key in ROOM_CENTERS:
		var pos: Vector3 = ROOM_CENTERS[key]
		k.lamp(pos+Vector3.UP*3.3,1.8,key!="maintenance")
		k.box("SectorPlaque",Vector3(-1.84 if pos.x<0 else 1.84,2.9,pos.z),Vector3(0.06,0.25,1.5),"steel",false)
		k.sign_text(titles[key],Vector3(-1.78 if pos.x<0 else 1.78,2.9,pos.z),1.4,PI/2 if pos.x<0 else -PI/2)
	# Reception counter, guest seating and notice board.
	k.box("ReceptionCounter",Vector3(-10,0.55,-35.6),Vector3(5.0,1.1,0.85),"wood",true)
	k.box("CounterWorktop",Vector3(-10,1.15,-35.6),Vector3(5.2,0.1,1.0),"steel:d8d8c5")
	k.desk(Vector3(-11,0,-35.6))
	for x in [-12.8,-11.5,-10.2]: k.chair(Vector3(x,0,-31.2),PI)
	_notice(k,Vector3(-14.80,1.9,-33.0),PI/2)
	# Main office keeps a clear route from the corridor to the archive door.
	for x in [5,10.6]:
		k.desk(Vector3(x,0,-31.0),PI)
		k.chair(Vector3(x,0,-32.3),PI)
	for x in [11.0,13.5]: _cabinet(k,Vector3(x,0,-36.25),false)
	k.box("OfficeDivider",Vector3(7.7,0.65,-32.0),Vector3(0.06,1.3,2.3),"fabric",true)
	# Archive: document shelves arranged longitudinally with two usable aisles.
	for x in [-12.7,-8.7,-4.8]:
		k.rack(Vector3(x,0,-43.6),2.8,true)
	for x in [-13.2,-10.8]: _cabinet(k,Vector3(x,0,-38.2),true)
	# Maintenance: bench, pegboard, vise, spare parts, electrical cabinets.
	k.desk(Vector3(10.8,0,-44),0.0,false)
	k.desk(Vector3(12.6,0,-44),0.0,false)
	k.box("ToolBoard",Vector3(11.6,1.8,-44.75),Vector3(4.2,1.25,0.08),"wood")
	for i in range(9):
		var x := 9.9+i*.40
		k.pipe(Vector3(x,1.5,-44.66),Vector3(x,2.0+(i%3)*.07,-44.66),0.025,"steel",false)
		k.cylinder("WrenchHead",Vector3(x,2.04+(i%3)*.07,-44.66),0.065,0.04,"steel",false,1.0,Vector3(PI/2,0,0),true)
	k.box("BenchVise",Vector3(10.2,0.94,-43.8),Vector3(0.25,0.22,0.24),"steel:71919a")
	k.pipe(Vector3(10,0.96,-43.8),Vector3(10.5,0.96,-43.8),0.025,"steel")
	for x in [4.0,5.6]: _cabinet(k,Vector3(x,0,-44),false)
	k.pallet(Vector3(12.6,0,-39.5))
	k.cylinder("SpareMotor",Vector3(12.6,0.54,-39.5),0.3,0.6,"steel",true,1.0,Vector3(0,0,PI/2))
	for x in [12.4,12.6,12.8]: k.cylinder("MotorFins",Vector3(x,0.54,-39.5),0.35,0.03,"steel",false,1.0,Vector3(0,0,PI/2))

static func _cabinet(k: EnvironmentKit, pos: Vector3, drawers: bool) -> void:
	k.box("Cabinet",pos+Vector3.UP*1.0,Vector3(1.2,2.0,0.55),"steel:bec8b7",true)
	for i in range(4 if drawers else 2):
		var y := 0.28+i*.47 if drawers else 1.0
		var x := 0.0 if drawers else (-0.30+i*.60)
		k.box("CabinetFront",pos+Vector3(x,y,0.286),Vector3(1.08 if drawers else .55,.42 if drawers else 1.86,0.025),"steel:a4b1a7")
		k.box("CabinetHandle",pos+Vector3(x,y,0.32),Vector3(0.22,0.03,0.045),"dark",false,Vector3.ZERO,true)

static func _notice(k: EnvironmentKit, pos: Vector3, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP,yaw)
	k.box("NoticeBoard",pos,Vector3(1.8,1.1,0.06),"wood",false,Vector3(0,yaw,0))
	for i in range(6): k.box("PaperNotice",pos+b*Vector3(-.6+(i%3)*.55,-.22+floori(i/3)*.45,.04),Vector3(.40,.33,.009),"plaster",false,Vector3(0,yaw,0),true)

static func _accessories(k: EnvironmentKit) -> void:
	for pos in [Vector3(-10.5,0,-27.3),Vector3(10.5,0,5),Vector3(1.65,0,-38.0)]:
		k.cylinder("Extinguisher",pos+Vector3.UP*1.0,.13,.58,"steel:ef634f",false,0.9)
		k.cylinder("ExtinguisherValve",pos+Vector3.UP*1.33,.06,.10,"steel",false)
		k.pipe(pos+Vector3(.1,1.3,0),pos+Vector3(.18,.84,0),.024,"dark")
		k.sign_text("EXTINTOR",pos+Vector3(0,1.9,.09),.75)
	for pos in [Vector3(-9,0,5.4),Vector3(14.1,0,-35),Vector3(-14,0,-43)]:
		k.cylinder("WasteBin",pos+Vector3.UP*.28,.23,.56,"steel",true,1.1)
		k.cylinder("BinLid",pos+Vector3.UP*.58,.25,.05,"dark",false)
	for pos in [Vector3(-9.8,0,4),Vector3(-13.8,0,-30.2),Vector3(13.8,0,-30.2)]:
		k.cylinder("PlantPot",pos+Vector3.UP*.25,.23,.50,"brick",true,.8)
		for i in range(9):
			var angle := i*2.399
			k.beam(pos+Vector3.UP*.45,pos+Vector3(sin(angle)*.33,.9+(i%3)*.13,cos(angle)*.33),.12,.025,"fabric:9fbb87")
	k.cylinder("ClockRim",Vector3(0,4.2,6.77),.36,.07,"steel",false,1,Vector3(PI/2,0,0))
	k.cylinder("ClockFace",Vector3(0,4.2,6.72),.32,.02,"plaster",false,1,Vector3(PI/2,0,0))
	k.pipe(Vector3(0,4.2,6.70),Vector3(.15,4.38,6.70),.012,"dark")
	k.pipe(Vector3(0,4.2,6.70),Vector3(-.20,4.2,6.70),.012,"dark")
	# A recognizable hand trolley remains parked clear of the main lanes.
	k.box("TrolleyBed",Vector3(8.7,.23,-19.4),Vector3(1.3,.14,.9),"steel",true)
	for x in [8.2,9.2]:
		for z in [-19.7,-19.1]: k.cylinder("TrolleyWheel",Vector3(x,.13,z),.13,.08,"dark",false,1,Vector3(0,0,PI/2))
	k.pipe(Vector3(8.2,.3,-19.75),Vector3(8.2,1.1,-19.75),.035,"steel")
	k.pipe(Vector3(9.2,.3,-19.75),Vector3(9.2,1.1,-19.75),.035,"steel")
	k.pipe(Vector3(8.2,1.1,-19.75),Vector3(9.2,1.1,-19.75),.035,"steel")
