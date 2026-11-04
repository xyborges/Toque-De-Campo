extends SceneTree
## Creates new reusable scenes. Existing/user-authored trees are preserved.
const DIR:="res://modes/battle_royale/library/"
var materials: Array[StandardMaterial3D]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for color: Color in [Color("41402f"),Color("465532"),Color("52623c"),Color("3b4a2b")]:
		var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=1.;m.vertex_color_use_as_albedo=true;m.cull_mode=BaseMaterial3D.CULL_DISABLED;materials.append(m)
	for willow: bool in [false,true]:build_tree(willow)
	quit()
func cylinder(root_node: Node3D,a: Vector3,b: Vector3,radius: float) -> void:
	var mesh:=CylinderMesh.new();mesh.bottom_radius=radius;mesh.top_radius=radius*.62;mesh.height=a.distance_to(b);mesh.radial_segments=6;mesh.rings=1
	var view:=MeshInstance3D.new();view.mesh=mesh;view.material_override=materials[0];view.position=(a+b)*.5
	var up: Vector3=(b-a).normalized();var right:=Vector3.FORWARD.cross(up).normalized()
	view.basis=Basis(right,up,right.cross(up));root_node.add_child(view)
func cluster(root_node: Node3D,position: Vector3,size: Vector3,rng: RandomNumberGenerator,index: int) -> void:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
	# Individual folded leaves, not solid balls or big transparent cards.
	for leaf in 36:
		var angle:=rng.randf_range(-PI,PI)
		var radial:=sqrt(rng.randf())*.55
		var origin:=Vector3(cos(angle)*radial,rng.randf_range(-.42,.42),sin(angle)*radial)*size
		var basis:=Basis.from_euler(Vector3(rng.randf_range(-.8,.8),angle,rng.randf_range(-.9,.9)))
		var length:=rng.randf_range(.30,.58);var width:=length*.38
		var base:=vertices.size()
		for p: Vector3 in [Vector3(0,0,-length*.5),Vector3(-width,0,0),Vector3(0,0,length*.5),Vector3(width,0,0),Vector3(0,.035,0)]:vertices.append(origin+basis*p)
		indices.append_array(PackedInt32Array([base,base+1,base+4,base+1,base+2,base+4,base+2,base+3,base+4,base+3,base,base+4]))
	var colors:=PackedColorArray()
	for _i in vertices.size():colors.append(Color.WHITE*(.85+.10*(index%3)))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_COLOR]=colors
	var raw:=ArrayMesh.new();raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var st:=SurfaceTool.new();st.create_from(raw,0);st.generate_normals()
	var view:=MeshInstance3D.new();view.mesh=st.commit();view.material_override=materials[1];view.position=position;root_node.add_child(view)
func core_cluster(root_node: Node3D,position: Vector3,size: Vector3,rng: RandomNumberGenerator,index: int) -> void:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
	for ring in 3:
		for i in 6:
			var angle: float=i*TAU/6.+ring*.25
			var radius: float=(.16 if ring==2 else (.45 if ring==0 else .65))*rng.randf_range(.8,1.12)
			vertices.append(Vector3(cos(angle)*radius,(ring-1)*.48+rand_height(rng),sin(angle)*radius)*size)
	for ring in 2:
		for i in 6:
			var a:=ring*6+i;var b:=ring*6+(i+1)%6;var c:=a+6;var d:=b+6
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	# Closed bottom/top: no alpha cards, no sorting or overdraw layers.
	for i in range(1,5):indices.append_array(PackedInt32Array([0,i+1,i,12,12+i,13+i]))
	var colors:=PackedColorArray()
	for _i in vertices.size():colors.append(Color.WHITE*(.85+.10*(index%3)))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_COLOR]=colors
	var raw:=ArrayMesh.new();raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var st:=SurfaceTool.new();st.create_from(raw,0);st.generate_normals()
	var view:=MeshInstance3D.new();view.mesh=st.commit();view.material_override=materials[1];view.position=position;root_node.add_child(view)
func rand_height(rng: RandomNumberGenerator) -> float:return rng.randf_range(-.09,.09)
func build_tree(willow: bool) -> void:
	var id:="willow_v6" if willow else "poplar_v6"
	if FileAccess.file_exists(DIR+id+".tscn"):print("PRESERVED ",id);return
	var node:=StaticBody3D.new();node.name=id;node.collision_layer=1;node.collision_mask=0;node.set_meta("library_id",id);node.set_meta("surface","wood");node.set_meta("br_library",true);node.set_meta("footprint",Vector2(5,5) if willow else Vector2(3,3));node.set_meta("height_m",8.5 if willow else 12.)
	var rng:=RandomNumberGenerator.new();rng.seed=8142 if willow else 8127
	var height:=8.5 if willow else 12.
	var middle:=Vector3(.19,height*.40,.10);var top:=Vector3(-.12,height*.84,.05)
	cylinder(node,Vector3.ZERO,middle,.18);cylinder(node,middle,top,.11)
	for i in 10:
		var angle: float=i*2.39996
		var level: float=3.7+float(i)/10.*(height-4.7)
		var spread:=1.9 if willow else .85
		var p:=Vector3(cos(angle)*spread*rng.randf_range(.6,1.),level,sin(angle)*spread*rng.randf_range(.6,1.))
		cylinder(node,Vector3(0,level-.7,0),p,.035)
		cluster(node,p,Vector3(2.2,2.7,2.) if willow else Vector3(1.65,2.8,1.45),rng,i)
		core_cluster(node,p,(Vector3(2.2,2.7,2.) if willow else Vector3(1.65,2.8,1.45))*.70,rng,i)
	var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.20;shape.height=4.4;collision.shape=shape;collision.position.y=2.2;node.add_child(collision)
	var grouped: Dictionary={}
	for child in node.get_children():
		if not child is MeshInstance3D:continue
		var material: Material=child.material_override
		var key:=material.get_instance_id()
		if not grouped.has(key):var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);grouped[key]={"st":st,"material":material}
		grouped[key].st.append_from(child.mesh,0,child.transform)
	for child in node.get_children():
		if child is MeshInstance3D:child.free()
	var importer:=ImporterMesh.new()
	for record: Dictionary in grouped.values():
		var mesh: ArrayMesh=record.st.commit();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0),[],{},record.material)
	importer.generate_lods(60.,25.,[])
	var visual:=MeshInstance3D.new();visual.name="Geometry";visual.mesh=importer.get_mesh();visual.visibility_range_end=650.;node.add_child(visual)
	for child in node.get_children():child.owner=node
	var scene:=PackedScene.new();scene.pack(node);var result:=ResourceSaver.save(scene,DIR+id+".tscn")
	print("AFGHAN_TREE ",id," ",result);node.free()

