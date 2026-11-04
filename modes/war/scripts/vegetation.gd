extends RefCounted
class_name WarVegetation
static var cache: Dictionary={}
const GRASS_BATCH:={"sector":180.,"lod_distance":150.,"shadows":false}

static func _append(surface: SurfaceTool,mesh: Mesh,pose: Transform3D,color: Color) -> void:
	var arrays:=mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var normal_basis:=pose.basis.inverse().transposed()
	for i in (indices if not indices.is_empty() else range(vertices.size())):
		surface.set_color(color);surface.set_normal((normal_basis*normals[i]).normalized());surface.add_vertex(pose*vertices[i])

static func tree_mesh(green: bool,variant: int,low: bool) -> ArrayMesh:
	var key:="tree:%s:%s:%s"%[green,variant,low]
	if cache.has(key): return cache[key]
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark:=Color("4c4b3e") if green else Color("343831")
	var trunk:=WarBodyMesh.loft("tree169-trunk-"+str(low),[[-.18,.34,.30,0],[.3,.30,.25,.02],[2.7,.21,.18,-.08],[5.2,.10,.09,.10],[6.6,.025,.035,.24]],5 if low else 10,.9)
	_append(surface,trunk,Transform3D.IDENTITY,bark)
	var branch:=WarBodyMesh.loft("tree169-branch-"+str(low),[[0,1,1,0],[.55,.65,.65,.1],[1,.06,.06,.18]],4 if low else 7,1.)
	var count:=3 if low else 7
	for i in count:
		var angle:=i*2.39+variant*.71;var start:=Vector3(0,2.8+i*(.75 if low else .40),0)
		var direction:=Vector3(cos(angle)*(1.9-i*.10),.8+i*.08,sin(angle)*(1.9-i*.10))
		var pose:=Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized()))*Basis.from_scale(Vector3(.10,direction.length(),.10)),start)
		_append(surface,branch,pose,bark.darkened(.08))
		if not low:
			var end:=start+direction;var fork:=direction*.4+Vector3(.3,.15,-.2)
			_append(surface,branch,Transform3D(Basis(Quaternion(Vector3.UP,fork.normalized()))*Basis.from_scale(Vector3(.038,fork.length(),.038)),end),bark)
	if green:
		var crown:=SphereMesh.new();crown.radius=1.;crown.height=2.;crown.radial_segments=5 if low else 9;crown.rings=3 if low else 5
		var arrays:=crown.get_mesh_arrays();var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for j in points.size():
			var point: Vector3=points[j];points[j]*=1+.13*sin(point.x*11+point.z*7+point.y*5)+.05*cos(point.z*17-point.y*13)
		arrays[Mesh.ARRAY_VERTEX]=points;var foliage:=ArrayMesh.new();foliage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		for i in 6:
			var angle:=i*2.4+variant;var y:=3.9+i*.43
			var scale:=Vector3(1.25+(variant%2)*.15,1.7,1.15)*(1.-i*.055)
			var point:=Vector3(cos(angle)*.7,y,sin(angle)*.7)
			_append(surface,foliage,Transform3D(Basis.from_euler(Vector3(.12*i,angle,.16))*Basis.from_scale(scale),point),Color("485637").lightened(float(i%3)*.035))
	surface.index();var mesh:=surface.commit();cache[key]=mesh;return mesh

static func grass_mesh() -> ArrayMesh:
	if cache.has("grass"): return cache.grass
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var angle:=i*2.4;var root:=Vector3(sin(angle)*.28,-.06,cos(angle)*.28);var side:=Vector3(cos(angle),0,-sin(angle))*.025
		var tip:=root+Vector3(sin(angle)*.20,.35+(i%3)*.12,cos(angle)*.20)
		var normal:=(tip-root).cross(side).normalized()
		for vertex in [root-side,root+side,tip]: surface.set_color(Color("778263").darkened((i%3)*.05));surface.set_normal(normal);surface.add_vertex(vertex)
	cache.grass=surface.commit();cache.grass.set_meta("legacy_grass",true);return cache.grass

static func _material() -> void:
	if EnvironmentKit.materials.has("war_vegetation169"): return
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.97;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	EnvironmentKit.materials["war_vegetation169"]=material

static func grass_low_mesh() -> ArrayMesh:
	if cache.has("grass_low"): return cache.grass_low
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two opaque crossed fans preserve height/width at distance. No alpha
	# card overdraw and no collision which could obstruct a walking player.
	for i in 2:
		var side:=Vector3.RIGHT.rotated(Vector3.UP,i*PI*.5)*.37
		var tip:=Vector3(0,.61,0)
		for vertex: Vector3 in [-side,side,tip]:
			surface.set_color(Color("778263"));surface.set_normal(Vector3.UP);surface.add_vertex(vertex)
	cache.grass_low=surface.commit();cache.grass_low.set_meta("legacy_grass",true);return cache.grass_low

static func tree(k: EnvironmentKit,p: Vector3,scale: float,green: bool) -> void:
	var variant:=posmod(int(p.x*7+p.z*13),3)
	if k.visuals:
		_material();var basis:=Basis(Vector3.UP,float(variant)*.79)*Basis.from_scale(Vector3.ONE*scale)
		# Keep detailed variants nearby; distant instances share a green/burnt
		# silhouette while preserving each tree's position, scale and rotation.
		k._instance(tree_mesh(green,variant,false),"war_vegetation169",Transform3D(basis,p),false,tree_mesh(green,variant,true),2700.)
	var collision:=CylinderShape3D.new();collision.radius=.26*scale;collision.height=5.4*scale
	var trunk:=k._collider("TreeTrunk",collision,Transform3D(Basis.IDENTITY,p+Vector3.UP*(collision.height*.5-.08)))
	if trunk.has_meta("qa_tree_ordinal"):
		trunk.set_meta("qa_tree_green",green);trunk.set_meta("qa_tree_scale",scale)

static func clear_site(point: Vector2,ground_cover:=false) -> bool:
	if WarTerrain.height_at(point.x,point.y)<3.8 or WarRoads.distance(point)<9: return false
	# Authored foundations and excavations share the terrain's spatial index.
	# Keep procedurally distributed trees out of edited houses and pathways.
	for edit: Dictionary in WarTerrainEdits.cells.get(Vector2i(floori(point.x/100),floori(point.y/100)),[]):
		var local: Vector3=Transform3D(edit.inverse)*Vector3(point.x,edit.plane.y,point.y)
		if absf(local.x)<edit.half.x+2. and absf(local.z)<edit.half.y+2.: return false
	for town: Vector2 in WarUrbanLayout.CENTRES:
		if not ground_cover and absf(point.x-town.x)<100 and absf(point.y-town.y)<90: return false
		if ground_cover:
			for lot in 6:
				var p:=town+Vector2((lot%3)*42-42,(lot/3)*58-29)
				if absf(point.x-p.x)<16 and absf(point.y-p.y)<13: return false
	for field: Vector2 in [Vector2(-590,370),Vector2(540,-410)]:
		if absf(point.x-field.x)<110 and absf(point.y-field.y)<75: return false
	for port: Vector3 in WarCoast.PORTS:
		if absf(point.x-port.x)<(62 if ground_cover else 220) and absf(point.y-port.z)<(155 if ground_cover else 200): return false
	for base: Vector3 in WarRules.BASES:
		if point.distance_to(Vector2(base.x,base.z))<82: return false
	for pad: Vector4 in WarTerrain.PADS:
		if absf(point.x-pad.x)<pad.z+4 and absf(point.y-pad.y)<pad.w+4: return false
	if absf(point.y-25*sin(point.x*.009))<13: return false
	if absf(point.x)<310 and point.y>-160 and point.y<90 and WarTerrain.trench_distance(point)<8: return false
	for id in ["A","B","C"]:
		var centre: Vector3=WarRules.OBJECTIVES[id].position
		if point.distance_to(Vector2(centre.x,centre.z))<28: return false
	return true

static func populate(k: EnvironmentKit) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=1692402
	var trees:=0
	# Mixed woods in the flanks, blasted copses through the combat belt.
	for i in 7800:
		var x:=rng.randf_range(-1390,1390);var z:=rng.randf_range(-1350,1350)
		# Reuse the tree budget in denser wooded belts, rather than adding an
		# even scattering of extra collision bodies across the entire island.
		if i%3==0: z=(1 if i%2 else -1)*rng.randf_range(470,840)
		var point:=Vector2(x,z)
		if not clear_site(point): continue
		var green:=absf(z)>330 or (absf(x)>360 and absf(z)>85 and absf(z)<190)
		if not green and i%3!=0: continue
		tree(k,WarTerrain.point(x,z),rng.randf_range(.65,1.55),green);trees+=1
	for side in [-1,1]:
		for row in 8:
			for column in 28:
				var p:=Vector2(-790+column*58+rng.randf_range(-15,15),side*(490+row*38)+rng.randf_range(-12,12))
				if clear_site(p): tree(k,WarTerrain.point(p.x,p.y),rng.randf_range(.75,1.45),true);trees+=1
	if k.visuals and not (load("res://scripts/maps/definition.gd").grass_enabled("ukraine") and "--nova-grama-preview" not in OS.get_cmdline_user_args()):
		_material();var mesh:=grass_mesh();var grass:=0
		for i in 90000:
			var p:=Vector2(rng.randf_range(-1380,1380),rng.randf_range(-1320,1320))
			if i%2==0: p=Vector2(rng.randf_range(-330,330),rng.randf_range(-310,260))
			if i>=43000:
				if i<50000:
					var port: Vector3=WarCoast.PORTS[i%2]
					p=Vector2(port.x+rng.randf_range(-235,235),port.z+rng.randf_range(-230,230))
				else:
					# Dense belts/copses, not a uniform green carpet over streets.
					p=Vector2(rng.randf_range(-1250,1250),(1 if i%2 else -1)*rng.randf_range(470,840))
			if not clear_site(p,true): continue
			var point:=WarTerrain.point(p.x,p.y);var scale:=rng.randf_range(.70,1.45)
			var normal:=Vector3(WarTerrain.height_at(p.x-.35,p.y)-WarTerrain.height_at(p.x+.35,p.y),.7,WarTerrain.height_at(p.x,p.y-.35)-WarTerrain.height_at(p.x,p.y+.35)).normalized()
			var basis:=Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,rng.randf()*TAU)*Basis.from_scale(Vector3.ONE*scale)
			k._instance(mesh,"war_vegetation169",Transform3D(basis,point),false,grass_low_mesh(),2400.,GRASS_BATCH);grass+=1
		k.root.set_meta("war_grass_count",grass)
	k.root.set_meta("war_tree_count",trees)
