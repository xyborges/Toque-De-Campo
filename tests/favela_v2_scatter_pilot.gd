extends SceneTree
## Actual ProtonScatter 4.x render path vs built-in MultiMesh baseline.
## The scatter source is the game's existing favela_arbusto_encosta.tscn.
## Transforms are deterministic placements away from the 29 streets/bases.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WORLD=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
# Do NOT static-preload optional plugins: other branches must load the game
# without these addons installed. Load only while running the benchmark.
const SHRUB_SCENE=preload("res://modes/war/library/favela_arbusto_encosta.tscn")
const COUNT:=480
static func valid(p:Vector2)->bool:
	if WORLD._distance_from_roads(p)<7.0:return false
	if not TOPO.BOUNDS.grow(-18).has_point(p):return false
	for id in ["base_sul","base_norte","campinho"]:
		if p.distance_to(TOPO.NODES[id]["p"])<35:return false
	return true

static func make_transforms()->Array[Transform3D]:
	var result:Array[Transform3D]=[]
	var random:=RandomNumberGenerator.new()
	random.seed=20261110
	var tries:=0
	while result.size()<COUNT and tries<50000:
		tries+=1
		var x:=random.randf_range(TOPO.BOUNDS.position.x,TOPO.BOUNDS.end.x)
		var z:=random.randf_range(TOPO.BOUNDS.position.y,TOPO.BOUNDS.end.y)
		var p:=Vector2(x,z)
		if not valid(p):continue
		var t:=Transform3D.IDENTITY
		t.origin=Vector3(x,T.height_at(x,z),z)
		t.basis=Basis(Vector3.UP,random.randf_range(-PI,PI)).scaled(
			Vector3.ONE*random.randf_range(.65,1.3))
		result.append(t)
	return result

static func create_proton(parent:Node3D,placements:Array[Transform3D])->Dictionary:
	var begun:=Time.get_ticks_msec()
	var scatter_script:Script=load("res://addons/proton_scatter/src/scatter.gd")
	var item_script:Script=load("res://addons/proton_scatter/src/scatter_item.gd")
	var transforms_script:Script=load("res://addons/proton_scatter/src/common/transform_list.gd")
	if scatter_script==null or item_script==null or transforms_script==null:
		return {"node":null,"build_ms":-1,"error":"optional ProtonScatter addon absent"}
	var scatter:=scatter_script.new() as Node3D
	scatter.name="ProtonScatterV2"
	scatter.set("force_rebuild_on_load",false)
	scatter.set("enable_updates_in_game",false)
	scatter.set("keep_static_colliders",false)
	scatter.set("render_mode",0)
	scatter.set("Performance/use_chunks",false)
	var item:=item_script.new() as Node3D
	item.name="ProtonVegetacao"
	item.set("source",1)
	item.set("path","res://modes/war/library/favela_arbusto_encosta.tscn")
	item.set("lod_generate",false)
	item.set("visibility_range_end",185.0)
	item.set("override_cast_shadow",GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	scatter.add_child(item)
	parent.add_child(scatter)
	scatter.call("_discover_items")
	var transform_list=transforms_script.new()
	transform_list.append(placements)
	scatter.set("transforms",transform_list)
	scatter.call("_update_multimeshes")
	return {"node":scatter,"build_ms":Time.get_ticks_msec()-begun}

static func create_native(parent:Node3D,placements:Array[Transform3D])->Dictionary:
	var begun:=Time.get_ticks_msec()
	var library=SHRUB_SCENE.instantiate() as Node3D
	var mesh_instance:=library.get_node("Forma") as MeshInstance3D
	var multimesh:=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=mesh_instance.mesh
	multimesh.instance_count=placements.size()
	for i in placements.size():
		multimesh.set_instance_transform(i,placements[i])
	var node:=MultiMeshInstance3D.new()
	node.name="NativeMultiMeshV2"
	node.multimesh=multimesh
	node.material_override=mesh_instance.material_override
	node.visibility_range_end=185
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	library.free()
	return {"node":node,"build_ms":Time.get_ticks_msec()-begun}

func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	var positions:=make_transforms()
	var root_node:=Node3D.new()
	root.add_child(root_node)
	var result:=create_proton(root_node,positions)
	await process_frame
	var scatter:Node3D=result["node"]
	var nodes=scatter.find_children("*","MultiMeshInstance3D",true,false)
	var rendered:=0
	for node:Node in nodes:
		rendered+=(node as MultiMeshInstance3D).multimesh.instance_count
	var other:=create_native(root_node,positions)
	var native:MultiMeshInstance3D=other["node"]
	var invalid_road_placements:=0
	for t:Transform3D in positions:
		if not valid(Vector2(t.origin.x,t.origin.z)):invalid_road_placements+=1
	var physics_nodes:=scatter.find_children("*","CollisionObject3D",true,false).size()
	var ok:=positions.size()==COUNT and rendered==COUNT and physics_nodes==0 and invalid_road_placements==0
	print("FAVELA_V2_PROTON_SCATTER_PILOT ",JSON.stringify({
		"pass":ok,"proton_render_mode":"real ProtonScatter MultiMesh",
		"seed":20261110,"placements":positions.size(),"rendered":rendered,
		"proton_multimeshes":nodes.size(),"native_multimeshes":1,
		"proton_build_ms":result["build_ms"],"native_build_ms":other["build_ms"],
		"unwanted_physics_bodies":physics_nodes,
		"blocked_roads":invalid_road_placements}))
	root_node.queue_free()
	quit(0 if ok else 1)
