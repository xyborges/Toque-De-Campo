extends RefCounted
class_name WarInfrastructureFactory
const ITEMS:={"estrada_curva_90":"Estrada · curva 90°","estrada_cruzamento":"Estrada · cruzamento","estrada_entroncamento":"Estrada · entroncamento T","estrada_rampa_12m":"Estrada · rampa 12 m","cais_curva_90":"Cais · curva 90°","cais_rampa_8m":"Cais · rampa 8 m","trincheira_escavavel_6m":"Trincheira escavável · 6 m"}

static func connector(root: Node3D,label: String,point: Vector3,outward: Vector3,profile: String,width: float) -> void:
	var holder:=root.get_node_or_null("Encaixes") as Node3D
	if holder==null: holder=Node3D.new();holder.name="Encaixes";root.add_child(holder)
	var socket:=Marker3D.new();socket.name=label;socket.position=point;socket.basis=Basis.looking_at(outward,Vector3.UP)
	socket.set_meta("profile",profile);socket.set_meta("width",width);holder.add_child(socket)

static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3) -> void:
	var points: Array[Vector3]=[a,b,c,d]
	# Godot's visible front face is clockwise viewed from outside.
	var order: Array=[0,1,2,0,2,3] if (b-a).cross(c-a).dot(normal)<0 else [0,2,1,0,3,2]
	for i in order: st.set_normal(normal);st.set_uv(Vector2(points[i].x,points[i].z)*.2);st.add_vertex(points[i])

static func arc(root: Node3D,inner: float,outer: float,top: float,bottom: float,finish: String,solid:=false,start:=PI,sweep:=PI*.5,count:=16) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre:=Vector3(12,0,0)
	for i in count:
		var a:=start+sweep*i/count;var b:=start+sweep*(i+1)/count
		var points: Array[Vector3]=[centre+Vector3(cos(a)*inner,top,sin(a)*inner),centre+Vector3(cos(a)*outer,top,sin(a)*outer),centre+Vector3(cos(b)*outer,top,sin(b)*outer),centre+Vector3(cos(b)*inner,top,sin(b)*inner)]
		quad(st,points[0],points[1],points[2],points[3],Vector3.UP)
		var hull:=PackedVector3Array(points)
		for p in points: hull.append(Vector3(p.x,bottom,p.z))
		quad(st,hull[4],hull[5],hull[6],hull[7],Vector3.DOWN)
		for edge in [[0,3],[1,2]]:
			var middle: Vector3=(points[edge[0]]+points[edge[1]])*.5-centre
			var normal:=Vector3(middle.x,0,middle.z).normalized()*(1. if edge[0]==1 else -1.)
			quad(st,hull[edge[0]],hull[edge[1]],hull[edge[1]+4],hull[edge[0]+4],normal)
		if i==0: quad(st,hull[0],hull[1],hull[5],hull[4],Vector3.BACK)
		if i==count-1: quad(st,hull[3],hull[2],hull[6],hull[7],Vector3.RIGHT)
		if solid:
			var shape:=ConvexPolygonShape3D.new();shape.points=hull
			WarPrefabFactory.body(root,"ColisaoCurva%02d"%i,shape,Transform3D.IDENTITY,WarPrefabFactory.surface(finish))
	st.index();WarArtStyle.mesh(root,"FaixaCurva",st.commit(),finish)

static func junction(root: Node3D,t_shaped: bool) -> void:
	var outline:=PackedVector2Array([Vector2(-3.5,-6),Vector2(3.5,-6),Vector2(3.5,-3.5),Vector2(6,-3.5),Vector2(6,3.5),Vector2(3.5,3.5),Vector2(3.5,6),Vector2(-3.5,6)]) if t_shaped else PackedVector2Array([Vector2(-3.5,-6),Vector2(3.5,-6),Vector2(3.5,-3.5),Vector2(6,-3.5),Vector2(6,3.5),Vector2(3.5,3.5),Vector2(3.5,6),Vector2(-3.5,6),Vector2(-3.5,3.5),Vector2(-6,3.5),Vector2(-6,-3.5),Vector2(-3.5,-3.5)])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices:=Geometry2D.triangulate_polygon(outline)
	for i in range(0,indices.size(),3):
		var a:=Vector3(outline[indices[i]].x,0,outline[indices[i]].y);var b:=Vector3(outline[indices[i+1]].x,0,outline[indices[i+1]].y);var c:=Vector3(outline[indices[i+2]].x,0,outline[indices[i+2]].y)
		quad(st,a,b,c,c,Vector3.UP)
	st.index();WarArtStyle.mesh(root,"Pavimento",st.commit(),"asphalt")
	var along:=BoxShape3D.new();along.size=Vector3(7,.26,12);WarPrefabFactory.body(root,"ViaPrincipal",along,Transform3D(Basis.IDENTITY,Vector3(0,-.13,0)),"asphalt")
	var cross:=BoxShape3D.new();cross.size=Vector3(6 if t_shaped else 12,.26,7);WarPrefabFactory.body(root,"ViaTransversal",cross,Transform3D(Basis.IDENTITY,Vector3(3 if t_shaped else 0,-.13,0)),"asphalt")
	for side in [-1,1]:
		for z in [-4.85,4.85]: WarPrefabFactory.box(root,"FaixaBorda",Vector3(side*3.14,.006,z),Vector3(.10,.012,2.3),"marking")
	connector(root,"Entrada",Vector3(0,0,6),Vector3.BACK,"road",7)
	connector(root,"Saida",Vector3(0,0,-6),Vector3.FORWARD,"road",7)
	connector(root,"Direita",Vector3(6,0,0),Vector3.RIGHT,"road",7)
	if not t_shaped: connector(root,"Esquerda",Vector3(-6,0,0),Vector3.LEFT,"road",7)
	root.set_meta("footprint",Vector2(12,12));root.set_meta("terrain_grade",true)

static func ramp(root: Node3D,quay: bool) -> void:
	var length:=8. if quay else 12.;var width:=8. if quay else 7.;var rise:=1.2 if quay else 1.5
	var h:=length*.5;var w:=width*.5
	var points:=PackedVector3Array([Vector3(-w,0,h),Vector3(w,0,h),Vector3(w,rise,-h),Vector3(-w,rise,-h),Vector3(-w,-.35,h),Vector3(w,-.35,h),Vector3(w,-.35,-h),Vector3(-w,-.35,-h)])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	quad(st,points[0],points[1],points[2],points[3],Vector3(0,length,rise).normalized())
	for entry in [[[0,3,7,4],Vector3.LEFT],[[1,2,6,5],Vector3.RIGHT],[[0,1,5,4],Vector3.BACK],[[3,2,6,7],Vector3.FORWARD],[[4,5,6,7],Vector3.DOWN]]:
		var ids: Array=entry[0];quad(st,points[ids[0]],points[ids[1]],points[ids[2]],points[ids[3]],entry[1])
	st.index();WarArtStyle.mesh(root,"Rampa",st.commit(),"concrete" if quay else "asphalt")
	var collision:=ConvexPolygonShape3D.new();collision.points=points;WarPrefabFactory.body(root,"Corpo",collision,Transform3D.IDENTITY,"concrete" if quay else "asphalt")
	var incline:=atan2(rise,length)
	for side in [-1,1]:
		WarPrefabFactory.box(root,"Borda",Vector3(side*(w-.22),rise*.5+.007,0),Vector3(.10,.014,sqrt(length*length+rise*rise)),"marking",false,Vector3(incline,0,0))
		if quay:
			for i in 4:
				var z:=h-.35-i*(length-.7)/3.;var y:=rise*(h-z)/length
				WarPrefabFactory.tube(root,"Montante",Vector3(side*(w-.13),y,z),Vector3(side*(w-.13),y+.9,z),.035,"dark_paint",true)
			WarPrefabFactory.tube(root,"Corrimao",Vector3(side*(w-.13),.9,h),Vector3(side*(w-.13),rise+.9,-h),.04,"dark_paint",true)
	connector(root,"Base",Vector3(0,0,h),Vector3.BACK,"surface" if quay else "road",width)
	connector(root,"Topo",Vector3(0,rise,-h),Vector3.FORWARD,"surface" if quay else "road",width)
	root.set_meta("footprint",Vector2(width,length));root.set_meta("rise",rise)
	if not quay: root.set_meta("terrain_grade",true)

static func build(id: String,root: Node3D) -> void:
	match id:
		"estrada_cruzamento","estrada_entroncamento": junction(root,id=="estrada_entroncamento")
		"estrada_rampa_12m","cais_rampa_8m": ramp(root,id=="cais_rampa_8m")
		"estrada_curva_90","cais_curva_90":
			var quay:=id=="cais_curva_90";var half:=4. if quay else 3.5
			arc(root,12-half,12+half,0,-.8 if quay else -.26,"concrete" if quay else "asphalt",true)
			for sign_value in [-1.,1.]: arc(root,12+sign_value*(half-.22)-.05,12+sign_value*(half-.22)+.05,.008,.002,"marking")
			if quay:
				for i in 5:
					var a:=PI+PI*.5*(i+.5)/5.;var p:=Vector3(12+cos(a)*12,-.8,sin(a)*12)
					WarPrefabFactory.tube(root,"Estaca",p-Vector3.UP*3.2,p,.32,"concrete",true)
			else:
				for i in 5: arc(root,11.94,12.06,.01,.003,"marking",false,PI+.03+i*.30,.15,3)
			connector(root,"Entrada",Vector3.ZERO,Vector3.BACK,"quay" if quay else "road",half*2)
			connector(root,"Saida",Vector3(12,0,-12),Vector3.RIGHT,"quay" if quay else "road",half*2)
			root.set_meta("footprint",Vector2(20,20));root.set_meta("grade_centre",Vector2(6,-6))
			if not quay: root.set_meta("terrain_grade",true)
		"trincheira_escavavel_6m":
			root.set_script(load("res://modes/war/scripts/trench_module.gd"))
			var lining:=load("res://modes/war/library/trincheira_6m.tscn").instantiate() as Node3D;lining.name="Revestimento";lining.position.y=-1.5;root.add_child(lining)
			connector(root,"Entrada",Vector3(0,0,3),Vector3.BACK,"trench",2.2)
			connector(root,"Saida",Vector3(0,0,-3),Vector3.FORWARD,"trench",2.2)
			root.set_meta("footprint",Vector2(3.4,6));root.set_meta("terrain_cut",true)
