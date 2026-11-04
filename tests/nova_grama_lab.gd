extends Node3D
class_name NovaGramaLab

# Isolated proof of concept only. The live world and authored scenes are not
# rewritten. Each visible detail is a MultiMesh, without per-instance scripts.
@export var enabled:=false
@export var ground_only:=false
@export var details_only:=false
const MAP_PATH:="res://assets/war/biomes/nova_grama.png"
const HALF:=1750.
const CELL:=20.
const CELLS:=10
const CANDIDATES:=200
const DETAIL_RANGE:=80.
const PALETTE:=[Color8(48,150,54),Color8(108,65,50),Color8(178,151,80),Color8(174,165,145)]
var image: Image
var surfaces: Array[Dictionary]=[]
var legacy: Array[Dictionary]=[]
var generated: Array[Node]=[]
var grass_material: ShaderMaterial
var soil_material: ShaderMaterial
var tree_controller: RefCounted
var counts: Dictionary={"green_tufts":0,"dry_tufts":0,"stumps":0,"logs":0,"ashes":0,"rubble":0,"trees_green":0,"trees_burnt":0,"legacy_removed":0,"legacy_kept":0,"cells":0,"max_tuft_candidates":CELLS*CELLS*CANDIDATES}

func load_map() -> bool:
	image=Image.new()
	return image.load(ProjectSettings.globalize_path(MAP_PATH))==OK and image.get_width()>0 and image.get_height()>0

func biome(p: Vector2) -> int:
	var x:=clampi(floori((p.x+HALF)/(2*HALF)*image.get_width()),0,image.get_width()-1)
	var y:=clampi(floori((p.y+HALF)/(2*HALF)*image.get_height()),0,image.get_height()-1)
	var c:=image.get_pixel(x,y)
	var best:=INF;var index:=0
	for i in PALETTE.size():
		var q: Color=PALETTE[i];var distance: float=pow(c.r-q.r,2)+pow(c.g-q.g,2)+pow(c.b-q.b,2)
		if distance<best: best=distance;index=i
	return index

func _ready() -> void:
	if enabled: activate()

func activate() -> bool:
	if not load_map(): push_error("Nova Grama: biome PNG unavailable");return false
	if get_parent()==null: return false
	var world:=get_parent()
	soil_material=ShaderMaterial.new();soil_material.shader=load("res://tests/nova_grama_ground.gdshader")
	soil_material.set_shader_parameter("biome",ImageTexture.create_from_image(image))
	soil_material.set_shader_parameter("soil",load("res://assets/environment/materials/sand-albedo.png"))
	soil_material.set_shader_parameter("stone",load("res://assets/environment/materials/rock-albedo.png"))
	soil_material.set_shader_parameter("gravel",load("res://assets/environment/materials/asphalt-albedo.png"))
	soil_material.set_shader_parameter("soil_normal",load("res://assets/environment/materials/sand-normal.png"))
	# Godot renames duplicate siblings; identify sectors by their shared
	# source material rather than their requested (non-unique) node name.
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if node.material_override!=WarTerrain.material: continue
		surfaces.append({"node":node,"material":node.material_override})
		if not details_only: node.material_override=soil_material
	counts["terrain_sectors"]=surfaces.size()
	if surfaces.is_empty(): push_error("Nova Grama: no terrain material found");return false
	# Isolate the cost of the ground shader from vegetation and props.
	if ground_only: return true
	# Rebuild the existing grass batches, filtering burnt areas, without
	# touching tree batches or authoring their shared source meshes.
	for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh==null: continue
		if node.multimesh.mesh!=WarVegetation.grass_mesh() and node.multimesh.mesh!=WarVegetation.grass_low_mesh(): continue
		var chosen: Array[Transform3D]=[]
		for i in node.multimesh.instance_count:
			var pose:=node.multimesh.get_instance_transform(i)
			var p:=node.to_global(pose.origin)
			if biome(Vector2(p.x,p.z))==1: counts.legacy_removed+=1
			else: chosen.append(pose);counts.legacy_kept+=1
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=node.multimesh.mesh;mm.instance_count=chosen.size()
		for i in chosen.size(): mm.set_instance_transform(i,chosen[i])
		var clone:=MultiMeshInstance3D.new();clone.name="NovaLegacyGrass";clone.multimesh=mm;clone.material_override=node.material_override
		clone.transform=node.transform;clone.visibility_range_begin=node.visibility_range_begin;clone.visibility_range_end=node.visibility_range_end
		clone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;clone.custom_aabb=node.custom_aabb;node.get_parent().add_child(clone);clone.visible=node.visible
		generated.append(clone);legacy.append({"node":node,"visible":node.visible});node.hide()
	grass_material=ShaderMaterial.new();grass_material.shader=load("res://tests/nova_grama_grass.gdshader")
	var grass:=_grass_mesh();var stump:=CylinderMesh.new();stump.height=.35;stump.top_radius=.11;stump.bottom_radius=.18;stump.radial_segments=6
	var log:=BoxMesh.new();log.size=Vector3(.14,.10,.7)
	var ash:=BoxMesh.new();ash.size=Vector3(.35,.025,.24)
	var mesh_material:=StandardMaterial3D.new();mesh_material.albedo_color=Color("454039");mesh_material.roughness=1
	var centre:=Vector2(-80,-240)
	for cx in CELLS:
		for cz in CELLS:
			var origin:=centre+Vector2(cx-CELLS/2,cz-CELLS/2)*CELL
			var rng:=RandomNumberGenerator.new();rng.seed=40100+cx*97+cz*1031
			var fields: Array[Transform3D]=[];var dry: Array[Transform3D]=[];var stumps: Array[Transform3D]=[];var logs: Array[Transform3D]=[];var ashes: Array[Transform3D]=[]
			var rubble:=0
			for i in CANDIDATES:
				var p:=origin+Vector2(rng.randf_range(0,CELL),rng.randf_range(0,CELL))
				var zone:=biome(p)
				if WarRoads.distance(p)<10 or WarTerrain.trench_distance(p)<6: continue
				var y:=WarTerrain.height_at(p.x,p.y);var pos:=Vector3(p.x,y,p.y)
				var scale:=rng.randf_range(.65,1.2)
				var pose:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU)*Basis.from_scale(Vector3.ONE*scale),pos)
				if zone==0 and sin(p.x*.2)*cos(p.y*.18)>.0: fields.append(pose)
				elif zone==2 and i%7==0: dry.append(pose)
				elif zone==1 and i%12==0:
					if (i/12)%4==0: stumps.append(Transform3D(pose.basis,pos+Vector3.UP*.17))
					elif (i/12)%4==1: logs.append(Transform3D(pose.basis,pos+Vector3.UP*.05))
					elif (i/12)%4==2: ashes.append(Transform3D(pose.basis,pos+Vector3.UP*.02))
					else:
						ashes.append(Transform3D(pose.basis*Basis.from_scale(Vector3(1.1,5.,.8)),pos+Vector3.UP*.065));rubble+=1
			counts.green_tufts+=fields.size();counts.dry_tufts+=dry.size();counts.stumps+=stumps.size();counts.logs+=logs.size();counts.ashes+=ashes.size()-rubble;counts.rubble+=rubble
			_batch(world,grass,fields,grass_material,Color("8ca764"));_batch(world,grass,dry,grass_material,Color("a69364"))
			_batch(world,stump,stumps,mesh_material,Color.WHITE);_batch(world,log,logs,mesh_material,Color.WHITE);_batch(world,ash,ashes,mesh_material,Color.WHITE)
			counts.cells+=1
	# Independent, sparse test silhouettes follow the same mask. They are
	# deliberately noninteractive and do not replace real map trees yet.
	var trees: Array[Transform3D]=[];var burned: Array[Transform3D]=[]
	for i in 36:
		var p:=centre+Vector2((i%6)*30-75,(i/6)*36-90)
		if WarRoads.distance(p)<12 or WarTerrain.trench_distance(p)<8: continue
		var pose:=Transform3D(Basis.IDENTITY,WarTerrain.point(p.x,p.y))
		if biome(p)==1: burned.append(pose)
		elif biome(p)==0: trees.append(pose)
	WarVegetation._material()
	_batch(world,WarVegetation.tree_mesh(true,0,true),trees,EnvironmentKit.materials["war_vegetation169"],Color.WHITE,180.)
	_batch(world,WarVegetation.tree_mesh(false,0,true),burned,EnvironmentKit.materials["war_vegetation169"],Color.WHITE,180.)
	counts.trees_green=trees.size();counts.trees_burnt=burned.size()
	return true

func _grass_mesh() -> ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var angle:=i*2.4;var base:=Vector3(sin(angle)*.18,0,cos(angle)*.18)
		var side:=Vector3(cos(angle),0,-sin(angle))*.045
		for v in [base-side,base+side,base+Vector3(sin(angle)*.13,.55+(i%3)*.1,cos(angle)*.13)]:
			surface.set_normal(Vector3.UP);surface.add_vertex(v)
	return surface.commit()

func _batch(parent: Node,mesh: Mesh,poses: Array[Transform3D],material: Material,color: Color,distance:=DETAIL_RANGE) -> void:
	if poses.is_empty(): return
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh;mm.instance_count=poses.size()
	for i in poses.size(): mm.set_instance_transform(i,poses[i]);mm.set_instance_color(i,color)
	var node:=MultiMeshInstance3D.new();node.name="NovaGramaCell";node.set_meta("nova_detail",true);node.multimesh=mm;node.material_override=material;node.visibility_range_end=distance
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);generated.append(node)

func deactivate() -> void:
	if tree_controller and tree_controller.has_method("restore"): tree_controller.call("restore");tree_controller=null
	for item in surfaces:
		if is_instance_valid(item.node): item.node.material_override=item.material
	for item in legacy:
		if is_instance_valid(item.node): item.node.visible=item.visible
	for node in generated:
		if is_instance_valid(node): node.queue_free()
	surfaces.clear();legacy.clear();generated.clear();enabled=false
