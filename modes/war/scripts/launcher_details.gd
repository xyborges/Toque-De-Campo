extends RefCounted
class_name WarLauncherDetails
const VERSION:=3
static var materials: Dictionary={}
static var grain: ImageTexture

# Metres, -Z forward; supplied RPG-7 and FIM-92 photographs define the shapes.
static func build(id: String) -> Node3D:
	var root:=Node3D.new();root.name="WarLauncher";root.set_meta("weapon",id)
	var olive:=material(Color("758056"),.15);var dark:=material(Color("283028"),.42)
	var metal:=material(Color("4b5248"),.72);var edge:=material(Color("8c927c"),.60)
	var wood:=material(Color("ba7b31"),0);var rubber:=material(Color("17201b"),0);var glass:=material(Color("608780"),.6)
	if id=="rpg":
		tube(root,"SteelLaunchTube",Vector3(0,0,-.03),1.18,.043,.043,metal)
		tube(root,"OrangeHeatShield",Vector3(0,0,.27),.47,.057,.057,wood)
		for z in [.055,.32,.49]: ring(root,"ShieldRetainingBand",Vector3(0,0,z),.058,.006,dark)
		for z in [-.36,-.12]: ring(root,"ReceiverCollar",Vector3(0,0,z),.047,.004,edge)
		profile(root,"HollowRearVenturi",[Vector2(.49,.044),Vector2(.56,.052),Vector2(.67,.090),Vector2(.70,.095),Vector2(.70,.078),Vector2(.65,.074),Vector2(.55,.041),Vector2(.49,.033)],dark)
		ring(root,"VenturiRim",Vector3(0,0,.698),.087,.008,rubber)
		tube(root,"WarheadNeck",Vector3(0,0,-.65),.17,.032,.032,olive)
		tube(root,"WarheadRearCone",Vector3(0,0,-.76),.12,.084,.034,olive)
		tube(root,"WarheadBelly",Vector3(0,0,-.855),.08,.084,.084,olive)
		tube(root,"WarheadLongNose",Vector3(0,0,-.968),.15,.016,.084,olive)
		tube(root,"FuseTip",Vector3(0,0,-1.065),.055,.010,.016,edge)
		for z in [-.812,-.900]: ring(root,"WarheadSeam",Vector3(0,0,z),.083,.0025,metal)
		box(root,"TriggerReceiver",Vector3(0,-.065,.005),Vector3(.080,.080,.19),dark)
		grip(root,"WoodTriggerGrip",Vector3(0,-.15,.045),material(Color("694224"),0))
		grip(root,"WoodForwardGrip",Vector3(0,-.15,-.36),material(Color("694224"),0))
		guard(root,Vector3(0,-.11,-.055),metal)
		for x in [-.043,.043]:
			for z in [-.045,.075]: screw(root,Vector3(x,-.075,z),edge)
		box(root,"OpticSideRail",Vector3(-.059,.012,-.19),Vector3(.035,.11,.27),dark)
		scope(root,Vector3(-.108,.137,-.20),.30,.033,dark,glass)
		tube(root,"OpticAdjustmentDrum",Vector3(-.15,.14,-.17),.048,.028,.028,metal,Vector3(0,0,PI*.5))
		for z in [-.50,.18]:
			box(root,"IronSightBracket",Vector3(0,.068,z),Vector3(.027,.073,.028),dark)
			ring(root,"IronSightRing",Vector3(0,.110,z),.018,.003,metal)
		marker(root,"LauncherMuzzle",Vector3(0,0,-1.108));marker(root,"GripRight",Vector3(0,-.17,.045));marker(root,"GripLeft",Vector3(0,-.17,-.36))
	else:
		tube(root,"FIM92LaunchContainer",Vector3(0,.005,-.05),1.47,.064,.064,olive)
		for section in [[-.65,8],[.28,10]]:
			for index in int(section[1]): ring(root,"CompositeRib",Vector3(0,.005,float(section[0])+index*.018),.0645,.0015,metal)
		for z in [-.72,-.53,.22,.61]: ring(root,"ReinforcedCollar",Vector3(0,.005,z),.068,.009,dark)
		profile(root,"FrontFlaredRim",[Vector2(-.77,.065),Vector2(-.84,.073),Vector2(-.885,.099),Vector2(-.900,.099),Vector2(-.900,.080),Vector2(-.865,.067),Vector2(-.79,.051),Vector2(-.77,.051)],olive,Vector3(0,.005,0))
		tube(root,"DarkInnerAperture",Vector3(0,.005,-.795),.006,.051,.051,rubber)
		profile(root,"RearProtectiveBell",[Vector2(.64,.065),Vector2(.70,.089),Vector2(.735,.092),Vector2(.735,.077),Vector2(.69,.057),Vector2(.64,.053)],dark,Vector3(0,.005,0))
		box(root,"GripstockHousing",Vector3(.016,-.105,.095),Vector3(.13,.12,.36),dark)
		box(root,"GripstockLowerBody",Vector3(.013,-.168,.115),Vector3(.105,.08,.30),olive)
		grip(root,"ContouredTriggerGrip",Vector3(.012,-.205,.13),rubber);guard(root,Vector3(.012,-.15,.005),metal)
		box(root,"ElectronicsReceiver",Vector3(.03,-.13,-.065),Vector3(.18,.115,.14),olive)
		box(root,"ReceiverEndPlate",Vector3(.03,-.13,-.144),Vector3(.19,.12,.016),edge)
		tube(root,"BatteryCoolantUnit",Vector3(.105,-.18,.11),.22,.038,.038,metal,Vector3.ZERO)
		tube(root,"CoolantFoot",Vector3(.105,-.295,.11),.025,.042,.042,rubber,Vector3.ZERO)
		for x in [-.057,.08]:
			for z in [-.02,.20]: screw(root,Vector3(x,-.11,z),edge)
		box(root,"ShoulderPad",Vector3(0,-.070,.46),Vector3(.15,.095,.23),rubber)
		box(root,"ForwardSupportCradle",Vector3(0,-.063,-.31),Vector3(.13,.072,.18),dark)
		for z in [-.25,.04]:
			var support:=box(root,"RaisedSightSupport",Vector3(-.035,.12,z),Vector3(.025,.18,.025),metal);support.rotation.x=-.20
		box(root,"SightPlatform",Vector3(-.035,.214,-.105),Vector3(.12,.025,.37),dark)
		box(root,"IFFOpticalHead",Vector3(-.035,.252,-.01),Vector3(.13,.075,.18),rubber)
		scope(root,Vector3(-.060,.254,-.23),.22,.027,dark,glass)
		var window:=box(root,"SightGlass",Vector3(-.035,.277,-.32),Vector3(.12,.09,.005),glass);window.rotation.x=-.12
		for x in [-.078,.018]: box(root,"SightProtectiveRail",Vector3(x,.27,-.22),Vector3(.008,.085,.24),metal)
		box(root,"IFFSideModule",Vector3(.085,.056,-.20),Vector3(.045,.070,.13),dark)
		for side in [-1,1]:
			var serial:=Label3D.new();serial.text="FIM-92   /   416";serial.font_size=40;serial.pixel_size=.00048;serial.modulate=Color("c7cbb4");serial.outline_size=0
			serial.position=Vector3(side*.065,.005,-.19);serial.rotation.y=side*PI*.5;serial.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;serial.visibility_range_end=35;root.add_child(serial)
		marker(root,"LauncherMuzzle",Vector3(0,.005,-.91));marker(root,"GripRight",Vector3(.012,-.21,.13));marker(root,"GripLeft",Vector3(0,-.105,-.31))
	var rigid: Array[Node]=[]
	for child in root.get_children():
		if child is MeshInstance3D: rigid.append(child)
	root.set_meta("model_details",{"version":VERSION,"parts":rigid.size(),"reference":"user-supplied RPG-7 / FIM-92 photos"})
	WarRenderBatch.merge(root,"launcher:%s:%d"%[id,VERSION],rigid)
	return root

static func material(color: Color,metallic: float) -> StandardMaterial3D:
	var key:=color.to_html()+":"+str(metallic)
	if not materials.has(key):
		if grain==null:
			var image:=Image.create(128,128,true,Image.FORMAT_RGB8);var noise:=FastNoiseLite.new();noise.seed=165;noise.frequency=.16
			for y in 128:
				for x in 128:
					var value:=.89+noise.get_noise_2d(x,y)*.1+sin(y*.45)*.015;image.set_pixel(x,y,Color(value,value,value))
			image.generate_mipmaps();grain=ImageTexture.create_from_image(image)
		var result:=StandardMaterial3D.new();result.albedo_color=color;result.albedo_texture=grain;result.metallic=metallic;result.roughness=.68 if metallic>0 else .86;materials[key]=result
	return materials[key]

static func box(root: Node3D,label: String,position: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var result:=MeshInstance3D.new();result.name=label;var mesh:=BoxMesh.new();mesh.size=size;result.mesh=mesh;result.position=position;result.material_override=mat;root.add_child(result);return result
static func tube(root: Node3D,label: String,position: Vector3,length: float,front: float,rear: float,mat: Material,angles:=Vector3(-PI*.5,0,0)) -> MeshInstance3D:
	var result:=MeshInstance3D.new();result.name=label;var mesh:=CylinderMesh.new();mesh.height=length;mesh.top_radius=front;mesh.bottom_radius=rear;mesh.radial_segments=24
	result.mesh=mesh;result.position=position;result.rotation=angles;result.material_override=mat;root.add_child(result);return result
static func ring(root: Node3D,label: String,position: Vector3,radius: float,thickness: float,mat: Material) -> void:
	var result:=MeshInstance3D.new();result.name=label;var mesh:=TorusMesh.new();mesh.inner_radius=radius-thickness;mesh.outer_radius=radius+thickness;mesh.rings=24;mesh.ring_segments=6
	result.mesh=mesh;result.position=position;result.rotation.x=PI*.5;result.material_override=mat;root.add_child(result)
static func profile(root: Node3D,label: String,points: Array,mat: Material,offset:=Vector3.ZERO) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in points.size():
		var a: Vector2=points[row];var b: Vector2=points[(row+1)%points.size()]
		for index in 32:
			var angle:=TAU*index/32.;var next:=TAU*(index+1)/32.
			var corners: Array[Vector3]=[Vector3(cos(angle)*a.y,sin(angle)*a.y,a.x),Vector3(cos(next)*a.y,sin(next)*a.y,a.x),Vector3(cos(next)*b.y,sin(next)*b.y,b.x),Vector3(cos(angle)*b.y,sin(angle)*b.y,b.x)]
			for corner in [0,1,2,0,2,3]: surface.set_uv(Vector2(float(index)/32.,float(row)/points.size()));surface.add_vertex(corners[corner])
	surface.generate_normals();surface.index();var node:=MeshInstance3D.new();node.name=label;node.mesh=surface.commit();node.position=offset;node.material_override=mat;root.add_child(node)
static func screw(root: Node3D,position: Vector3,mat: Material) -> void: tube(root,"ReceiverScrew",position,.006,.007,.007,mat,Vector3(0,0,PI*.5))
static func grip(root: Node3D,label: String,position: Vector3,mat: Material) -> void:
	var handle:=box(root,label,position,Vector3(.065,.20,.085),mat);handle.rotation.x=.14
	for n in 4: box(handle,"GripGroove",Vector3(0,-.06+n*.035,-.044),Vector3(.067,.007,.006),mat)
static func guard(root: Node3D,position: Vector3,mat: Material) -> void:
	box(root,"TriggerGuardLower",position+Vector3(0,-.055,0),Vector3(.06,.013,.12),mat);box(root,"TriggerGuardFront",position+Vector3(0,-.012,-.06),Vector3(.06,.10,.013),mat);box(root,"Trigger",position+Vector3(0,.005,0),Vector3(.014,.05,.018),mat)
static func scope(root: Node3D,position: Vector3,length: float,radius: float,metal: Material,glass: Material) -> void:
	tube(root,"OpticBody",position,length,radius,radius,metal);tube(root,"OpticObjective",position+Vector3(0,0,-length*.5),.055,radius*1.3,radius*1.2,metal)
	tube(root,"OpticLens",position+Vector3(0,0,-length*.5-.03),.004,radius*1.05,radius*1.05,glass);tube(root,"OpticEyepiece",position+Vector3(0,0,length*.5),.045,radius*1.25,radius*1.3,metal)
static func marker(root: Node3D,label: String,position: Vector3) -> void:
	var node:=Marker3D.new();node.name=label;node.position=position;root.add_child(node)
