extends Node3D

const BIOME=preload("res://modes/war/scripts/biome_map.gd")
const STREAM=preload("res://modes/war/scripts/grass_stream.gd")
var world: Node3D
var level:=0
var biome: RefCounted
var streamer: Node3D
var ground: ShaderMaterial
var ground_slots: Array[Dictionary]=[]
var legacy_slots: Array[Dictionary]=[]
var refresh_clock:=0.0
var available:=false
var map_id:="ukraine"
var warmed:=false

func _ready() -> void:
 name="VegetationVisuals";set_process(false)
 if DisplayServer.get_name()!="headless":add_to_group("war_vegetation_visuals")

func initialize(target: Node3D,key:="ukraine") -> void:
 if DisplayServer.get_name()=="headless":return
 _restore();world=target;map_id=key
 if not is_instance_valid(world) or not world.is_inside_tree():return
 streamer=STREAM.new();add_child(streamer)
 if not streamer.configure(world,null,key):streamer.free();streamer=null;return
 streamer.set_process(false)
 if key=="ukraine":
  if WarTerrain.material==null:_restore();return
  biome=BIOME.new()
  if not biome.load_map():_restore();return
  ground=ShaderMaterial.new();ground.shader=load("res://modes/war/shaders/biome_ground.gdshader")
  ground.set_shader_parameter("biome",biome.get_texture())
  for pair in [["soil","sand-albedo"],["stone","rock-albedo"],["gravel","asphalt-albedo"],["soil_normal","sand-normal"]]:
   ground.set_shader_parameter(pair[0],load("res://assets/environment/materials/"+pair[1]+".png"))
  ground.set_shader_parameter("variation",WarTerrain.material.get_shader_parameter("variation"))
  for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
   if node.material_override==WarTerrain.material:ground_slots.append({"node":weakref(node),"material":node.material_override})
  for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
   if node.multimesh and node.multimesh.mesh in [WarVegetation.grass_mesh(),WarVegetation.grass_low_mesh()]:legacy_slots.append({"node":weakref(node),"visible":node.visible})
 available=true

func warmup() -> void:
 if warmed or not available or DisplayServer.get_name()=="headless":return
 var viewport:=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,1.,2.5);camera.look_at(Vector3.ZERO)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-60,-20,0);stage.add_child(light)
 var grass:=MeshInstance3D.new();grass.mesh=streamer.mesh;grass.material_override=streamer.material;stage.add_child(grass)
 var distant:=MeshInstance3D.new();distant.mesh=streamer.far_mesh;distant.material_override=streamer.far_material;distant.position.x=1.;stage.add_child(distant)
 if ground:
  var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.material_override=ground;stage.add_child(floor_mesh)
 # Force actual draws only during loading. The driver can compile even when
 # the loading window is unfocused; no warmup is scheduled during gameplay.
 for variant: ArrayMesh in streamer.variants:
  grass.mesh=variant
  for frame in 3:
   await get_tree().process_frame
   RenderingServer.force_draw(false)
 viewport.queue_free();warmed=true

func apply_level(value: int) -> bool:
 if not available or not is_instance_valid(world) or not is_instance_valid(streamer):return false
 level=clampi(value,0,3)
 for item: Dictionary in ground_slots:
  var node: MeshInstance3D=item.node.get_ref()
  if is_instance_valid(node):node.material_override=ground if level>0 else item.material
 for item: Dictionary in legacy_slots:
  var node: MultiMeshInstance3D=item.node.get_ref()
  if is_instance_valid(node):node.visible=false if level>0 else bool(item.visible)
 for node: MultiMeshInstance3D in streamer.pool:node.visible=level>0 and node.multimesh.visible_instance_count>0
 for node: MultiMeshInstance3D in streamer.far_pool:node.visible=level>0 and node.multimesh.visible_instance_count>0
 streamer.set_level(maxi(1,level));streamer.set_process(level>0);set_process(level>0)
 return true

func _process(delta: float) -> void:
 if not is_instance_valid(world) or not is_instance_valid(streamer):_restore();return
 var camera:=get_viewport().get_camera_3d()
 if is_instance_valid(camera):streamer.observer=camera
 refresh_clock+=delta
 if refresh_clock<.2:return
 refresh_clock=0.
 var storm:=0.
 if map_id=="ukraine":
  var game: Node=world.get_parent()
  var clock: Variant=game.get("war_clock") if is_instance_valid(game) else null
  if clock is float or clock is int:storm=WarWeather.intensity(float(clock))
 if ground:ground.set_shader_parameter("storm",storm)
 streamer.material.set_shader_parameter("storm",storm)
 streamer.far_material.set_shader_parameter("storm",storm)

func _restore() -> void:
 if available:apply_level(0)
 level=0;refresh_clock=0.;set_process(false);available=false;warmed=false
 if is_instance_valid(streamer):streamer.clear();streamer.queue_free()
 streamer=null;ground_slots.clear();legacy_slots.clear();ground=null;biome=null;world=null

func _exit_tree() -> void:_restore()
