extends SceneTree

# Offline authoring: three material surfaces, no per-piece runtime nodes.
var housing := SurfaceTool.new()
var rubber := SurfaceTool.new()
var glass := SurfaceTool.new()
var vertex_counts := {}

func _initialize() -> void:
	for tool: SurfaceTool in [housing, rubber, glass]:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES); vertex_counts[tool] = 0
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(.245, .265, .195); paint.metallic = .42; paint.roughness = .72
	var elastomer := StandardMaterial3D.new()
	elastomer.albedo_color = Color(.035, .040, .032); elastomer.roughness = .97
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(.055, .13, .14); lens.metallic = .4; lens.roughness = .16
	housing.set_material(paint); rubber.set_material(elastomer); glass.set_material(lens)
	# Short folded-prism housing, not the shared PSO telescope tube.
	bevel_block(housing, Vector3(0., .016, -.008), Vector3(.112, .102, .174), .015)
	bevel_block(housing, Vector3(0., .023, -.109), Vector3(.084, .080, .048), .012)
	box(housing, Vector3(0., -.073, -.012), Vector3(.073, .014, .206))
	box(housing, Vector3(0., -.052, .051), Vector3(.052, .030, .032))
	box(housing, Vector3(0., -.052, -.066), Vector3(.052, .030, .034))
	cylinder(housing, Vector3(.012, .083, -.064), .022, .020, Basis.IDENTITY, 16)
	cylinder(rubber, Vector3(.012, .095, -.064), .0225, .005, Basis.IDENTITY, 16)
	cylinder(housing, Vector3(-.065, .020, -.018), .014, .014, Basis(Vector3.FORWARD, PI * .5), 12)
	cylinder(rubber, Vector3(-.073, .020, -.018), .0145, .005, Basis(Vector3.FORWARD, PI * .5), 12)
	# Eye and Lens stay fixed; the compact octagonal eyecup frames z=.118.
	tube(rubber, Vector3(0., 0., .104), .043, .033, .030, 8)
	tube(housing, Vector3(0., 0., .084), .039, .033, .014, 8)
	box(rubber, Vector3(.056, .027, -.013), Vector3(.007, .017, .043))
	box(housing, Vector3(.059, .038, -.027), Vector3(.012, .008, .012))
	tube(rubber, Vector3(0., .023, -.134), .032, .027, .010, 8)
	cylinder(glass, Vector3(0., .023, -.137), .0265, .002, Basis(Vector3.RIGHT, PI * .5), 16)
	for z in [-.076, .066]:
		cylinder(rubber, Vector3(.038, -.073, z), .004, .003, Basis(Vector3.FORWARD, PI * .5), 8)
		cylinder(rubber, Vector3(-.038, -.073, z), .004, .003, Basis(Vector3.FORWARD, PI * .5), 8)
	var mesh := ArrayMesh.new()
	for tool: SurfaceTool in [housing, rubber, glass]: tool.generate_normals(); tool.commit(mesh)
	var status := ResourceSaver.save(mesh, "res://scenes/weapons/scope4x_fal_housing.res")
	print("PRISMATIC_HOUSING_BAKE ", status, " surfaces=", mesh.get_surface_count())
	quit(0 if status == OK else 1)

func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a); tool.add_vertex(c); tool.add_vertex(b)
	var index: int = vertex_counts[tool]
	tool.add_index(index); tool.add_index(index + 1); tool.add_index(index + 2)
	vertex_counts[tool] = index + 3
func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	triangle(tool, a, b, c); triangle(tool, a, c, d)
func bevel_block(tool: SurfaceTool, center: Vector3, size: Vector3, bevel: float) -> void:
	var hx := size.x * .5; var hy := size.y * .5; var hz := size.z * .5
	var section := PackedVector2Array([Vector2(-hx + bevel, -hy), Vector2(hx - bevel, -hy),
		Vector2(hx, -hy + bevel), Vector2(hx, hy - bevel), Vector2(hx - bevel, hy),
		Vector2(-hx + bevel, hy), Vector2(-hx, hy - bevel), Vector2(-hx, -hy + bevel)])
	for index in section.size():
		var next := (index + 1) % section.size()
		var a := center + Vector3(section[index].x, section[index].y, hz)
		var b := center + Vector3(section[next].x, section[next].y, hz)
		var c := center + Vector3(section[next].x, section[next].y, -hz)
		var d := center + Vector3(section[index].x, section[index].y, -hz)
		quad(tool, a, d, c, b)
		triangle(tool, center + Vector3(0, 0, hz), a, b)
		triangle(tool, center - Vector3(0, 0, hz), c, d)
func box(tool: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new(); mesh.size = size
	tool.append_from(mesh, 0, Transform3D(Basis.IDENTITY, center))
	vertex_counts[tool] += mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
func cylinder(tool: SurfaceTool, center: Vector3, radius: float, height: float, basis: Basis, sides: int) -> void:
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mesh.radial_segments = sides; mesh.rings = 1
	tool.append_from(mesh, 0, Transform3D(basis, center))
	vertex_counts[tool] += mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
func tube(tool: SurfaceTool, center: Vector3, outer: float, inner: float, depth: float, sides: int) -> void:
	for index in sides:
		var a := TAU * float(index) / float(sides); var b := TAU * float(index + 1) / float(sides)
		var v := Vector2(cos(a), sin(a)); var w := Vector2(cos(b), sin(b))
		var ofa := center + Vector3(v.x * outer, v.y * outer, depth * .5)
		var ofb := center + Vector3(w.x * outer, w.y * outer, depth * .5)
		var ora := center + Vector3(v.x * outer, v.y * outer, -depth * .5)
		var orb := center + Vector3(w.x * outer, w.y * outer, -depth * .5)
		var ifa := center + Vector3(v.x * inner, v.y * inner, depth * .5)
		var ifb := center + Vector3(w.x * inner, w.y * inner, depth * .5)
		var ira := center + Vector3(v.x * inner, v.y * inner, -depth * .5)
		var irb := center + Vector3(w.x * inner, w.y * inner, -depth * .5)
		quad(tool, ofa, ora, orb, ofb); quad(tool, ifa, ifb, irb, ira)
		quad(tool, ofa, ofb, ifb, ifa); quad(tool, ora, ira, irb, orb)
