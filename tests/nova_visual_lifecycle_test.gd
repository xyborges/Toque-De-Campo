extends SceneTree

const BIOME=preload("res://modes/war/scripts/biome_map.gd")
const ASSETS=preload("res://modes/war/scripts/grass_assets.gd")
const STREAM=preload("res://modes/war/scripts/grass_stream.gd")
const VISUALS=preload("res://modes/war/scripts/vegetation_visuals.gd")
var errors: Array[String]=[]

func check(ok: bool,message: String) -> void:
	if not ok: errors.append(message)

func _initialize() -> void: run.call_deferred()

func add_terrain(parent: Node3D,source: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=PlaneMesh.new();node.material_override=source;parent.add_child(node);return node

func add_legacy_grass(parent: Node3D) -> MultiMeshInstance3D:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=WarVegetation.grass_mesh();mm.instance_count=1
	var node:=MultiMeshInstance3D.new();node.multimesh=mm;parent.add_child(node);return node

func run() -> void:
	# These guards avoid null image dereferences and undefined floor(NaN).
	var map=BIOME.new()
	check(map.region(Vector2.ZERO)==-1 and map.colour_at(Vector2.ZERO)==Color.TRANSPARENT,"unloaded biome queries are safe")
	map.image=Image.create(2,2,false,Image.FORMAT_RGBA8);map.image.fill(BIOME.PALETTE[0])
	check(map.region(Vector2(NAN,0.))==-1,"non-finite biome coordinate is rejected")
	check(not map.footprint_field(Vector2.ZERO,-1.) and not map.footprint_field(Vector2.ZERO,NAN),"invalid footprint radii are rejected")
	check(not map.all_field(Vector2(1750.,0.),1.),"all_field preserves exact out-of-map guard")
	# Isolated material state: rain in one active preview must not mutate
	# cached materials or a separate stream at the same quality setting.
	var one=STREAM.new();var two=STREAM.new();root.add_child(one);root.add_child(two)
	one.initialised=true;two.initialised=true
	one.material=ASSETS.grass_material(1).duplicate() as ShaderMaterial;two.material=ASSETS.grass_material(1).duplicate() as ShaderMaterial
	one.material.set_shader_parameter("storm",.7)
	var cached_storm: Variant=ASSETS.grass_material(2).get_shader_parameter("storm")
	one.set_level(2);two.set_level(2)
	check(one.material!=two.material,"separate streams own distinct mutable uniforms")
	check(is_equal_approx(float(one.material.get_shader_parameter("storm")),.7),"quality change preserves the world's storm intensity")
	check(two.material.get_shader_parameter("storm")!=.7 and ASSETS.grass_material(2).get_shader_parameter("storm")==cached_storm,"weather does not leak to another stream or the cache")
	one.clear();two.clear();one.queue_free();two.queue_free()
	var world_one:=Node3D.new();var world_two:=Node3D.new();root.add_child(world_one);root.add_child(world_two)
	var component=VISUALS.new();root.add_child(component);component.initialize(world_one)
	if DisplayServer.get_name()=="headless":
		check(not component.available and not component.apply_level(2) and component.biome==null and component.streamer==null,"headless component performs no visual setup")
	else:
		var old_terrain_material: ShaderMaterial=WarTerrain.material
		var original:=ShaderMaterial.new();original.shader=load("res://modes/war/shaders/ground.gdshader");WarTerrain.material=original
		var terrain_one:=add_terrain(world_one,original);var terrain_two:=add_terrain(world_two,original)
		var grass:=add_legacy_grass(world_one)
		check(component.apply_level(1),"first visual world can activate")
		component.set_process(false)
		check(terrain_one.material_override!=original and not grass.visible,"activation updates only visual slots")
		component.initialize(world_two)
		check(terrain_one.material_override==original and grass.visible,"reinitializing with another world restores the previous one")
		check(component.apply_level(2),"second world can activate after restoration")
		component.set_process(false)
		check(component.apply_level(0) and terrain_two.material_override==original,"rollback restores second world's terrain")
		WarTerrain.material=old_terrain_material
	component.queue_free();world_one.queue_free();world_two.queue_free();await process_frame
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"scope":"visual lifecycle and material isolation; not performance or multiplayer validation"}))
	quit(0 if errors.is_empty() else 1)
