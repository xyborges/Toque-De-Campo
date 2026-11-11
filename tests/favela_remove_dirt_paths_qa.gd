extends SceneTree
## Confirms the removed 253 residential dirt overlays never spawn again.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var world := Node3D.new()
	world.name="FavelaDirtRemovalQA"
	root.add_child(world)
	WarWorld.build(world,true)
	await physics_frame
	await physics_frame
	var map := world.get_node_or_null("FavelaWar") as WarFavelaMap
	var failures: Array[String]=[]
	if map==null:
		failures.append("Favela world missing")
	else:
		if map.find_child("CaminhosDeTerraPortas",true,false)!=null:
			failures.append("Dirt path mesh still spawned")
		if map.build_metrics.has("door_footpaths") or map.build_metrics.has("door_footpaths_triangles"):
			failures.append("Old path generator still contributes metrics")
		if int(map.build_metrics.get("houses",0))<4000:
			failures.append("Houses missing after removing footpaths")
		if int(map.build_metrics.get("facade_modules",0))<20000:
			failures.append("Facade modules were removed unexpectedly")
		if int(map.build_metrics.get("pedestrian_stair_treads",0))<150:
			failures.append("Existing alley stairs missing")
	if FileAccess.file_exists("res://modes/war/scripts/favela_door_paths.gd"):
		failures.append("Old dirt path generator still present")
	if WarFavelaMap.road_envelopes().size()!=18:
		failures.append("Road network modified")
	print("FAVELA_REMOVE_DIRT_PATHS_QA ",JSON.stringify({
		"ok":failures.is_empty(),
		"houses":map.build_metrics.get("houses",0) if map else -1,
		"roads":WarFavelaMap.road_envelopes().size(),
		"pedestrian_stair_treads":map.build_metrics.get("pedestrian_stair_treads",0) if map else -1,
		"old_path_node":map.find_child("CaminhosDeTerraPortas",true,false)!=null if map else true,
		"errors":failures}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
