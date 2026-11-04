extends RefCounted

# Test-only index for the already generated trees. The real game does not
# install this manager. Stable IDs are per-cell positions sorted by the
# deterministic creation ordinal, not scene node names or object IDs.
const Model=preload("res://tests/impact_breakage_model.gd")
var model=Model.new()
var cells: Dictionary={}
var shape_to_id: Dictionary={}
var visuals: Dictionary={}
var signature:=""
var unmatched_visuals:=0
var ambiguous_ids:=0
var presentation: WeakRef

func build(world: Node3D,include_visuals: bool) -> Dictionary:
	var grouped: Dictionary={}
	for shape: CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
		if not shape.has_meta("qa_tree_ordinal"): continue
		var point:=shape.global_position
		point.y-=float((shape.shape as CylinderShape3D).height)*.5-.08
		var scale: float=shape.get_meta("qa_tree_scale")
		var green: bool=shape.get_meta("qa_tree_green")
		var cell: Vector2i=model.cell_for(point)
		if not grouped.has(cell): grouped[cell]=[]
		grouped[cell].append({"shape":shape,"position":point,"scale":scale,"green":green,"ordinal":int(shape.get_meta("qa_tree_ordinal"))})
	var ordered_cells: Array=grouped.keys()
	ordered_cells.sort_custom(func(a: Vector2i,b: Vector2i):return a.x<b.x or (a.x==b.x and a.y<b.y))
	var signature_text:=""
	for cell: Vector2i in ordered_cells:
		var entries: Array=grouped[cell]
		entries.sort_custom(func(a: Dictionary,b: Dictionary):
			if a.ordinal!=b.ordinal: return a.ordinal<b.ordinal
			if a.position.x!=b.position.x: return a.position.x<b.position.x
			if a.position.z!=b.position.z: return a.position.z<b.position.z
			if a.scale!=b.scale: return a.scale<b.scale
			return int(a.green)<int(b.green))
		var items: Array=[]
		for i in entries.size():
			var entry: Dictionary=entries[i]
			if i>0:
				var prev: Dictionary=entries[i-1]
				if prev.ordinal==entry.ordinal and prev.position==entry.position and prev.scale==entry.scale and prev.green==entry.green: ambiguous_ids+=1
			var kind: String="burnt" if not entry.green else ("thin" if entry.scale<=1.0 else "thick")
			items.append({"kind":kind,"position":entry.position})
			shape_to_id[entry.shape.get_instance_id()]={"cell":cell,"index":i}
			var key:=_position_key(entry.position)
			if not visuals.has(key): visuals[key]=[]
			visuals[key].append({"cell":cell,"index":i,"scale":entry.scale,"green":entry.green,"lod":{}})
			signature_text+="%d,%d,%d,%s,%d,%d;"%[cell.x,cell.y,entry.ordinal,kind,roundi(entry.position.x*100),roundi(entry.position.z*100)]
		cells[cell]=entries;model.register(cell,items)
	signature=signature_text.sha256_text()
	if include_visuals: _index_visuals(world)
	return {"cells":cells.size(),"trees":shape_to_id.size(),"signature":signature,"unmatched_visuals":unmatched_visuals,"ambiguous_ids":ambiguous_ids}

func _position_key(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x*100),roundi(point.z*100))

func _index_visuals(world: Node3D) -> void:
	var lookup: Dictionary={}
	for green in [false,true]:
		for variant in 3:
			for low in [false,true]: lookup[WarVegetation.tree_mesh(green,variant,low)]={"green":green,"low":low}
	for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh==null or not lookup.has(node.multimesh.mesh) or node.material_override!=EnvironmentKit.materials.get("war_vegetation169"): continue
		var info: Dictionary=lookup[node.multimesh.mesh]
		for i in node.multimesh.instance_count:
			var pose:=node.multimesh.get_instance_transform(i);var p:=node.to_global(pose.origin)
			var options: Array=visuals.get(_position_key(p),[]);var match_found:=false
			for candidate: Dictionary in options:
				var level: String="far" if info.low else "near"
				if candidate.green!=info.green or absf(candidate.scale-pose.basis.get_scale().x)>.005 or candidate.lod.has(level): continue
				candidate.lod[level]={"node":node,"index":i};match_found=true;break
			if not match_found: unmatched_visuals+=1

func apply(event: Dictionary,animate:=true) -> bool:
	if not model.apply_event(event): return false
	_present(event,animate)
	return true

func impact(cell: Vector2i,index: int,mass: float,speed: float,direction: Vector3) -> Dictionary:
	var event: Dictionary=model.impact(cell,index,mass,speed,direction)
	if not event.is_empty(): _present(event)
	return event

func explosion(point: Vector3,calibre: float,radius: float) -> Array[Dictionary]:
	var events: Array[Dictionary]=model.explosion(point,calibre,radius)
	for event in events: _present(event)
	return events

func _present(event: Dictionary,animate:=true) -> void:
	var cell: Vector2i=event.cell;var index:=int(event.index);var entry: Dictionary=cells[cell][index]
	(entry.shape as CollisionShape3D).set_deferred("disabled",true)
	for candidate: Dictionary in visuals.get(_position_key(entry.position),[]):
		if candidate.cell!=cell or candidate.index!=index: continue
		for lod: Dictionary in candidate.lod.values():
			var node: MultiMeshInstance3D=lod.node
			var pose:=node.multimesh.get_instance_transform(lod.index)
			pose.basis=Basis.from_scale(Vector3.ZERO);node.multimesh.set_instance_transform(lod.index,pose)
	var presenter: Object=presentation.get_ref() if presentation else null
	if is_instance_valid(presenter): presenter.call("on_break",event,animate)
