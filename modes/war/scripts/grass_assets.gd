extends RefCounted

const PATCH:=2.0
static var meshes: Dictionary={}
static var materials: Dictionary={}

static func create_cell(source_mesh: Mesh,source_material: Material,capacity: int) -> MultiMeshInstance3D:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=source_mesh;mm.instance_count=capacity
	var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=source_material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=50.
	return node

static func blade_mesh(level: int) -> ArrayMesh:
	level=clampi(level,1,3)
	if meshes.has(level): return meshes[level]
	var side: int=[0,5,7,9][level]
	var rng:=RandomNumberGenerator.new();rng.seed=504982
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in side:
		for z in side:
			var spacing:=PATCH/side
			var p:=Vector3(-1.+(x+.5)*spacing+rng.randf_range(-spacing*.3,spacing*.3),0.,-1.+(z+.5)*spacing+rng.randf_range(-spacing*.3,spacing*.3))
			for leaf in 3:
				var height:=rng.randf_range(.18,.28);var width:=rng.randf_range(.035,.065)
				var root:=p+Vector3(rng.randf_range(-.035,.035),0,rng.randf_range(-.035,.035))
				var angle:=rng.randf()*TAU;var edge:=Vector3.RIGHT.rotated(Vector3.UP,angle)*width*.5
				var bend:=Vector3.FORWARD.rotated(Vector3.UP,angle)*rng.randf_range(.035,.085)
				var mid:=root+Vector3.UP*height*.62+bend*.3
				var tip:=root+Vector3.UP*height+bend
				var base:=Color("3d5930").lightened(rng.randf_range(0,.05))
				var top:=Color("789657").lightened(rng.randf_range(0,.07))
				var left:=root-edge;var right:=root+edge;var ml:=mid-edge*.62;var mr:=mid+edge*.62
				for item in [[left,base],[right,base],[mr,base.lerp(top,.55)],[left,base],[mr,base.lerp(top,.55)],[ml,base.lerp(top,.55)],[ml,base.lerp(top,.55)],[mr,base.lerp(top,.55)],[tip,top]]:
					s.set_normal(Vector3.UP);s.set_color(item[1]);s.set_uv(Vector2(0,clampf((Vector3(item[0]).y)/.28,0.,1.)));s.add_vertex(item[0])
	var result:=s.commit();result.set_meta("blades",side*side*3);result.set_meta("triangles",side*side*9)
	meshes[level]=result;return result

static func grass_material(level: int) -> ShaderMaterial:
	level=clampi(level,1,3)
	if materials.has(level): return materials[level]
	var result:=ShaderMaterial.new();result.shader=load("res://modes/war/shaders/grass_field.gdshader")
	result.set_shader_parameter("storm",0.0)
	result.set_shader_parameter("wind_strength",[0.,.012,.022,.032][level])
	result.set_shader_parameter("near_end",[0.,14.,21.,29.][level])
	result.set_shader_parameter("far_end",[0.,20.,29.,38.][level])
	materials[level]=result;return result

static func distant_mesh() -> ArrayMesh:
	if meshes.has("distant"):return meshes.distant
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=504982
	for i in 25:
		var p:=Vector3(-.9+(i%5)*.45,0,-.9+(i/5)*.45)
		var edge:=Vector3.RIGHT.rotated(Vector3.UP,rng.randf()*TAU)*.04
		var tip:=p+Vector3(0,rng.randf_range(.18,.28),.04)
		for vertex in [p-edge,p+edge,tip]:
			s.set_normal(Vector3.UP);s.set_color(Color("65834a"));s.set_uv(Vector2(0,clampf(vertex.y/.28,0.,1.)));s.add_vertex(vertex)
	meshes.distant=s.commit();return meshes.distant
