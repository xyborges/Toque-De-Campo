extends SceneTree

const Stream=preload("res://modes/war/scripts/grass_stream.gd")
var errors: Array[String]=[]

class PreparedData extends Resource:
 var buffers: Dictionary={}
 var counts: Dictionary={}
 var bounds: Dictionary={}
 var far_buffers: Dictionary={}
 var far_counts: Dictionary={}
 var far_bounds: Dictionary={}

func check(ok: bool,label: String) -> void:
 if not ok:errors.append(label);push_error(label)

func _initialize() -> void:run.call_deferred()

func run() -> void:
 # A headless synthetic map exercises the real fixed-pool uploader without
 # needing a GPU or a 3.5 km map. Real prepared resources are tested separately.
 var world:=Node3D.new();root.add_child(world)
 var camera:=Camera3D.new();world.add_child(camera)
 var stream:=Stream.new();world.add_child(stream)
 var prepared:=PreparedData.new()
 var buffer:=PackedFloat32Array([1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.,0.])
 for x in range(-5,30):
  for z in range(-4,5):
   var id:=Vector2i(x,z)
   prepared.buffers[id]=buffer;prepared.counts[id]=1
   prepared.bounds[id]=AABB(Vector3.ZERO,Vector3(20,2,20))
 for x in range(-4,11):
  for z in range(-4,5):
   var id:=Vector2i(x,z)
   prepared.far_buffers[id]=buffer;prepared.far_counts[id]=1
   prepared.far_bounds[id]=AABB(Vector3.ZERO,Vector3(80,2,80))
 var shader:=Shader.new();shader.code="shader_type spatial; uniform vec3 observer_position;"
 var material:=ShaderMaterial.new();material.shader=shader
 var distant_material:=ShaderMaterial.new();distant_material.shader=shader
 stream.data=prepared;stream.world=world;stream.observer=camera
 stream.material=material;stream.far_material=distant_material
 var shared_mesh:=BoxMesh.new()
 for index in stream.MAX_CELLS:
  var near:=MultiMeshInstance3D.new();var mm:=MultiMesh.new()
  mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=shared_mesh;mm.instance_count=1;mm.visible_instance_count=0
  near.multimesh=mm;near.hide();world.add_child(near);stream.pool.append(near)
  var far:=MultiMeshInstance3D.new();var fm:=MultiMesh.new()
  fm.transform_format=MultiMesh.TRANSFORM_3D;fm.mesh=shared_mesh;fm.instance_count=1;fm.visible_instance_count=0
  far.multimesh=fm;far.hide();world.add_child(far);stream.far_pool.append(far)
 stream.initialised=true;stream.set_process(false)
 stream._requeue()
 check(stream.cells.size()==3 and stream.pending.size()==46,"initial near upload capped at three")
 check(stream.far_updates==2 and stream.far_pending.size()==47,"initial far upload capped at two")
 for frame in 30:stream._requeue()
 check(stream.cells.size()==49 and stream.pending.is_empty() and stream.far_pending.is_empty(),"initial field converges")
 check(stream.max_bindings_per_frame<=5 and stream.updates==49 and stream.far_updates==49,"upload budget respected")
 var near_ids: Array=[];var far_ids: Array=[]
 for node in stream.pool:near_ids.append(node.get_instance_id())
 for node in stream.far_pool:far_ids.append(node.get_instance_id())
 camera.position.x=400.
 stream._requeue()
 check(stream.pending.size()<=46 and stream.far_pending.size()<=47,"teleport does not upload entire field at once")
 for node in stream.pool:
  if node.visible:
   var id: Vector2i=node.get_meta("cell",stream.INVALID_CELL)
   check(id.x>=17 and id.x<=23,"teleport hides stale near buffers before replacement")
 camera.position.x=500.
 stream._requeue()
 for frame in 30:stream._requeue()
 check(stream.pending.is_empty() and stream.far_pending.is_empty() and stream.cells.size()==49,"interrupted teleport resumes at latest destination")
 for id: Vector2i in stream.cells:check(id.x>=22 and id.x<=28,"no abandoned near cell reappears")
 for index in stream.MAX_CELLS:
  check(stream.pool[index].get_instance_id()==near_ids[index] and stream.far_pool[index].get_instance_id()==far_ids[index],"pool identity remains stable")
 camera.position.x=900.
 stream._requeue()
 check(stream.cells.is_empty() and stream.pending.is_empty(),"out-of-bounds teleport hides old near field")
 stream.clear()
 check(stream.pool.is_empty() and stream.far_pool.is_empty() and stream.far_pending.is_empty(),"cleanup releases queue and fixed pools")
 world.queue_free()
 await process_frame
 print("GRASS_STREAM_BUDGET ",JSON.stringify({"ok":errors.is_empty(),"errors":errors}))
 quit(0 if errors.is_empty() else 1)
