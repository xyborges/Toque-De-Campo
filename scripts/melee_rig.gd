extends Node3D
class_name MeleeRig

# One world-space rig drives the hands, first-person copy and damage samples.
const SPECS := {
	"broom":{"duration":0.86,"active_start":0.26,"active_end":0.51,"radius":0.055},
	"squeegee":{"duration":1.0,"active_start":0.32,"active_end":0.56,"radius":0.05},
	"axe":{"duration":1.22,"active_start":0.40,"active_end":0.64,"radius":0.045}}
var id := "broom"
var swing: Node3D
var animator: AnimationPlayer
var grip_right: Marker3D
var grip_left: Marker3D
var impact_points: Array[Marker3D] = []
var elapsed := 0.0
var running := false
var sweep_shape := CapsuleShape3D.new()
var sweep_query := PhysicsShapeQueryParameters3D.new()

func build(weapon: String) -> void:
	id = weapon
	name = "MeleeRig"
	swing = Node3D.new()
	swing.name = "Swing"
	add_child(swing)
	var length := 1.12 if id == "axe" else 1.53
	_cylinder("Handle",Vector3(0,0.35,0),0.028 if id == "axe" else 0.021,length,Color("865b35"))
	_cylinder("GripWrap",Vector3(0,-0.12,0),0.031,0.25,Color("3b3430"))
	grip_right = _marker("RightGrip",Vector3(0,-0.12,0))
	grip_left = _marker("LeftGrip",Vector3(0,0.27,0))
	if id == "broom":
		_box("BrushBlock",Vector3(0,1.10,0),Vector3(0.44,0.085,0.16),Color("805b36"))
		_cylinder("Socket",Vector3(0,1.025,0),0.045,0.16,Color("535e57"))
		for x in range(13):
			for z in range(3):
				var bristle := _cylinder("Bristles",Vector3((x-6)*0.032,1.23,(z-1)*0.047),0.010,0.19,Color("c4a16a") if x % 2 else Color("a48650"))
				bristle.rotation.z = (x-6)*-0.007
		for x in [-.21,-.14,-.07,0,.07,.14,.21]: impact_points.append(_marker("Impact",Vector3(x,1.24,0)))
	elif id == "squeegee":
		_box("Crossbar",Vector3(0,1.11,0),Vector3(0.58,0.08,0.10),Color("81999d"))
		_box("Rubber",Vector3(0,1.19,0),Vector3(0.60,0.10,0.042),Color("202929"))
		_cylinder("Socket",Vector3(0,1.025,0),0.043,0.18,Color("647d7b"))
		for x in [-.28,-.21,-.14,-.07,0,.07,.14,.21,.28]: impact_points.append(_marker("Impact",Vector3(x,1.20,0)))
	else:
		_cylinder("HeadSocket",Vector3(0,0.84,0),0.065,0.19,Color("4b565c"))
		_box("Poll",Vector3(-0.10,0.84,0),Vector3(0.18,0.14,0.10),Color("4e5b62"))
		# A tapered convex wedge, not a flat rectangular plate or a cross.
		var vertices := PackedVector3Array([
			Vector3(0.025,0.77,-0.065),Vector3(0.025,0.91,-0.065),Vector3(0.34,1.005,-0.012),Vector3(0.39,0.69,-0.012),
			Vector3(0.025,0.77,0.065),Vector3(0.025,0.91,0.065),Vector3(0.34,1.005,0.012),Vector3(0.39,0.69,0.012)])
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,1,2,6,1,6,5,0,4,7,0,7,3])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var blade := MeshInstance3D.new()
		blade.name = "ForgedBlade"
		var surface := SurfaceTool.new()
		surface.create_from(mesh,0)
		surface.generate_normals()
		blade.mesh = surface.commit()
		blade.material_override = _material(Color("9caeb6"),0.8)
		swing.add_child(blade)
		for y in [.71,.78,.85,.92,.99]: impact_points.append(_marker("CuttingEdge",Vector3(.37,y,0)))
		impact_points.append(_marker("HeadFace",Vector3(.12,.84,0)))
		impact_points.append(_marker("PollContact",Vector3(-.15,.84,0)))
	if id in ["broom","squeegee"]:
		# Sample the visible shaft too, at its own thin radius. A brush-sized
		# collision radius on the entire handle would produce phantom contacts.
		for i in 9:
			var contact := _marker("HandleContact",Vector3(0,-.28+i*.16,0))
			contact.set_meta("radius",.028)
			impact_points.append(contact)
	_build_animation()

func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65 if metallic == 0.0 else 0.3
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _box(label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	swing.add_child(node)
	return node

func _cylinder(label: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	swing.add_child(node)
	return node

func _marker(label: String, pos: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = pos
	swing.add_child(marker)
	return marker

func _build_animation() -> void:
	animator = AnimationPlayer.new()
	animator.name = "AttackAnimation"
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animator)
	var spec: Dictionary = SPECS[id]
	var times := [0.0,float(spec.active_start),float(spec.active_end),float(spec.duration)]
	var angles: Array[Vector3]
	var positions: Array[Vector3]
	if id == "axe":
		angles = [Vector3(-0.65,0,-0.10),Vector3(0.55,-0.12,-0.20),Vector3(-2.20,0.10,0.10),Vector3(-0.65,0,-0.10)]
		positions = [Vector3.ZERO,Vector3(0,0.42,0.08),Vector3(0,-0.12,-0.10),Vector3.ZERO]
		for i in range(positions.size()): positions[i].x -= 0.34
	elif id == "broom":
		angles = [Vector3(-0.65,0,-0.10),Vector3(-1.40,-1.15,-0.12),Vector3(-1.65,1.10,0.12),Vector3(-0.65,0,-0.10)]
		positions = [Vector3.ZERO,Vector3(0,0.03,0),Vector3(-0.10,-0.04,-0.08),Vector3.ZERO]
	else:
		angles = [Vector3(-0.65,0,-0.10),Vector3(0.20,-0.35,-0.25),Vector3(-2.10,0.30,0.14),Vector3(-0.65,0,-0.10)]
		positions = [Vector3.ZERO,Vector3(0,0.30,0.05),Vector3(-0.06,-0.10,-0.12),Vector3.ZERO]
	var animation := Animation.new()
	animation.length = float(spec.duration)
	for property_index in range(2):
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track,NodePath("Swing:" + ("rotation" if property_index == 0 else "position")))
		animation.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
		for i in range(times.size()):
			animation.track_insert_key(track,times[i],angles[i] if property_index == 0 else positions[i])
	var library := AnimationLibrary.new()
	library.add_animation("attack",animation)
	animator.add_animation_library("",library)
	swing.rotation = angles[0]
	swing.position = positions[0]

func start() -> void:
	elapsed = 0.0
	running = true
	animator.play("attack")
	animator.advance(0.0)

func step_size(delta: float) -> float:
	var step := minf(delta,1.0/120.0)
	for time in [float(SPECS[id].active_start),float(SPECS[id].active_end),float(SPECS[id].duration)]:
		if time > elapsed + 0.00001: step = minf(step,time-elapsed)
	return maxf(step,0.00001)

func advance(delta: float) -> void:
	if not running: return
	elapsed = minf(elapsed + delta,float(SPECS[id].duration))
	animator.advance(delta)
	if elapsed >= float(SPECS[id].duration) - 0.00001: running = false

func samples() -> PackedVector3Array:
	var result := PackedVector3Array()
	for marker in impact_points: result.append(marker.global_position)
	return result

func contact_radius(index: int) -> float:
	return float(impact_points[index].get_meta("radius",SPECS[id].radius))

func contact_reach() -> float:
	var reach:=0.0
	for i in impact_points.size(): reach=maxf(reach,grip_right.position.distance_to(impact_points[i].position)+contact_radius(i))
	return reach

func active_between(before: float, after: float) -> bool:
	return before >= float(SPECS[id].active_start) - 0.00001 and after <= float(SPECS[id].active_end) + 0.00001 and after > before
