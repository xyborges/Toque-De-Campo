extends Node3D

# Fixed, preallocated renderer. No terrain sampling, generation, loading or
# allocation of scene nodes at cell boundaries during a match.
const DEFINITIONS=preload("res://scripts/maps/definition.gd")
const ASSETS=preload("res://modes/war/scripts/grass_assets.gd")
const CELL:=20.0
const PATCH:=2.0
const RADIUS:=3
const GRID:=RADIUS*2+1
const MAX_CELLS:=GRID*GRID
const FOOTPRINT_HALF:=1.35
var world: Node3D
var observer: Camera3D
var data: Resource
var mesh: ArrayMesh
var material: ShaderMaterial
var cells: Dictionary={}
var pool: Array[MultiMeshInstance3D]=[]
var pending: Array[Vector2i]=[]
var retired: Array[Vector2i]=[] # Diagnostic compatibility; pool cells are never retired.
var centre:=Vector2i(2147483647,2147483647)
var created:=0
var retired_count:=0
var max_build_ms:=0.0
var max_cell_cpu_ms:=0.0
var max_candidates_per_frame:=0
var peak_cell_count:=0
var initialised:=false
var level:=2
var map_id:="ukraine"
var updates:=0
var last_update_ms:=0.0
var last_update_cells:=0
var visible_instances:=0
var far_pool: Array[MultiMeshInstance3D]=[]
var far_material: ShaderMaterial
var far_mesh: ArrayMesh
var variants: Array[ArrayMesh]=[]
var far_centre:=Vector2i(2147483647,2147483647)
var far_updates:=0

func _ready() -> void:
 set_process(false)

func set_level(value: int) -> void:
 level=clampi(value,1,3)
 if variants.size()==3:
  mesh=variants[level-1]
  for node in pool:node.multimesh.mesh=mesh
 # Patch positions, height, and the 220 m outer extent stay identical.

func configure(target_world: Node3D,target_camera: Camera3D=null,key:="ukraine") -> bool:
 if initialised or not is_inside_tree() or DisplayServer.get_name()=="headless":return false
 if not is_instance_valid(target_world) or not target_world.is_inside_tree():return false
 if not DEFINITIONS.current(key):return false
 var path:=DEFINITIONS.ROOT+key+"/grass.res"
 if not ResourceLoader.exists(path):return false
 data=load(path)
 if data.map_id!=key or data.source_hash!=DEFINITIONS.get_definition(key).get("source_hash","") or data.capacity!=100:return false
 map_id=key;world=target_world;observer=target_camera
 var folder: String=DEFINITIONS.ROOT+key+"/"
 if not ResourceLoader.exists(folder+"grass_mesh.res") or not ResourceLoader.exists(folder+"grass_material.res"):return false
 mesh=load(folder+"grass_mesh.res");material=load(folder+"grass_material.res").duplicate() as ShaderMaterial
 if not ResourceLoader.exists(folder+"grass_far_mesh.res") or data.far_buffers.is_empty():return false
 variants.assign([load(folder+"grass_mesh_low.res"),mesh,load(folder+"grass_mesh_high.res")])
 far_mesh=load(folder+"grass_far_mesh.res");material.set_shader_parameter("prepared_field",true)
 far_material=material.duplicate() as ShaderMaterial;far_material.set_shader_parameter("distant",true)
 material.set_shader_parameter("dry",1.0 if key=="desert" else 0.0)
 far_material.set_shader_parameter("dry",1.0 if key=="desert" else 0.0)
 var empty:=PackedFloat32Array();empty.resize(1200)
 for index in MAX_CELLS:
  var node:=ASSETS.create_cell(mesh,material,100);var mm:=node.multimesh
  mm.buffer=empty;mm.visible_instance_count=0
  node.name="GrassPool_%02d"%index
  node.visibility_range_end=100.
  world.add_child(node);node.hide();pool.append(node)
  var low:=ASSETS.create_cell(far_mesh,far_material,100);low.name="GrassFarPool_%02d"%index
  low.visibility_range_end=360.;low.multimesh.buffer=empty;low.multimesh.visible_instance_count=0
  world.add_child(low);low.hide();far_pool.append(low)
 created=pool.size();peak_cell_count=pool.size();initialised=true;set_process(true)
 _requeue();return true

func _requeue() -> void:
 if not initialised or not is_instance_valid(observer):return
 material.set_shader_parameter("observer_position",observer.global_position)
 far_material.set_shader_parameter("observer_position",observer.global_position)
 _requeue_far()
 var pos:=world.to_local(observer.global_position)
 var next:=Vector2i(floori(pos.x/CELL),floori(pos.z/CELL))
 if next==centre:return
 var started:=Time.get_ticks_usec();centre=next;cells.clear();last_update_cells=0;visible_instances=0
 for z in range(-RADIUS,RADIUS+1):
  for x in range(-RADIUS,RADIUS+1):
   var id:=centre+Vector2i(x,z)
   var index:=posmod(id.y,GRID)*GRID+posmod(id.x,GRID)
   var node:=pool[index]
   if not data.buffers.has(id):
    node.hide();node.multimesh.visible_instance_count=0
    node.set_meta("cell",Vector2i(2147483647,2147483647));continue
   if node.get_meta("cell",Vector2i(2147483647,2147483647))!=id:
    node.position=Vector3(id.x*CELL,0,id.y*CELL)
    node.multimesh.buffer=data.buffers[id];node.multimesh.custom_aabb=data.bounds[id]
    node.multimesh.visible_instance_count=int(data.counts[id]);node.set_meta("cell",id);updates+=1;last_update_cells+=1
   visible_instances+=node.multimesh.visible_instance_count;node.show();cells[id]=node
 last_update_ms=float(Time.get_ticks_usec()-started)*.001
 max_build_ms=maxf(max_build_ms,last_update_ms)

func _requeue_far() -> void:
 var pos:=world.to_local(observer.global_position)
 var next:=Vector2i(floori(pos.x/80.),floori(pos.z/80.))
 if next==far_centre:return
 far_centre=next
 for z in range(-RADIUS,RADIUS+1):
  for x in range(-RADIUS,RADIUS+1):
   var id:=far_centre+Vector2i(x,z);var node:=far_pool[posmod(id.y,GRID)*GRID+posmod(id.x,GRID)]
   if not data.far_buffers.has(id):
    node.hide();node.multimesh.visible_instance_count=0;node.set_meta("cell",Vector2i(2147483647,2147483647));continue
   if node.get_meta("cell",Vector2i(2147483647,2147483647))!=id:
    node.position=Vector3(id.x*80.,0,id.y*80.);node.multimesh.buffer=data.far_buffers[id];node.multimesh.custom_aabb=data.far_bounds[id]
    node.multimesh.visible_instance_count=int(data.far_counts[id]);node.set_meta("cell",id);far_updates+=1
   node.show()

func _process(_delta: float) -> void:
 if not initialised:return
 if not is_instance_valid(world):clear();return
 _requeue()

func clear() -> void:
 initialised=false;set_process(false)
 for node in pool:
  if is_instance_valid(node):node.hide();node.queue_free()
 for node in far_pool:
  if is_instance_valid(node):node.hide();node.queue_free()
 far_pool.clear();variants.clear();far_material=null;far_mesh=null;far_centre=Vector2i(2147483647,2147483647)
 pool.clear();cells.clear();pending.clear();data=null;mesh=null;material=null;world=null;observer=null
 centre=Vector2i(2147483647,2147483647)

func _exit_tree() -> void:clear()
