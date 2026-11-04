extends "res://modes/battle_royale/library/build_context_v8.gd"
## New reusable assets; inherits the library's preserve-existing rule.
func run() -> void:
	prepare_materials()
	materials["weathered_rock_v8"]=load(DIR+"materials/weathered_rock_v8.tres")
	for entry in [["dry_leaf_v9",Color("87815b")],["chalk_v9",Color("a79e86")]]:
		var path: String=DIR+"materials/"+entry[0]+".tres"
		if not ResourceLoader.exists(path):
			var material:=StandardMaterial3D.new();material.albedo_color=entry[1];material.roughness=1.;material.vertex_color_use_as_albedo=true
			if entry[0]=="dry_leaf_v9":material.cull_mode=BaseMaterial3D.CULL_DISABLED
			ResourceSaver.save(material,path)
		materials[entry[0]]=load(path)
	var shelf:=context_root("stratified_shelf_v9",Vector2(20,9),6.5,"stone",true)
	for i in 6:
		var p:=Vector3((i-2.5)*3.1,-.55+(i%3)*.34,(i%2)*1.4)
		rock_form(shelf,p,Vector3(4.8+(i%3)*.7,4.2+(i%3)*.85,5.5),921+i,true)
		# Narrow overlapping ledges leave real crevices between the buttresses.
		rock_form(shelf,p+Vector3(.25,3.8,-.7),Vector3(4.4,.75,4.7),961+i)
	save_piece(shelf,"stratified_shelf_v9")
	var boulders:=context_root("wadi_boulders_v9",Vector2(7,5),1.3,"stone",true)
	for i in 4:
		rock_form(boulders,Vector3((i-1.5)*1.6,-.22,cos(i*2.4)*1.3),Vector3(1.6+(i%2)*.9,.75+(i%3)*.38,1.4+(i%2)*.7),982+i,true)
	save_piece(boulders,"wadi_boulders_v9")
	var plants:=context_root("wild_margin_v9",Vector2(6,5),.75,"grass")
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=919197
	for clump in 17:
		var p:=Vector3(sin(clump*2.4)*(.5+clump%4*.65),0,cos(clump*2.4)*(.5+clump%4*.5))
		for blade in 7:
			var angle:=rng.randf_range(-PI,PI);var height:=rng.randf_range(.22,.72)
			var side:=Vector3(cos(angle),0,sin(angle))*.04
			var bend:=Vector3(sin(angle),0,cos(angle))*height*.30
			var base:=p+Vector3(rng.randf_range(-.15,.15),0,rng.randf_range(-.15,.15))
			var middle:=base+Vector3.UP*height*.60+bend*.35
			var top:=base+Vector3.UP*height+bend
			st.set_color(Color.WHITE*rng.randf_range(.78,1.12))
			for v: Vector3 in [base-side,base+side,middle-side*.65,base+side,middle+side*.65,middle-side*.65,middle-side*.65,middle+side*.65,top]:st.add_vertex(v)
	st.generate_normals();st.index()
	var view:=MeshInstance3D.new();view.mesh=st.commit();view.material_override=materials.dry_leaf_v9;plants.add_child(view)
	save_piece(plants,"wild_margin_v9")
	print("AFGHAN_LANDSCAPE_LIBRARY ",JSON.stringify({"written":written,"preserved":skipped}));quit()
