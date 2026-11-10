extends SceneTree
## Regression: deterministic dirt footpaths to real residential doorways.
const PATHS=preload("res://modes/war/scripts/favela_door_paths.gd")
var errors: Array[String]=[]
func check(condition: bool,label: String) -> void:
	if not condition:errors.append(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var roads: Array[Dictionary]=[{"id":0,"width":3.0,"points":[Vector2(0,0),Vector2(0,25)]}]
	var doors: Array[Dictionary]=[
		{"position":Vector2(5,10),"outward":Vector2(-1,0)},
		{"position":Vector2(5,15),"outward":Vector2(1,0)},
		{"position":Vector2(20,20),"outward":Vector2(-1,0)}
	]
	var planned:=PATHS.plan(doors,roads)
	check(planned.size()==1,"only correctly oriented nearby door receives path")
	if planned.size()==1:
		check(absf(float(planned[0].length)-3.5)<.01,"path terminates at street edge")
		check(int(planned[0].road)==0,"path is connected to road")
	var probe:=Node3D.new()
	root.add_child(probe)
	var visual:=PATHS.populate(probe,doors,roads,
		func(_x: float,_z: float)->float:return 0.0,true)
	check(int(visual.door_footpaths_triangles)>0,"visual mesh has dirt triangles")
	check(probe.get_child_count()==1 and probe.get_child(0) is MeshInstance3D,
		"one batched visual mesh without any collision bodies")
	probe.queue_free()
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var world:=Node3D.new()
	root.add_child(world)
	WarWorld.build(world,false)
	await physics_frame
	var map:=world.get_node_or_null("FavelaWar") as WarFavelaMap
	check(map!=null,"favela instantiated")
	if map!=null:
		var count:=int(map.build_metrics.get("door_footpaths",0))
		var paths:=PATHS.plan(map.door_accesses,WarFavelaMap.road_envelopes())
		check(paths.size()==count,"all doors use deterministic plan")
		check(count>=100,"sufficient residential routes to make noticeable detail")
		check(int(map.build_metrics.get("door_footpaths_triangles",-1))==0,
			"headless dedicated physics creates no visual triangles")
		for item: Dictionary in paths:
			check(float(item.length)<=PATHS.MAX_LENGTH,"paths are short")
		print("FAVELA_DOOR_PATHS_QA ",JSON.stringify({"ok":errors.is_empty(),
			"houses":int(map.build_metrics.get("houses",0)),
			"doors":map.door_accesses.size(),"paths":count,"errors":errors.slice(0,10)}))
	world.queue_free()
	quit(0 if errors.is_empty() else 1)
