extends RefCounted
class_name NavalGeometry

static var materials: Dictionary = {}
static func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var key := color.to_html()+str(metal)
	if materials.has(key): return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = 0.65
	materials[key] = result
	return result

static func box(parent: Node3D, label: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, color: Color, top_radius := -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = pos
	node.material_override = material(color,0.15)
	parent.add_child(node)
	return node

static func hull(parent: Node3D, kind: String) -> PackedVector3Array:
	var data: Dictionary = NavalCatalog.SHIPS[kind]
	var w := float(data.width)*0.5
	var l := float(data.length)
	var top := float(data.height)*0.55
	var polygon := [Vector2(-w*0.65,l*0.48),Vector2(-w,l*0.25),Vector2(-w,-l*0.25),Vector2(-w*0.28,-l*0.49),Vector2(0,-l*0.58),Vector2(w*0.28,-l*0.49),Vector2(w,-l*0.25),Vector2(w,l*0.25),Vector2(w*0.65,l*0.48)]
	var points := PackedVector3Array()
	for level in range(2):
		for p in polygon: points.append(Vector3(p.x*(0.62 if level == 0 else 1.0),-0.85 if level == 0 else top,p.y*(0.91 if level == 0 else 1.0)))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := polygon.size()
	for i in range(n):
		var next := (i+1)%n
		for point in [points[i],points[i+n],points[next+n],points[i],points[next+n],points[next]]: surface.add_vertex(point)
		for point in [Vector3(0,top,0),points[i+n],points[next+n]]: surface.add_vertex(point)
		for point in [Vector3(0,-0.85,0),points[next],points[i]]: surface.add_vertex(point)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Hull"
	mesh.mesh = surface.commit()
	var material := material(Color("3f555f"),0.25).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	parent.add_child(mesh)
	return points

static func ship_details(body: CharacterBody3D, kind: String) -> void:
	var data: Dictionary = NavalCatalog.SHIPS[kind]
	if kind == "submarine":
		_submarine(body,data)
		return
	var l := float(data.length)
	var w := float(data.width)
	var deck := float(data.height)*0.55
	var points := hull(body,kind)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.name = "HullCollision"
	collision.shape = shape
	body.add_child(collision)
	var cabin_size := Vector3(w*0.52,1.35 if kind == "light" else 2.8,l*0.22)
	var cabin_pos := Vector3(0,deck+cabin_size.y*0.5,l*0.04)
	if kind == "assault":
		cabin_size = Vector3(w*0.40,3.3,l*0.29)
		cabin_pos.x = w*0.18
	if kind == "submarine":
		# Rounded pressure hull, a conning tower, diving planes and stern propeller.
		var pressure := cylinder(body,"PressureHull",Vector3(0,0.12,0),w*0.46,l*0.87,Color("293a40"))
		pressure.rotation.x = PI/2
		pressure.scale.z = 0.17
		cabin_size = Vector3(w*0.30,2.4,l*0.12)
		cabin_pos = Vector3(0,deck+1.2,0)
		box(body,"SternPlanes",Vector3(0,0,l*0.44),Vector3(w*1.3,0.18,l*0.065),Color("42575a"))
		box(body,"VerticalRudder",Vector3(0,0.25,l*0.43),Vector3(0.18,1.8,l*0.08),Color("42575a"))
		var hub := cylinder(body,"PropellerHub",Vector3(0,-0.15,l*0.48),0.34,0.9,Color("837653"))
		hub.rotation.x = PI/2
		for angle in [0.0,TAU/3,TAU*2/3]:
			var blade := box(body,"PropellerBlade",Vector3(0,-0.15,l*0.49),Vector3(0.18,2.0,0.20),Color("aa9156"))
			blade.rotation.z = angle
	box(body,"Bridge",cabin_pos,cabin_size,Color("758789"))
	var cabin := CollisionShape3D.new()
	var cabin_shape := BoxShape3D.new()
	cabin_shape.size = cabin_size
	cabin.shape = cabin_shape
	cabin.position = cabin_pos
	cabin.name = "BridgeCollision"
	body.add_child(cabin)
	for side in [-1.0,1.0]:
		box(body,"BridgeWindows",cabin_pos+Vector3(side*(cabin_size.x*0.5+0.012),cabin_size.y*0.22,-cabin_size.z*0.05),Vector3(0.025,cabin_size.y*0.24,cabin_size.z*0.73),Color("192e3d"))
		for index in range(8 if kind != "light" else 4):
			var z := -l*0.35+index*l*(0.10 if kind != "light" else 0.21)
			cylinder(body,"RailPost",Vector3(side*w*0.44,deck+0.35,z),0.022,0.70,Color("9ba5a0"))
		box(body,"SideRail",Vector3(side*w*0.44,deck+0.65,l*0.02),Vector3(0.035,0.035,l*0.78),Color("9ba5a0"))
	var mast_height := 2.0 if kind == "light" else 3.2
	var mast_base := cabin_pos+Vector3(0,cabin_size.y*0.5+mast_height*0.5,0)
	cylinder(body,"Mast",mast_base,0.045,mast_height,Color("4e626a"))
	box(body,"Radar",mast_base+Vector3(0,mast_height*0.4,0),Vector3(w*0.55,0.22,0.22),Color("9ca6a6"))
	if kind != "light":
		for side in [-1.0,1.0]:
			cylinder(body,"Exhaust",Vector3(side*w*0.19,deck+1.1,l*0.12),0.25,2.1,Color("414e50"))
	if kind == "assault":
		for index in range(3): box(body,"Cargo",Vector3(-w*0.22,deck+0.3,l*(-0.11+index*0.12)),Vector3(w*0.25,0.6,l*0.08),Color("566951"))


static func _submarine(body: CharacterBody3D, data: Dictionary) -> void:
	var length := float(data.length)
	var radius := float(data.width)*0.46
	var pressure := cylinder(body,"PressureHull",Vector3(0,0.10,0),radius,length*0.80,Color("293d46"))
	pressure.rotation.x = PI/2
	pressure.scale.z = 0.65
	for side in [-1.0,1.0]:
		var cap := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius*2.0
		sphere.radial_segments = 20
		sphere.rings = 12
		cap.mesh = sphere
		cap.material_override = material(Color("293d46"),0.2)
		cap.position = Vector3(0,0.10,side*length*0.40)
		cap.scale = Vector3(1,0.65,1.15)
		body.add_child(cap)
	var points := PackedVector3Array()
	for ring in [-0.49,-0.33,0.33,0.49]:
		for index in range(16):
			var angle := index*TAU/16.0
			var taper := 0.28 if absf(ring)>0.4 else 1.0
			points.append(Vector3(cos(angle)*radius*taper,0.10+sin(angle)*radius*0.65*taper,ring*length))
	var hull_shape := ConvexPolygonShape3D.new()
	hull_shape.points = points
	var hull_collision := CollisionShape3D.new()
	hull_collision.name = "HullCollision"
	hull_collision.shape = hull_shape
	body.add_child(hull_collision)
	box(body,"Sail",Vector3(0,2.0,0.6),Vector3(1.5,2.3,4.0),Color("4d6369"))
	var sail := CollisionShape3D.new()
	var sail_shape := BoxShape3D.new()
	sail_shape.size = Vector3(1.5,2.3,4.0)
	sail.shape = sail_shape
	sail.name = "BridgeCollision"
	sail.position = Vector3(0,2.0,0.6)
	body.add_child(sail)
	for offset in [-0.55,0.55]:
		cylinder(body,"Periscope",Vector3(offset*0.5,3.85,0.6),0.065,1.8,Color("96a7a7"))
		box(body,"PeriscopeHead",Vector3(offset*0.5,4.7,0.45),Vector3(0.20,0.15,0.5),Color("445b61"))
	box(body,"BowDivingPlanes",Vector3(0,0.05,-length*0.28),Vector3(7.2,0.17,1.15),Color("526a70"))
	box(body,"SternPlanes",Vector3(0,0.1,length*0.43),Vector3(6.9,0.18,1.1),Color("526a70"))
	box(body,"Rudder",Vector3(0,0.5,length*0.43),Vector3(0.20,2.8,1.3),Color("526a70"))
	var propeller := cylinder(body,"PropellerHub",Vector3(0,0.1,length*0.51),0.30,0.8,Color("a2915b"))
	propeller.rotation.x = PI/2
	for angle in [0.0,TAU/3,TAU*2/3]:
		var blade := box(body,"PropellerBlade",Vector3(0,0.1,length*0.515),Vector3(0.16,2.5,0.20),Color("aa9156"))
		blade.rotation.z = angle
