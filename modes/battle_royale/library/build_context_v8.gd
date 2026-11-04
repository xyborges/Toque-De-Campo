extends "res://modes/battle_royale/library/build_library_v2.gd"
## Authoring only: reusable pieces; an existing scene is always preserved.
func run() -> void:
	prepare_materials()
	for item in [["weathered_rock_v8",Color("b6aa91")],["dry_growth_v8",Color("8a8058")],["rust_v8",Color("574d40")]]:
		var path: String=DIR+"materials/"+item[0]+".tres"
		if not ResourceLoader.exists(path):
			var mat:=StandardMaterial3D.new();mat.albedo_color=item[1];mat.vertex_color_use_as_albedo=true;mat.roughness=1.
			if item[0]=="weathered_rock_v8":mat.albedo_texture=load("res://assets/environment/materials/rock-albedo.png");mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*.19
			ResourceSaver.save(mat,path)
		materials[item[0]]=load(path)
	cliff();talus();scrub();work_corner();broken_wall();furrows()
	print("AFGHAN_CONTEXT_LIBRARY ",JSON.stringify({"written":written,"preserved":skipped}));quit()
func context_root(id: String,foot: Vector2,height: float,surface: String,solid:=false) -> Node3D:
	var n: Node3D=StaticBody3D.new() if solid else Node3D.new();n.name=id
	if solid:n.collision_layer=1;n.collision_mask=0
	n.set_meta("library_id",id);n.set_meta("surface",surface);n.set_meta("br_library",true);n.set_meta("footprint",foot);n.set_meta("height_m",height);n.set_meta("decorative",not solid)
	return n
func rock_form(n: Node3D,p: Vector3,size: Vector3,seed_value: int,solid:=false) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var points:=PackedVector3Array()
	for layer in 4:
		for side in 7:
			var angle: float=side*TAU/7.
			var width: float=[.48,.55,.46,.26][layer]*rng.randf_range(.83,1.15)
			points.append(p+Vector3(cos(angle)*width*size.x+(layer%2)*size.x*.06,(layer/3.-.03)*size.y,sin(angle)*width*size.z+(layer%2)*size.z*.08))
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 3:
		for side in 7:
			var a:=layer*7+side;var b:=layer*7+(side+1)%7
			st.set_color(Color.WHITE*rng.randf_range(.78,1.08))
			rock_face(st,points[a],points[a+7],points[b],p+Vector3.UP*size.y*.5)
			rock_face(st,points[b],points[a+7],points[b+7],p+Vector3.UP*size.y*.5)
	for i in range(1,6):
		st.set_color(Color(.88,.88,.88))
		rock_face(st,points[0],points[i],points[i+1],p+Vector3.UP*size.y*.5)
		rock_face(st,points[21],points[22+i],points[21+i],p+Vector3.UP*size.y*.5)
	st.generate_normals();st.index()
	var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=materials.weathered_rock_v8;n.add_child(mesh)
	if solid:
		var shape:=ConvexPolygonShape3D.new();shape.points=points
		var collider:=CollisionShape3D.new();collider.shape=shape;n.add_child(collider)
func rock_face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,centre: Vector3) -> void:
	# Plane uses Godot's clockwise front faces. Orient every facet outward,
	# including the cap, so opaque rocks never look like hollow shells.
	var outward: Vector3=(a+b+c)/3.-centre
	if Plane(a,b,c).normal.dot(outward)<0.:
		st.add_vertex(a);st.add_vertex(c);st.add_vertex(b)
	else:
		st.add_vertex(a);st.add_vertex(b);st.add_vertex(c)
func cliff() -> void:
	var n:=context_root("cliff_buttress_v8",Vector2(10,5),9.,"stone",true)
	rock_form(n,Vector3.ZERO,Vector3(9,8.7,4.8),81,true)
	rock_form(n,Vector3(-2.3,-.3,1.4),Vector3(4.2,3.1,3.5),82,true)
	rock_form(n,Vector3(3.2,-.2,.8),Vector3(3.,4.7,2.8),83,true)
	save_piece(n,"cliff_buttress_v8")
func talus() -> void:
	var n:=context_root("talus_fan_v8",Vector2(11,8),.28,"stone")
	for i in 19:
		var p:=Vector3(sin(i*2.4)*(.6+(i%6)*.75),-.035,cos(i*2.4)*(.5+(i%5)*.8))
		rock_form(n,p,Vector3(.28+(i%4)*.13,.10+(i%3)*.055,.3+(i%4)*.1),810+i)
	save_piece(n,"talus_fan_v8")
func scrub() -> void:
	var n:=context_root("dry_scrub_patch_v8",Vector2(5,4),.8,"grass")
	for i in 9:
		var p:=Vector3(sin(i*2.4)*(i%3)*.7,0,cos(i*2.4)*(i%3)*.7)
		var h:=.25+(i%4)*.14
		cylinder(n,p+Vector3.UP*h*.5,.016,h,"dry_growth_v8",false,Vector3(.1*sin(i),0,.15*cos(i)),.007)
		for side in [-1,1]:
			box(n,p+Vector3(side*.11,h*.67,0),Vector3(.02,h*.65,.025),"dry_growth_v8",false,Vector3(.2,0,side*.55))
			for axis in 2:box(n,p+Vector3(side*.17,h*.78,axis*.08-.04),Vector3(.16,.025,.055),"dry_growth_v8",false,Vector3(.1,i*.8,side*.2))
	save_piece(n,"dry_scrub_patch_v8")
func work_corner() -> void:
	var n:=context_root("farm_work_corner_v8",Vector2(4.5,3.2),1.8,"wood",true)
	box(n,Vector3(-1.,.45,0),Vector3(1.2,.9,.85),"wood")
	for y in [.2,.65]:box(n,Vector3(-1.,y,.45),Vector3(1.25,.08,.065),"reed",false)
	for i in 5:box(n,Vector3(.3,.08+i*.065,-.6),Vector3(2.2,.065,.17),"wood",false,Vector3(0,.08*i,0))
	# Barrels have their own surface metadata for impact sounds/material hits.
	var barrel_body:=StaticBody3D.new();barrel_body.name="Metal";barrel_body.collision_layer=1;barrel_body.collision_mask=0;barrel_body.set_meta("surface","metal");n.add_child(barrel_body)
	for x in [.2,1.1]:
		cylinder(n,Vector3(x,.49,.5),.32,.98,"rust_v8")
		var collider:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.32;shape.height=.98;collider.shape=shape;collider.position=Vector3(x,.49,.5);barrel_body.add_child(collider)
		for y in [.10,.85]:cylinder(n,Vector3(x,y,.5),.335,.04,"dark")
	for i in 2:
		box(n,Vector3(-1.5+i*.3,.8,-.75),Vector3(.045,1.65,.045),"wood",false,Vector3(.12,0,.2))
		box(n,Vector3(-1.65+i*.3,1.53,-.82),Vector3(.3,.08,.18),"rust_v8",false)
	marker(n,"LootStorage",Vector3(-1.,.94,0))
	save_piece(n,"farm_work_corner_v8")
func broken_wall() -> void:
	var n:=context_root("collapsed_farm_wall_v8",Vector2(7,3),1.5,"stone",true)
	for i in 7:
		var h:=1.35 if i<2 else (.8 if i<4 else .38)
		box(n,Vector3(-3.+i,.5*h,0),Vector3(.96,h,.5),"stone",i<4,Vector3(0,0,.035*sin(i*2.4)))
	for i in 12:rock_form(n,Vector3(sin(i*2.4)*2.8,-.05,cos(i*2.4)*.9),Vector3(.4,.13+(i%3)*.06,.34),920+i)
	save_piece(n,"collapsed_farm_wall_v8")
func furrows() -> void:
	var n:=context_root("field_furrows_v8",Vector2(8,8),.16,"dirt")
	for i in 6:
		var x: float=(i-2.5)*1.25
		box(n,Vector3(x,.045,0),Vector3(.25,.09,7.6),"dry_growth_v8",false,Vector3(0,0,.06*sin(i*2.4)))
		for side in [-1,1]:box(n,Vector3(x+side*.17,.025,0),Vector3(.19,.07,7.6),"dry_growth_v8",false,Vector3(0,0,side*.25))
	save_piece(n,"field_furrows_v8")
