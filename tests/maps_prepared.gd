extends SceneTree
const DEFINITIONS=preload("res://scripts/maps/definition.gd")
const STREAM=preload("res://modes/war/scripts/grass_stream.gd")
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	for id: String in DEFINITIONS.IDS:
		check(DEFINITIONS.current(id),id+": fresh prepared sources")
		var identity:=DEFINITIONS.identity(id)
		check(DEFINITIONS.compatible(id,identity),id+": matching map admitted")
		check(not DEFINITIONS.compatible(id,{}),id+": missing map rejected")
		var wrong:=identity.duplicate();wrong.hash="wrong"
		check(not DEFINITIONS.compatible(id,wrong),id+": changed content rejected")
		wrong=identity.duplicate();wrong.version=-1
		check(not DEFINITIONS.compatible(id,wrong),id+": wrong version rejected")
		for artifact: Dictionary in DEFINITIONS.get_definition(id).get("artifacts",[]):
			check(FileAccess.get_sha256(artifact.path)==artifact.sha256,id+": artifact hash "+str(artifact.path))
		if id not in ["ukraine","afghan","desert"]:continue
		var data: Resource=load(DEFINITIONS.ROOT+id+"/grass.res")
		check(data.source_hash==DEFINITIONS.get_definition(id).source_hash,id+": grass belongs to current map")
		var total:=0
		for cell: Vector2i in data.buffers:
			var count: int=data.counts[cell];total+=count
			check(count>0 and count<=100 and data.buffers[cell].size()==1200,id+": fixed GPU capacity")
			var buffer: PackedFloat32Array=data.buffers[cell]
			for value in buffer:check(is_finite(value),id+": finite transform buffer")
		check(total==data.patches,id+": complete patch inventory")
		check(not data.far_buffers.is_empty(),id+": distant grass is prepared")
		for cell: Vector2i in data.far_buffers:
			check(int(data.far_counts[cell])>0 and int(data.far_counts[cell])<=100 and data.far_buffers[cell].size()==1200,id+": distant GPU capacity")
			for value: float in data.far_buffers[cell]:check(is_finite(value),id+": finite distant buffer")
		var world:=Node3D.new();root.add_child(world);world.position=Vector3(100,5,70);world.rotation.y=.35
		var camera:=Camera3D.new();root.add_child(camera)
		var stream:=STREAM.new();world.add_child(stream)
		if DisplayServer.get_name()=="headless":
			check(not stream.configure(world,camera,id) and stream.pool.is_empty(),id+": headless never creates visual cells")
		else:
			check(stream.configure(world,camera,id),id+": graphical renderer configured")
			stream.set_process(false)
			if stream.initialised:
				var nodes: Array=[];var far_nodes: Array=[]
				for node in stream.pool:nodes.append(node.get_instance_id())
				for node in stream.far_pool:far_nodes.append(node.get_instance_id())
				var cells: Array=data.buffers.keys();var limit:=mini(60,cells.size())
				for i in limit:
					var cell: Vector2i=cells[i*cells.size()/limit]
					camera.global_position=world.to_global(Vector3(cell.x*20.+10,2,cell.y*20.+10));stream._requeue()
					check(stream.pool.size()==49 and stream.created==49 and stream.retired_count==0,id+": teleport reuses the same 49 cells")
					check(stream.far_pool.size()==49,id+": teleport retains the distant pool")
					for j in stream.pool.size():check(stream.pool[j].get_instance_id()==nodes[j],id+": stable node identity")
					for j in stream.far_pool.size():check(stream.far_pool[j].get_instance_id()==far_nodes[j],id+": stable distant node identity")
					for key: Vector2i in stream.cells:
						var node: MultiMeshInstance3D=stream.cells[key]
						check(node.multimesh.visible_instance_count==data.counts[key],id+": valid cell recovers after empty cell")
						check(node.position==Vector3(key.x*20.,0,key.y*20.),id+": local cell origin follows transformed world")
						check(node.find_children("*","CollisionObject3D",true,false).is_empty() and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,id+": no contact or shadows")
				var material:=stream.material;var counts: int=data.counts.hash()
				for quality in [1,2,3]:
					stream.set_level(quality);check(stream.mesh==stream.variants[quality-1] and stream.material==material and data.counts.hash()==counts,id+": prepared quality changes geometry without changing patch distribution")
		stream.clear();await process_frame
		check(stream.pool.is_empty() and stream.far_pool.is_empty() and stream.cells.is_empty(),id+": release on leaving world")
		world.free();camera.free();await process_frame
	var result:={"checks":checks,"ok":errors.is_empty(),"errors":errors,"graphical":DisplayServer.get_name()!="headless"}
	NavalStorage.write_json("res://work/maps-prepared-test"+("-headless" if DisplayServer.get_name()=="headless" else "-graphical")+".json",result)
	print("MAPS_PREPARED_TEST ",JSON.stringify(result));quit(0 if errors.is_empty() else 1)
