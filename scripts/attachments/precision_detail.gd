extends Node3D
## Shared housing with continuous profiles and recessed glass.
const TOOLS=preload("res://scripts/attachments/hensoldt_detail.gd")
static var meshes: Array[Mesh]=[]
static var finishes: Array[Material]=[]

static func lathe(tool: SurfaceTool, profile: PackedVector2Array) -> void:
	const SIDES:=32
	var shell:=SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in profile.size()-1:
		var from:=profile[band]
		var to:=profile[band+1]
		var edge:=(to-from).normalized()
		for side in SIDES:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var angle:=TAU*float(side+corner.y)/SIDES
				var radial:=Vector2(cos(angle),sin(angle))
				var point:=from if corner.x==0 else to
				shell.set_normal(Vector3(radial.x*edge.x,radial.y*edge.x,-edge.y))
				shell.add_vertex(Vector3(radial.x*point.y,radial.y*point.y,point.x))
	# Match the indexed primitives appended to the shared material mesh.
	shell.index()
	tool.append_from(shell.commit(),0,Transform3D.IDENTITY)

static func build() -> void:
	if not meshes.is_empty():return
	var metal:=SurfaceTool.new();var rubber:=SurfaceTool.new();var marks:=SurfaceTool.new()
	for tool in [metal,rubber,marks]:tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axial:=Basis(Vector3.RIGHT,PI*.5)
	var side_axis:=Basis(Vector3.BACK,PI*.5)
	# One exterior from the objective rim to the eyepiece. The first two
	# steps form an inward-facing lip that meets the recessed objective.
	lathe(metal,PackedVector2Array([
		Vector2(-.224,.037),Vector2(-.238,.037),Vector2(-.241,.040),
		Vector2(-.238,.044),Vector2(-.221,.044),Vector2(-.216,.042),
		Vector2(-.203,.041),Vector2(-.165,.023),Vector2(-.152,.020),
		Vector2(.123,.020),Vector2(.137,.024),Vector2(.158,.028),
		Vector2(.166,.030),Vector2(.192,.030),Vector2(.206,.032)
	]))
	# Closed annular eyepiece. The sleeve seats on the metal shoulder and
	# the rear bevel ends in a single face perpendicular to the optical axis.
	# The inner wall meets the Lens mask at Z=.210 and stays open at its centre.
	lathe(rubber,PackedVector2Array([
		Vector2(.158,.0275),Vector2(.158,.0295),Vector2(.163,.032),
		Vector2(.166,.033),Vector2(.171,.033),Vector2(.173,.0345),
		Vector2(.177,.0345),Vector2(.179,.0335),Vector2(.182,.034),
		Vector2(.184,.0355),Vector2(.189,.0355),Vector2(.191,.0345),
		Vector2(.197,.0355),Vector2(.219,.037),Vector2(.223,.0355),
		Vector2(.223,.033),Vector2(.217,.0315),Vector2(.207,.0315),
		Vector2(.193,.029),Vector2(.167,.0285),Vector2(.158,.0275)
	]))
	for z in [-.099,.079]:
		TOOLS._ring(metal,.020,.025,Vector3(0,0,z),axial)
		TOOLS._box(metal,Vector3(.045,.026,.030),Vector3(0,-.030,z))
		for side in [-1,1]:TOOLS._cylinder(marks,.003,.005,Vector3(side*.019,-.033,z),Basis.IDENTITY,10)
	TOOLS._cylinder(metal,.020,.040,Vector3(0,.032,-.005))
	TOOLS._cylinder(metal,.025,.015,Vector3(0,.052,-.005))
	TOOLS._cylinder(metal,.020,.036,Vector3(.029,0,-.005),side_axis)
	TOOLS._cylinder(metal,.024,.016,Vector3(.051,0,-.005),side_axis)
	for i in 24:
		var a:=TAU*i/24.;var x:=cos(a);var z:=sin(a)
		TOOLS._box(rubber,Vector3(.002,.012,.003),Vector3(x*.025,.052,-.005+z*.025),Basis(Vector3.UP,-a))
		TOOLS._box(rubber,Vector3(.012,.002,.003),Vector3(.051,x*.024,-.005+z*.024),Basis(Vector3.RIGHT,a))
		if i%3==0:TOOLS._box(marks,Vector3(.001,.001,.006),Vector3(x*.018,.060,-.005+z*.018),Basis(Vector3.UP,-a))
	var objective:=CylinderMesh.new()
	objective.top_radius=.0375;objective.bottom_radius=.0375
	objective.height=.004;objective.radial_segments=32
	# Bake the cylinder into the scope's axis with the same cached mesh path.
	var glass:=SurfaceTool.new();glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	glass.append_from(objective,0,Transform3D(axial,Vector3(0,0,-.224)))
	var coating:=StandardMaterial3D.new()
	coating.albedo_color=Color(.065,.17,.18);coating.metallic=.25;coating.roughness=.19
	meshes=[metal.commit(),rubber.commit(),marks.commit(),glass.commit()]
	finishes=[WarArtStyle.material("gunmetal"),WarArtStyle.material("rubber"),WarArtStyle.material("marking"),coating]

func _ready() -> void:
	if get_child_count()>0:return
	build()
	for i in meshes.size():
		var node:=MeshInstance3D.new();node.name=["RingsAndOcular","FocusGrip","AdjustmentMarks","ObjectiveGlass"][i]
		node.mesh=meshes[i];node.material_override=finishes[i];node.visibility_range_end=85.;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
