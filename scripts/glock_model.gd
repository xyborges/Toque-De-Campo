extends RefCounted
class_name GlockModel
const MUZZLE:=Vector3(0,.046,-.183)
const GRIP:=Vector3(0,-.034,.004)
const SUPPORT:=Vector3(-.044,-.045,-.005)
const SIGHT_Y:=.084
static var meshes: Dictionary={}
static var slide_meshes: Dictionary={}
static var magazine_mesh: Mesh

static func create() -> Node3D:
	if meshes.is_empty(): _build()
	var root:=Node3D.new();root.name="Imported_glock";root.set_meta("rest_position",Vector3.ZERO)
	for finish in meshes:
		var part:=MeshInstance3D.new();part.name=finish;part.mesh=meshes[finish];part.material_override=WarArtStyle.material(finish);root.add_child(part)
	var slide:=Node3D.new();slide.name="SlideAssembly";root.add_child(slide)
	for finish in slide_meshes:
		var part:=MeshInstance3D.new();part.name=finish;part.mesh=slide_meshes[finish];part.material_override=WarArtStyle.material(finish);slide.add_child(part)
	var magazine:=MeshInstance3D.new();magazine.name="Magazine";magazine.mesh=magazine_mesh;magazine.material_override=WarArtStyle.material("gunmetal");magazine.position=Vector3(0,-.067,.012);root.add_child(magazine)
	for point in [["Muzzle",MUZZLE],["GripRight",GRIP],["SupportGrip",SUPPORT],["RearSight",Vector3(0,SIGHT_Y,.014)],["FrontSight",Vector3(0,SIGHT_Y,-.159)]]:
		var marker:=Marker3D.new();marker.name=point[0];marker.position=point[1];root.add_child(marker)
	return root

static func _build() -> void:
	var source:=Node3D.new()
	var slide_source:=Node3D.new();var magazine_source:=Node3D.new()
	# Authored bevelled profiles, metres, forward -Z. The slide, frame,
	# trigger opening and muzzle bore remain separate silhouettes.
	FALModel._slab(slide_source,"gunmetal",[Vector2(.074,.033),Vector2(.077,-.154),Vector2(.067,-.179),Vector2(.025,-.179),Vector2(.016,-.151),Vector2(.017,.033)],.029,.002)
	FALModel._slab(source,"polymer",[Vector2(.015,.027),Vector2(.015,-.168),Vector2(-.013,-.167),Vector2(-.020,-.070),Vector2(-.038,-.048),Vector2(-.113,-.005),Vector2(-.121,.024),Vector2(-.088,.050),Vector2(-.015,.024)],.032,.003)
	FALModel._slab(source,"polymer",[Vector2(-.014,-.076),Vector2(-.039,-.081),Vector2(-.059,-.062),Vector2(-.060,-.022),Vector2(-.040,-.014),Vector2(-.037,-.025),Vector2(-.049,-.030),Vector2(-.048,-.058),Vector2(-.034,-.067),Vector2(-.019,-.063)],.024,.0015)
	FALModel._box(magazine_source,"gunmetal",Vector3(0,-.116,.010),Vector3(.035,.009,.042))
	FALModel._box(magazine_source,"gunmetal",Vector3(0,-.067,.012),Vector3(.024,.098,.032))
	FALModel._bar(source,"gunmetal",Vector3(0,-.010,-.040),Vector3(0,-.039,-.045),.003)
	FALModel._bar(source,"polymer",Vector3(0,-.027,-.041),Vector3(0,-.043,-.040),.0017)
	# Rear serrations and ejection port; no imported bright baked material.
	for side in [-1,1]:
		for i in 8: FALModel._box(slide_source,"recess",Vector3(side*.0147,.047,.020-i*.0047),Vector3(.0012,.037,.0015))
		for row in 7:
			for col in 4: FALModel._box(source,"polymer",Vector3(side*.0165,-.036-row*.010,.005+col*.006-row*.0017),Vector3(.0015,.003,.003))
	FALModel._box(slide_source,"recess",Vector3(.0149,.058,-.077),Vector3(.001,.023,.036))
	FALModel._box(slide_source,"bare_metal",Vector3(.0152,.046,-.078),Vector3(.0012,.003,.032))
	FALModel._box(source,"gunmetal",Vector3(-.018,.006,.011),Vector3(.004,.007,.021))
	FALModel._box(source,"gunmetal",Vector3(.017,.007,-.035),Vector3(.004,.007,.018))
	FALModel._box(source,"gunmetal",Vector3(-.018,-.018,.013),Vector3(.004,.009,.011))
	FALModel._ring(source,"gunmetal",MUZZLE+Vector3(0,0,.002),.008,.0045,.004)
	FALModel._ring(source,"recess",MUZZLE+Vector3(0,-.025,0),.0045,.002,.004)
	for side in [-1,1]:
		FALModel._box(slide_source,"gunmetal",Vector3(side*.0084,.078,.014),Vector3(.008,.012,.012))
		FALModel._box(slide_source,"bare_metal",Vector3(side*.0084,.081,.0205),Vector3(.004,.005,.001))
	FALModel._box(slide_source,"gunmetal",Vector3(0,.079,-.159),Vector3(.003,.010,.008))
	FALModel._box(slide_source,"bare_metal",Vector3(0,.081,-.1545),Vector3(.0018,.003,.001))
	batch(source,meshes);batch(slide_source,slide_meshes)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece: MeshInstance3D in magazine_source.get_children(): st.append_from(piece.mesh,0,Transform3D(Basis.IDENTITY,Vector3(0,.067,-.012))*piece.transform)
	st.index();magazine_mesh=st.commit()
	source.free();slide_source.free();magazine_source.free()

static func batch(source: Node3D,target: Dictionary) -> void:
	for finish in ["gunmetal","polymer","recess","bare_metal"]:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count:=0
		for piece: MeshInstance3D in source.get_children():
			if piece.get_meta("finish","")==finish: st.append_from(piece.mesh,0,piece.transform);count+=1
		if count>0: st.index();target[finish]=st.commit()
