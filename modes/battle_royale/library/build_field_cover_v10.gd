extends "res://modes/battle_royale/library/build_library_v2.gd"
## Explicit authoring only. Existing, potentially edited scenes are preserved.
func run() -> void:
	prepare_materials()
	var leaf_path:=DIR+"materials/tamarisk_v10.tres"
	if not ResourceLoader.exists(leaf_path):
		var leaf:=StandardMaterial3D.new();leaf.albedo_color=Color(.24,.30,.17);leaf.vertex_color_use_as_albedo=true;leaf.roughness=1.;leaf.cull_mode=BaseMaterial3D.CULL_DISABLED;ResourceSaver.save(leaf,leaf_path)
	materials["tamarisk"]=load(leaf_path)
	bank();broken_wall();tamarisk(false);tamarisk(true)
	for id: String in written:install_lod(id)
	print("AFGHAN_FIELD_LIBRARY ",JSON.stringify({"written":written,"preserved":skipped}));quit()

func piece(id: String,footprint: Vector2,height: float,solid: bool) -> Node3D:
	var n: Node3D=StaticBody3D.new() if solid else Node3D.new();n.name=id
	if solid:n.collision_layer=1;n.collision_mask=0
	n.set_meta("library_id",id);n.set_meta("br_library",true);n.set_meta("surface","dirt" if "bank" in id else ("grass" if "tamarisk" in id else "stone"))
	n.set_meta("footprint",footprint);n.set_meta("height_m",height);n.set_meta("decorative",not solid)
	n.set_meta("collision_persistent",solid);n.set_meta("resistance","earthwork" if solid else "foliage")
	n.set_meta("lod_profile","physical_cover" if solid else "foliage_geometry")
	n.set_meta("lod_near_end",3000. if solid else 150.);n.set_meta("lod_far_end",3000.);n.set_meta("individual_shadows",false)
	marker(n,"GroundAnchor",Vector3.ZERO)
	return n

func install_lod(id: String) -> void:
	var n: Node3D=load(DIR+id+".tscn").instantiate();var geometry: MeshInstance3D=n.get_node("Geometry")
	geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.visibility_range_end=150. if id=="tamarisk_v10" else 3000.
	if id=="tamarisk_v10":
		var source: Node3D=load(DIR+"tamarisk_far_v10.tscn").instantiate()
		var holder:=Node3D.new();holder.name="DistanceLOD";n.add_child(holder)
		var far:=MeshInstance3D.new();far.name="FarGeometry";far.mesh=source.get_node("Geometry").mesh;far.visibility_range_begin=150.;far.visibility_range_end=3000.;far.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;holder.add_child(far);source.free()
	set_owners(n,n);var packed:=PackedScene.new();packed.pack(n);ResourceSaver.save(packed,DIR+id+".tscn");n.free()

func bank() -> void:
	var n:=piece("field_bank_v10",Vector2(8.4,2.8),1.35,true)
	# A field's retained earth bank, with sloping shoulders and a broad crest.
	var points:=PackedVector3Array([Vector3(-4.2,-.22,-1.4),Vector3(4.2,-.22,-1.4),Vector3(4.2,-.22,1.4),Vector3(-4.2,-.22,1.4),Vector3(-3.65,1.12,-.48),Vector3(3.35,1.35,-.43),Vector3(3.35,1.35,.43),Vector3(-3.65,1.12,.48)])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in [[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7],[4,5,6,7],[3,2,1,0]]:
		for index in [0,1,2,0,2,3]:
			var p: Vector3=points[face[index]];st.set_uv(Vector2(p.x,p.y+p.z));st.set_color(Color(.84,.80,.70));st.add_vertex(p)
	st.generate_normals();st.index()
	var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=materials.adobe;n.add_child(mesh)
	var shape:=ConvexPolygonShape3D.new();shape.points=points
	var collider:=CollisionShape3D.new();collider.shape=shape;n.add_child(collider)
	sockets(n,Vector3(-4.2,0,0),Vector3(4.2,0,0),"rural_bank",2.8,true)
	save_piece(n,"field_bank_v10")

func broken_wall() -> void:
	var n:=piece("field_wall_v10",Vector2(6.8,1.4),1.65,true)
	for i in 6:
		var height: float=[.95,1.45,1.65,1.34,.77,1.12][i]
		box(n,Vector3(-2.75+i*1.1,height*.5-.13,0),Vector3(1.12,height,.68),"adobe")
	for i in 3:box(n,Vector3(-2.8+i*2.7,.08,.56),Vector3(.7,.40,.65),"adobe",false,Vector3(.08,0,.13*(i-1)))
	sockets(n,Vector3(-3.35,0,0),Vector3(3.35,0,0),"rural_wall",.68,true)
	save_piece(n,"field_wall_v10")

func tamarisk(far: bool) -> void:
	var id: String="tamarisk_far_v10" if far else "tamarisk_v10"
	var n:=piece(id,Vector2(3.6,3.2),2.15,false)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in (5 if far else 9):
		var angle: float=i*2.399;var height: float=1.1+(i%4)*.26
		var end:=Vector3(cos(angle)*(.75+(i%3)*.25),height,sin(angle)*(.75+(i%3)*.25))
		if not far:cylinder(n,end*.40,.022,height*.75,"bark",false,Vector3(.40*cos(angle),0,-.40*sin(angle)),.008)
		for j in (3 if far else 5):
			var centre:=end*(.28+j*(.20 if far else .135))
			var turn:=angle+j*1.91;var across:=Vector3(cos(turn),.12,sin(turn))*(.40 if far else .32)
			var tip:=centre+end.normalized()*(.45 if far else .36)
			for side in [-1.,1.]:
				st.set_color(Color(.79+(j%3)*.075,.88+(i%3)*.035,.74))
				for v in [centre-across*.12,centre+across*side,tip]:st.add_vertex(v)
	st.generate_normals();st.index()
	var visual:=MeshInstance3D.new();visual.mesh=st.commit();visual.material_override=materials.tamarisk;n.add_child(visual)
	save_piece(n,id)
