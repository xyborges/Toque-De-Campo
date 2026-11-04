extends SceneTree
# Authoring tool only. Ordinary map generation never writes reusable scenes.
const DIR:="res://modes/battle_royale/library/"
var mats: Dictionary={}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for entry in [["adobe",Color(.60,.46,.31)],["stone",Color(.39,.36,.30)],["wood",Color(.25,.17,.10)],["cloth",Color(.44,.32,.23)],["dry",Color(.37,.34,.18)]]:
		var m:=StandardMaterial3D.new();m.albedo_color=entry[1];m.roughness=.96
		var texture_path:="res://assets/environment/materials/"+("plaster" if entry[0]=="adobe" else "concrete")+"-albedo.png"
		if ResourceLoader.exists(texture_path) and entry[0] in ["adobe","stone"]:
			m.albedo_texture=load(texture_path);m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*.35
		var material_path: String=DIR+"materials/"+entry[0]+".tres"
		ResourceSaver.save(m,material_path);mats[entry[0]]=load(material_path)
	house();wall();ruin();market();rock();shrub()
	print("BR_LIBRARY_GENERATED 6 reusable scenes");quit()
func root_for(id: String,surface: String) -> StaticBody3D:
	var n:=StaticBody3D.new();n.name=id;n.collision_layer=1;n.collision_mask=0
	n.set_meta("library_id",id);n.set_meta("surface",surface);n.set_meta("br_library",true)
	return n
func box(n: Node3D,p: Vector3,s: Vector3,mat: String,solid:=true) -> void:
	var v:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=s;v.mesh=mesh;v.material_override=mats[mat];v.position=p;n.add_child(v)
	if solid:
		var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=s;col.shape=shape;col.position=p;n.add_child(col)
func save_piece(n: Node3D,id: String) -> void:
	# Bake common material groups into one mesh; no per-building script runs.
	var groups: Dictionary={}
	for child in n.get_children():
		if child is MeshInstance3D:
			var key: String=child.material_override.resource_path
			if not groups.has(key): var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]=st
			groups[key].append_from(child.mesh,0,child.transform)
	for child in n.get_children():
		if child is MeshInstance3D: child.free()
	var merged:=ArrayMesh.new()
	for key in groups:
		var data: ArrayMesh=groups[key].commit();merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.surface_get_arrays(0));merged.surface_set_material(merged.get_surface_count()-1,load(key))
	var visual:=MeshInstance3D.new();visual.name="Geometry";visual.mesh=merged;visual.visibility_range_end=1100;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;n.add_child(visual)
	for child in n.get_children(): child.owner=n
	var packed:=PackedScene.new();packed.pack(n);ResourceSaver.save(packed,DIR+id+".tscn");n.free()
func house() -> void:
	var n:=root_for("adobe_house","stone")
	box(n,Vector3(0,.09,0),Vector3(10,.18,8),"stone")
	# South door 2.2 m clear, side windows cut into wall rather than painted.
	box(n,Vector3(-3.05,1.8,3.82),Vector3(3.9,3.6,.36),"adobe")
	box(n,Vector3(3.05,1.8,3.82),Vector3(3.9,3.6,.36),"adobe")
	box(n,Vector3(0,3.05,3.82),Vector3(2.2,1.1,.36),"adobe")
	box(n,Vector3(0,1.8,-3.82),Vector3(10,3.6,.36),"adobe")
	for side in [-1.,1.]:
		box(n,Vector3(side*4.82,.65,0),Vector3(.36,1.3,8),"adobe")
		box(n,Vector3(side*4.82,3.1,0),Vector3(.36,1.,8),"adobe")
		for z in [-2.65,2.65]:box(n,Vector3(side*4.82,1.95,z),Vector3(.36,1.3,2.7),"adobe")
	box(n,Vector3(0,3.65,0),Vector3(10.4,.24,8.4),"adobe")
	for x in [-4.25,-2.1,0.,2.1,4.25]:box(n,Vector3(x,3.42,0),Vector3(.15,.23,8.7),"wood",false)
	for x in [-4.95,4.95]:box(n,Vector3(x,4.,0),Vector3(.25,.5,8.4),"adobe")
	box(n,Vector3(0,4.,-4.),Vector3(10,.5,.25),"adobe")
	# Low 0.18 m steps, 0.35 m treads; climbable by shared step controller.
	for i in 21:box(n,Vector3(6.1,.09*(i+1),3.8-.35*i),Vector3(1.8,.18*(i+1),.36),"adobe")
	box(n,Vector3(5.25,3.69,-3.15),Vector3(1.3,.15,1.5),"wood")
	var loot:=Marker3D.new();loot.name="LootInterior";loot.position=Vector3(-2.6,.26,0);n.add_child(loot)
	var roof:=Marker3D.new();roof.name="LootRoof";roof.position=Vector3(1.8,3.87,-1.8);n.add_child(roof)
	save_piece(n,"adobe_house")
func wall() -> void:
	var n:=root_for("courtyard_wall","stone");box(n,Vector3(0,1.,0),Vector3(8,2.,.5),"adobe");box(n,Vector3(0,2.02,0),Vector3(8.15,.15,.58),"stone");save_piece(n,"courtyard_wall")
func ruin() -> void:
	var n:=root_for("stone_ruin","stone")
	box(n,Vector3(0,.08,0),Vector3(8,.16,6),"stone")
	box(n,Vector3(-3.8,1.1,0),Vector3(.5,2.2,6),"stone")
	box(n,Vector3(-1.7,1.65,-2.75),Vector3(4.5,3.3,.5),"stone")
	for i in 5:box(n,Vector3(.7+i*.5,.85-i*.13,-2.75),Vector3(.55,1.7-i*.26,.5),"stone")
	box(n,Vector3(-2.4,2.6,-1.3),Vector3(.18,.22,3.5),"wood",false);save_piece(n,"stone_ruin")
func market() -> void:
	var n:=root_for("market_stall","wood")
	for x in [-2.,2.]:
		for z in [-1.5,1.5]:box(n,Vector3(x,1.6,z),Vector3(.14,3.2,.14),"wood")
	box(n,Vector3(0,3.2,0),Vector3(4.5,.12,3.7),"cloth",false)
	box(n,Vector3(0,.85,0),Vector3(3.7,.12,1.),"wood");save_piece(n,"market_stall")
func rock() -> void:
	var n:=root_for("rock_outcrop","stone")
	var v:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radial_segments=9;mesh.rings=4;mesh.radius=1.;mesh.height=2.;v.mesh=mesh;v.material_override=mats.stone;v.scale=Vector3(2.5,1.8,2.);v.position=Vector3(0,.8,0);n.add_child(v)
	var col:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=1.8;col.shape=shape;col.position=Vector3(0,.5,0);n.add_child(col);save_piece(n,"rock_outcrop")
func shrub() -> void:
	var n:=root_for("dry_shrub","grass");n.collision_layer=0
	for i in 6:
		var theta:=i*PI/3.;var p:=Vector3(cos(theta)*.2,.3,sin(theta)*.2)
		box(n,p,Vector3(.08,.65,.08),"dry",false)
	save_piece(n,"dry_shrub")
