extends RefCounted
class_name DesertMap
const REVISION := 3
const SPAWN_PADS := [Vector2(-58,-52),Vector2(58,-52),Vector2(-62,52),Vector2(62,52),Vector2(0,71),Vector2(0,-75),Vector2(-83,7),Vector2(83,-8)]

static func build(parent: Node3D,visuals := true) -> void:
	parent.set_meta("map_bounds",Rect2(-150,-150,300,300))
	DesertTerrain.build(parent,visuals)
	var k := EnvironmentKit.new(parent,visuals,35)
	_outpost(k)
	_logistics(k)
	_perimeter(k)
	_landscape(k)
	k.flush()
	if visuals:
		var atmosphere := EnvironmentAtmosphere.new()
		atmosphere.kind = "desert"
		parent.add_child(atmosphere)
		if load("res://scripts/maps/definition.gd").grass_enabled("desert"):
			var grass=load("res://modes/war/scripts/vegetation_visuals.gd").new()
			parent.add_child(grass);grass.initialize(parent,"desert");grass.apply_level(2)
	parent.set_meta("layout_version","desert-outpost-3")

static func spawn_pad(index: int) -> Vector3:
	var p: Vector2 = SPAWN_PADS[posmod(index,SPAWN_PADS.size())]
	return safe_ground_point(Vector3(p.x,0,p.y))

static func safe_ground_point(point: Vector3) -> Vector3:
	var ground:=DesertTerrain.height_at(point.x,point.z)
	# The entire capsule footprint must clear a slope, not only its centre.
	for side in [Vector2(.34,0),Vector2(-.34,0),Vector2(0,.34),Vector2(0,-.34)]:
		ground=maxf(ground,DesertTerrain.height_at(point.x+side.x,point.z+side.y))
	return Vector3(point.x,ground+.16,point.z)

static func _outpost(k: EnvironmentKit) -> void:
	k.box("OutpostFoundation",Vector3(0,-.05,-7),Vector3(15.6,.14,11.6),"concrete",true)
	for z in [-12.5,-1.5]:
		k.wall("PostFacade",Vector3(-7.5,0,z),Vector3(7.5,0,z),3.6,"concrete",[
			{"at":3.2,"width":2.1,"sill":1.05,"top":2.5},
			{"at":7.5,"width":2.6,"top":2.85},
			{"at":11.8,"width":2.1,"sill":1.05,"top":2.5}],.34)
		for x in [-4.3,4.3]:
			k.box("WindowLedge",Vector3(x,1.02,z),Vector3(2.3,.12,.54),"concrete")
			for i in range(4): k.box("Louver",Vector3(x,1.22+i*.28,z),Vector3(2,.035,.14),"steel",true,Vector3(.30,0,0))
	for x in [-7.5,7.5]:
		k.wall("PostSide",Vector3(x,0,-12.5),Vector3(x,0,-1.5),3.6,"concrete",[{"at":5.5,"width":2.8,"sill":1.1,"top":2.5}],.34)
	k.box("RoofSlab",Vector3(0,3.7,-7),Vector3(16,.22,12),"concrete",true)
	for x in [-7.5,7.5]: k.box("RoofParapet",Vector3(x,3.98,-7),Vector3(.20,.40,11.5),"concrete",true)
	for z in [-12.5,-1.5]: k.box("RoofParapet",Vector3(0,3.98,z),Vector3(15,.40,.20),"concrete",true)
	for x in [-2.0,2.0]: k.wall("CommsPartition",Vector3(x,0,-11.7),Vector3(x,0,-3.0),3.5,"plaster",[{"at":4.35,"width":2.5,"top":2.8}],.18)
	k.sign_text("POSTO AVANÇADO  /  TDC",Vector3(0,3.2,-1.29),4.6)
	k.sign_text("COMUNICAÇÕES",Vector3(-4.4,2.8,-3.0),2.1)
	k.sign_text("EQUIPAMENTOS",Vector3(4.4,2.8,-3.0),2.1)
	for z in [-5,-9.5]:
		k.desk(Vector3(-5.8,.03,z),PI/2)
		k.chair(Vector3(-4.5,.03,z),PI/2)
	for x in [3.1,5.8]:
		k.rack(Vector3(x,.02,-11.65),2.0,true)
		k.crate(Vector3(x,.02,-4.3),Vector3(1.0,.8,.9),true)
	for x in [-4.6,4.6]: k.lamp(Vector3(x,3.3,-7),1.5,false)
	var supply:=Vector3(-3.35,.02,-7)
	k.box("AmmoCrate",supply+Vector3.UP*.36,Vector3(1.05,.72,.66),"steel:54634b",true)
	k.box("AmmoCrateLid",supply+Vector3.UP*.75,Vector3(1.12,.08,.72),"steel:71815b",true)
	for x in [-.36,.36]: k.box("AmmoCrateBand",supply+Vector3(x,.38,.345),Vector3(.08,.60,.035),"steel:c6cbb0")
	k.box("AmmoHandle",supply+Vector3(0,.51,.36),Vector3(.24,.08,.06),"dark")
	k.sign_text("MUNIÇÃO  /  E",supply+Vector3(0,.95,.38),1.05)
	k.box("RooftopAC",Vector3(4.3,4.3,-8.2),Vector3(2.5,.9,1.4),"steel:c9c9b0",true)
	for i in range(11): k.box("ACFins",Vector3(3.2+i*.2,4.3,-7.47),Vector3(.04,.65,.025),"dark",false,Vector3.ZERO,true)
	k.pipe(Vector3(3.2,4,-6.5),Vector3(3.2,5.3,-6.5),.09,"steel")
	k.pipe(Vector3(3.2,5.3,-6.5),Vector3(2.5,5.3,-6.5),.09,"steel")
	for side in [-1.0,1.0]:
		EnvironmentProps.sandbags(k,Vector3(side*13,.02,0),6.7)
		k.box("ConcreteBarrier",Vector3(side*10,.58,-18),Vector3(5,1.15,.65),"concrete",true)

static func _logistics(k: EnvironmentKit) -> void:
	for i in range(3): EnvironmentProps.container(k,Vector3(-27+i*6.4,.02,-19),i==1)
	for pos in [Vector3(-27,.03,-8),Vector3(-24,.03,-7),Vector3(-20,.03,-6),Vector3(-25,.03,1)]:
		k.pallet(pos)
		k.crate(pos+Vector3.UP*.2,Vector3(1.1,1.2,1.0),true)
	for i in range(6): EnvironmentProps.drum(k,Vector3(-30+(i%3)*1.0,.02,6.0+floori(i/3)*1.1),i%3==0)
	EnvironmentProps.canopy(k,Vector3(23,0,-12),Vector2(11,9),4.1)
	EnvironmentProps.truck(k,Vector3(24,.02,-12))
	k.desk(Vector3(19,.02,-15.6),0,false)
	EnvironmentProps.generator(k,Vector3(19,.02,-5))
	for i in range(4): k.cylinder("SpareWheel",Vector3(28,.25+i*.19,-16),.51,.18,"dark",true)
	var tower := Vector3(-23,.02,22)
	EnvironmentProps.tower(k,tower,16)
	k.box("RadioShelter",Vector3(-29,1.25,22),Vector3(4,2.5,3.6),"steel:acbba9",true)
	k.box("ShelterRoof",Vector3(-29,2.6,22),Vector3(4.4,.18,4),"steel",true)
	k.sign_text("RÁDIO  /  03",Vector3(-29,2.1,23.84),2)
	EnvironmentProps.generator(k,Vector3(-29,.02,26))
	k.pipe(tower+Vector3.UP*.1,Vector3(-29,.12,22),.035,"dark",false,false)
	EnvironmentProps.canopy(k,Vector3(16,0,22),Vector2(8,5),3.0)
	for pos in [Vector3(14,.02,22),Vector3(18,.02,22)]: k.crate(pos,Vector3(1.8,1.3,1.2),true)
	k.box("CanvasAwning",Vector3(16,3.1,22),Vector3(8.5,.045,5.5),"fabric",false,Vector3(.025,0,0))

static func _perimeter(k: EnvironmentKit) -> void:
	for side in [-1.0,1.0]:
		EnvironmentProps.fence(k,Vector3(side*37,0,-34),Vector3(side*37,0,-4))
		EnvironmentProps.fence(k,Vector3(side*37,0,4),Vector3(side*37,0,34))
		EnvironmentProps.fence(k,Vector3(-37,0,side*34),Vector3(-5,0,side*34))
		EnvironmentProps.fence(k,Vector3(5,0,side*34),Vector3(37,0,side*34))
		EnvironmentProps.sandbags(k,Vector3(side*7,.01,30),5.0)
		EnvironmentProps.sandbags(k,Vector3(side*14,.01,-30),5.0)
	for pos in [Vector3(32,0,28),Vector3(-32,0,-28)]:
		k.box("GuardBoothFloor",pos+Vector3.UP*.15,Vector3(3.0,.3,3.0),"concrete",true)
		for x in [-1.3,1.3]:
			for z in [-1.3,1.3]: k.box("GuardBoothPillar",pos+Vector3(x,1.6,z),Vector3(.12,3.2,.12),"steel",true)
		k.box("GuardBoothRoof",pos+Vector3.UP*3.3,Vector3(3.2,.16,3.2),"steel",true)
		EnvironmentProps.sandbags(k,pos+Vector3(0,.3,-1.3),2.6)
		k.sign_text("GUARDA",pos+Vector3(0,2.8,1.34),1.6)
	for x in [-6,6]:
		k.cylinder("GatePost",Vector3(x,2.1,34),.11,4.2,"steel",true)
		k.box("Floodlight",Vector3(x,4.15,34),Vector3(.6,.35,.3),"steel")
		k.box("FloodlightLens",Vector3(x,4.15,34.16),Vector3(.51,.25,.02),"plaster")
	k.sign_text("POSTO AVANÇADO / ACESSO",Vector3(0,3.7,34.2),5.0)

static func _landscape(k: EnvironmentKit) -> void:
	# Several approaches: a broken rocky arc, dune saddles and logistics cover.
	for i in range(28):
		var angle := i*2.399
		var radius := 47.0+(i%4)*18.0
		var p := DesertTerrain.point(sin(angle)*radius,cos(angle)*radius)
		var near_pad := false
		for pad: Vector2 in SPAWN_PADS:
			if Vector2(p.x,p.z).distance_to(pad)<7.0: near_pad = true
		if near_pad: continue
		k.rock(p+Vector3.UP*.9,Vector3(2.0+(i%3),1.5+(i%4)*.35,1.7+(i%2)),i,true)
	for i in range(180):
		var x := fposmod(i*71.73,286)-143
		var z := fposmod(i*93.41,286)-143
		if maxf(absf(x),absf(z))<39: continue
		var p := DesertTerrain.point(x,z)
		if i%3==0: k.rock(p+Vector3.UP*.08,Vector3(.18,.12,.24),i,false)
		else: EnvironmentProps.grass(k,p,.7+(i%4)*.2)
	# Twin tire marks follow the actual terrain instead of floating planes.
	for i in range(170):
		var z := -140+i*1.65
		var x := 12*sin(z*.024)
		for side in [-1.0,1.0]:
			var p := DesertTerrain.point(x+side*.9,z)
			var n := DesertTerrain.normal_at(p.x,p.z)
			var b := Basis(Quaternion(Vector3.UP,n))
			k.box("TireMark",p+Vector3.UP*.012,Vector3(.30,.012,.75),"sand:8a8070",false,b.get_euler(),true)
	for pos in [Vector3(21,0,-3),Vector3(-29,0,25)]:
		k.box("OilStain",pos+Vector3.UP*.014,Vector3(1.5,.01,.8),"asphalt",false,Vector3(0,.34,0),true)
	for side in [-1.0,1.0]:
		var p := DesertTerrain.point(side*140,0)
		k.pipe(p,p+Vector3.UP*2.0,.04,"steel",true,false)
		k.sign_text("LIMITE DA OPERAÇÃO",p+Vector3.UP*1.8+Vector3(0,0,.05),2.5)
