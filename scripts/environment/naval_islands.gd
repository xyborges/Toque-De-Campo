extends RefCounted
class_name NavalIslands
const NAMES := ["Farol costeiro","Estação de radar","Costa selvagem","Fortificação","Porto abandonado"]
const ANCHORS := [Vector2(-.22,.08),Vector2(.10,-.08),Vector2(.0,.0),Vector2(-.13,.06),Vector2(.0,.61)]
const LEVELS := [16.0,18.0,19.0,14.0,4.0]

static func height_at(p: Vector2,index: int,mountain: int) -> float:
	var radius := float(NavalCatalog.RADII[index])
	var angle := atan2(p.y,p.x)
	var coast := radius*(.98+sin(angle*5+index)*.055+cos(angle*3-index)*.045)
	var aspect: float = [.86,.95,.76,.92,.92][index]
	var r := Vector2(p.x,p.y/aspect).length()/coast
	var center := 19.0+sin(p.x*.085+index)*2.4+cos(p.y*.11)*1.8
	if index==2: center -= 6.0*exp(-pow((p.x+p.y*.35)/2.6,2))
	if index==4: r += .14*exp(-pow(wrapf(angle-1.5,-PI,PI)/.42,2))
	var h := center
	if r>.46: h = lerpf(center,3.0,smoothstep(.46,.83,r))
	if r>.83: h = lerpf(3.0,-9.0,smoothstep(.83,1.08,r))
	if r>1.08: h = lerpf(-9.0,-36.0,smoothstep(1.08,1.25,r))
	if index==mountain:
		var peak := Vector2(radius*.19,-radius*.18)
		h += 98.0*exp(-p.distance_squared_to(peak)/pow(radius*.23,2))
	if index!=2:
		var pad: Vector2 = ANCHORS[index]*radius
		var flat := 1.0-smoothstep(9.0 if index!=4 else 12.0,16.0 if index!=4 else 20.0,p.distance_to(pad))
		h = lerpf(h,float(LEVELS[index]),flat)
	return h

static func build(parent: Node3D,index: int,mountain: int,visuals: bool) -> void:
	var island := Node3D.new()
	island.name = "Island_%d" % index
	island.position = NavalCatalog.ISLANDS[index]
	island.set_meta("identity",NAMES[index])
	parent.add_child(island)
	var radius := float(NavalCatalog.RADII[index])
	var extent := radius*1.25
	var step := extent*2.0/48.0
	var faces := PackedVector3Array()
	var mesh_builder := SurfaceTool.new()
	var prepared: Resource
	var definitions=load("res://scripts/maps/definition.gd")
	var path: String=definitions.ROOT+"naval/islands_"+str(mountain)+".res"
	if not "--map-uncached" in OS.get_cmdline_user_args() and definitions.current("naval") and ResourceLoader.exists(path):prepared=load(path)
	if visuals: mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(48):
		for x in range(48):
			var p := Vector2(x*step-extent,z*step-extent)
			var points: Array[Vector2] = [p,p+Vector2(step,0),p+Vector2(0,step),p+Vector2(step,0),p+Vector2(step,step),p+Vector2(0,step)]
			for sample: Vector2 in points:
				var sx:=roundi((sample.x+extent)/step);var sz:=roundi((sample.y+extent)/step)
				var y: float=prepared.buffers[index][sz*49+sx] if prepared else height_at(sample,index,mountain)
				var vertex := Vector3(sample.x,y,sample.y)
				faces.append(vertex)
				if visuals:
					var dx := height_at(sample+Vector2(.5,0),index,mountain)-height_at(sample-Vector2(.5,0),index,mountain)
					var dz := height_at(sample+Vector2(0,.5),index,mountain)-height_at(sample-Vector2(0,.5),index,mountain)
					var normal := Vector3(-dx,1,-dz).normalized()
					var tint := Color("c0ac83") if y<3.2 else Color("7d8980")
					if normal.y<.66: tint = Color("778184")
					if normal.y>.87 and y>7: tint = Color("819074")
					mesh_builder.set_color(tint)
					mesh_builder.set_normal(normal)
					mesh_builder.add_vertex(vertex)
	var body := StaticBody3D.new()
	body.name = "IslandTerrain"
	body.collision_layer = 1
	island.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)
	if visuals:
		var terrain := MeshInstance3D.new()
		mesh_builder.index()
		terrain.mesh = mesh_builder.commit()
		var material := EnvironmentKit.material("rock").duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(1.6,1.6,1.6)
		terrain.material_override = material
		island.add_child(terrain)
	var k := EnvironmentKit.new(island,visuals,80.0)
	var anchor: Vector2 = ANCHORS[index]*radius
	var base := Vector3(anchor.x,float(LEVELS[index]),anchor.y)
	match index:
		0: _lighthouse(k,base)
		1: _radar(k,base)
		2: _wild_coast(k,index,mountain)
		3: _fort(k,base)
		4: _port(k,base)
	# Coastal vegetation and exposed rock shoulders, kept inside existing shores.
	for i in range(42):
		var angle := i*2.399+index
		var distance := radius*(.50+float(i%5)*.075)
		var local := Vector2(sin(angle),cos(angle))*distance
		var y := height_at(local,index,mountain)
		if y<1.2 or (index!=2 and local.distance_to(anchor)<13): continue
		var p := Vector3(local.x,y,local.y)
		if i%6==0: k.rock(p,Vector3(2.3,1.7+(i%4),2.7),i+index,true)
		else: EnvironmentProps.grass(k,p,2.0+(i%3),true)
	k.flush()
	island.set_meta("layout_version","archipelago-2")

static func _building(k: EnvironmentKit,base: Vector3,size: Vector3,roof := "steel") -> void:
	k.box("ConcreteFoundation",base-Vector3.UP*.45,Vector3(size.x+.6,.9,size.z+.6),"concrete",true)
	k.wall("CoastalFacade",base+Vector3(-size.x*.5,0,size.z*.5),base+Vector3(size.x*.5,0,size.z*.5),size.y,"concrete",[{"at":size.x*.35,"width":1.8,"top":2.6},{"at":size.x*.75,"width":1.4,"sill":1.1,"top":2.4}])
	k.wall("CoastalRear",base+Vector3(-size.x*.5,0,-size.z*.5),base+Vector3(size.x*.5,0,-size.z*.5),size.y,"concrete")
	for side in [-1.0,1.0]: k.wall("CoastalSide",base+Vector3(side*size.x*.5,0,-size.z*.5),base+Vector3(side*size.x*.5,0,size.z*.5),size.y,"concrete")
	k.box("BuildingRoof",base+Vector3.UP*(size.y+.07),Vector3(size.x+.5,.18,size.z+.5),roof,true)
	for x in [-size.x*.35,size.x*.35]: k.pipe(base+Vector3(x,size.y,.0),base+Vector3(x,size.y+1.2,.0),.08,"steel")

static func _lighthouse(k: EnvironmentKit,base: Vector3) -> void:
	k.cylinder("LighthousePlinth",base+Vector3.UP*.25,4.2,.5,"concrete",true)
	k.cylinder("LighthouseTower",base+Vector3.UP*8.5,2.6,17.0,"brick",true,.62)
	for y in [4.5,9.5,14.5]: k.cylinder("LighthouseBands",base+Vector3.UP*y,lerpf(2.6,1.62,y/17),.65,"plaster",false,1.0)
	k.cylinder("LanternBalcony",base+Vector3.UP*17.1,2.65,.30,"steel",true)
	for i in range(16):
		var offset := Vector3(sin(i*TAU/16)*2.48,17.8,cos(i*TAU/16)*2.48)
		k.pipe(base+offset-Vector3.UP*.55,base+offset+Vector3.UP*.40,.035,"steel")
		var next := Vector3(sin((i+1)*TAU/16)*2.48,18.15,cos((i+1)*TAU/16)*2.48)
		k.pipe(base+offset+Vector3.UP*.35,base+next,.035,"steel")
	for i in range(8):
		var p := Vector3(sin(i*TAU/8)*1.55,18.2,cos(i*TAU/8)*1.55)
		k.pipe(base+p-Vector3.UP*.8,base+p+Vector3.UP*.8,.045,"steel")
	k.cylinder("LanternLight",base+Vector3.UP*18.2,.42,1.4,"light",false)
	k.cylinder("LanternCap",base+Vector3.UP*19.5,2.0,1.1,"steel",false,.0)
	k.pipe(base+Vector3.UP*20,base+Vector3.UP*21.6,.035,"steel")
	_building(k,base+Vector3(9,-.2,2),Vector3(7,3.3,5),"steel")
	k.sign_text("FAROL / TDC",base+Vector3(8,2.5,4.7),3.2)
	for i in range(18): k.box("LighthouseStair",base+Vector3(0,-.2-i*.27,4.4+i*.43),Vector3(2.7,.26,.46),"concrete",true)
	if k.visuals:
		var beacon := SpotLight3D.new()
		beacon.name = "LighthouseBeacon"
		beacon.position = base+Vector3.UP*18.2
		beacon.rotation = Vector3(-.045,0,0)
		beacon.light_color = Color("ffe3a4")
		beacon.spot_range = 320
		beacon.spot_angle = 12
		beacon.light_energy = 5
		beacon.set_meta("night_light",true)
		beacon.set_meta("beacon",true)
		k.root.add_child(beacon)

static func _radar(k: EnvironmentKit,base: Vector3) -> void:
	k.box("RadarPlatform",base-Vector3.UP*.35,Vector3(15,.7,13),"concrete",true)
	EnvironmentProps.tower(k,base+Vector3(10,0,-2),14)
	_building(k,base+Vector3(-5,0,3),Vector3(7,3.2,6))
	k.cylinder("RadarPedestal",base+Vector3(1.5,2,-2),1.15,4.0,"steel",true,.75)
	k.beam(base+Vector3(1.5,3.9,-2),base+Vector3(1.5,6.7,-1),.65,.60,"steel",true)
	var dish_faces := PackedVector3Array()
	for ring in range(5):
		for segment in range(32):
			var r0 := ring*.64
			var r1 := (ring+1)*.64
			var a0 := segment*TAU/32
			var a1 := (segment+1)*TAU/32
			for p: Vector2 in [Vector2(cos(a0),sin(a0))*r0,Vector2(cos(a1),sin(a1))*r0,Vector2(cos(a0),sin(a0))*r1,Vector2(cos(a1),sin(a1))*r0,Vector2(cos(a1),sin(a1))*r1,Vector2(cos(a0),sin(a0))*r1]:
				dish_faces.append(base+Vector3(1.5+p.x,7.0+p.y,-1.0+p.length_squared()*.13))
	var dish_shape := ConcavePolygonShape3D.new()
	dish_shape.backface_collision = true
	dish_shape.set_faces(dish_faces)
	k._collider("RadarDish",dish_shape,Transform3D.IDENTITY)
	if k.visuals:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in dish_faces: surface.add_vertex(vertex)
		surface.generate_normals()
		var dish := MeshInstance3D.new()
		dish.name = "ParabolicRadarDish"
		dish.mesh = surface.commit()
		var mat := EnvironmentKit.material("steel:d1d5b8").duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		dish.material_override = mat
		k.root.add_child(dish)
	for side in [-1.0,1.0]: k.pipe(base+Vector3(1.5+side*2.5,7,-.2),base+Vector3(1.5,7,1.8),.06,"steel")
	k.cylinder("RadarFeed",base+Vector3(1.5,7,1.8),.18,.65,"steel",false,1,Vector3(PI/2,0,0))
	EnvironmentProps.fence(k,base+Vector3(-11,0,-8),base+Vector3(12,0,-8),false)
	EnvironmentProps.generator(k,base+Vector3(-5,0,-3))
	k.sign_text("ESTAÇÃO / RADAR",base+Vector3(-5,2.6,6.14),3.5)

static func _wild_coast(k: EnvironmentKit,index: int,mountain: int) -> void:
	for i in range(15):
		var p := Vector2(sin(i*2.7)*22,cos(i*1.9)*25)
		var y := height_at(p,index,mountain)
		k.rock(Vector3(p.x,y+.5,p.y),Vector3(3.0+i%4,3.2+i%3,2.8),i,true)
	for i in range(6):
		var p := Vector2(-24+i*5,18+i*.7)
		k.rock(Vector3(p.x,height_at(p,index,mountain),p.y),Vector3(2.5,6+i,3),i+6,true)

static func _fort(k: EnvironmentKit,base: Vector3) -> void:
	k.box("BunkerFoundation",base-Vector3.UP*.5,Vector3(20,1,12),"concrete",true)
	k.wall("BunkerFacade",base+Vector3(-9,0,5),base+Vector3(9,0,5),3.6,"concrete",[{"at":5.0,"width":4.6,"sill":1.3,"top":2.0},{"at":13.0,"width":4.6,"sill":1.3,"top":2.0}],1.1)
	k.wall("BunkerBack",base+Vector3(-9,0,-5),base+Vector3(9,0,-5),3.6,"concrete",[{"at":8.0,"width":2,"top":2.6}],.8)
	for side in [-1.0,1.0]: k.wall("BunkerSide",base+Vector3(side*9,0,-5),base+Vector3(side*9,0,5),3.6,"concrete",[],.8)
	k.box("BunkerRoof",base+Vector3.UP*3.9,Vector3(20,.8,12),"concrete",true)
	for side in [-1.0,1.0]:
		k.box("FortificationWall",base+Vector3(side*14,.9,1),Vector3(1,1.8,13),"concrete",true)
		for i in range(4): k.box("BrokenBattlement",base+Vector3(side*14,2.1,-4+i*3),Vector3(1,.6,1.5),"concrete",true)
	for i in range(8): k.rock(base+Vector3(-8+i*2.4,.3,8),Vector3(.65,.5,.9),i,true)
	EnvironmentProps.tower(k,base+Vector3(4,4,-1),7)
	k.sign_text("POSTO COSTEIRO / 04",base+Vector3(0,2.8,5.6),5.0)

static func _port(k: EnvironmentKit,base: Vector3) -> void:
	_building(k,base+Vector3(-8,0,-2),Vector3(11,5.3,10),"steel")
	for side in [-1.0,1.0]:
		k.beam(base+Vector3(-8,5.5,-7),base+Vector3(-8+side*5.9,4.7,-7),.2,.18,"steel")
	for side in [-1.0,1.0]:
		k.box("WarehousePitchedRoof",base+Vector3(-8+side*2.87,6.05,-2),Vector3(5.95,.12,10.8),"steel",true,Vector3(0,0,-side*.255))
	for z in [-7.0,3.0]:
		k.beam(base+Vector3(-13.7,5.3,z),base+Vector3(-8,6.8,z),.12,.12,"steel")
		k.beam(base+Vector3(-2.3,5.3,z),base+Vector3(-8,6.8,z),.12,.12,"steel")
	# Pier and beams stay within the original island safety radius.
	for i in range(11):
		var z := i*.65
		k.box("PierPlank",base+Vector3(6,-.8,z),Vector3(6,.17,.56),"wood",true)
	for side in [-1.0,1.0]:
		for z in [0,3.2,6.4]:
			k.cylinder("PierPile",base+Vector3(6+side*2.6,-3.0,z),.18,6.0,"wood",true)
		k.beam(base+Vector3(6+side*2.6,-1,0),base+Vector3(6+side*2.6,-4,3.2),.12,.12,"wood")
	var crane := base+Vector3(8,-.8,1)
	k.cylinder("CraneBase",crane+Vector3.UP*.35,1.0,.7,"steel",true)
	k.beam(crane+Vector3.UP*.6,crane+Vector3(0,6,0),.35,.35,"steel",true)
	k.beam(crane+Vector3(0,6,0),crane+Vector3(4.5,7,0),.22,.22,"steel")
	k.beam(crane+Vector3(0,5,0),crane+Vector3(4.5,7,0),.07,.07,"steel")
	k.pipe(crane+Vector3(4.5,7,0),crane+Vector3(4.5,1.5,0),.018,"steel")
	k.cylinder("CraneHook",crane+Vector3(4.5,1.4,0),.15,.15,"steel")
	EnvironmentProps.container(k,base+Vector3(-7,0,-11),false)
	for x in [-4,0,3]:
		k.pallet(base+Vector3(x,0,1))
		k.crate(base+Vector3(x,.2,1),Vector3(1.1,.9,1.1),true)
	k.sign_text("CAIS / ÁREA DESATIVADA",base+Vector3(-8,3.9,3.14),5.0)
	# Original retired launch hull: a static object, not a replicated player ship.
	var launch := Node3D.new()
	launch.name = "AbandonedLaunch"
	launch.position = base+Vector3(-15,-1,8)
	launch.rotation = Vector3(.08,-.8,.16)
	k.root.add_child(launch)
	if k.visuals: NavalGeometry.hull(launch,"light")
	var proxy := BoxShape3D.new()
	proxy.size = Vector3(2.6,1.1,7.8)
	k._collider("AbandonedLaunch",proxy,launch.transform)
	for side in [-1.0,1.0]:
		var buoy := base+Vector3(side*17,-3.6,12)
		k.cylinder("MooringBuoy",buoy,.55,.9,"steel:c2b59c",true,.65)
		k.pipe(buoy+Vector3.UP*.4,buoy+Vector3.UP*2.0,.035,"steel")

static func seabed(parent: Node3D,visuals: bool,mountain: int) -> void:
	var surface := SurfaceTool.new()
	if visuals: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for z in range(64):
		for x in range(64):
			for offset: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p := Vector2(-1100+(x+offset.x)*34.375,-1100+(z+offset.y)*34.375)
				var depth := seabed_height(p.x,p.y)
				var vertex := Vector3(p.x,depth,p.y)
				faces.append(vertex)
				if visuals: surface.add_vertex(vertex)
	var body := StaticBody3D.new()
	body.name = "OceanFloor"
	body.collision_layer = 1
	parent.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)
	if visuals:
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		mesh.material_override = EnvironmentKit.material("sand:819b93")
		body.add_child(mesh)

	var k := EnvironmentKit.new(parent,visuals,140)
	for i in range(25):
		var center: Vector3 = NavalCatalog.ISLANDS[i%5]
		var angle := i*2.399
		var radius := float(NavalCatalog.RADII[i%5])*1.4
		var x := center.x+sin(angle)*radius
		var z := center.z+cos(angle)*radius
		k.rock(Vector3(x,seabed_height(x,z)+1.1,z),Vector3(3.4,2.7+(i%3),4.0),i,true)
	k.flush()

static func seabed_height(x: float,z: float) -> float:
	var grid := Vector2((x+1100.0)/34.375,(z+1100.0)/34.375)
	var low := grid.floor()
	var f := grid-low
	var x0 := low.x*34.375-1100.0
	var z0 := low.y*34.375-1100.0
	var a := _seabed_raw(x0,z0)
	var b := _seabed_raw(x0+34.375,z0)
	var c := _seabed_raw(x0,z0+34.375)
	var d := _seabed_raw(x0+34.375,z0+34.375)
	return a+f.x*(b-a)+f.y*(c-a) if f.x+f.y<=1 else d+(1-f.x)*(c-d)+(1-f.y)*(b-d)

static func _seabed_raw(x: float,z: float) -> float:
	var depth := -76.0+sin(x*.008)*14+cos(z*.011)*11
	for i in range(5):
		var center: Vector3 = NavalCatalog.ISLANDS[i]
		var distance := Vector2(x,z).distance_to(Vector2(center.x,center.z))
		var reef := -7.0-maxf(0.0,distance-float(NavalCatalog.RADII[i])*.9)*.9
		depth = maxf(depth,reef)
	return depth
