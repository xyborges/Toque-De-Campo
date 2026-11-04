extends RefCounted
class_name WarVehicleModels

# Visual construction only. Turret/elevation/muzzle nodes belong to WarVehicle
# and are identical on the dedicated server and every client.
const REFERENCE_VERSION:=3
const RUBBER:="252b28"
const STEEL:="384039"
const DIRT:="635f4a"
const GLASS:="213d40"
const EDGE:="727963"
var v: WarVehicle
var paint: String
var pieces:=0

static func build(actor: WarVehicle) -> void:
	var builder:=WarVehicleModels.new();builder.v=actor
	builder.paint="657052" if actor.team==0 else "4c6047"
	match actor.kind:
		"guarani": builder.guarani()
		"bmp2": builder.bmp()
		"abrams": builder.abrams()
		"t90": builder.t90()
	builder.common()
	if actor.kind in ["guarani","bmp2"]: builder.tv_launcher()
	actor.set_meta("model_details",{"version":REFERENCE_VERSION,"pieces":builder.pieces,"weapon":{"guarani":"Torre 30 mm","bmp2":"2A42 30 mm","abrams":"M256 120 mm","t90":"2A46 125 mm"}[actor.kind],"wheels":actor.wheels.size()})
	WarRenderBatch.vehicle(actor)
	builder.distance_lod()

func box(parent: Node3D,label: String,pos: Vector3,size: Vector3,color: String,rotation:=Vector3.ZERO) -> MeshInstance3D:
	pieces+=1
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size
	node.name=label;node.mesh=mesh;node.material_override=WarVehicle.material(color)
	node.position=pos;node.rotation=rotation;node.visibility_range_end=950;parent.add_child(node)
	return node

func tube(parent: Node3D,label: String,pos: Vector3,radius: float,length: float,color: String,rotation:=Vector3.ZERO,top:=1.) -> MeshInstance3D:
	pieces+=1
	return v.cylinder(parent,label,pos,radius,length,color,rotation,top)

func mesh_node(parent: Node3D,label: String,surface: SurfaceTool,color: String) -> MeshInstance3D:
	pieces+=1;surface.generate_normals();surface.index()
	var node:=MeshInstance3D.new();node.name=label;node.mesh=surface.commit()
	node.material_override=WarVehicle.material(color);node.visibility_range_end=950;parent.add_child(node)
	return node

func tri(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	# Godot front faces use clockwise winding.
	surface.add_vertex(a);surface.add_vertex(b);surface.add_vertex(c)

# Cross-sections: longitudinal position, lower height/width, shoulder
# height/width, roof height/width. The nose and V-bottom are actual geometry.
func hull(label: String,sections: Array,color: String) -> void:
	var rings: Array[PackedVector3Array]=[]
	for row: Array in sections:
		var z:=float(row[0]);var low:=float(row[1]);var lw:=float(row[2])
		var sh:=float(row[3]);var sw:=float(row[4]);var top:=float(row[5]);var tw:=float(row[6])
		rings.append(PackedVector3Array([Vector3(-lw,low,z),Vector3(lw,low,z),Vector3(sw,sh,z),Vector3(tw,top,z),Vector3(-tw,top,z),Vector3(-sw,sh,z)]))
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in rings.size()-1:
		for j in 6:
			var next:=(j+1)%6
			tri(surface,rings[i][j],rings[i+1][j],rings[i+1][next])
			tri(surface,rings[i][j],rings[i+1][next],rings[i][next])
	for j in range(1,5):
		tri(surface,rings[0][0],rings[0][j],rings[0][j+1])
		tri(surface,rings[-1][0],rings[-1][j+1],rings[-1][j])
	mesh_node(v,label,surface,color)

# Faceted turret plan with a tapered upper ring, rather than a box or a cone.
func turret_shell(label: String,outline: Array[Vector2],bottom: float,height: float,inset: float,color: String,front_slope:=1.) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in outline.size():
		var j:=(i+1)%outline.size()
		var a:=Vector3(outline[i].x,bottom,outline[i].y);var b:=Vector3(outline[j].x,bottom,outline[j].y)
		var c:=Vector3(outline[j].x*inset,bottom+height,outline[j].y*inset*(front_slope if outline[j].y<0 else 1.))
		var d:=Vector3(outline[i].x*inset,bottom+height,outline[i].y*inset*(front_slope if outline[i].y<0 else 1.))
		tri(surface,a,c,b);tri(surface,a,d,c)
		tri(surface,Vector3(0,bottom+height,0),c,d)
		tri(surface,Vector3(0,bottom,0),a,b)
	mesh_node(v.turret,label,surface,color)

func grilles(parent: Node3D,pos: Vector3,size: Vector2,count: int,label: String) -> void:
	box(parent,label+"Recess",pos,Vector3(size.x,.035,size.y),STEEL)
	for i in count:
		box(parent,label+"Slat",pos+Vector3(0,.035,(float(i)/maxi(1,count-1)-.5)*size.y),Vector3(size.x,.025,.035),paint)

func hatch(parent: Node3D,pos: Vector3,radius: float) -> void:
	tube(parent,"HatchGasket",pos,radius+.025,.045,RUBBER)
	tube(parent,"ArmouredHatch",pos+Vector3.UP*.045,radius,.06,paint)
	box(parent,"HatchHandle",pos+Vector3(0,.10,0),Vector3(.17,.035,.035),STEEL)
	for x in [-.07,.07]: box(parent,"HatchHandleFoot",pos+Vector3(x,.08,0),Vector3(.025,.06,.035),STEEL)

func wheel(side: int,z: float,radius: float,width: float,x: float,tyre:=false) -> void:
	var root:=Node3D.new();root.name="Tyre" if tyre else "RoadWheel"
	root.set_meta("wheel_radius",radius)
	root.position=Vector3(side*x,radius+.12,z);v.add_child(root);v.wheels.append(root)
	tube(root,"RubberTread",Vector3.ZERO,radius,width,RUBBER,Vector3(0,0,PI/2))
	tube(root,"PressedWheelRim",Vector3(side*(width*.5+.012),0,0),radius*.70,.04,paint,Vector3(0,0,PI/2))
	tube(root,"WheelHub",Vector3(side*(width*.5+.04),0,0),radius*.27,.08,paint,Vector3(0,0,PI/2))
	for i in (16 if tyre else 8):
		var a:=float(i)/ (16 if tyre else 8)*TAU
		if tyre:
			for stripe in [-1,1]: box(root,"ChevronTread",Vector3(stripe*width*.24,cos(a)*(radius+.012),sin(a)*(radius+.012)),Vector3(width*.52,.045,.11),RUBBER,Vector3(a,0,stripe*.18))
		else:
			tube(root,"RimRecess",Vector3(side*(width*.5+.036),cos(a)*radius*.47,sin(a)*radius*.47),radius*.09,.015,RUBBER,Vector3(0,0,PI/2))
	for i in 8:
		var a:=i*TAU/8
		tube(root,"HubBolt",Vector3(side*(width*.5+.085),cos(a)*radius*.20,sin(a)*radius*.20),.022,.025,paint,Vector3(0,0,PI/2))
	var roots: Array[Node]=[]
	for child in root.get_children(): roots.append(child)
	WarRenderBatch.merge(root,"vehicle-wheel-v2:%s:%s:%s"%[v.kind,side,tyre],roots)

func tracks(count: int) -> void:
	var length:=float(v.spec.size.z);var x:=float(v.spec.size.x)*.415
	var r:=.43 if v.kind=="abrams" else .40
	for side in [-1,1]:
		for i in count: wheel(side,-length*.34+i*length*.68/(count-1),r,.44,x)
		# Capsule-shaped continuous band, with curved front/rear runs.
		var path: Array[Vector3]=[];var half:=length*.38
		for end in [-1,1]:
			for i in 13:
				var a: float=(-PI if end==-1 else 0.)+float(i)/12*PI
				path.append(Vector3(side*x,.64+cos(a)*.50,end*half+sin(a)*.50))
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in path.size():
			var next:=(i+1)%path.size()
			var a:=path[i]+Vector3.LEFT*.29;var b:=path[i]+Vector3.RIGHT*.29
			var c:=path[next]+Vector3.RIGHT*.29;var d:=path[next]+Vector3.LEFT*.29
			tri(surface,a,b,c);tri(surface,a,c,d);tri(surface,c,b,a);tri(surface,d,c,a)
		mesh_node(v,"ContinuousTrackBelt",surface,RUBBER)
		for end in [-1,1]:
			tube(v,"DriveSprocket",Vector3(side*x,.64,end*half),.39,.48,STEEL,Vector3(0,0,PI/2))
			for i in 12:
				var a:=i*TAU/12
				box(v,"SprocketTooth",Vector3(side*x,.64+cos(a)*.39,end*half+sin(a)*.39),Vector3(.49,.06,.09),EDGE,Vector3(a,0,0))
		for i in 36:
			var z: float=-half+float(i)/35*half*2
			box(v,"TrackLowerShoe",Vector3(side*x,.13,z),Vector3(.60,.065,.13),STEEL)
			box(v,"TrackUpperShoe",Vector3(side*x,1.15,z),Vector3(.60,.055,.13),STEEL)
			box(v,"TrackRubberPad",Vector3(side*x,.09,z),Vector3(.35,.025,.08),RUBBER)

func barrel(parent: Node3D,end: Vector3,start_z: float,radius: float,calibre: float,label: String) -> void:
	var length:=start_z-end.z
	tube(parent,"Gun"+label,Vector3(end.x,end.y,(start_z+end.z)*.5+.01),radius,maxf(.01,length-.02),STEEL,Vector3(PI/2,0,0))
	# Open muzzle annulus: the visible front plane is exactly the shot marker.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var a:=i*TAU/16;var b:=(i+1)*TAU/16
		var outer_a:=end+Vector3(cos(a)*radius,sin(a)*radius,0)
		var outer_b:=end+Vector3(cos(b)*radius,sin(b)*radius,0)
		var inner_a:=end+Vector3(cos(a)*calibre*.5,sin(a)*calibre*.5,0)
		var inner_b:=end+Vector3(cos(b)*calibre*.5,sin(b)*calibre*.5,0)
		tri(surface,outer_a,inner_b,outer_b);tri(surface,outer_a,inner_a,inner_b)
		tri(surface,inner_a,inner_a+Vector3.BACK*.09,inner_b+Vector3.BACK*.09)
		tri(surface,inner_a,inner_b+Vector3.BACK*.09,inner_b)
	mesh_node(parent,"Muzzle"+label,surface,RUBBER)

func coax() -> void:
	if v.kind not in ["abrams","t90"]: return
	box(v.elevation,"CoaxialArmouredSupport",v.secondary_muzzle.position+Vector3(0,0,.72),Vector3(.16,.16,.25),paint)
	var rise:=Vector2(v.secondary_muzzle.position.x,v.secondary_muzzle.position.y)
	box(v.elevation,"CoaxialSupportArm",Vector3(rise.x*.5,rise.y*.5,.10),Vector3(rise.length()+.10,.10,.18),paint,Vector3(0,0,atan2(rise.y,rise.x)))
	barrel(v.elevation,v.secondary_muzzle.position,.04,.027,.012,"Coaxial")
	v.elevation.set_meta("secondary_tip",v.secondary_muzzle.position)

func guarani() -> void:
	hull("GuaraniVBottomHull",[[-3.40,.83,.76,1.32,1.28,1.44,1.12],[-2.25,.43,.62,1.57,1.38,1.95,1.10],[-1.2,.42,.62,1.57,1.38,1.95,1.15],[2.95,.62,.75,1.57,1.33,1.95,1.12],[3.4,.94,.86,1.57,1.20,1.84,1.05]],paint)
	for side in [-1,1]:
		# Welded side armour, reinforced towing eyes, steps and service panels
		# share the hull batch. They do not add collision or moving bodies.
		for z in [-2.62,.48,2.68]:
			box(v,"SideWeldSeam",Vector3(side*1.335,1.58,z),Vector3(.012,.018,.72),EDGE)
		for z in [-1.1,.82,2.70]:
			box(v,"HullLowerWear",Vector3(side*1.355,1.20,z),Vector3(.016,.11,.52),DIRT)
			for y in [1.48,1.74]: tube(v,"ArmourFastener",Vector3(side*1.365,y,z),.021,.016,STEEL,Vector3(0,0,PI*.5))
		box(v,"EmbarkStep",Vector3(side*1.40,.71,.82),Vector3(.35,.055,.65),STEEL)
		for z in [.60,1.04]: box(v,"StepSupport",Vector3(side*1.29,.82,z),Vector3(.12,.22,.045),STEEL)
		for z in [-1.92,-.22,1.78]:
			wheel(side,z,.62,.42,1.29,true)
			box(v,"WheelArchTop",Vector3(side*1.29,1.42,z),Vector3(.48,.10,1.28),paint)
			for end in [-1,1]: box(v,"SlopingWheelArch",Vector3(side*1.29,1.29,z+end*.64),Vector3(.48,.1,.40),paint,Vector3(end*.65,0,0))
		for z in [-2.8,.7,2.75]:
			box(v,"SideStowageLocker",Vector3(side*1.29,1.68,z),Vector3(.08,.28,.48),paint)
		for z in [.2,1.2,2.2]: box(v,"TroopVisionBlock",Vector3(side*1.22,1.86,z),Vector3(.035,.10,.19),GLASS)
		box(v,"RearLampHousing",Vector3(side*.92,1.28,3.33),Vector3(.22,.28,.08),STEEL)
		box(v,"RearRedLamp",Vector3(side*.92,1.34,3.38),Vector3(.13,.07,.025),"743a32")
		box(v,"RearMudflap",Vector3(side*1.29,.58,2.63),Vector3(.52,.72,.06),RUBBER)
		box(v,"RearPropulsorGuard",Vector3(side*.94,.90,3.25),Vector3(.48,.32,.32),STEEL)
	hatch(v,Vector3(-.57,1.98,-1.45),.32)
	for x in [-.8,-.57,-.34]: box(v,"DriverPeriscope",Vector3(x,2.02,-1.80),Vector3(.18,.10,.15),GLASS)
	grilles(v,Vector3(.57,1.97,-1.55),Vector2(.65,1.05),11,"EngineGuarani")
	box(v,"WaveDeflector",Vector3(0,1.48,-3.05),Vector3(2.13,.08,.68),paint,Vector3(-.28,0,0))
	for side in [-1,1]:
		box(v,"FrontServicePanel",Vector3(side*.70,1.40,-2.72),Vector3(.57,.045,.50),paint,Vector3(-.24,0,0))
		for x in [-.18,.18]: box(v,"PanelBolt",Vector3(side*.70+x,1.43,-2.83),Vector3(.035,.024,.035),STEEL)
		box(v,"BowLampGuard",Vector3(side*1.01,1.38,-3.11),Vector3(.34,.18,.15),STEEL,Vector3(-.10,0,0))
		box(v,"BowHeadlamp",Vector3(side*1.01,1.38,-3.20),Vector3(.23,.10,.016),"b4bba5")
	for z in [.64,1.18,1.72,2.28]:
		box(v,"RoofAntiSlip",Vector3(0,1.977,z),Vector3(1.28,.014,.33),RUBBER)
	box(v,"RearRampFrame",Vector3(0,1.24,3.38),Vector3(1.78,1.25,.12),STEEL)
	box(v,"RearRamp",Vector3(0,1.24,3.46),Vector3(1.57,1.12,.06),paint)
	box(v,"RampPersonnelDoor",Vector3(-.20,1.29,3.51),Vector3(.68,.86,.035),EDGE)
	box(v,"RampDoorInset",Vector3(-.20,1.29,3.54),Vector3(.62,.80,.025),paint)
	for x in [-.58,.58]: box(v,"RampHinge",Vector3(x,.70,3.52),Vector3(.17,.13,.16),STEEL)
	for y in [.89,1.13,1.37,1.61]:
		box(v,"RampAntiSlip",Vector3(.43,y,3.504),Vector3(.28,.025,.012),RUBBER)
	box(v,"DoorHandle",Vector3(.025,1.44,3.585),Vector3(.025,.15,.025),STEEL)
	box(v,"DoorHandleMount",Vector3(.025,1.44,3.555),Vector3(.07,.20,.025),paint)
	hatch(v,Vector3(-.48,1.98,1.4),.39);hatch(v,Vector3(.48,1.98,2.25),.39)
	tube(v.turret,"CannonTurretRing",Vector3(0,-.01,0),.60,.13,STEEL)
	turret_shell("Guarani30Turret",[Vector2(-.58,-.72),Vector2(-.68,.45),Vector2(.68,.45),Vector2(.58,-.72)],.02,.48,.75,paint)
	for side in [-1,1]: box(v.turret,"CannonElevationYoke",Vector3(side*.25,.30,-.47),Vector3(.09,.36,.44),paint)
	box(v.elevation,"Gun30Receiver",Vector3(0,0,.08),Vector3(.22,.25,.68),STEEL)
	box(v.elevation,"Gun30Feed",Vector3(-.34,-.04,.12),Vector3(.43,.40,.55),paint)
	box(v.elevation,"GunnerSensor",Vector3(.32,.02,-.12),Vector3(.26,.29,.35),paint)
	box(v.elevation,"GunnerOpticalWindow",Vector3(.32,.03,-.30),Vector3(.18,.16,.02),GLASS)
	barrel(v.elevation,v.muzzle.position,-.25,.042,.030,"30mm")
	tube(v.elevation,"Gun30Sleeve",Vector3(0,0,-.53),.07,.56,STEEL,Vector3(PI/2,0,0))
	for z in [-2.12,-2.03]: tube(v.elevation,"Gun30Brake",Vector3(0,0,z),.065,.055,STEEL,Vector3(PI/2,0,0))

func bmp() -> void:
	hull("BMPLowSlopedHull",[[-3.35,.67,.85,.94,1.43,1.02,1.22],[-1.35,.45,.98,1.12,1.48,1.47,1.25],[2.7,.45,1.01,1.11,1.45,1.47,1.23],[3.32,.64,1.08,1.10,1.37,1.35,1.18]],paint)
	tracks(6)
	for side in [-1,1]:
		box(v,"BMPFlotationSkirt",Vector3(side*1.45,1.16,.0),Vector3(.12,.31,6.20),paint)
		for z in [.45,1.35,2.25]:
			box(v,"BMPFiringPort",Vector3(side*1.35,1.31,z),Vector3(.06,.13,.17),STEEL)
			box(v,"BMPPortVision",Vector3(side*1.26,1.47,z-.12),Vector3(.12,.035,.16),GLASS)
		box(v,"RearTroopDoorFrame",Vector3(side*.60,1.02,3.31),Vector3(1.12,.93,.13),STEEL)
		box(v,"RearTroopFuelDoor",Vector3(side*.60,1.02,3.41),Vector3(1.02,.84,.18),paint)
		box(v,"RearDoorVision",Vector3(side*.60,1.31,3.51),Vector3(.23,.10,.025),GLASS)
		box(v,"TroopRoofHatch",Vector3(side*.63,1.51,1.72),Vector3(1.06,.075,1.65),paint)
		box(v,"RoofHatchHinge",Vector3(side*.63,1.57,1.05),Vector3(.46,.045,.07),STEEL)
		box(v,"BMPMudflap",Vector3(side*1.27,.50,3.1),Vector3(.60,.54,.08),RUBBER)
	hatch(v,Vector3(-.69,1.49,-1.55),.29)
	grilles(v,Vector3(.62,1.49,-1.62),Vector2(.78,1.05),12,"EngineBMP")
	box(v,"BMPBowTrimVane",Vector3(0,1.08,-2.62),Vector3(2.40,.075,1.08),paint,Vector3(-.21,0,0))
	tube(v.turret,"BMPTurretRing",Vector3(0,0,0),.96,.12,STEEL)
	var outline: Array[Vector2]=[]
	for i in 12: outline.append(Vector2(sin(i*TAU/12)*.94,cos(i*TAU/12)*.98))
	turret_shell("BMPFacetedConicalTurret",outline,.01,.48,.68,paint)
	hatch(v.turret,Vector3(-.36,.54,.18),.25);hatch(v.turret,Vector3(.32,.54,.18),.24)
	box(v.turret,"BMPGunnerSight",Vector3(-.45,.49,-.45),Vector3(.23,.21,.24),STEEL)
	box(v.turret,"BMPGunnerLens",Vector3(-.45,.51,-.58),Vector3(.16,.09,.025),GLASS)
	box(v.elevation,"Gun2A42Mantlet",Vector3(0,.02,.11),Vector3(.37,.38,.60),paint)
	box(v.elevation,"Gun2A42Receiver",Vector3(0,0,-.20),Vector3(.15,.17,.64),STEEL)
	barrel(v.elevation,v.muzzle.position,-.39,.038,.030,"2A42")
	tube(v.elevation,"Gun2A42Sleeve",Vector3(0,0,-.63),.064,.38,STEEL,Vector3(PI/2,0,0))
	for z in [-2.11,-2.02]:
		tube(v.elevation,"Gun2A42MuzzleBrake",Vector3(0,0,z),.067,.065,STEEL,Vector3(PI/2,0,0))
	coax()

func abrams() -> void:
	hull("AbramsLongGlacisHull",[[-3.94,.60,1.18,.97,1.67,1.15,1.51],[-1.62,.44,1.24,1.24,1.74,1.71,1.43],[2.90,.44,1.24,1.26,1.74,1.71,1.48],[3.94,.70,1.26,1.34,1.65,1.65,1.43]],paint)
	tracks(7)
	for side in [-1,1]:
		for i in 6:
			box(v,"AbramsSegmentedSideSkirt",Vector3(side*1.75,1.21,-2.90+i*1.06),Vector3(.09,.72,1.01),paint)
			box(v,"SkirtUpperBolt",Vector3(side*1.81,1.52,-2.90+i*1.06),Vector3(.03,.06,.06),EDGE)
		box(v,"AbramsFrontMudguard",Vector3(side*1.50,.75,-3.80),Vector3(.66,.52,.12),RUBBER,Vector3(-.16,0,0))
	grilles(v,Vector3(0,1.75,2.70),Vector2(2.42,1.50),16,"EngineTurbineDeck")
	box(v,"EngineRearExhaustGrille",Vector3(0,1.20,3.95),Vector3(2.33,.53,.09),STEEL)
	for i in 16: box(v,"EngineExhaustSlat",Vector3(-1.08+i*.144,1.20,4.01),Vector3(.048,.46,.05),paint)
	hatch(v,Vector3(0,1.65,-1.57),.31)
	for x in [-.21,0.,.21]: box(v,"AbramsDriverPeriscope",Vector3(x,1.67,-1.91),Vector3(.16,.10,.13),GLASS)
	var outline: Array[Vector2]=[Vector2(-.48,-1.69),Vector2(-1.56,-1.12),Vector2(-1.61,.76),Vector2(-1.34,2.34),Vector2(1.34,2.34),Vector2(1.61,.76),Vector2(1.56,-1.12),Vector2(.48,-1.69)]
	turret_shell("AbramsWeldedAngularTurret",outline,-.24,.87,.83,paint,.64)
	box(v.turret,"AbramsBustleAmmoCompartment",Vector3(0,.24,2.06),Vector3(2.54,.68,.89),paint)
	for x in [-.64,.64]: box(v.turret,"BustleBlowoffPanel",Vector3(x,.62,2.05),Vector3(1.20,.05,.82),EDGE)
	for x in [-1.38,1.38]:
		box(v.turret,"BustleRackSide",Vector3(x,.20,2.62),Vector3(.045,.49,1.03),STEEL)
		for z in [2.14,2.61,3.1]: box(v.turret,"BustleRackPost",Vector3(x,.22,z),Vector3(.045,.55,.045),EDGE)
	for y in [0.,.45]: box(v.turret,"BustleRackRearRail",Vector3(0,y,3.10),Vector3(2.81,.04,.045),STEEL)
	for x in [-1.1,-.55,0.,.55,1.1]: box(v.turret,"BustleBasketFloor",Vector3(x,-.05,2.74),Vector3(.035,.04,.75),STEEL)
	hatch(v.turret,Vector3(.59,.68,.48),.34);hatch(v.turret,Vector3(-.59,.68,.59),.31)
	tube(v.turret,"CommanderIndependentSight",Vector3(-.67,.88,-.49),.20,.40,paint)
	box(v.turret,"CITVOptic",Vector3(-.67,.94,-.69),Vector3(.23,.18,.04),GLASS)
	box(v.turret,"GunnerPrimarySight",Vector3(.68,.77,-.79),Vector3(.41,.27,.43),paint)
	box(v.turret,"GunnerPrimaryLens",Vector3(.68,.78,-1.02),Vector3(.30,.16,.035),GLASS)
	main_tank_gun("M256",.120)

func t90_outline() -> Array[Vector2]:
	return [Vector2(-.42,-1.24),Vector2(-1.12,-.92),Vector2(-1.34,-.25),Vector2(-1.27,.82),Vector2(-.65,1.26),Vector2(.65,1.26),Vector2(1.27,.82),Vector2(1.34,-.25),Vector2(1.12,-.92),Vector2(.42,-1.24)]

func t90() -> void:
	hull("T90LowHull",[[-3.44,.63,1.01,.97,1.52,1.12,1.25],[-1.64,.40,1.06,1.15,1.61,1.57,1.27],[2.75,.42,1.08,1.20,1.61,1.57,1.31],[3.44,.66,1.12,1.21,1.52,1.51,1.29]],paint)
	tracks(6)
	for side in [-1,1]:
		for i in 6:
			box(v,"T90SideSkirtPanel",Vector3(side*1.65,.94,-2.62+i*.99),Vector3(.08,.90,.94),RUBBER)
			if i<3: box(v,"T90SideERA",Vector3(side*1.72,1.23,-2.62+i*.99),Vector3(.18,.42,.86),paint)
		for i in 4:
			box(v,"GlacisReactiveArmour",Vector3(side*(.22+i*.34),1.36,-2.34),Vector3(.31,.19,.73),paint,Vector3(-.25,0,0))
		box(v,"FrontMudguard",Vector3(side*1.42,.72,-3.28),Vector3(.62,.53,.10),RUBBER)
	grilles(v,Vector3(0,1.61,2.37),Vector2(2.1,1.21),12,"EngineT90Deck")
	for side in [-1,1]:
		tube(v,"ExternalFuelDrum",Vector3(side*.78,1.28,3.56),.31,.92,paint,Vector3(0,0,PI/2))
		for x in [-.31,.31]: tube(v,"FuelDrumStrap",Vector3(side*.78+x,1.28,3.56),.322,.045,STEEL,Vector3(0,0,PI/2))
	box(v,"UnditchingLog",Vector3(0,.74,3.47),Vector3(2.67,.18,.18),"685b43")
	hatch(v,Vector3(0,1.62,-1.42),.27)
	turret_shell("T90LowWeldedTurret",t90_outline(),-.13,.66,.82,paint)
	for side in [-1,1]:
		for i in 4:
			box(v.turret,"TurretKontaktStyleArmour",Vector3(side*(.54+i*.22),.23,-1.04+i*.13),Vector3(.31,.37,.45),EDGE,Vector3(.19,side*(.28+i*.17),0))
		for i in 3: box(v.turret,"TurretRoofERA",Vector3(side*(.45+i*.27),.57,-.27),Vector3(.24,.12,.43),paint)
		box(v.turret,"OptoelectronicHousing",Vector3(side*.74,.35,-1.16),Vector3(.26,.27,.18),STEEL)
		box(v.turret,"OptoelectronicLens",Vector3(side*.74,.35,-1.265),Vector3(.17,.16,.025),"693d35")
	hatch(v.turret,Vector3(.52,.59,.43),.29);hatch(v.turret,Vector3(-.50,.59,.36),.28)
	box(v.turret,"T90GunnerSight",Vector3(-.60,.70,-.57),Vector3(.34,.27,.31),paint)
	box(v.turret,"T90SightLens",Vector3(-.60,.71,-.74),Vector3(.24,.15,.03),GLASS)
	main_tank_gun("2A46",.125)

func main_tank_gun(label: String,calibre: float) -> void:
	box(v.elevation,"GunMantlet",Vector3(0,0,.13),Vector3(.57,.45,.56),paint)
	barrel(v.elevation,v.muzzle.position,-.10,.091,calibre,label)
	tube(v.elevation,"GunThermalSleeve",Vector3(0,0,-1.10),.113,1.42,paint,Vector3(PI/2,0,0))
	tube(v.elevation,"GunFumeExtractor",Vector3(0,0,-1.92),.155,.55,paint,Vector3(PI/2,0,0),.88)
	for z in [-.48,-1.0,-1.55,-2.24,-2.9]: tube(v.elevation,"GunSleeveBand",Vector3(0,0,z),.119,.035,EDGE,Vector3(PI/2,0,0))
	coax()

func common() -> void:
	var width:=float(v.spec.size.x);var length:=float(v.spec.size.z)
	for side in [-1,1]:
		for i in (3 if v.kind in ["guarani","bmp2"] else 6):
			var pos:=Vector3(side*(.49 if v.kind=="guarani" else .93),.22,-.10+i*.115)
			tube(v.turret,"SmokeDischarger",pos,.048,.24,STEEL,Vector3(.8,0,side*.70))
		box(v,"FrontHeadlampGuard",Vector3(side*width*.36,1.02,-length*.47),Vector3(.26,.23,.17),STEEL)
		box(v,"Headlamp",Vector3(side*width*.36,1.03,-length*.47-.09),Vector3(.15,.115,.025),"a6ad95")
		for z in [-length*.43,length*.43]:
			tube(v,"TowLug",Vector3(side*width*.28,.65,z),.08,.16,EDGE,Vector3(PI/2,0,0))
		# APC radios mount directly on their rear roof. A tank radio follows its
		# turret; the base touches the turret roof instead of hanging above it.
		var radio_parent: Node3D=v if v.kind in ["guarani","bmp2"] else v.turret
		var radio_base: Vector3={"guarani":Vector3(side*.95,1.95,2.55),"bmp2":Vector3(side*1.08,1.47,2.40),"abrams":Vector3(side*.65,.63,.91),"t90":Vector3(side*.65,.53,.91)}[v.kind]
		tube(radio_parent,"RadioAntennaBase",radio_base+Vector3.UP*.07,.035,.14,STEEL)
		tube(radio_parent,"RadioWhip",radio_base+Vector3.UP*.75,.008,1.22,RUBBER)
		var grab: Vector2={"guarani":Vector2(1.30,1.68),"bmp2":Vector2(1.44,1.18),"abrams":Vector2(1.74,1.42),"t90":Vector2(1.63,1.30)}[v.kind]
		for z in [.4,1.5]:
			box(v,"HullGrabHandle",Vector3(side*grab.x,grab.y,z),Vector3(.045,.04,.27),EDGE)
			for end in [-1,1]: box(v,"HullGrabHandleFoot",Vector3(side*(grab.x-.035),grab.y,z+end*.115),Vector3(.08,.04,.035),paint)
	v.elevation.set_meta("barrel_tip",v.muzzle.position)

func all_meshes(parent: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	for child in parent.get_children():
		if child is MeshInstance3D: result.append(child)
		result.append_array(all_meshes(child))
	return result

func distance_lod() -> void:
	# The coarse silhouette still follows the same turret/elevation pivots.
	# Physics and hit detection never use these visibility ranges.
	for mesh in all_meshes(v): mesh.visibility_range_end=160
	var existing: Array[MeshInstance3D]=all_meshes(v)
	var width:=float(v.spec.size.x);var length:=float(v.spec.size.z)
	var roof: float={"guarani":1.95,"bmp2":1.47,"abrams":1.71,"t90":1.57}[v.kind]
	hull("FarHull",[[-length*.49,.65,width*.32,roof*.70,width*.47,roof*.72,width*.43],[-length*.24,.45,width*.31,roof*.81,width*.49,roof,width*.40],[length*.47,.58,width*.34,roof*.81,width*.47,roof,width*.40]],paint)
	for side in [-1,1]:
		if v.kind=="guarani":
			for z in [-1.92,-.22,1.78]: tube(v,"FarTyre",Vector3(side*1.29,.74,z),.62,.42,RUBBER,Vector3(0,0,PI/2))
		else: box(v,"FarTrack",Vector3(side*width*.415,.66,0),Vector3(.60,1.0,length*.87),RUBBER)
	if v.kind=="abrams":
		var outline: Array[Vector2]=[Vector2(-.48,-1.69),Vector2(-1.56,-1.12),Vector2(-1.34,2.34),Vector2(1.34,2.34),Vector2(1.56,-1.12),Vector2(.48,-1.69)]
		turret_shell("FarAbramsTurret",outline,-.24,.87,.83,paint,.64)
	elif v.kind=="t90": turret_shell("FarT90Turret",t90_outline(),-.13,.66,.82,paint)
	elif v.kind=="bmp2": tube(v.turret,"FarBMPTurret",Vector3(0,.25,0),.94,.48,paint,Vector3.ZERO,.68)
	else: box(v.turret,"FarRemax",Vector3(0,.16,-.15),Vector3(.63,.39,.66),paint)
	var length_gun:=absf(v.muzzle.position.z)
	tube(v.elevation,"FarGun",Vector3(0,0,-length_gun*.5),.092 if v.kind in ["abrams","t90"] else .038,length_gun,STEEL,Vector3(PI/2,0,0))
	for label in ["hull","turret","elevation"]:
		var parent: Node3D=v if label=="hull" else (v.turret if label=="turret" else v.elevation)
		var roots: Array[Node]=[]
		for child in parent.get_children():
			if child is MeshInstance3D and child not in existing: roots.append(child)
		WarRenderBatch.merge(parent,"vehicle-far-v2:%s:%s"%[v.kind,label],roots)
	for mesh in all_meshes(v):
		if mesh not in existing:
			mesh.visibility_range_begin=160;mesh.visibility_range_end=2300;mesh.set_meta("vehicle_lod",true)

func tv_launcher() -> void:
	var tip:=v.secondary_muzzle.position
	box(v.elevation,"TVLauncherCradle",tip+Vector3(0,-.12,.64),Vector3(.42,.18,.42),paint)
	tube(v.elevation,"TVLaunchContainer",tip+Vector3(0,0,.64),.16,1.28,paint,Vector3(PI*.5,0,0))
	tube(v.elevation,"TVLaunchCollar",tip+Vector3(0,0,.04),.175,.08,EDGE,Vector3(PI*.5,0,0))
	tube(v.elevation,"TVLaunchAperture",tip+Vector3(0,0,-.007),.13,.01,RUBBER,Vector3(PI*.5,0,0))
	for z in [.35,.95]: box(v.elevation,"TVClamp",tip+Vector3(0,-.05,z),Vector3(.37,.09,.08),STEEL)
