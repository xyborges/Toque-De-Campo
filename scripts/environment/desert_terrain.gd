extends RefCounted
class_name DesertTerrain
const SIZE := 300.0
const HALF := 150.0
const STEP := 2.0
const SIDE := 151
static var heights := PackedFloat32Array()
static var terrain_material: StandardMaterial3D

static func prepare() -> void:
	if not heights.is_empty(): return
	heights.resize(SIDE*SIDE)
	for z in SIDE:
		for x in SIDE: heights[z*SIDE+x] = _raw_height(x*STEP-HALF,z*STEP-HALF)

static func _raw_height(x: float,z: float) -> float:
	var rolling := 2.2*sin(x*.038+0.5)*cos(z*.025)+1.1*sin(z*.071+x*.024)+0.55*cos(x*.109-z*.046)
	var ridge := 3.9*exp(-pow((x-80.0)/33.0,2)-pow((z+54.0)/64.0,2))
	ridge += 4.2*exp(-pow((x+90.0)/38.0,2)-pow((z-44.0)/49.0,2))
	var depression := -2.1*exp(-pow((x+54.0)/23.0,2)-pow((z+66.0)/26.0,2))
	var center := smoothstep(34.0,56.0,maxf(absf(x),absf(z+3.0)))
	var road := 1.0-0.68*exp(-pow((x-12.0*sin(z*.024))/5.5,2))
	return (rolling+ridge+depression)*center*road+0.001

static func height_at(x: float,z: float) -> float:
	prepare()
	var gx := clampf((x+HALF)/STEP,0.0,SIDE-1.001)
	var gz := clampf((z+HALF)/STEP,0.0,SIDE-1.001)
	var ix := floori(gx)
	var iz := floori(gz)
	var fx := gx-ix
	var fz := gz-iz
	var a := heights[iz*SIDE+ix]
	var b := heights[iz*SIDE+ix+1]
	var c := heights[(iz+1)*SIDE+ix]
	var d := heights[(iz+1)*SIDE+ix+1]
	# Interpolate the same diagonal triangles used by the render and collider.
	return a+fx*(b-a)+fz*(c-a) if fx+fz<=1.0 else d+(1.0-fx)*(c-d)+(1.0-fz)*(b-d)

static func point(x: float,z: float) -> Vector3:
	return Vector3(x,height_at(x,z),z)

static func normal_at(x: float,z: float) -> Vector3:
	return Vector3(height_at(x-1,z)-height_at(x+1,z),2.0,height_at(x,z-1)-height_at(x,z+1)).normalized()

static func build(parent: Node3D,visuals := true) -> void:
	prepare()
	if visuals and terrain_material==null:
		terrain_material = EnvironmentKit.material("sand").duplicate()
		terrain_material.vertex_color_use_as_albedo = true
	for cz in range(0,SIDE-1,25):
		for cx in range(0,SIDE-1,25):
			var body := StaticBody3D.new()
			body.name = "DuneTerrain_%d_%d" % [cx,cz]
			body.collision_layer = 1
			parent.add_child(body)
			var faces := PackedVector3Array()
			var surface := SurfaceTool.new()
			if visuals: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for z in range(cz,mini(cz+25,SIDE-1)):
				for x in range(cx,mini(cx+25,SIDE-1)):
					var a := point(x*STEP-HALF,z*STEP-HALF)
					var b := point((x+1)*STEP-HALF,z*STEP-HALF)
					var c := point(x*STEP-HALF,(z+1)*STEP-HALF)
					var d := point((x+1)*STEP-HALF,(z+1)*STEP-HALF)
					for p: Vector3 in [a,b,c,b,d,c]:
						faces.append(p)
						if visuals:
							var normal := normal_at(p.x,p.z)
							var tone := 0.93+sin(p.x*.052+p.z*.08)*.035+clampf(p.y*.018,-.07,.09)
							surface.set_color(Color(tone*1.05,tone*1.02,tone*.96))
							surface.set_normal(normal)
							surface.add_vertex(p)
			var collider := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(faces)
			collider.shape = shape
			body.add_child(collider)
			if visuals:
				var mesh := MeshInstance3D.new()
				surface.index()
				mesh.mesh = surface.commit()
				mesh.material_override = terrain_material
				body.add_child(mesh)
	parent.set_meta("terrain_size",SIZE)
