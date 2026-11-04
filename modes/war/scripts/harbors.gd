extends RefCounted
class_name WarHarbors
static func walkway(k: EnvironmentKit,a: Vector3,b: Vector3,width: float,mat: String) -> void:
	var direction: Vector3=b-a
	var rotation:=Basis.looking_at(direction.normalized(),Vector3.UP).get_euler()
	k.box("HarborWalkway",(a+b)*.5,Vector3(width,.45,direction.length()+.4),mat,true,rotation)
static func foundation(k: EnvironmentKit,point: Vector3,size: Vector3,label: String) -> void:
	var lowest:=point.y-size.y*.5
	for dx in [-.5,.5]:
		for dz in [-.5,.5]: lowest=minf(lowest,WarTerrain.height_at(point.x+dx*size.x,point.z+dz*size.z)-.3)
	k.box(label,Vector3(point.x,(lowest+point.y+size.y*.5)*.5,point.z),Vector3(size.x,point.y+size.y*.5-lowest,size.z),"concrete:777c77",true)
static func build(k: EnvironmentKit) -> void:
	for team in 2:
		var p: Vector3=WarCoast.PORTS[team]
		foundation(k,p+Vector3(0,-.3,0),Vector3(82,.6,230),"HarborQuay")
		for index in 2:
			var ship: Vector3=WarCoast.BERTHS[team][index]
			var bank:=p+Vector3(0,0,ship.z-p.z+5.8)
			var end:=Vector3(ship.x,2.2,ship.z+5.8)
			walkway(k,bank,end,4.5,"concrete:81857e")
			for fraction in [0.,.3,.6,.9,1.]:
				var at:=bank.lerp(end,fraction)
				var bottom:=WarTerrain.height_at(at.x,at.z)
				if bottom<at.y-.3: k.cylinder("PierPile",Vector3(at.x,(bottom+at.y-.3)*.5,at.z),.45,at.y-.3-bottom,"concrete:555e5d",true)
			for dx in [-12.,0.,12.]:
				k.cylinder("Bollard",end+Vector3(dx,.35,0),.2,.7,"steel:393f3e",true)
		# WarRoads already follows the hill to the terminal. Only bridge the
		# small apron step here; a straight ramp to the hill floated over it.
		var side:=1. if team==0 else -1.
		var start:=p+Vector3(side*49,0,0);start.y=WarTerrain.height_at(start.x,start.z)+.10
		var end:=p+Vector3(side*35,.02,0)
		walkway(k,start,end,12,"asphalt:6c706c")
		if team==0: warehouse(k,p+Vector3(0,0,68),false)
		else: authored_east(k,p)
		crane(k,p+Vector3(0,0,-75),-1 if team==0 else 1)
		for i in 7:
			if team==1: break
			var at:=p+Vector3((i%2)*19-10,0,-22+(i/2)*13)
			EnvironmentProps.container(k,at,i%3==0)
		for i in 11:
			var at:=p+Vector3(-34+i*6,0,107)
			k.box("DamagedRailSleeper",at,Vector3(.22,.15,3),"wood:595747",false)
		for dz in [-1.05,1.05]: k.beam(p+Vector3(-34,.18,107+dz),p+Vector3(32,.18,107+dz),.08,.13,"steel:565e5c",false)
		industrial(k,p,team)
		# Breakwaters leave one navigable mouth; only west is a land-cut bay.
		var first: Vector3=WarCoast.BERTHS[team][0];var second: Vector3=WarCoast.BERTHS[team][1]
		for z in [first.z-62,second.z+62]:
			var a:=Vector3(p.x,1.6,z);var b:=Vector3(first.x+(-60 if team==0 else 60),1.6,z)
			foundation(k,(a+b)*.5,Vector3(absf(a.x-b.x)+10,2.2,10),"HarborBreakwater")
		k.sign_text("ПОРТ / "+("ЗАХІД" if team==0 else "СХІД"),p+Vector3(0,6,4),9)
	k.root.set_meta("war_ports",2);k.root.set_meta("war_bays",1)
	curved_quay(k)
static func authored_east(k: EnvironmentKit,point: Vector3) -> void:
	if k.root.get_meta("authoring_reference",false): return
	# A normal scene is the source of truth: the user can place/edit objects
	# directly in Godot. Runtime batches only its rigid render geometry.
	var scene:=preload("res://modes/war/scenes/east_port.tscn").instantiate() as Node3D
	scene.position=point;k.root.add_child(scene)
	var rigid: Array[Node]=[]
	for mesh: MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		if k.visuals: mesh.reparent(scene,true);rigid.append(mesh)
		else: mesh.free()
	if k.visuals: WarRenderBatch.merge(scene,"east-port-184",rigid)
	else:
		for label: Label3D in scene.find_children("*","Label3D",true,false): label.free()
static func warehouse(k: EnvironmentKit,p: Vector3,ruined: bool) -> void:
	foundation(k,p+Vector3(0,.1,0),Vector3(28,.5,23),"WarehouseFoundation")
	for x in [-13.,13.]: k.box("WarehouseWall",p+Vector3(x,3.5,0),Vector3(.4,7,22),"brick:8a8172",true)
	for z in [-11.,11.]: k.wall("WarehouseEnd",p+Vector3(-13,0,z),p+Vector3(13,0,z),7,"plaster:9f9c8e",[{"at":13.,"width":7.,"top":5.5}])
	for z in [-10.,0.,10.]:
		for side in [-1.,1.]: k.beam(p+Vector3(side*13,7,z),p+Vector3(0,10,z),.25,.3,"steel:4b5755",true)
	for side in [-1.,1.]:
		if ruined and side>0: continue
		k.box("WarehouseRoof",p+Vector3(side*6.5,8.5,0),Vector3(13.4,.2,23),"steel:737b77",true,Vector3(0,0,-side*atan2(3,13)))
static func crane(k: EnvironmentKit,p: Vector3,side: int) -> void:
	foundation(k,p+Vector3(0,-.2,0),Vector3(12,.4,12),"CraneFoundation")
	for dx in [-3.,3.]:
		for dz in [-3.,3.]:
			k.beam(p+Vector3(dx,0,dz),p+Vector3(dx*.6,18,dz*.6),.55,.55,"steel:8b9272",true)
		for level in range(0,18,3):
			k.beam(p+Vector3(dx,level,-3),p+Vector3(dx*.6,level+3,1.8),.12,.12,"steel:69775d")
			k.beam(p+Vector3(dx,level,3),p+Vector3(dx*.6,level+3,-1.8),.12,.12,"steel:69775d")
	k.cylinder("CraneSlewRing",p+Vector3(0,18,0),3.7,.7,"steel:555f5c",true)
	k.box("CraneMachinery",p+Vector3(-side*3,20,0),Vector3(6,3.2,4),"steel:7d8569",true)
	k.box("CraneCounterweight",p+Vector3(-side*7,20.5,0),Vector3(3,2,4.8),"concrete:777971",true)
	k.box("CraneCab",p+Vector3(side*2.5,20.5,2),Vector3(2.5,3.4,2.4),"steel:8f9a7a",true)
	k.box("CraneCabGlass",p+Vector3(side*3.79,21,2),Vector3(.05,1.6,1.9),"screen")
	var base:=p+Vector3(0,22,0);var tip:=p+Vector3(side*34,28,0)
	for dz in [-.65,.65]:
		k.beam(base+Vector3(0,0,dz),tip+Vector3(0,0,dz),.20,.20,"steel:8f9c75")
		k.beam(base+Vector3(0,2,dz),tip+Vector3(0,1.5,dz),.20,.20,"steel:8f9c75")
		for i in 12:
			var a:=base.lerp(tip,i/12.0)+Vector3(0,0,dz)
			var b:=base.lerp(tip,(i+1)/12.0)+Vector3(0,1.7,dz)
			k.beam(a,b,.10,.10,"steel:6a795f")
	k.beam(p+Vector3(0,31,0),tip+Vector3.UP*1.5,.06,.06,"steel:353f39")
	k.beam(p+Vector3(-side*7,20,0),p+Vector3(0,31,0),.06,.06,"steel:353f39")
	k.beam(tip,tip-Vector3.UP*21,.045,.045,"steel:272e2b")
	k.box("CraneHookBlock",tip-Vector3.UP*21,Vector3(.65,1.2,.6),"steel:4c5347",false)
	for level in range(1,18):
		k.beam(p+Vector3(-2.3,level,2.5),p+Vector3(-1.7,level,2.5),.055,.055,"steel:7e8571")

static func curved_quay(k: EnvironmentKit) -> void:
	for side in [-1.,1.]:
		for i in 13:
			var a: float=deg_to_rad(28+i*4.5)*side;var b: float=deg_to_rad(28+(i+1)*4.5)*side
			var from:=Vector3(WarCoast.BAY_CENTER.x+280*cos(a),4,WarCoast.BAY_CENTER.y+245*sin(a))
			var to:=Vector3(WarCoast.BAY_CENTER.x+280*cos(b),4,WarCoast.BAY_CENTER.y+245*sin(b))
			var angle:=atan2((to-from).x,(to-from).z)
			k.box("CurvedBayQuay",(from+to)*.5-Vector3.UP*.32,Vector3(12,.64,from.distance_to(to)+.8),"concrete:747b75",true,Vector3(0,angle,0))
			if i%2==0:
				var bottom:=WarTerrain.height_at(from.x,from.z)
				k.cylinder("BayQuayPile",Vector3(from.x,(bottom+3.6)*.5,from.z),.45,maxf(.2,3.6-bottom),"concrete:525d58",true)
			var water_side: Vector3=((from+to)*.5-Vector3(WarCoast.BAY_CENTER.x,4,WarCoast.BAY_CENTER.y)).normalized()
			k.box("BayQuayFender",(from+to)*.5-water_side*6-Vector3.UP*.7,Vector3(.6,1.4,1.1),"fabric:252d29",false)

static func industrial(k: EnvironmentKit,p: Vector3,team: int) -> void:
	# Separate storage/rail areas, clear vehicle lanes, supported machinery.
	if team==0:
		for z in [45.,60.,75.]:
			var at:=p+Vector3(29,0,z)
			foundation(k,at+Vector3(0,.1,0),Vector3(10,.2,11),"SiloFoundation")
			k.cylinder("GrainSilo",at+Vector3.UP*8,3.5,16,"steel:9b9d83",true)
			k.cylinder("SiloCap",at+Vector3.UP*16.5,3.55,1.0,"steel:787f6c",false,.05)
			for y in [3.,6.,9.,12.,15.]: k.cylinder("SiloRing",at+Vector3.UP*y,3.57,.07,"steel:5f6958")
			for y in range(1,16): k.beam(at+Vector3(3.55,y,-.3),at+Vector3(3.55,y,.3),.045,.045,"steel:53604e")
		for z in [-45.,-15.,15.,40.,82.]:
			k.beam(p+Vector3(28,0,z),p+Vector3(28,14,z),.3,.3,"steel:5e6c54",true)
		k.box("GrainConveyor",p+Vector3(28,14,20),Vector3(2.2,.6,132),"steel:6b775a",true)
		for z in range(-45,86,6):
			k.box("ConveyorFrame",p+Vector3(28,14.65,z),Vector3(2.6,.12,.16),"steel:56624c")
		for z in [-48.,-57.]: k.rock(p+Vector3(-23,1,z),Vector3(7,3,5),int(absf(z)),true)
	else:
		for x in [-24.,-8.,8.]:
			var at:=p+Vector3(x,.45,106)
			k.box("FreightWagon",at+Vector3.UP*1.1,Vector3(12,1.5,2.4),"steel:5d6859",true)
			for dx in [-4.,4.]:
				for dz in [-1.1,1.1]: k.cylinder("RailWheel",at+Vector3(dx,.1,dz),.4,.18,"steel:303b32",false,1,Vector3(PI*.5,0,0))
			for dx in [-5.,-2.5,0.,2.5,5.]:
				k.box("WagonStake",at+Vector3(dx,2.1,1.2),Vector3(.09,2,.1),"steel:4a5847")
			k.box("SteelCargo",at+Vector3.UP*2,Vector3(10,.5,1.6),"steel:7a8174",false)
	for team_side in [-1.,1.]:
		for z in [-96.,-52.,2.,48.,96.]:
			k.box("QuayEdgeMarker",p+Vector3(team_side*39,.05,z),Vector3(.7,.08,3),"plaster:c4bc83")
	# A recognisable forklift: wheels, overhead guard, mast and grounded forks.
	var at:=p+Vector3(-23,0,-22)
	k.box("ForkliftBody",at+Vector3.UP*.8,Vector3(1.8,1.2,2.4),"steel:9a8a45",true)
	for dx in [-.85,.85]:
		for dz in [-.8,.8]: k.cylinder("ForkliftWheel",at+Vector3(dx,.42,dz),.42,.28,"fabric:252b25",false,1,Vector3(0,0,PI*.5))
		k.beam(at+Vector3(dx,1,-.2),at+Vector3(dx,2.7,-.2),.09,.09,"steel:404c3c")
		k.beam(at+Vector3(dx,1,.9),at+Vector3(dx,2.7,.9),.09,.09,"steel:404c3c")
	k.box("ForkliftGuard",at+Vector3(0,2.75,.4),Vector3(1.9,.10,1.5),"steel:545d46")
	for dx in [-.5,.5]:
		k.box("ForkliftMast",at+Vector3(dx,1.3,-1.4),Vector3(.13,2.6,.18),"steel:333e32")
		k.box("ForkliftFork",at+Vector3(dx,.12,-2.2),Vector3(.16,.16,1.7),"steel:535e50",true)
