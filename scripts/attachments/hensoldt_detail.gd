extends Node3D
# Shared low-poly detail package: the 1P and 3P Hensoldt scopes reuse the
# same three GPU meshes instead of allocating a draw call for every screw.
static var housing_mesh: ArrayMesh
static var rubber_mesh: ArrayMesh
static var detail_mesh: ArrayMesh
static var housing_material: StandardMaterial3D
static var rubber_material: StandardMaterial3D
static var detail_material: StandardMaterial3D

static func _cylinder(tool: SurfaceTool,radius: float,height: float,position: Vector3,rotation: Basis=Basis.IDENTITY,radial:=16) -> void:
	var primitive:=CylinderMesh.new()
	primitive.top_radius=radius
	primitive.bottom_radius=radius
	primitive.height=height
	primitive.radial_segments=radial
	tool.append_from(primitive,0,Transform3D(rotation,position))

static func _ring(tool: SurfaceTool,inner: float,outer: float,position: Vector3,rotation: Basis=Basis.IDENTITY) -> void:
	var primitive:=TorusMesh.new()
	primitive.inner_radius=inner
	primitive.outer_radius=outer
	primitive.rings=16
	primitive.ring_segments=6
	tool.append_from(primitive,0,Transform3D(rotation,position))

static func _box(tool: SurfaceTool,size: Vector3,position: Vector3,basis: Basis=Basis.IDENTITY) -> void:
	var primitive:=BoxMesh.new()
	primitive.size=size
	tool.append_from(primitive,0,Transform3D(basis,position))

static func _build() -> void:
	if housing_mesh:return
	housing_material=StandardMaterial3D.new()
	housing_material.albedo_color=Color(.115,.126,.123)
	housing_material.metallic=.56
	housing_material.roughness=.58
	rubber_material=StandardMaterial3D.new()
	rubber_material.albedo_color=Color(.027,.031,.030)
	rubber_material.roughness=.93
	detail_material=StandardMaterial3D.new()
	detail_material.albedo_color=Color(.34,.32,.26)
	detail_material.metallic=.53
	detail_material.roughness=.69
	var main:=SurfaceTool.new()
	var rubber:=SurfaceTool.new()
	var accent:=SurfaceTool.new()
	for tool in [main,rubber,accent]:tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along_barrel:=Basis(Vector3.RIGHT,PI*.5)
	var side_turret:=Basis(Vector3.BACK,PI*.5)
	# Slim clamp collars around the original Hensoldt barrel.
	for z in [-.101,.108]:
		_ring(main,.029,.037,Vector3(0,0,z),along_barrel)
		_box(main,Vector3(.050,.028,.018),Vector3(0,-.034,z))
		_cylinder(accent,.0045,.008,Vector3(-.025,-.067,z),Basis.IDENTITY,10)
		_cylinder(accent,.0045,.008,Vector3(.025,-.067,z),Basis.IDENTITY,10)
	# Hollow eyepiece sleeve connects all rubber rings to the steel tube.
	# The front decoration overlaps the objective bell instead of floating.
	var sleeve:=CylinderMesh.new()
	sleeve.top_radius=.034
	sleeve.bottom_radius=.034
	sleeve.height=.081
	sleeve.radial_segments=18
	sleeve.cap_top=false
	sleeve.cap_bottom=false
	rubber.append_from(sleeve,0,Transform3D(along_barrel,Vector3(0,0,.174)))
	_ring(rubber,.034,.040,Vector3(0,0,.186),along_barrel)
	_ring(rubber,.033,.039,Vector3(0,0,.207),along_barrel)
	_ring(main,.033,.040,Vector3(0,0,-.143),along_barrel)
	# Machined turret stacks and the toothed adjustment wheels.
	_cylinder(main,.022,.014,Vector3(0,.050,0))
	_cylinder(main,.020,.010,Vector3(0,.062,0))
	_cylinder(main,.021,.014,Vector3(.052,0,0),side_turret)
	_cylinder(main,.019,.010,Vector3(.064,0,0),side_turret)
	for i in 16:
		var a:=TAU*float(i)/16.
		var radial:=Vector2(cos(a),sin(a))
		_box(main,Vector3(.003,.010,.004),Vector3(radial.x*.023,.055,radial.y*.023),Basis(Vector3.UP,-a))
		_box(main,Vector3(.010,.003,.004),Vector3(.057,radial.x*.022,radial.y*.022),Basis(Vector3.RIGHT,a))
		if i%2==0:
			_box(accent,Vector3(.0012,.0012,.006),Vector3(radial.x*.017,.0675,radial.y*.017),Basis(Vector3.UP,-a))
	# Three tiny screw heads on the locking side and circular end-cap features.
	for z in [-.094,0.,.094]:
		_cylinder(accent,.005,.004,Vector3(.043,-.034,z),side_turret,10)
	housing_mesh=main.commit()
	rubber_mesh=rubber.commit()
	detail_mesh=accent.commit()

func _ready() -> void:
	if get_node_or_null("MachinedFinish"):return
	_build()
	for pair in [
		["MachinedFinish",housing_mesh,housing_material],
		["EyecupRubber",rubber_mesh,rubber_material],
		["ScrewMarks",detail_mesh,detail_material]
	]:
		var instance:=MeshInstance3D.new()
		instance.name=str(pair[0])
		instance.mesh=pair[1]
		instance.material_override=pair[2]
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end=85.0
		add_child(instance)
