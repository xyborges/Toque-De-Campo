extends SceneTree
var graphical:=false
class FakeGame extends Node3D:
	var weather_seed:=0
	var war_clock:=0.0

func _initialize() -> void:
	graphical="--graphical" in OS.get_cmdline_user_args()
	run.call_deferred()

func run() -> void:
	var game:=FakeGame.new();root.add_child(game)
	var world:=Node3D.new();world.set_meta("qa_breakable_index",true);game.add_child(world)
	WarWorld.build(world,graphical)
	await process_frame;await physics_frame
	var index=load("res://tests/war_tree_index.gd").new()
	var stats: Dictionary=index.build(world,graphical)
	var near:=0;var far:=0
	for candidates: Array in index.visuals.values():
		for candidate: Dictionary in candidates:
			if candidate.lod.has("near"): near+=1
			if candidate.lod.has("far"): far+=1
	var cell:=Vector2i.ZERO;var selected:=-1
	for key: Vector2i in index.cells:
		for i in index.cells[key].size():
			if index.model.cells[key][i].kind=="thin": cell=key;selected=i;break
		if selected>=0: break
	var errors: Array[String]=[]
	if stats.trees<4000: errors.append("incomplete tree registry")
	if int(stats.ambiguous_ids)>0: errors.append("ambiguous deterministic tree IDs")
	if selected<0: errors.append("no thin tree")
	elif graphical and (stats.unmatched_visuals>0 or near!=stats.trees or far!=stats.trees): errors.append("visual and collision mapping incomplete")
	if selected>=0:
		var entry: Dictionary=index.cells[cell][selected]
		var shape: CollisionShape3D=entry.shape;var body:=shape.get_parent() as StaticBody3D
		var owners:=body.get_shape_owners()
		var event: Dictionary=index.impact(cell,selected,30000.,4.,Vector3.RIGHT)
		if event.is_empty(): errors.append("impact not accepted")
		await process_frame;await physics_frame
		if not shape.disabled or body.get_shape_owners()!=owners: errors.append("collider or stable owner")
		if graphical:
			for candidate: Dictionary in index.visuals.get(index._position_key(entry.position),[]):
				if candidate.cell!=cell or candidate.index!=selected: continue
				for lod: Dictionary in candidate.lod.values():
					if lod.node.multimesh.get_instance_transform(lod.index).basis.determinant()!=0.: errors.append("visual still visible")
	stats["near"]=near;stats["far"]=far;stats["errors"]=errors;stats["ok"]=errors.is_empty();stats["graphical"]=graphical
	var path:="res://work/war-tree-index-"+("graphical" if graphical else "headless")+".json"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(stats));file.close()
	print(JSON.stringify(stats));quit(0 if errors.is_empty() else 1)
