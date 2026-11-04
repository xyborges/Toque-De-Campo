extends RefCounted
class_name FALModel

# Original standard-pattern FAL geometry, metres; forward is local -Z.
const MUZZLE:=Vector3(0,.075,-.79)
const SUPPORT:=Vector3(-.018,-.012,-.34)
const GRIP:=Vector3(0,-.045,.035)
const SIGHT_Y:=.148
static var meshes: Dictionary={}
static var materials: Dictionary={}
static var magazine_mesh: Mesh
static var charging_mesh: Mesh

static func create() -> Node3D:
	if meshes.is_empty(): _build()
	var model:=Node3D.new();model.name="Imported_fal";model.set_meta("rest_position",Vector3.ZERO)
	for finish in meshes:
		var part:=MeshInstance3D.new();part.name=finish;part.mesh=meshes[finish];part.material_override=materials[finish];model.add_child(part)
	var magazine:=MeshInstance3D.new();magazine.name="Magazine";magazine.mesh=magazine_mesh;magazine.material_override=materials.Parkerized;magazine.position=Vector3(0,-.095,-.135);model.add_child(magazine)
	var charging:=MeshInstance3D.new();charging.name="ChargingHandle";charging.mesh=charging_mesh;charging.material_override=materials.SteelEdges;model.add_child(charging)
	for point in [["Muzzle",MUZZLE],["GripRight",GRIP],["SupportGrip",SUPPORT],["RearAperture",Vector3(0,SIGHT_Y,.105)],["FrontPost",Vector3(0,SIGHT_Y,-.57)]]:
		var marker:=Marker3D.new();marker.name=point[0];marker.position=point[1];model.add_child(marker)
	return model

static func _build() -> void:
	var source:=Node3D.new()
	var magazine_source:=Node3D.new();var charging_source:=Node3D.new()
	for entry in [["Parkerized",Color("343a37"),.72,.55],["Polymer",Color("202923"),.05,.76],["SteelEdges",Color("59615a"),.78,.43],["Recess",Color("0e1512"),.25,.64]]:
		var id: String={"Parkerized":"gunmetal","Polymer":"polymer","SteelEdges":"bare_metal","Recess":"recess"}[entry[0]]
		materials[entry[0]]=WarArtStyle.material(id)
	# Sloped, fixed buttstock and separate serrated butt pad.
	_slab(source,"Polymer",[Vector2(.083,.075),Vector2(.062,.19),Vector2(.038,.31),Vector2(-.12,.31),Vector2(-.106,.285),Vector2(-.027,.11),Vector2(-.01,.075)],.052,.004)
	_slab(source,"Recess",[Vector2(.039,.307),Vector2(.036,.324),Vector2(-.124,.324),Vector2(-.12,.307)],.060,.002)
	for i in 8: _bar(source,"SteelEdges",Vector3(-.026,-.11+i*.019,.324),Vector3(.026,-.11+i*.019,.324),.0016)
	# Upper/lower receiver, stamped top cover, ejection port and charging handle.
	_slab(source,"Parkerized",[Vector2(.109,.092),Vector2(.116,-.025),Vector2(.109,-.185),Vector2(.081,-.218),Vector2(.004,-.218),Vector2(-.012,.054)],.048,.003)
	_slab(source,"SteelEdges",[Vector2(.11,.089),Vector2(.123,.083),Vector2(.124,-.164),Vector2(.11,-.18)],.043,.002)
	_box(source,"Recess",Vector3(.025,.080,-.095),Vector3(.001,.032,.092))
	_box(source,"SteelEdges",Vector3(.026,.065,-.10),Vector3(.002,.004,.098))
	_box(source,"Parkerized",Vector3(-.027,.074,-.065),Vector3(.010,.012,.16))
	_bar(charging_source,"SteelEdges",Vector3(-.025,.076,-.135),Vector3(-.049,.076,-.135),.005)
	_bar(charging_source,"Polymer",Vector3(-.049,.076,-.135),Vector3(-.049,.089,-.135),.008)
	# Pistol grip slopes rearward, separate from the magazine.
	_slab(source,"Polymer",[Vector2(-.005,.027),Vector2(-.015,-.014),Vector2(-.135,.045),Vector2(-.116,.087)],.037,.004)
	for i in 5: _bar(source,"Parkerized",Vector3(-.019,-.033-i*.016,.02+i*.008),Vector3(.019,-.033-i*.016,.02+i*.008),.0011)
	# Trigger guard is open geometry rather than a solid filled rectangle.
	var guard: Array[Vector3]=[Vector3(0,-.010,-.075),Vector3(0,-.051,-.079),Vector3(0,-.069,-.057),Vector3(0,-.065,-.012),Vector3(0,-.02,.009)]
	for i in guard.size()-1: _bar(source,"Parkerized",guard[i],guard[i+1],.0035)
	_bar(source,"SteelEdges",Vector3(0,-.007,-.041),Vector3(0,-.043,-.036),.003)
	# Straight 20-round box with stamped ribs and floor plate.
	_slab(magazine_source,"Parkerized",[Vector2(.015,-.175),Vector2(.008,-.100),Vector2(-.17,-.093),Vector2(-.181,-.173)],.043,.0025)
	_box(magazine_source,"SteelEdges",Vector3(0,-.177,-.135),Vector3(.047,.006,.088))
	for side in [-1,1]:
		for z in [-.159,-.117]: _box(magazine_source,"SteelEdges",Vector3(side*.022,-.092,z),Vector3(.0018,.148,.003))
	# Long tapered fore-end with three vent recesses on each side.
	_slab(source,"Polymer",[Vector2(.100,-.219),Vector2(.110,-.280),Vector2(.107,-.541),Vector2(.049,-.555),Vector2(.025,-.25)],.057,.004)
	for side in [-1,1]:
		for i in 3:
			_box(source,"Recess",Vector3(side*.029,.087,-.30-i*.065),Vector3(.0015,.009,.039))
			_box(source,"SteelEdges",Vector3(side*.030,.093,-.30-i*.065),Vector3(.001,.0018,.039))
		_bar(source,"Parkerized",Vector3(side*.025,.039,-.25),Vector3(side*.025,.039,-.527),.002)
	for z in [-.224,-.548]: _box(source,"Parkerized",Vector3(0,.070,z),Vector3(.061,.075,.010))
	# Barrel, gas cylinder and gas regulator remain distinct silhouettes.
	_bar(source,"Parkerized",Vector3(0,.075,-.53),Vector3(0,.075,-.758),.009)
	_bar(source,"SteelEdges",Vector3(0,.113,-.195),Vector3(0,.113,-.571),.006)
	_bar(source,"Parkerized",Vector3(0,.11,-.548),Vector3(0,.11,-.584),.015)
	for i in 6: _ring(source,"SteelEdges",Vector3(0,.11,-.548-i*.004),.0154,.0142,.0015)
	_slab(source,"Parkerized",[Vector2(.077,-.585),Vector2(.140,-.583),Vector2(.150,-.566),Vector2(.111,-.55),Vector2(.062,-.555)],.020,.002)
	# Open flash suppressor and individual slots; bore is not a filled cap.
	_ring(source,"Parkerized",Vector3(0,.075,-.766),.014,.0065,.046)
	for i in 6:
		var angle:=TAU*i/6
		_bar(source,"Recess",Vector3(cos(angle)*.014,.075+sin(angle)*.014,-.754),Vector3(cos(angle)*.014,.075+sin(angle)*.014,-.778),.002)
	_ring(source,"SteelEdges",MUZZLE+Vector3(0,0,.002),.0145,.0066,.002)
	# Aperture rear sight and protected front blade at the same height.
	_box(source,"Parkerized",Vector3(0,.1185,.106),Vector3(.028,.041,.037))
	_ring(source,"SteelEdges",Vector3(0,SIGHT_Y,.106),.010,.007,.005)
	for side in [-1,1]: _box(source,"Parkerized",Vector3(side*.017,.147,-.574),Vector3(.004,.034,.025))
	_box(source,"SteelEdges",Vector3(0,.140,-.574),Vector3(.0012,.016,.003))
	# Folding carry handle, selector, receiver pins and sling attachment.
	_bar(source,"SteelEdges",Vector3(.025,.11,-.205),Vector3(.055,.143,-.205),.0025)
	_bar(source,"SteelEdges",Vector3(.055,.143,-.205),Vector3(.055,.143,-.125),.0025)
	_bar(source,"Polymer",Vector3(.055,.143,-.19),Vector3(.055,.143,-.13),.005)
	for z in [-.003,.048,-.19]: _bar(source,"SteelEdges",Vector3(-.027,.030,z),Vector3(.027,.030,z),.004)
	_bar(source,"SteelEdges",Vector3(-.027,.02,.021),Vector3(-.029,.038,-.001),.003)
	# Merge rigid parts by finish once. Each world/view copy shares four meshes.
	for finish in materials:
		var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child: MeshInstance3D in source.get_children():
			if child.get_meta("finish","")==finish: builder.append_from(child.mesh,0,child.transform)
		builder.index();meshes[finish]=builder.commit()
	var magazine_builder:=SurfaceTool.new();magazine_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child: MeshInstance3D in magazine_source.get_children(): magazine_builder.append_from(child.mesh,0,Transform3D(Basis.IDENTITY,Vector3(0,.095,.135))*child.transform)
	magazine_builder.index();magazine_mesh=magazine_builder.commit()
	var charging_builder:=SurfaceTool.new();charging_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child: MeshInstance3D in charging_source.get_children(): charging_builder.append_from(child.mesh,0,child.transform)
	charging_builder.index();charging_mesh=charging_builder.commit()
	magazine_source.free();charging_source.free()
	source.free()

static func _part(parent: Node3D,finish: String,mesh: Mesh,point: Vector3,basis:=Basis.IDENTITY) -> void:
	var part:=MeshInstance3D.new();part.mesh=mesh;part.transform=Transform3D(basis,point);part.set_meta("finish",finish);parent.add_child(part)

static func _box(parent: Node3D,finish: String,point: Vector3,size: Vector3) -> void:
	# Small details only; large stock/receiver parts have bevelled silhouettes.
	var mesh:=BoxMesh.new();mesh.size=size;_part(parent,finish,mesh,point)

static func _bar(parent: Node3D,finish: String,a: Vector3,b: Vector3,radius: float) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=10;mesh.rings=1
	_part(parent,finish,mesh,(a+b)*.5,Basis(Quaternion(Vector3.UP,(b-a).normalized())))

static func _tri(builder: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	var normal: Vector3=(b-a).cross(c-a).normalized()
	for p in [a,c,b]: builder.set_normal(normal);builder.add_vertex(p)

static func _slab(parent: Node3D,finish: String,outline: Array,width: float,bevel: float) -> void:
	var profile:=PackedVector2Array(outline);var centre:=Vector2.ZERO
	if Geometry2D.is_polygon_clockwise(profile): profile.reverse()
	for p in profile: centre+=p
	centre/=profile.size()
	var rings: Array=[]
	for data in [[-width*.5,bevel],[-width*.5+bevel,0],[width*.5-bevel,0],[width*.5,bevel]]:
		var ring: Array[Vector3]=[]
		for p in profile:
			var inset: Vector2=p+(centre-p).normalized()*float(data[1]);ring.append(Vector3(data[0],inset.x,inset.y))
		rings.append(ring)
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces:=Geometry2D.triangulate_polygon(profile)
	for i in range(0,faces.size(),3):
		_tri(builder,rings[0][faces[i]],rings[0][faces[i+2]],rings[0][faces[i+1]])
		_tri(builder,rings[3][faces[i]],rings[3][faces[i+1]],rings[3][faces[i+2]])
	for layer in 3:
		for i in profile.size():
			var n: int=(i+1)%profile.size()
			_tri(builder,rings[layer][i],rings[layer][n],rings[layer+1][n]);_tri(builder,rings[layer][i],rings[layer+1][n],rings[layer+1][i])
	# append_from must receive indexed surfaces consistently. Mixing an
	# unindexed custom shell with indexed primitive details drops its faces.
	builder.index()
	_part(parent,finish,builder.commit(),Vector3.ZERO)

static func _ring(parent: Node3D,finish: String,point: Vector3,outer: float,inner: float,length: float) -> void:
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var a:=TAU*i/20;var b:=TAU*(i+1)/20
		for radii in [[outer,outer,-length*.5,length*.5],[inner,inner,length*.5,-length*.5],[inner,outer,-length*.5,-length*.5],[outer,inner,length*.5,length*.5]]:
			var p:=Vector3(cos(a)*radii[0],sin(a)*radii[0],radii[2]);var q:=Vector3(cos(b)*radii[0],sin(b)*radii[0],radii[2])
			var r:=Vector3(cos(b)*radii[1],sin(b)*radii[1],radii[3]);var s:=Vector3(cos(a)*radii[1],sin(a)*radii[1],radii[3])
			_tri(builder,p,q,r);_tri(builder,p,r,s)
	builder.index()
	_part(parent,finish,builder.commit(),point)
