extends RefCounted
class_name WarStructures
static var gables: Dictionary={}

static func gable(k: EnvironmentKit,point: Vector3,width: float,height: float,yaw: float,mat: String) -> void:
	var key:=str(Vector2(width,height))
	if not gables.has(key):
		var p:=PackedVector3Array([Vector3(-.12,0,-width*.5),Vector3(-.12,0,width*.5),Vector3(-.12,height,0),Vector3(.12,0,-width*.5),Vector3(.12,0,width*.5),Vector3(.12,height,0)])
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in [0,2,1,3,4,5,0,1,3,1,4,3,1,2,4,2,5,4,2,0,5,0,3,5]: surface.add_vertex(p[index])
		surface.generate_normals();gables[key]={"mesh":surface.commit(),"points":p}
	var pose:=Transform3D(Basis(Vector3.UP,yaw),point)
	k._instance(gables[key].mesh,mat,pose)
	var shape:=ConvexPolygonShape3D.new();shape.points=gables[key].points;k._collider("Gable",shape,pose)

static func house(k: EnvironmentKit,p2: Vector2,ruined: bool) -> void:
	var p:=WarTerrain.point(p2.x,p2.y);var floor_y:=.4;var eave:=3.6;var ridge:=5.7
	k.box("HouseFoundation",p+Vector3(0,.10,0),Vector3(12.5,.6,9.5),"concrete",true)
	k.wall("HouseFront",p+Vector3(-6,floor_y,-4.5),p+Vector3(6,floor_y,-4.5),3.2,"plaster:b9b0a2",[{"at":6.,"width":1.6,"top":2.5},{"at":2.2,"width":1.5,"sill":1.,"top":2.3}])
	k.wall("HouseLeft",p+Vector3(-6,floor_y,-4.5),p+Vector3(-6,floor_y,4.5),3.2,"brick",[{"at":4.5,"width":1.5,"sill":1.,"top":2.3}])
	k.wall("HouseRear",p+Vector3(-6,floor_y,4.5),p+Vector3(6,floor_y,4.5),1.1 if ruined else 3.2,"plaster:aba492",[{"at":6.,"width":2.,"top":2.5}])
	if not ruined:
		k.wall("HouseRight",p+Vector3(6,floor_y,-4.5),p+Vector3(6,floor_y,4.5),3.2,"brick",[{"at":5.,"width":1.5,"sill":1.,"top":2.3}])
		gable(k,p+Vector3(6,eave,0),9,ridge-eave,0,"brick")
	else:
		k.wall("BrokenReturnWall",p+Vector3(6,floor_y,-4.5),p+Vector3(6,floor_y,-2.3),1.7,"brick:918573")
		for x in [-5.8,5.8]:
			k.beam(p+Vector3(x,floor_y,0),p+Vector3(x,ridge,0),.22,.22,"wood:514839",true)
			k.beam(p+Vector3(x,3.2,-3.5),p+Vector3(x,ridge,0),.16,.16,"wood:514839",true)
	gable(k,p+Vector3(-6,eave,0),9,ridge-eave,0,"plaster:a69b88")
	var run:=4.85;var outer_eave:=eave-(run-4.5)*(ridge-eave)/4.5;var angle:=atan2(ridge-outer_eave,run);var length_value:=Vector2(run,ridge-outer_eave).length()
	for side in [-1,1]:
		if ruined and side==1: continue
		k.box("SlopingRoof",p+Vector3(0,(ridge+outer_eave)*.5,side*run*.5),Vector3(12.8,.18,length_value),"steel:514a43",true,Vector3(side*angle,0,0))
		for x in [-5.8,-3.,0.,3.,5.8]: k.beam(p+Vector3(x,outer_eave,side*run),p+Vector3(x,ridge,0),.17,.17,"wood:50453a")
	k.beam(p+Vector3(-6.3,ridge-.08,0),p+Vector3(6.3,ridge-.08,0),.20,.20,"wood:50453a",true)
	# The chimney is a continuous stack from the floor, not a floating top.
	k.box("Chimney",p+Vector3(3,(floor_y+6.1)*.5,1),Vector3(.8,6.1-floor_y,.8),"brick",true)
	k.box("ChimneyCrown",p+Vector3(3,6.14,1),Vector3(.95,.15,.95),"concrete:8d8980",true)
	if ruined:
		for i in 14:
			k.box("BrokenBrickwork",p+Vector3(2.8+i%4,.4+(i%3)*.10,(i/4.)-1.6),Vector3(.7,.4,.6),"brick:8c8072",true,Vector3(.1*i,.4*i,0))
	else:
		k.desk(p+Vector3(-3,floor_y,1));k.chair(p+Vector3(-3,floor_y,2.1))
	# Two connected entry treads meet the foundation instead of floating.
	for step in 2: k.box("EntryStep",p+Vector3(0,.10+step*.10,-5.20+step*.27),Vector3(1.9,.20+step*.20,.60),"concrete:9a978a",true)
	for side in [-1,1]:
		var a:=Vector2(p.x+side*8.2,p.z-6);var b:=Vector2(p.x+side*8.2,p.z+7)
		for segment in 5:
			var point:=a.lerp(b,segment/4.);var base:=WarTerrain.point(point.x,point.y)
			k.box("GardenPost",base+Vector3.UP*.56,Vector3(.12,1.2,.12),"wood:625c4c",true)
			if segment<4 and (not ruined or segment%3!=0):
				var next:=a.lerp(b,(segment+1)/4.);var end:=WarTerrain.point(next.x,next.y)
				for y in [.4,.9]: k.beam(base+Vector3.UP*y,end+Vector3.UP*y,.08,.13,"wood:625c4c",true)
	var report: Array=k.root.get_meta("war_buildings",[])
	report.append({"kind":"house","position":p,"half":Vector2(6.25,4.75),"foundation_bottom":p.y-.2,"foundation_top":p.y+.4,"chimney_bottom":p.y+floor_y,"ruined":ruined});k.root.set_meta("war_buildings",report)

static func barn(k: EnvironmentKit,p2: Vector2) -> void:
	var p:=WarTerrain.point(p2.x,p2.y);var floor_y:=.4;var eave:=5.4;var ridge:=8.
	k.box("BarnFoundation",p+Vector3(0,.1,0),Vector3(18.6,.6,14.6),"concrete",true)
	for side in [-1,1]: k.wall("BarnSide",p+Vector3(side*9,floor_y,-7),p+Vector3(side*9,floor_y,7),5,"wood:716858")
	k.wall("BarnRear",p+Vector3(-9,floor_y,7),p+Vector3(9,floor_y,7),5,"wood:716858")
	for z in [-7.,0.,7.]:
		k.beam(p+Vector3(-9,eave,z),p+Vector3(0,ridge,z),.23,.23,"wood:514839",true)
		k.beam(p+Vector3(0,ridge,z),p+Vector3(9,eave,z),.23,.23,"wood:514839",true)
		k.beam(p+Vector3(-9,eave-.1,z),p+Vector3(9,eave-.1,z),.22,.22,"wood:514839",true)
	for z in [-7.,7.]: gable(k,p+Vector3(0,eave,z),18,ridge-eave,PI*.5,"wood:716858")
	var run:=9.35;var outer_eave:=eave-(run-9)*(ridge-eave)/9;var angle:=atan2(ridge-outer_eave,run)
	for side in [-1,1]: k.box("BarnRoof",p+Vector3(side*run*.5,(ridge+outer_eave)*.5,0),Vector3(Vector2(run,ridge-outer_eave).length(),.20,15),"steel:534e49",true,Vector3(0,0,-side*angle))
	for i in 4: k.crate(p+Vector3(i*2-3,floor_y,4),Vector3(1.4,1.2,1.4))
	var report: Array=k.root.get_meta("war_buildings",[]);report.append({"kind":"barn","position":p,"half":Vector2(9.3,7.3),"foundation_bottom":p.y-.2,"foundation_top":p.y+.4});k.root.set_meta("war_buildings",report)

static func shelter(k: EnvironmentKit,floor_point: Vector3,yaw: float) -> void:
	var basis:=Basis(Vector3.UP,yaw);var roof:=floor_point+Vector3.UP*2.25
	k.box("CoveredTrenchShelter",roof,Vector3(5.7,.3,4.8),"wood:443e32",true,Vector3(0,yaw,0))
	k.box("ShelterEarth",roof+Vector3.UP*.3,Vector3(6.,.4,5.),"asphalt:564b3c",false,Vector3(0,yaw,0))
	for x in [-2.55,2.55]:
		for z in [-2.1,2.1]:
			var offset:=basis*Vector3(x,0,z);var root_point:=WarTerrain.point(floor_point.x+offset.x,floor_point.z+offset.z)-Vector3.UP*.08
			var top:=Vector3(root_point.x,roof.y-.10,root_point.z)
			if root_point.y>top.y-.25: root_point.y=minf(floor_point.y,top.y-.35)
			k.beam(root_point,top,.21,.21,"wood:514738",true)
			var supports: Array=k.root.get_meta("war_roof_supports",[]);supports.append({"bottom":root_point,"top":top,"roof_bottom":roof.y-.15});k.root.set_meta("war_roof_supports",supports)
	for z in [-2.1,2.1]: k.beam(roof+basis*Vector3(-2.65,-.12,z),roof+basis*Vector3(2.65,-.12,z),.23,.23,"wood:514738",true)

static func road(k: EnvironmentKit) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-110,110,2):
		for z in range(108,116,2):
			for d in [Vector2(0,0),Vector2(2,0),Vector2(0,2),Vector2(2,0),Vector2(2,2),Vector2(0,2)]: surface.add_vertex(WarTerrain.point(x+d.x,z+d.y)+Vector3.UP*.025)
	surface.generate_normals();surface.index();var mesh:=surface.commit();k._instance(mesh,"asphalt:655f53",Transform3D.IDENTITY);k.root.set_meta("war_road_mesh",mesh)

static func fence(k: EnvironmentKit,start: Vector2,finish: Vector2) -> void:
	var count:=ceili(start.distance_to(finish)/3.)
	for i in count+1:
		var p2:=start.lerp(finish,float(i)/count);var p:=WarTerrain.point(p2.x,p2.y)
		k.cylinder("FencePost",p+Vector3.UP*1.1,.045,2.2,"steel",true)
		if i==count: continue
		var next:=start.lerp(finish,float(i+1)/count);var end:=WarTerrain.point(next.x,next.y)
		for y in [.8,2.15]: k.pipe(p+Vector3.UP*y,end+Vector3.UP*y,.022,"steel",true,false)
		for y in [.25,.55,1.05,1.55]: k.pipe(p+Vector3.UP*y,end+Vector3.UP*(y+.15),.006,"steel",false,true)
		for step in 7:
			var point:=p.lerp(end,float(step)/7)
			k.pipe(point+Vector3.UP*.1,point+Vector3.UP*2.1,.006,"steel",false,true)

static func sandbags(k: EnvironmentKit,point: Vector3,length_value: float,yaw: float) -> void:
	if not EnvironmentKit.meshes.has("sandbag"):
		var mesh:=SphereMesh.new();mesh.radius=1.;mesh.height=2.;mesh.radial_segments=12;mesh.rings=5;EnvironmentKit.meshes.sandbag=mesh
	var basis:=Basis(Vector3.UP,yaw);var count:=maxi(1,int(length_value/.85))
	for i in count:
		var offset:=basis*Vector3((i-(count-1)*.5)*.85,0,0);var position:=WarTerrain.point(point.x+offset.x,point.z+offset.z)
		for row in 3:
			var shift:=basis*Vector3(.12 if row==1 else 0,0,0)
			var origin:=WarTerrain.point(position.x+shift.x,position.z+shift.z)+Vector3.UP*(.17+row*.28)
			k._instance(EnvironmentKit.meshes.sandbag,"fabric:e9d7af",Transform3D(basis*Basis.from_scale(Vector3(.50,.19,.32)),origin))
		var collision:=BoxShape3D.new();collision.size=Vector3(.85,.90,.62)
		k._collider("GroundedSandbagCover",collision,Transform3D(basis,position+Vector3.UP*.45))
		var points: Array=k.root.get_meta("war_cover_feet",[]);points.append(position);k.root.set_meta("war_cover_feet",points)
