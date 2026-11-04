extends RefCounted
class_name EnvironmentKit

# Original modular geometry: collisions are explicit, render details are batched
# per 24/80 m sector. Solid geometry never disappears at a gameplay distance.
static var materials: Dictionary = {}
static var meshes: Dictionary = {}
var root: Node3D
var solids: StaticBody3D
var visuals := true
var sector := 24.0
var batches: Dictionary = {}
var collision_count := 0
var collision_bodies: Dictionary={}
var detail_count := 0

func _init(parent: Node3D, render_visuals := true, sector_size := 24.0) -> void:
	root = parent
	visuals = render_visuals
	sector = sector_size
	solids = StaticBody3D.new()
	solids.name = "EnvironmentSolids"
	solids.collision_layer = 1
	solids.collision_mask = 0
	root.add_child(solids)

static func material(id: String) -> StandardMaterial3D:
	if materials.has(id): return materials[id]
	var data := id.split(":")
	var surface := data[0]
	var result := StandardMaterial3D.new()
	result.roughness = 0.86
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if ResourceLoader.exists("res://assets/environment/materials/"+surface+"-albedo.png"):
		result.albedo_texture = load("res://assets/environment/materials/"+surface+"-albedo.png")
		result.normal_enabled = true
		result.normal_texture = load("res://assets/environment/materials/"+surface+"-normal.png")
		result.normal_scale = 0.65
		result.roughness_texture = load("res://assets/environment/materials/"+surface+"-roughness.png")
		result.uv1_triplanar = true
		result.uv1_world_triplanar = true
		result.uv1_scale = Vector3.ONE*(0.45 if surface in ["concrete","plaster","rock","sand","floor"] else 1.4)
		result.metallic = 0.55 if surface=="steel" else 0.0
	elif surface=="screen":
		result.albedo_color = Color("183a41")
		result.emission_enabled = true
		result.emission = Color("4d817b")
		result.emission_energy_multiplier = 0.35
	elif surface=="light":
		result.albedo_color = Color("fff0cd")
		result.emission_enabled = true
		result.emission = Color("ffe1a1")
		result.emission_energy_multiplier = 1.7
	else: result.albedo_color = Color("414a46")
	if data.size()>1: result.albedo_color *= Color(data[1])
	materials[id] = result
	return result

func _instance(mesh: Mesh, mat: String, transform: Transform3D, micro := false, low_mesh: Mesh = null, range_end:=0.,options: Dictionary={}) -> void:
	if not visuals: return
	var tint:=Color.WHITE
	# Texture family + per-instance tint lets differently colored houses/props
	# share a draw. Geometry, texture maps, normals and collision are unchanged.
	if root.get_meta("sector_colliders",false):
		var family:=mat.get_slice(":",0)
		if family in ["concrete","plaster","steel","wood","cardboard","sand","rock","fabric","floor","asphalt","brick"]:
			var parts:=mat.split(":")
			if parts.size()>1: tint=Color(parts[1])
			mat="InstancedTint_"+family
			if not materials.has(mat):
				var shared:=material(family).duplicate() as StandardMaterial3D
				shared.vertex_color_use_as_albedo=true
				shared.vertex_color_is_srgb=true
				materials[mat]=shared
	var visual_sector: float=options.get("sector",sector)
	var lod_distance: float=options.get("lod_distance",85.)
	var shadows: bool=options.get("shadows",true)
	var optional: bool=options.get("optional",false)
	var chunk := Vector2i(floori(transform.origin.x/visual_sector),floori(transform.origin.z/visual_sector))
	var key := str(mesh.get_instance_id())+":"+mat+":"+str(chunk)+":"+str(micro)+":"+str(range_end)+":"+str(visual_sector)+":"+str(lod_distance)+":"+str(shadows)+":"+str(optional)
	if not batches.has(key): batches[key] = {"mesh":mesh,"material":mat,"transforms":[],"colors":[],"micro":micro,"low":low_mesh,"end":range_end,"chunk":chunk,"lod_distance":lod_distance,"shadows":shadows,"optional":optional}
	batches[key].transforms.append(transform)
	batches[key].colors.append(tint)
	detail_count += 1

func box(label: String, pos: Vector3, size: Vector3, mat := "steel", solid := false, angles := Vector3.ZERO, micro := false) -> void:
	if not meshes.has("box"):
		var unit := BoxMesh.new()
		unit.size = Vector3.ONE
		meshes.box = unit
	var basis := Basis.from_euler(angles)
	var end:=0.
	if root.get_meta("sector_colliders",false) and (not solid or root.get_meta("war_detail_lod",false)):
		var extent:=maxf(size.x,maxf(size.y,size.z))
		end=110. if extent<.7 else (220. if extent<2 else (500. if extent<5 else 1000.))
	_instance(meshes.box,mat,Transform3D(basis*Basis.from_scale(size),pos),micro,null,end,{"optional":not solid})
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_collider(label,shape,Transform3D(basis,pos),mat.get_slice(":",0))

func cylinder(label: String, pos: Vector3, radius: float, height: float, mat := "steel", solid := false, top := 1.0, angles := Vector3.ZERO, micro := false) -> void:
	var key := "cylinder"+str(top)
	if not meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 16
		meshes[key] = mesh
	var basis := Basis.from_euler(angles)
	var end:=220. if not solid and radius<.15 and root.get_meta("sector_colliders",false) else 0.
	if solid and root.get_meta("war_detail_lod",false):
		var extent:=maxf(height,radius*2)
		end=180. if extent<.7 else (300. if extent<2 else (650. if extent<5 else 1200.))
	_instance(meshes[key],mat,Transform3D(basis*Basis.from_scale(Vector3(radius,height,radius)),pos),micro,null,end,{"optional":not solid})
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_collider(label,shape,Transform3D(basis,pos),mat.get_slice(":",0))

func pipe(a: Vector3, b: Vector3, radius: float, mat := "steel", solid := false, micro := true) -> void:
	var direction := b-a
	if direction.length()<0.001: return
	var rotation := Basis(Quaternion(Vector3.UP,direction.normalized())).get_euler()
	cylinder("Pipe",(a+b)*0.5,radius,direction.length(),mat,solid,1.0,rotation,micro)

func beam(a: Vector3, b: Vector3, width: float, depth: float, mat := "steel", solid := false) -> void:
	var direction := b-a
	if direction.length()<0.001: return
	var rotation := Basis(Quaternion(Vector3.UP,direction.normalized())).get_euler()
	box("Brace",(a+b)*0.5,Vector3(width,direction.length(),depth),mat,solid,rotation)

func _collider(label: String, shape: Shape3D, transform: Transform3D,surface:="") -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = label
	collision.set_meta("surface",surface)
	if label=="TreeTrunk" and root.get_meta("qa_breakable_index",false):
		collision.set_meta("qa_tree_ordinal",collision_count)
	collision.shape = shape
	collision.transform = transform
	var body:=solids
	if root.get_meta("sector_colliders",false):
		var key:=Vector2i(floori(transform.origin.x/sector),floori(transform.origin.z/sector))
		if not collision_bodies.has(key):
			var sector_body:=StaticBody3D.new();sector_body.name="EnvironmentSector_%d_%d"%[key.x,key.y];sector_body.collision_layer=1;sector_body.collision_mask=0;root.add_child(sector_body);collision_bodies[key]=sector_body
		body=collision_bodies[key]
	body.add_child(collision)
	collision_count += 1
	if visuals and root.get_meta("use_occluders",false) and shape is BoxShape3D and shape.size.y>2.0 and maxf(shape.size.x,shape.size.z)>3.0:
		var occluder := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = shape.size
		occluder.occluder = box
		occluder.transform = transform
		root.add_child(occluder)
	return collision

func rock(pos: Vector3, scale: Vector3, variant := 0, solid := true, material_id := "rock") -> void:
	var key := "rock"+str(posmod(variant,7))
	if not meshes.has(key):
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 9
		sphere.rings = 5
		var arrays := sphere.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var p := vertices[i]
			vertices[i] *= 1.0+sin(p.x*7.0+p.z*8.0+variant)*0.11+cos(p.y*9.0+variant)*0.09
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var surface := SurfaceTool.new()
		var temp := ArrayMesh.new()
		temp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		surface.create_from(temp,0)
		surface.generate_normals()
		meshes[key] = surface.commit()
	var transform := Transform3D(Basis.IDENTITY.scaled(scale),pos)
	var low_key := key+"Low"
	if not meshes.has(low_key):
		var low := SphereMesh.new()
		low.radius = 1.0
		low.height = 2.0
		low.radial_segments = 6
		low.rings = 3
		meshes[low_key] = low
	_instance(meshes[key],material_id,transform,false,meshes[low_key])
	if solid:
		var shape := ConvexPolygonShape3D.new()
		var points: PackedVector3Array = meshes[key].get_faces()
		for i in points.size(): points[i] *= scale
		shape.points = points
		_collider("Rock",shape,Transform3D(Basis.IDENTITY,pos))

func sign_text(text: String, pos: Vector3, width := 1.6, yaw := 0.0, color := Color("ded7b9")) -> void:
	if not visuals: return
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.rotation.y = yaw
	label.font_size = 56
	label.pixel_size = width/maxf(float(text.length())*31.0,90.0)
	label.modulate = color
	label.outline_modulate = Color("242d29")
	label.outline_size = 5
	label.no_depth_test = false
	label.visibility_range_end = 65.0
	root.add_child(label)

func wall(label: String, start: Vector3, end: Vector3, height: float, mat := "plaster", openings: Array = [], thickness := 0.24) -> void:
	var tangent := (end-start).normalized()
	var length := start.distance_to(end)
	var yaw := -atan2(tangent.z,tangent.x)
	var holes := openings.duplicate(true)
	holes.sort_custom(func(a: Dictionary,b: Dictionary): return a.at<b.at)
	var cursor := 0.0
	for hole: Dictionary in holes:
		var low := float(hole.at)-float(hole.width)*0.5
		var high := float(hole.at)+float(hole.width)*0.5
		if low>cursor: box(label,start+tangent*((low+cursor)*0.5)+Vector3.UP*height*0.5,Vector3(low-cursor,height,thickness),mat,true,Vector3(0,yaw,0))
		var bottom := float(hole.get("sill",0.0))
		var top := float(hole.get("top",2.7))
		var center := start+tangent*float(hole.at)
		if bottom>0.0: box(label+"Sill",center+Vector3.UP*bottom*0.5,Vector3(hole.width,bottom,thickness),mat,true,Vector3(0,yaw,0))
		if height>top: box(label+"Lintel",center+Vector3.UP*(height+top)*0.5,Vector3(hole.width,height-top,thickness),mat,true,Vector3(0,yaw,0))
		for side in [-1.0,1.0]: box("OpeningJamb",center+tangent*side*float(hole.width)*0.5+Vector3.UP*(bottom+top)*0.5,Vector3(0.07,top-bottom,thickness+0.08),"steel",false,Vector3(0,yaw,0))
		box("OpeningHeader",center+Vector3.UP*top,Vector3(hole.width+0.14,0.08,thickness+0.08),"steel",false,Vector3(0,yaw,0))
		cursor = high
	if cursor<length: box(label,start+tangent*((cursor+length)*0.5)+Vector3.UP*height*0.5,Vector3(length-cursor,height,thickness),mat,true,Vector3(0,yaw,0))

func crate(pos: Vector3, scale := Vector3.ONE, military := false) -> void:
	var mat := "steel:929c7c" if military else "cardboard"
	box("Crate",pos+Vector3.UP*scale.y*0.5,scale,mat,true)
	for side in [-1.0,1.0]:
		box("CrateBand",pos+Vector3(side*scale.x*0.28,scale.y+0.005,0),Vector3(0.045,0.018,scale.z+0.02),"steel" if military else "wood:e0c993",false,Vector3.ZERO,true)
	box("CrateLabel",pos+Vector3(scale.x*0.22,scale.y*0.57,scale.z*0.5+0.006),Vector3(scale.x*0.26,scale.y*0.22,0.012),"plaster",false,Vector3.ZERO,true)
	for i in range(3): box("LabelBarcode",pos+Vector3(scale.x*(0.15+i*0.06),scale.y*0.58,scale.z*0.5+0.014),Vector3(0.014,scale.y*0.15,0.008),"dark",false,Vector3.ZERO,true)

func pallet(pos: Vector3) -> void:
	for z in [-0.45,0.0,0.45]: box("PalletRunner",pos+Vector3(0,0.07,z),Vector3(1.2,0.12,0.12),"wood",false)
	for x in [-0.5,-0.25,0.0,0.25,0.5]: box("PalletPlank",pos+Vector3(x,0.16,0),Vector3(0.18,0.07,1.1),"wood",false)
	box("PalletSolid",pos+Vector3.UP*0.08,Vector3(1.2,0.16,1.1),"wood",true)

func desk(pos: Vector3, yaw := 0.0, screen := true) -> void:
	var b := Basis(Vector3.UP,yaw)
	box("DeskTop",pos+Vector3.UP*0.78,Vector3(1.7,0.085,0.85),"wood",true,Vector3(0,yaw,0))
	for x in [-0.72,0.72]:
		for z in [-0.31,0.31]: box("DeskLeg",pos+b*Vector3(x,0.38,z),Vector3(0.055,0.75,0.055),"steel",true)
	if screen:
		box("MonitorBase",pos+b*Vector3(0.25,0.85,-0.18),Vector3(0.30,0.035,0.19),"dark",false)
		box("MonitorStem",pos+b*Vector3(0.25,1.01,-0.22),Vector3(0.05,0.30,0.05),"steel",false)
		box("MonitorCase",pos+b*Vector3(0.25,1.22,-0.22),Vector3(0.65,0.39,0.055),"dark",false,Vector3(0,yaw,0))
		box("MonitorScreen",pos+b*Vector3(0.25,1.22,-0.186),Vector3(0.59,0.33,0.008),"screen",false,Vector3(0,yaw,0))
		for i in range(4): box("ScreenInterface",pos+b*Vector3(0.16,1.31-i*0.045,-0.18),Vector3(0.30-i*0.035,0.012,0.004),"light:6c9881",false,Vector3(0,yaw,0),true)
		box("Keyboard",pos+b*Vector3(0.20,0.841,0.15),Vector3(0.43,0.025,0.15),"dark",false,Vector3(0,yaw,0))
		for i in range(5): box("KeyboardKeys",pos+b*Vector3(0.04+i*0.075,0.86,0.15),Vector3(0.018,0.008,0.12),"steel",false,Vector3(0,yaw,0),true)
	box("Documents",pos+b*Vector3(-0.5,0.84,0.16),Vector3(0.24,0.025,0.32),"plaster",false,Vector3(0,yaw+0.12,0),true)
	pipe(pos+b*Vector3(0.25,0.78,-0.27),pos+b*Vector3(0.38,0.18,-0.38),0.012,"dark",false)

func chair(pos: Vector3, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP,yaw)
	cylinder("ChairPiston",pos+Vector3.UP*0.30,0.045,0.46,"steel",false)
	box("ChairSeat",pos+Vector3.UP*0.55,Vector3(0.52,0.10,0.52),"fabric:7f8985",true,Vector3(0,yaw,0))
	box("ChairBack",pos+b*Vector3(0,0.91,0.24),Vector3(0.50,0.59,0.095),"fabric:7f8985",false,Vector3(0,yaw-0.0,0))
	for side in [-1.0,1.0]:
		pipe(pos+b*Vector3(side*0.26,0.55,0.12),pos+b*Vector3(side*0.26,0.77,0.12),0.022,"steel")
		box("ArmRest",pos+b*Vector3(side*0.27,0.77,0.02),Vector3(0.06,0.05,0.33),"dark",false,Vector3(0,yaw,0))
	for i in range(5):
		var offset := Vector3(cos(i*TAU/5)*0.31,0.10,sin(i*TAU/5)*0.31)
		pipe(pos+Vector3.UP*0.17,pos+offset,0.025,"steel")
		cylinder("Caster",pos+offset,0.058,0.045,"dark",false,1.0,Vector3(0,0,PI/2),true)

func rack(pos: Vector3, width := 4.6, documents := false) -> void:
	var depth := 0.8 if not documents else 0.5
	var height := 4.4 if not documents else 2.6
	for x in [-width*0.5,width*0.5]:
		for z in [-depth*0.5,depth*0.5]: box("RackUpright",pos+Vector3(x,height*0.5,z),Vector3(0.09,height,0.09),"steel",true)
		beam(pos+Vector3(x,0.2,-depth*.5),pos+Vector3(x,height*.7,depth*.5),0.035,0.035,"steel")
	for level in range(3):
		var y := 0.3+float(level)*(1.6 if not documents else 0.86)
		box("RackShelf",pos+Vector3(0,y,0),Vector3(width,0.09,depth),"steel:cfac74",true)
		for index in range(3 if not documents else 6):
			var x := -width*.37+index*(width*.37 if not documents else width*.145)
			if not documents: crate(pos+Vector3(x,y+0.05,0),Vector3(0.86,0.82 if level!=1 else 1.05,0.65))
			else:
				box("ArchiveBinder",pos+Vector3(x,y+0.31,0),Vector3(0.26,0.5,0.38),"cardboard:8a9c8d",false)
				box("BinderSpine",pos+Vector3(x,y+0.31,depth*.5),Vector3(0.15,0.07,0.012),"plaster",false,Vector3.ZERO,true)

func lamp(pos: Vector3, length := 2.0, warm := true, light := true) -> void:
	box("LampHousing",pos,Vector3(length,0.12,0.30),"steel",false)
	box("LampDiffuser",pos-Vector3.UP*0.07,Vector3(length*.92,0.03,0.23),"light",false)
	if visuals and light:
		var node := OmniLight3D.new()
		node.position = pos-Vector3.UP*0.5
		node.light_color = Color("ffe2b7") if warm else Color("d6e5e4")
		node.omni_range = 7.5
		node.light_energy = 0.65
		node.shadow_enabled = false
		node.distance_fade_enabled = true
		node.distance_fade_begin = 30
		root.add_child(node)

func _instance_bounds(mesh: Mesh,transforms: Array) -> AABB:
	var bounds:=AABB();var first:=true;var local_bounds:=mesh.get_aabb()
	for transform: Transform3D in transforms:
		var box:=transform*local_bounds
		bounds=box if first else bounds.merge(box);first=false
	return bounds

func flush() -> void:
	if not visuals: return
	var distant_batches: Dictionary={}
	for data: Dictionary in batches.values():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var uses_colors:=false
		for tint: Color in data.colors:
			if tint!=Color.WHITE: uses_colors=true;break
		multimesh.use_colors = uses_colors
		multimesh.mesh = data.mesh
		multimesh.instance_count = data.transforms.size()
		multimesh.custom_aabb=_instance_bounds(data.mesh,data.transforms)
		for i in data.transforms.size():
			multimesh.set_instance_transform(i,data.transforms[i])
			if uses_colors: multimesh.set_instance_color(i,data.colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = "DetailBatch_"+str(data.material).replace(":","_")
		node.multimesh = multimesh
		node.custom_aabb=multimesh.custom_aabb
		node.material_override = material(data.material)
		# Keep the original grass separate in frame-pacing evidence.  It is a
		# static batched fallback, not the prepared Nova Grass streamer.
		if bool(data.mesh.get_meta("legacy_grass",false)): node.add_to_group("war_legacy_grass")
		node.visibility_range_end=float(data.end)
		if not data.shadows: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if data.low!=null:
			node.visibility_range_end = float(data.lod_distance)
			var key:=str(data.low.get_instance_id())+":"+str(data.material)+":"+str(data.chunk)+":"+str(data.optional)
			if not distant_batches.has(key): distant_batches[key]={"mesh":data.low,"material":node.material_override,"transforms":[],"colors":[],"near_nodes":[],"bounds":node.multimesh.custom_aabb,"end":data.end,"lod_distance":data.lod_distance,"legacy_grass":bool(data.mesh.get_meta("legacy_grass",false)),"optional":data.optional}
			var distant: Dictionary=distant_batches[key]
			distant.transforms.append_array(data.transforms);distant.colors.append_array(data.colors);distant.near_nodes.append(node)
			distant.bounds=AABB(distant.bounds).merge(node.multimesh.custom_aabb)
		if data.micro:
			node.visibility_range_end = 70.0
			node.visibility_range_end_margin = 8.0
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if data.low==null and bool(data.optional):
			node.add_to_group("scenario_rendering");node.set_meta("scenario_optional",true);node.set_meta("scenario_end",node.visibility_range_end)
		root.add_child(node)
	for data: Dictionary in distant_batches.values():
		var low:=MultiMeshInstance3D.new();low.name="DistantLOD"
		var uses_colors:=false
		for tint: Color in data.colors:
			if tint!=Color.WHITE: uses_colors=true;break
		var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_colors=uses_colors;instances.mesh=data.mesh;instances.instance_count=data.transforms.size()
		for i in data.transforms.size():
			instances.set_instance_transform(i,data.transforms[i])
			if uses_colors: instances.set_instance_color(i,data.colors[i])
		low.multimesh=instances;low.material_override=data.material;low.visibility_range_begin=float(data.lod_distance)
		if bool(data.get("legacy_grass",false)): low.add_to_group("war_legacy_grass")
		# Matching conservative bounds make near/far switches use the same
		# distance centre even when several detailed variants share one LOD.
		var bounds:=AABB(data.bounds).merge(_instance_bounds(data.mesh,data.transforms))
		instances.custom_aabb=bounds
		low.custom_aabb=bounds
		for near_node: MultiMeshInstance3D in data.near_nodes: near_node.custom_aabb=bounds
		if not bool(data.get("legacy_grass",false)):
			var refs: Array=[]
			for near_node: MultiMeshInstance3D in data.near_nodes:refs.append(weakref(near_node))
			low.add_to_group("scenario_rendering");low.set_meta("scenario_near_nodes",refs);low.set_meta("scenario_lod",data.lod_distance)
			low.set_meta("scenario_optional",data.optional)
		if root.get_meta("sector_colliders",false):
			low.visibility_range_end=float(data.end) if float(data.end)>0 else 900.;low.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(low)
	root.set_meta("environment_instances",detail_count)
	root.set_meta("environment_colliders",collision_count)
	batches.clear()
