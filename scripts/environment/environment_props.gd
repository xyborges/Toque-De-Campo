extends RefCounted
class_name EnvironmentProps

static func drum(k: EnvironmentKit,pos: Vector3,red := false) -> void:
	k.cylinder("Drum",pos+Vector3.UP*.48,.33,.96,"steel:c7a18c" if red else "steel:adb59c",true)
	for y in [.06,.28,.70,.94]: k.cylinder("DrumHoop",pos+Vector3.UP*y,.345,.035,"steel")
	k.cylinder("DrumCap",pos+Vector3(.12,.975,0),.045,.025,"dark",false,1,Vector3.ZERO,true)

static func sandbags(k: EnvironmentKit,pos: Vector3,length := 6.0,yaw := 0.0) -> void:
	if not EnvironmentKit.meshes.has("sandbag"):
		var shape := SphereMesh.new()
		shape.radius = 1
		shape.height = 2
		shape.radial_segments = 12
		shape.rings = 5
		EnvironmentKit.meshes.sandbag = shape
	var b := Basis(Vector3.UP,yaw)
	for row in range(3):
		for i in range(int(length/.85)):
			var p := pos+b*Vector3(-length*.5+.45+i*.85+(.12 if row==1 else 0),.17+row*.28,0)
			k._instance(EnvironmentKit.meshes.sandbag,"fabric:e9d7af",Transform3D(b*Basis.from_scale(Vector3(.50,.19,.32)),p))
	var collision := BoxShape3D.new()
	collision.size = Vector3(length-.15,.90,.62)
	k._collider("SandbagCover",collision,Transform3D(b,pos+Vector3.UP*.45))

static func container(k: EnvironmentKit,pos: Vector3,open := false) -> void:
	k.box("ContainerFloor",pos+Vector3.UP*.10,Vector3(2.5,.2,6),"steel",true)
	k.box("ContainerRoof",pos+Vector3.UP*2.55,Vector3(2.5,.13,6),"steel:a6b5b4",true)
	for side in [-1.0,1.0]:
		k.box("ContainerSide",pos+Vector3(side*1.22,1.3,0),Vector3(.10,2.5,6),"steel:9fae9e",true)
		for i in range(24): k.box("CorrugatedRib",pos+Vector3(side*1.29,1.33,-2.88+i*.25),Vector3(.045,2.25,.05),"steel:9fae9e")
		for z in [-2.96,2.96]: k.box("ContainerCorner",pos+Vector3(side*1.19,1.3,z),Vector3(.18,2.6,.18),"steel")
	k.box("ContainerBack",pos+Vector3(0,1.3,-2.95),Vector3(2.5,2.6,.10),"steel:9fae9e",true)
	if not open:
		for side in [-1.0,1.0]:
			k.box("CargoDoor",pos+Vector3(side*.61,1.3,2.98),Vector3(1.20,2.44,.08),"steel:9fae9e",true)
			k.pipe(pos+Vector3(side*.39,.22,3.05),pos+Vector3(side*.39,2.37,3.05),.024,"steel")
	else:
		for side in [-1.0,1.0]: k.box("OpenCargoDoor",pos+Vector3(side*1.25,1.3,3.55),Vector3(.10,2.45,1.2),"steel:9fae9e",true)
		k.crate(pos+Vector3(-.5,.2,-1.9),Vector3(.9,1.15,.9),true)
	k.sign_text("TDC / LOG 034",pos+Vector3(0,2.1,3.045),1.6)

static func tower(k: EnvironmentKit,pos: Vector3,height := 15.0) -> void:
	for x in [-.7,.7]:
		for z in [-.7,.7]:
			k.beam(pos+Vector3(x,0,z),pos+Vector3(x*.25,height,z*.25),.10,.10,"steel",true)
	for i in range(int(height/2)):
		var y := i*2.0
		var w := lerpf(.7,.175,y/height)
		for side in [-1.0,1.0]:
			k.beam(pos+Vector3(-w,y,side*w),pos+Vector3(w,y+2,side*w*.85),.045,.045,"steel")
			k.beam(pos+Vector3(side*w,y,-w),pos+Vector3(side*w*.85,y+2,w),.045,.045,"steel")
	k.pipe(pos+Vector3.UP*height,pos+Vector3.UP*(height+2),.04,"steel")
	for y in [height*.66,height*.86]: k.box("AntennaPanel",pos+Vector3(.40,y,0),Vector3(.2,1.4,.48),"plaster",false)
	for anchor in [Vector3(4,0,4),Vector3(-4,0,4),Vector3(0,0,-5)]: k.pipe(pos+Vector3.UP*(height*.7),pos+anchor,.012,"steel",false)

static func generator(k: EnvironmentKit,pos: Vector3) -> void:
	k.box("GeneratorSkid",pos+Vector3.UP*.12,Vector3(2.2,.24,1.05),"steel",true)
	k.box("EngineHousing",pos+Vector3.UP*.8,Vector3(1.9,1.3,.95),"steel:a5ad8e",true)
	for i in range(10): k.box("RadiatorSlat",pos+Vector3(-.96,.9,-.35+i*.08),Vector3(.04,.76,.025),"dark",false,Vector3.ZERO,true)
	k.box("GeneratorControls",pos+Vector3(.5,1.05,.49),Vector3(.55,.40,.025),"dark")
	for x in [.34,.48,.62]: k.cylinder("ControlDial",pos+Vector3(x,1.08,.515),.04,.015,"plaster",false,1,Vector3(PI/2,0,0),true)
	k.pipe(pos+Vector3(.65,1.2,-.20),pos+Vector3(.65,2.05,-.20),.055,"steel")
	k.pipe(pos+Vector3(.65,2.05,-.20),pos+Vector3(.85,2.05,-.20),.055,"steel")

static func canopy(k: EnvironmentKit,pos: Vector3,size := Vector2(8,6),height := 3.8) -> void:
	for x in [-size.x*.5,size.x*.5]:
		for z in [-size.y*.5,size.y*.5]: k.box("CanopyPost",pos+Vector3(x,height*.5,z),Vector3(.13,height,.13),"steel",true)
	for z in [-size.y*.5,0.0,size.y*.5]: k.box("RoofPurlin",pos+Vector3(0,height-.05,z),Vector3(size.x+.3,.16,.10),"steel")
	k.box("CanopyRoof",pos+Vector3(0,height+.08,0),Vector3(size.x+.65,.10,size.y+.65),"steel:b1ad98",true,Vector3(0,0,.025))
	for i in range(int(size.x/.4)):
		k.box("RoofCorrugation",pos+Vector3(-size.x*.5+i*.4,height+.15,0),Vector3(.04,.035,size.y+.65),"steel:b1ad98")

static func fence(k: EnvironmentKit,a: Vector3,b: Vector3,ground_follow := true) -> void:
	var length := a.distance_to(b)
	var segments := maxi(1,ceili(length/3.0))
	for i in range(segments+1):
		var p := a.lerp(b,float(i)/segments)
		if ground_follow: p.y = DesertTerrain.height_at(p.x,p.z)
		k.cylinder("FencePost",p+Vector3.UP*1.15,.045,2.3,"steel",true)
		if i==segments: continue
		var next := a.lerp(b,float(i+1)/segments)
		if ground_follow: next.y = DesertTerrain.height_at(next.x,next.z)
		# Real rails stop movement; fine wire is visual and bullets pass through.
		for y in [.8,2.15]: k.pipe(p+Vector3.UP*y,next+Vector3.UP*y,.022,"steel",true,false)
		for row in range(7):
			var y := .2+row*.27
			k.pipe(p+Vector3.UP*y,next+Vector3.UP*(y+.12),.006,"steel",false,true)
		for step in range(8):
			var p0 := p.lerp(next,step/8.0)
			k.pipe(p0+Vector3.UP*.1,p0+Vector3.UP*2.1,.006,"steel",false,true)

static func truck(k: EnvironmentKit,pos: Vector3) -> void:
	# Static maintenance prop, never a drivable vehicle or an inventory item.
	k.box("TruckChassis",pos+Vector3.UP*.65,Vector3(2.1,.35,5.2),"steel",true)
	k.box("TruckHood",pos+Vector3(0,1.17,-1.8),Vector3(1.9,.65,1.4),"steel:8b9a76",true)
	k.box("TruckCabRear",pos+Vector3(0,1.45,-.25),Vector3(2.0,1.5,.16),"steel:8b9a76",true)
	k.box("CabRoof",pos+Vector3(0,2.25,-.9),Vector3(2.04,.12,1.6),"steel:8b9a76",true)
	for side in [-1.0,1.0]:
		for z in [-1.55,-.25]: k.beam(pos+Vector3(side*.94,1.35,z),pos+Vector3(side*.94,2.25,z+.12),.08,.08,"steel",true)
		k.box("TruckDoor",pos+Vector3(side*1.0,1.15,-.85),Vector3(.10,.70,1.30),"steel:8b9a76",true)
		k.box("CargoSide",pos+Vector3(side*1.0,1.30,1.45),Vector3(.10,.85,2.7),"wood",true)
		for z in [-1.65,1.7]:
			k.cylinder("TruckTire",pos+Vector3(side*1.05,.53,z),.53,.27,"dark",true,1,Vector3(0,0,PI/2))
			k.cylinder("TruckHub",pos+Vector3(side*1.21,.53,z),.26,.03,"steel",false,1,Vector3(0,0,PI/2))
		for z in [.4,1.5,2.5]: k.box("BedRib",pos+Vector3(side*1.06,1.3,z),Vector3(.06,.95,.08),"steel")
	k.box("CargoFloor",pos+Vector3(0,.92,1.4),Vector3(2,.12,2.7),"wood",true)
	k.box("TailGate",pos+Vector3(0,1.3,2.75),Vector3(2,.85,.10),"wood",true)
	k.box("TruckGrille",pos+Vector3(0,1.1,-2.52),Vector3(1.5,.45,.03),"dark")
	for x in [-.7,.7]: k.cylinder("Headlamp",pos+Vector3(x,1.35,-2.55),.13,.035,"plaster",false,1,Vector3(PI/2,0,0))

static func grass(k: EnvironmentKit,pos: Vector3,scale := 1.0,coastal := false) -> void:
	for i in range(5):
		var angle := i*2.4+pos.x
		var end := pos+Vector3(sin(angle)*.22,.38+(i%3)*.12,cos(angle)*.22)*scale
		k.beam(pos,end,.025*scale,.018*scale,"fabric:a4b38b" if coastal else "fabric:d6bc86")
