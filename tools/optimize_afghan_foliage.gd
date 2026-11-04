extends SceneTree
## Authoring conversion: identical static geometry and colliders, one colour
## material per vegetation mesh. Existing scenes are read, never overwritten.
const DIR:="res://modes/battle_royale/library/"
var materials: Dictionary={}
func _initialize() -> void:run.call_deferred()
func shared_material(double_sided: bool) -> StandardMaterial3D:
	if materials.has(double_sided):return materials[double_sided]
	var path:=DIR+"materials/foliage_%s_v7.tres"%("double" if double_sided else "solid")
	var material: StandardMaterial3D
	if ResourceLoader.exists(path):material=load(path)
	else:
		material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=1.
		material.cull_mode=BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
		ResourceSaver.save(material,path)
	materials[double_sided]=material;return material
func convert_mesh(source: Mesh) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset:=0
	var double_sided:=false
	for surface in source.get_surface_count():
		var material: StandardMaterial3D=source.surface_get_material(surface)
		assert(material.albedo_texture==null and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED)
		double_sided=double_sided or material.cull_mode==BaseMaterial3D.CULL_DISABLED
		var arrays:=source.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in vertices.size():
			st.set_normal(normals[i]);st.set_color((colors[i] if i<colors.size() else Color.WHITE)*material.albedo_color);st.add_vertex(vertices[i])
		if indices.is_empty():
			for i in vertices.size():st.add_index(offset+i)
		else:
			for i in indices:st.add_index(offset+i)
		offset+=vertices.size()
	var mesh:=st.commit();var importer:=ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0),[],{},shared_material(double_sided))
	importer.generate_lods(60.,25.,[])
	return importer.get_mesh()
func run() -> void:
	for pair in [["poplar_v6","poplar_v7"],["willow_v6","willow_v7"],["garden_shrub_v6","garden_shrub_v7"],["poplar_v4","poplar_far_v7"],["willow_v4","willow_far_v7"],["garden_shrub_v4","garden_shrub_far_v7"]]:
		var target: String=DIR+pair[1]+".tscn"
		if FileAccess.file_exists(target):print("PRESERVED ",target);continue
		var node: Node3D=load(DIR+pair[0]+".tscn").instantiate()
		var visual:=node.get_node("Geometry") as MeshInstance3D
		var before: Mesh=visual.mesh;visual.mesh=convert_mesh(before)
		assert(visual.mesh.get_surface_count()==1)
		node.name=pair[1];node.set_meta("library_id",pair[1])
		var packed:=PackedScene.new();packed.pack(node)
		var error:=ResourceSaver.save(packed,target)
		print("FOLIAGE_SINGLE_MATERIAL ",pair[1]," surfaces ",before.get_surface_count()," -> ",visual.mesh.get_surface_count()," save ",error)
		node.free()
	quit()
