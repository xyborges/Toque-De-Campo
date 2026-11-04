extends SceneTree
# Explicit authoring command. Never writes an existing user-authored asset.
const DIR:="res://modes/battle_royale/library/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for kind in ["pebble_patch_v3","dry_cluster_v3","crop_patch_v3","cliff_slab_v3"]:
		if FileAccess.file_exists(DIR+kind+".tscn"): continue
		var root_node:=Node3D.new();root_node.name=kind;root_node.set_meta("library_id",kind);root_node.set_meta("surface","stone" if "pebble" in kind or "cliff" in kind else "grass")
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng:=RandomNumberGenerator.new();rng.seed=712907+kind.hash()
		if kind in ["pebble_patch_v3","cliff_slab_v3"]:
			var count:=7 if "pebble" in kind else 1
			for i in count:
				var radius:=rng.randf_range(.06,.2) if count>1 else 1.
				var offset:=Vector3(rng.randf_range(-.6,.6),-.03,rng.randf_range(-.6,.6)) if count>1 else Vector3.ZERO
				var points: Array[Vector3]=[]
				for layer in 5:
					var y:=layer*.44
					for side in 8:
						var a:=side*TAU/8.
						var r:=radius*(rng.randf_range(.8,1.1))*(1.-layer*.13)
						points.append(offset+Vector3(cos(a)*r,y*radius,sin(a)*r*.66))
				for layer in 4:
					for side in 8:
						var a:=layer*8+side;var b:=layer*8+(side+1)%8
						for index in [a,a+8,b,b,a+8,b+8]:
							st.set_uv(Vector2(points[index].x,points[index].y));st.add_vertex(points[index])
		else:
			var count:=9 if "dry" in kind else 22
			for i in count:
				var p:=Vector3(rng.randf_range(-.7,.7),0,rng.randf_range(-.7,.7))
				var height:=rng.randf_range(.12,.36);var side:=Vector3(cos(i*2.4),0,sin(i*2.4))*.024
				for v in [p-side,p+side,p+Vector3(.05,height,.02),p+Vector3(.05,height,.02),p+side,p-side]: st.add_vertex(v)
		st.generate_normals();st.index()
		var mesh:=MeshInstance3D.new();mesh.name="Geometry";mesh.mesh=st.commit();mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.visibility_range_end=65 if "crop" in kind else 150
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("a39b78") if "crop" in kind else (Color("756c4b") if "dry" in kind else Color("81796a"));mat.vertex_color_use_as_albedo=true;mat.roughness=1.
		if "cliff" in kind:
			mat.albedo_texture=load("res://assets/environment/materials/rock-albedo.png");mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*.25
		mesh.material_override=mat;root_node.add_child(mesh);mesh.owner=root_node
		var packed:=PackedScene.new();packed.pack(root_node);ResourceSaver.save(packed,DIR+kind+".tscn");root_node.free()
	print("AFGHAN_ENVIRONMENT_LIBRARY_READY");quit()
