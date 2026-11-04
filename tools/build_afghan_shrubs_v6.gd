extends SceneTree
const DIR:="res://modes/battle_royale/library/"
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for version in [6]:
		var id:="garden_shrub_v%d"%version
		if FileAccess.file_exists(DIR+id+".tscn"):continue
		var tree: Node3D=load(DIR+"willow_v%d.tscn"%version).instantiate()
		var source: Mesh=tree.get_node("Geometry").mesh
		var importer:=ImporterMesh.new()
		for surface in source.get_surface_count():
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.append_from(source,surface,Transform3D(Basis.from_scale(Vector3(.5,.18,.5)),Vector3.ZERO))
			var data:=st.commit();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,data.surface_get_arrays(0),[],{},source.surface_get_material(surface))
		importer.generate_lods(60.,25.,[])
		var root_node:=Node3D.new();root_node.name=id;root_node.set_meta("library_id",id);root_node.set_meta("surface","grass");root_node.set_meta("decorative",true);root_node.set_meta("footprint",Vector2(2.5,2.5))
		var visual:=MeshInstance3D.new();visual.name="Geometry";visual.mesh=importer.get_mesh();visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root_node.add_child(visual);visual.owner=root_node
		var packed:=PackedScene.new();packed.pack(root_node);var error:=ResourceSaver.save(packed,DIR+id+".tscn");print("SHRUB ",id," ",error)
		tree.free();root_node.free()
	quit()

