extends RefCounted
class_name G3Model

# G3 clássico com móveis oliva. Dimensões em metros; cano aponta para -Z.
# Quatro materiais e malhas compartilhadas entre jogadores e visualizações.
const MUZZLE := Vector3(0.0, 0.070, -0.828)
const SUPPORT := Vector3(-0.02, -0.012, -0.36)
const GRIP := Vector3(0.0, -0.046, 0.035)
const SIGHT_Y := 0.143
const MAG_DOCK := Vector3(0.0, -0.095, -0.135)
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
static var magazine_mesh: Mesh
static var charging_mesh: Mesh
static var iron_mesh: Mesh
static var front_sight_mesh: Mesh

static func create() -> Node3D:
	if meshes.is_empty(): _build()
	var model := Node3D.new()
	model.name = "Imported_g3"
	model.set_meta("rest_position", Vector3.ZERO)
	for finish in meshes:
		var part := MeshInstance3D.new()
		part.name = finish
		part.mesh = meshes[finish]
		part.material_override = materials[finish]
		model.add_child(part)
	var magazine := MeshInstance3D.new()
	magazine.name = "Magazine"
	magazine.mesh = magazine_mesh
	magazine.material_override = materials.Metal
	magazine.position = MAG_DOCK
	model.add_child(magazine)
	var handle := MeshInstance3D.new()
	handle.name = "ChargingHandle"
	handle.mesh = charging_mesh
	handle.material_override = materials.Steel
	model.add_child(handle)
	var irons:=Node3D.new();irons.name="IronSightAssembly";model.add_child(irons)
	var sight:=MeshInstance3D.new();sight.name="RearDiopter";sight.mesh=iron_mesh;sight.material_override=materials.Metal;irons.add_child(sight)
	var hood:=MeshInstance3D.new();hood.name="FrontSightHood";hood.mesh=front_sight_mesh;hood.material_override=materials.Metal;model.add_child(hood)
	for entry in [["Muzzle", MUZZLE], ["GripRight", GRIP], ["SupportGrip", SUPPORT],
			["RearSight", Vector3(0, SIGHT_Y, 0.105)], ["FrontSight", Vector3(0, SIGHT_Y, -0.655)]]:
		var marker := Marker3D.new()
		marker.name = entry[0]
		marker.position = entry[1]
		model.add_child(marker)
	return model

static func _build() -> void:
	materials["Metal"] = WarArtStyle.material("gunmetal")
	materials["Steel"] = WarArtStyle.material("bare_metal")
	materials["Dark"] = WarArtStyle.material("recess")
	var parkerized:=StandardMaterial3D.new();parkerized.albedo_color=Color(.20,.23,.215);parkerized.metallic=.38;parkerized.roughness=.66
	materials["Metal"]=parkerized
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("465139")
	green.metallic = 0.04
	green.roughness = 0.84
	materials["Olive"] = green
	var source := Node3D.new()
	var mag_source := Node3D.new()
	mag_source.name = "G3MagazineSource"
	var handle_source := Node3D.new()
	var iron_source:=Node3D.new()
	var front_sight_source:=Node3D.new()

	# Coronha verde fixa, reta e alongada: silhueta própria do G3.
	FALModel._slab(source, "Olive", [
		Vector2(0.073, 0.086), Vector2(0.084, 0.34), Vector2(-0.111, 0.34),
		Vector2(-0.097, 0.29), Vector2(-0.052, 0.115)], 0.058, 0.008)
	FALModel._box(source, "Dark", Vector3(0, -0.013, 0.352), Vector3(0.064, 0.195, 0.018))
	for i in 7:
		FALModel._bar(source, "Dark", Vector3(-0.030, -0.094 + i * 0.028, 0.362),
			Vector3(0.030, -0.094 + i * 0.028, 0.362), 0.0013)

	# Receptor estampado metálico e tubo superior do sistema roller-delayed.
	FALModel._slab(source, "Metal", [
		Vector2(0.096, 0.115), Vector2(0.117, 0.070), Vector2(0.104, -0.221),
		Vector2(0.012, -0.231), Vector2(-0.023, -0.17), Vector2(-0.015, 0.108)], 0.058, 0.004)
	FALModel._bar(source, "Metal", Vector3(0, 0.102, 0.119),
		Vector3(0, 0.102, -0.245), 0.039)
	# Pressed receiver ribs, rear cap and the separate cocking tube.
	for side in [-1,1]:
		FALModel._bar(source,"Metal",Vector3(side*.029,.041,.090),Vector3(side*.029,.041,-.195),.0035)
		FALModel._bar(source,"Steel",Vector3(side*.025,.020,.082),Vector3(side*.025,.020,-.187),.0013)
	FALModel._ring(source,"Metal",Vector3(0,.084,.120),.039,.033,.014)
	FALModel._bar(source,"Metal",Vector3(0,.118,-.205),Vector3(0,.118,-.650),.010)
	FALModel._bar(source,"Dark",Vector3(0,.118,-.220),Vector3(0,.118,-.564),.005)
	FALModel._box(source, "Dark", Vector3(0.030, 0.073, -0.081), Vector3(0.0016, 0.038, 0.106))
	FALModel._box(source, "Steel", Vector3(0.032, 0.051, -0.079), Vector3(0.002, 0.004, 0.100))
	for z in [-0.013, 0.050, -0.184]:
		FALModel._bar(source, "Steel", Vector3(-0.031, 0.029, z), Vector3(0.031, 0.029, z), 0.003)

	# Guarda-mão verde ventilado, com repetição leve de ranhuras.
	FALModel._slab(source, "Olive", [
		Vector2(0.073, -0.231), Vector2(0.097, -0.259), Vector2(0.083, -0.559),
		Vector2(0.027, -0.575), Vector2(0.006, -0.250)], 0.068, 0.007)
	for side in [-1, 1]:
		for index in 8:
			var z := -0.285 - index * 0.032
			FALModel._box(source, "Dark", Vector3(side * 0.034, 0.063, z),Vector3(.0014,.009,.018))
		FALModel._bar(source,"Olive",Vector3(side*.032,.025,-.255),Vector3(side*.032,.040,-.558),.003)
	for z in [-0.233, -0.571]:
		FALModel._box(source, "Metal", Vector3(0, 0.067, z), Vector3(0.070, 0.062, 0.010))
	# Slim sling lug, magazine catch and selector with readable mechanical relief.
	FALModel._ring(source,"Steel",Vector3(-.035,.025,-.566),.009,.006,.004)
	FALModel._box(source,"Metal",Vector3(-.024,-.003,.022),Vector3(.008,.018,.040))
	FALModel._bar(source,"Metal",Vector3(-.030,.002,.014),Vector3(-.031,-.018,.044),.004)
	FALModel._bar(source,"Steel",Vector3(.032,-.015,-.103),Vector3(.040,-.015,-.103),.006)

	# Empunhadura verde inclinada e guarda-mato vazado.
	FALModel._slab(source, "Olive", [
		Vector2(-0.001, 0.027), Vector2(-0.011, -0.012),
		Vector2(-0.139, 0.054), Vector2(-0.115, 0.099)], 0.039, 0.004)
	for index in 6:
		FALModel._bar(source, "Dark", Vector3(-0.020, -0.040 - index * 0.014, 0.031 + index * 0.007),
			Vector3(0.020, -0.040 - index * 0.014, 0.031 + index * 0.007), 0.0015)
	var guard := [Vector3(0, -0.015, -0.076), Vector3(0, -0.054, -0.078),
		Vector3(0, -0.070, -0.040), Vector3(0, -0.056, 0.011)]
	for index in guard.size() - 1:
		FALModel._bar(source, "Metal", guard[index], guard[index + 1], 0.003)
	FALModel._bar(source, "Steel", Vector3(0, -0.011, -0.038),
		Vector3(0, -0.048, -0.035), 0.0025)

	# Carregador reto destacável, 20 cartuchos.
	FALModel._slab(mag_source, "Metal", [
		Vector2(0.004, -0.088), Vector2(0.002, -0.185),
		Vector2(-0.160, -0.178), Vector2(-0.170, -0.096)], 0.046, 0.002)
	FALModel._box(mag_source, "Steel", Vector3(0, -0.181, -0.133),
		Vector3(0.052, 0.007, 0.092))
	for side in [-1, 1]:
		for z in [-0.156, -0.118]:
			FALModel._box(mag_source, "Steel", Vector3(side * 0.024, -0.127, z),
				Vector3(0.0015, 0.091, 0.003))

	# Alavanca lateral dianteira, animável durante a recarga.
	FALModel._bar(handle_source, "Steel", Vector3(-0.043, 0.111, -0.227),
		Vector3(-0.080, 0.111, -0.227), 0.005)
	FALModel._bar(handle_source, "Dark", Vector3(-0.080, 0.111, -0.227),
		Vector3(-0.080, 0.128, -0.227), 0.008)

	# Cano longo, quebra-chamas aberto e miras típicas do G3.
	FALModel._bar(source, "Metal", Vector3(0, 0.070, -0.570),
		Vector3(0, 0.070, -0.791), 0.010)
	FALModel._ring(source, "Metal", Vector3(0, 0.070, -0.811), 0.016, 0.007, 0.036)
	FALModel._ring(source, "Steel", MUZZLE, 0.016, 0.007, 0.002)
	for index in 5:
		var a := TAU * index / 5
		FALModel._bar(source, "Dark",
			Vector3(cos(a) * 0.016, 0.070 + sin(a) * 0.016, -0.800),
			Vector3(cos(a) * 0.016, 0.070 + sin(a) * 0.016, -0.827), 0.002)
	# Aperture and front blade share the exact sight line used by ADS.
	FALModel._box(iron_source,"Metal",Vector3(0,.122,.105),Vector3(.034,.018,.034))
	FALModel._ring(iron_source,"Metal",Vector3(0,SIGHT_Y,.105),.014,.0065,.016)
	for side in [-1,1]:FALModel._bar(iron_source,"Metal",Vector3(side*.011,.132,.116),Vector3(side*.011,.132,.094),.003)
	FALModel._box(front_sight_source,"Metal",Vector3(0,.102,-.655),Vector3(.021,.046,.022))
	FALModel._ring(front_sight_source,"Metal",Vector3(0,SIGHT_Y,-.655),.016,.013,.009)
	FALModel._bar(front_sight_source,"Metal",Vector3(0,.126,-.655),Vector3(0,SIGHT_Y,-.655),.0013)
	FALModel._bar(front_sight_source,"Metal",Vector3(-.013,.117,-.655),Vector3(.013,.117,-.655),.0028)
	for finish in materials:
		meshes[finish] = _merge(source, finish)
	magazine_mesh = _merge(mag_source, "")
	charging_mesh = _merge(handle_source, "")
	iron_mesh=_merge(iron_source,"")
	front_sight_mesh=_merge(front_sight_source,"")
	source.free()
	mag_source.free()
	handle_source.free()
	iron_source.free()
	front_sight_source.free()

static func _merge(source: Node3D, finish: String) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child: MeshInstance3D in source.get_children():
		if finish.is_empty() or str(child.get_meta("finish", "")) == finish:
			surface.append_from(child.mesh, 0, (Transform3D(Basis.IDENTITY, -MAG_DOCK) * child.transform) if source.name == "G3MagazineSource" else child.transform)
	surface.index()
	return surface.commit()
