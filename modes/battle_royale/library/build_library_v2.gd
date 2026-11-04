extends SceneTree
## Explicit authoring tool. New v2 paths only; never overwrites existing assets.
const DIR:="res://modes/battle_royale/library/"
var materials: Dictionary={}
var written: Array[String]=[]
var skipped: Array[String]=[]

func _initialize() -> void: run.call_deferred()
func run() -> void:
	prepare_materials()
	house();terrace();store();qala();ruin()
	wall();bridge();tree(false);tree(true);crate();well();woodpile();clothesline();haystack()
	print("AFGHAN_LIBRARY_V2 ",JSON.stringify({"written":written,"preserved_existing":skipped}));quit()

func prepare_materials() -> void:
	var entries:={"adobe":Color(.71,.61,.47),"stone":Color(.55,.53,.46),"wood":Color(.29,.22,.15),"dark":Color(.14,.12,.09),"reed":Color(.58,.51,.32),"cloth":Color(.41,.35,.29),"leaves":Color(.32,.39,.22),"bark":Color(.34,.30,.23)}
	for id: String in entries:
		var path:=DIR+"materials/"+id+"_v2.tres"
		if ResourceLoader.exists(path): materials[id]=load(path);continue
		var mat:=StandardMaterial3D.new();mat.albedo_color=entries[id];mat.roughness=.96;mat.vertex_color_use_as_albedo=true
		if id in ["adobe","stone"]:
			var texture_path:="res://assets/environment/materials/"+("plaster" if id=="adobe" else "concrete")+"-albedo.png"
			mat.albedo_texture=load(texture_path);mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*.28
		ResourceSaver.save(mat,path);materials[id]=load(path)

func root_for(id: String,footprint: Vector2,height: float,surface:="stone") -> StaticBody3D:
	var n:=StaticBody3D.new();n.name=id;n.collision_layer=1;n.collision_mask=0
	n.set_meta("library_id",id);n.set_meta("surface",surface);n.set_meta("br_library",true)
	n.set_meta("footprint",footprint);n.set_meta("building_height",height);n.set_meta("loot_kind","building")
	marker(n,"GroundAnchor",Vector3.ZERO)
	marker(n,"FoundationTop",Vector3(0,.18,0))
	return n

func marker(n: Node3D,label: String,p: Vector3) -> void:
	var point:=Marker3D.new();point.name=label;point.position=p;n.add_child(point)

func sockets(n: Node3D,a: Vector3,b: Vector3,profile: String,width: float,axis_x:=false) -> void:
	var holder:=Node3D.new();holder.name="Encaixes";n.add_child(holder)
	for i in 2:
		var point:=Marker3D.new();point.name="Entrada" if i==0 else "Saida";point.position=a if i==0 else b
		point.rotation.y=(-PI*.5 if i==0 else PI*.5) if axis_x else (0. if i==0 else PI)
		point.set_meta("profile",profile);point.set_meta("width",width);holder.add_child(point)

func box(n: Node3D,p: Vector3,s: Vector3,mat: String,solid:=true,rotation:=Vector3.ZERO) -> void:
	var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=s
	visual.mesh=mesh;visual.material_override=materials[mat];visual.position=p;visual.rotation=rotation;n.add_child(visual)
	if solid:
		var shape:=BoxShape3D.new();shape.size=s
		var collider:=CollisionShape3D.new();collider.shape=shape;collider.position=p;collider.rotation=rotation;n.add_child(collider)

func cylinder(n: Node3D,p: Vector3,radius: float,height: float,mat: String,solid:=false,rotation:=Vector3.ZERO,top:=-1.0) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius if top<0 else top;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=10;mesh.rings=1
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=materials[mat];visual.position=p;visual.rotation=rotation;n.add_child(visual)
	if solid:
		var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=height
		var collider:=CollisionShape3D.new();collider.shape=shape;collider.position=p;collider.rotation=rotation;n.add_child(collider)

func sphere(n: Node3D,p: Vector3,size: Vector3,mat: String) -> void:
	var mesh:=SphereMesh.new();mesh.radius=.5;mesh.height=1.;mesh.radial_segments=10;mesh.rings=5
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.scale=size;visual.position=p;visual.material_override=materials[mat];n.add_child(visual)

func room(n: Node3D,origin: Vector3,w: float,d: float,h:=3.1,mat:="adobe",door:=1.5,roof:=true,gap_side:=1,gap_z:=-2.58) -> void:
	box(n,origin+Vector3(0,.09,0),Vector3(w,.18,d),"stone")
	# Thick front wall with an actual 2.3 m high doorway.
	var segment: float=(w-door)*.5
	for side in [-1.,1.]: box(n,origin+Vector3(side*(door*.5+segment*.5),h*.5,d*.5-.23),Vector3(segment,h,.46),mat)
	box(n,origin+Vector3(0,(h+2.45)*.5,d*.5-.23),Vector3(door,h-2.45,.46),mat)
	box(n,origin+Vector3(0,h*.5,-d*.5+.23),Vector3(w,h,.46),mat)
	for side in [-1.,1.]:
		var x: float=side*(w*.5-.23)
		box(n,origin+Vector3(x,.62,0),Vector3(.46,1.24,d),mat)
		box(n,origin+Vector3(x,(2.26+h)*.5,0),Vector3(.46,h-2.26,d),mat)
		for sign_z in [-1.,1.]: box(n,origin+Vector3(x,1.75,sign_z*(d+1.25)*.25),Vector3(.46,1.02,(d-1.25)*.5),mat)
		# Recessed timber bars sit inside the opening, not on the facade.
		for z in [-.40,0.,.40]: box(n,origin+Vector3(x,1.74,z),Vector3(.055,1.05,.045),"wood",false)
		box(n,origin+Vector3(x,1.22,0),Vector3(.6,.11,1.4),"wood",false)
	# Open wooden leaf folds against the inside wall and does not obstruct entry.
	box(n,origin+Vector3(door*.5+.10,1.14,d*.5-1.0),Vector3(.10,2.22,1.30),"wood",false)
	for x in range(-floori(w*.5)+1,floori(w*.5),2): box(n,origin+Vector3(x,h-.14,0),Vector3(.13,.21,d+.28),"wood",false)
	if roof:
		box(n,origin+Vector3(0,h+.10,0),Vector3(w+.2,.20,d+.2),mat)
		for side in [-1.,1.]:
			if int(side)!=gap_side: box(n,origin+Vector3(side*(w*.5),h+.38,0),Vector3(.24,.38,d+.25),mat);continue
			var start: float=-d*.5-.125;var finish: float=d*.5+.125
			var low:=clampf(gap_z-.85,start,finish);var high:=clampf(gap_z+.85,start,finish)
			if low-start>.02: box(n,origin+Vector3(side*w*.5,h+.38,(start+low)*.5),Vector3(.24,.38,low-start),mat)
			if finish-high>.02: box(n,origin+Vector3(side*w*.5,h+.38,(finish+high)*.5),Vector3(.24,.38,finish-high),mat)
		box(n,origin+Vector3(0,h+.38,-d*.5),Vector3(w,.38,.24),mat)

func steps(n: Node3D,x: float,z_start: float,y_base: float,count: int,reverse:=false,width:=1.65) -> void:
	for i in count:
		var height: float=.18*(i+1)
		var total:=y_base+height
		box(n,Vector3(x,total*.5,z_start+(1. if reverse else -1.)*i*.34),Vector3(width,total,.35),"adobe")

func house() -> void:
	var n:=root_for("adobe_house_v2",Vector2(13,8),3.65)
	room(n,Vector3.ZERO,9.,7.)
	steps(n,5.45,3.2,0.,18)
	box(n,Vector3(4.7,3.24,-2.58),Vector3(1.55,.14,1.3),"wood")
	marker(n,"Door",Vector3(0,.2,3.7));marker(n,"LootInterior",Vector3(-2.45,.21,-1.5));marker(n,"LootRoof",Vector3(1.3,3.35,-1.4))
	marker(n,"Entrance",Vector3(0,.2,3.8))
	marker(n,"StairFoot",Vector3(5.45,.03,3.65));marker(n,"StairTurn",Vector3(5.45,3.27,-2.58));marker(n,"StairLanding",Vector3(3.9,3.33,-2.58))
	# Built-in ledge, sleeping mat and storage: visual decoration only.
	box(n,Vector3(-3.8,.36,-1.6),Vector3(.65,.55,2.2),"adobe")
	box(n,Vector3(2.6,.19,-1.25),Vector3(1.4,.04,2.0),"cloth",false)
	save_piece(n,"adobe_house_v2")

func terrace() -> void:
	var n:=root_for("terrace_house_v2",Vector2(15,12),6.9)
	room(n,Vector3.ZERO,10.,8.)
	room(n,Vector3(-1.25,3.3,-.5),6.5,6.,3.0,"adobe",1.5,true,-1,2.5)
	steps(n,5.9,3.9,0.,19)
	box(n,Vector3(4.75,3.37,-2.6),Vector3(2.8,.15,1.65),"wood")
	steps(n,-6.0,-3.8,3.3,18,true)
	box(n,Vector3(-5.35,3.28,-3.8),Vector3(1.6,.15,1.1),"wood")
	box(n,Vector3(-4.75,6.54,2.0),Vector3(2.0,.15,1.5),"wood")
	marker(n,"Door",Vector3(0,.2,4.2));marker(n,"LootInterior",Vector3(-3,.21,-2.));marker(n,"LootUpper",Vector3(-2.4,3.51,-1.4));marker(n,"LootRoof",Vector3(-1.1,6.55,-1.))
	marker(n,"Entrance",Vector3(0,.2,4.3))
	marker(n,"StairFoot",Vector3(5.9,.03,4.3));marker(n,"StairTurn",Vector3(5.9,3.45,-2.22));marker(n,"StairLanding",Vector3(4.3,3.48,-2.22))
	marker(n,"UpperStairFoot",Vector3(-6.0,3.4,-4.1));marker(n,"UpperStairTurn",Vector3(-6.0,6.57,1.98));marker(n,"UpperStairLanding",Vector3(-3.5,6.6,1.98))
	save_piece(n,"terrace_house_v2")

func store() -> void:
	var n:=root_for("farm_store_v2",Vector2(16.0,11.0),3.65)
	room(n,Vector3.ZERO,12.,7.,3.1,"stone",2.5)
	for x in [-5.0,5.0]:
		cylinder(n,Vector3(x,1.4,5.0),.10,2.8,"wood")
	box(n,Vector3(0,2.82,4.5),Vector3(11,.12,3.4),"reed",false)
	for z in [-2.,-.7,.6]:
		box(n,Vector3(-4.8,.7,z),Vector3(1.35,1.1,.8),"wood")
		for y in [.38,.75,1.12]:box(n,Vector3(4.5,y,z),Vector3(2.,.08,.6),"wood",false)
	marker(n,"Door",Vector3(0,.2,3.7));marker(n,"LootInterior",Vector3(0,.21,-1.4));marker(n,"LootStorage",Vector3(-3.7,.21,-2.));marker(n,"LootRoof",Vector3(2,3.35,-1.5))
	marker(n,"Entrance",Vector3(0,.2,5.2))
	steps(n,7.0,3.1,0.,18)
	box(n,Vector3(6.2,3.24,-2.68),Vector3(2.,.14,1.3),"wood")
	marker(n,"StairFoot",Vector3(7.0,.03,3.55));marker(n,"StairTurn",Vector3(7.0,3.27,-2.68));marker(n,"StairLanding",Vector3(5.3,3.33,-2.68))
	save_piece(n,"farm_store_v2")

func qala() -> void:
	var n:=root_for("qala_compound_v2",Vector2(18,17),4.9)
	room(n,Vector3(0,0,-5.1),10.0,4.,3.1,"adobe",1.5,true,1,-.28)
	for side in [-1.,1.]:
		box(n,Vector3(side*7.4,1.35,0),Vector3(.65,2.7,15.),"adobe")
		box(n,Vector3(side*4.5,1.35,7.2),Vector3(6.,2.7,.65),"adobe")
		for z in [-7.1,7.1]:
			box(n,Vector3(side*7.4,2.1,z),Vector3(1.65,4.2,1.65),"adobe")
			box(n,Vector3(side*7.4,4.35,z),Vector3(1.95,.3,1.95),"stone")
			for dx in [-.7,.7]:box(n,Vector3(side*7.4+dx,4.72,z),Vector3(.35,.55,1.95),"adobe")
	box(n,Vector3(0,1.35,-7.3),Vector3(15.4,2.7,.65),"adobe")
	box(n,Vector3(0,2.75,7.2),Vector3(3.,.4,.70),"wood")
	steps(n,6.1,.4,0.,18)
	box(n,Vector3(5.25,3.24,-5.5),Vector3(1.6,.14,1.5),"wood")
	box(n,Vector3(-5.,.18,2.0),Vector3(3.,.2,2.),"stone")
	marker(n,"Door",Vector3(0,.2,7.7));marker(n,"LootInterior",Vector3(-2.7,.21,-5.3));marker(n,"LootCourtyard",Vector3(-4.4,.32,2.));marker(n,"LootRoof",Vector3(1.4,3.35,-5.1))
	marker(n,"Entrance",Vector3(0,.2,7.8))
	marker(n,"StairFoot",Vector3(6.1,.03,.85));marker(n,"StairTurn",Vector3(6.1,3.27,-5.38));marker(n,"StairLanding",Vector3(4.4,3.33,-5.38))
	save_piece(n,"qala_compound_v2")

func ruin() -> void:
	var n:=root_for("stone_ruin_v2",Vector2(10,8),3.3)
	box(n,Vector3(0,.09,0),Vector3(9,.18,7),"stone")
	box(n,Vector3(-4.25,1.55,-.5),Vector3(.5,3.1,6),"stone")
	box(n,Vector3(-1.6,1.5,-3.25),Vector3(5.7,3.,.5),"stone")
	for i in 6:
		box(n,Vector3(1.4+i*.5,1.1-i*.12,-3.25),Vector3(.55,2.2-i*.24,.5),"adobe")
	for i in 7:
		box(n,Vector3(-3.3+i*.9,.18+(i%2)*.12,1.2+sin(i*2.)*.8),Vector3(.75,.32,.6),"stone",false,Vector3(.1,i*.8,-.1))
	box(n,Vector3(-2.2,2.95,-1.2),Vector3(.18,.20,4.3),"wood",false,Vector3(.1,0,.08))
	marker(n,"Door",Vector3(0,.2,3.8));marker(n,"LootInterior",Vector3(-2.,.22,-1.5))
	marker(n,"Entrance",Vector3(0,.2,3.9))
	save_piece(n,"stone_ruin_v2")

func wall() -> void:
	var n:=root_for("courtyard_wall_v2",Vector2(6,.6),2.1)
	box(n,Vector3(0,.95,0),Vector3(6,1.9,.5),"adobe");box(n,Vector3(0,1.98,0),Vector3(6.08,.16,.58),"stone")
	marker(n,"SnapA",Vector3(-3,0,0));marker(n,"SnapB",Vector3(3,0,0));sockets(n,Vector3(-3,0,0),Vector3(3,0,0),"afghan_wall",.5,true);save_piece(n,"courtyard_wall_v2")

func bridge() -> void:
	var n:=root_for("rural_bridge_v2",Vector2(3.5,10),1.4,"wood")
	box(n,Vector3(0,.19,0),Vector3(3.2,.20,10),"wood")
	for side in [-1.,1.]:
		for z in [-4.4,0.,4.4]:box(n,Vector3(side*1.5,.73,z),Vector3(.12,1.15,.12),"wood")
		box(n,Vector3(side*1.5,1.16,0),Vector3(.10,.10,9.4),"wood")
	for z in [-4.4,4.4]:box(n,Vector3(0,-.25,z),Vector3(3.8,.7,1.),"stone")
	marker(n,"SnapA",Vector3(0,.29,-5.));marker(n,"SnapB",Vector3(0,.29,5.));sockets(n,Vector3(0,.29,-5.),Vector3(0,.29,5.),"afghan_bridge",3.2);save_piece(n,"rural_bridge_v2")

func tree(willow: bool) -> void:
	var id:="willow_v2" if willow else "poplar_v2"
	var n:=root_for(id,Vector2(6,6) if willow else Vector2(3,3),8.0 if willow else 12.0,"wood")
	n.set_meta("loot_kind","")
	cylinder(n,Vector3(0,2.2,0),.20 if willow else .16,4.4,"bark",true,Vector3.ZERO,.1)
	if willow:
		for i in 5:
			var a: float=i*TAU/5.;var p:=Vector3(cos(a)*1.55,4.8,sin(a)*1.55)
			sphere(n,p,Vector3(3.1,4.5,2.6),"leaves")
			cylinder(n,Vector3(cos(a)*.6,3.3,sin(a)*.6),.065,2.8,"bark",false,Vector3(sin(a)*.7,0,cos(a)*.7),.025)
	else:
		for i in 4:
			sphere(n,Vector3(sin(i*2.)*.32,4.8+i*1.55,cos(i*1.8)*.28),Vector3(2.1-i*.22,4.0-i*.30,2.0-i*.2),"leaves")
	save_piece(n,id)

func crate() -> void:
	var n:=root_for("farm_crate_v2",Vector2(1.3,.95),.92,"wood");n.set_meta("loot_kind","farm_crate")
	box(n,Vector3(0,.4,0),Vector3(1.2,.8,.85),"wood")
	for x in [-.5,.5]:box(n,Vector3(x,.42,0),Vector3(.09,.86,.96),"reed",false)
	marker(n,"LootInterior",Vector3(0,.86,0));save_piece(n,"farm_crate_v2")

func well() -> void:
	var n:=root_for("village_well_v2",Vector2(2.3,2.3),2.5)
	for i in 12:
		var angle: float=i*TAU/12.;box(n,Vector3(cos(angle)*.78,.48,sin(angle)*.78),Vector3(.48,.95,.30),"stone",true,Vector3(0,-angle,0))
	for side in [-1.,1.]:box(n,Vector3(side*1.,1.4,0),Vector3(.12,2.4,.12),"wood")
	box(n,Vector3(0,2.42,0),Vector3(2.3,.13,.15),"wood")
	cylinder(n,Vector3(0,1.8,0),.028,1.1,"reed");save_piece(n,"village_well_v2")

func woodpile() -> void:
	var n:=root_for("woodpile_v2",Vector2(2.5,1.2),1.1,"wood")
	box(n,Vector3(0,.43,0),Vector3(2.2,.82,1.0),"dark")
	for row in 3:
		for i in 4-row:cylinder(n,Vector3((i-(3-row)*.5)*.3,.18+row*.27,0),.17,2.1,"bark",false,Vector3(0,0,PI*.5))
	save_piece(n,"woodpile_v2")

func clothesline() -> void:
	var n:=root_for("clothesline_v2",Vector2(6.2,.6),2.6,"wood");n.collision_layer=0
	for side in [-1.,1.]:box(n,Vector3(side*3.,1.3,0),Vector3(.09,2.6,.09),"wood",false)
	box(n,Vector3(0,2.4,0),Vector3(6.,.015,.015),"dark",false)
	for i in 5:box(n,Vector3(-2.2+i*1.05,1.8-(i%2)*.1,0),Vector3(.7,1.0,.025),"cloth",false,Vector3(.09*i,0,.06))
	save_piece(n,"clothesline_v2")

func haystack() -> void:
	var n:=root_for("haystack_v2",Vector2(3.6,3.),2.4,"grass")
	cylinder(n,Vector3(0,.85,0),1.55,1.7,"reed",true,Vector3.ZERO,1.3)
	cylinder(n,Vector3(0,1.92,0),1.3,.65,"reed",false,Vector3.ZERO,.15)
	save_piece(n,"haystack_v2")

func save_piece(n: Node3D,id: String) -> void:
	var path:=DIR+id+".tscn"
	var repair_new_context: bool="--repair-context-caps" in OS.get_cmdline_user_args() and id in ["cliff_buttress_v8","talus_fan_v8","collapsed_farm_wall_v8"]
	var repair_field_cover: bool="--repair-field-cover-v10" in OS.get_cmdline_user_args() and id in ["field_bank_v10","field_wall_v10","tamarisk_v10","tamarisk_far_v10"]
	if FileAccess.file_exists(path) and not repair_new_context and not repair_field_cover: skipped.append(id);n.free();return
	var groups: Dictionary={}
	for child in n.get_children():
		if child is MeshInstance3D:
			var key: String=child.material_override.resource_path
			if not groups.has(key):
				var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]=surface
			groups[key].append_from(child.mesh,0,child.transform)
	for child in n.get_children():
		if child is MeshInstance3D: child.free()
	var merged:=ArrayMesh.new()
	for key in groups:
		var data: ArrayMesh=groups[key].commit();merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.surface_get_arrays(0));merged.surface_set_material(merged.get_surface_count()-1,load(key))
	# Native mesh LOD preserves the outer silhouette while reducing the many
	# timber/window details at distance. Collision remains the authored boxes.
	var importer:=ImporterMesh.new()
	for surface in merged.get_surface_count(): importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,merged.surface_get_arrays(surface),[],{},merged.surface_get_material(surface))
	importer.generate_lods(60.,25.,[])
	var lod_mesh:=importer.get_mesh()
	var visual:=MeshInstance3D.new();visual.name="Geometry";visual.mesh=lod_mesh if lod_mesh else merged
	visual.visibility_range_end=1000. if n.get_meta("loot_kind","")=="building" else (650. if "poplar" in id or "willow" in id else 170.)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;n.add_child(visual)
	set_owners(n,n)
	var packed:=PackedScene.new();packed.pack(n)
	var error:=ResourceSaver.save(packed,path)
	if error==OK: written.append(id)
	else: push_error("Could not save "+path)
	n.free()

func set_owners(node: Node,root_node: Node) -> void:
	for child in node.get_children(): child.owner=root_node;set_owners(child,root_node)
