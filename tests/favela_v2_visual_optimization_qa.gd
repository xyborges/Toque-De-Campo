extends SceneTree
## Same closed house geometry, same server collision and opt-in occluders.
const WORLD=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const POLICY=preload("res://modes/war/scripts/favela_v2_visual_optimization.gd")
var failures:Array[String]=[]
var checks:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	var enabled:bool=POLICY.enabled_by_command_line()
	check(POLICY.CELL_METERS==32.0,"32m pilot cell cap")
	var world:=Node3D.new()
	root.add_child(world)
	var data:Dictionary=WORLD.build(world,true)
	var map_root:=world.get_node("FavelaV2EstruturaAscensao") as Node3D
	var houses:Array[Node3D]=POLICY._houses(map_root)
	var metrics:Dictionary=data["visual_policy"]
	check(int(metrics.houses)==houses.size(),"house list includes west + main")
	check(houses.size()>=190,"representative V2 houses")
	check(int(metrics.lod_details)>houses.size(),"LOD applied to house details")
	check(bool(metrics.enabled)==enabled,"opt-in from explicit CLI only")
	var occluder_count:=0
	var cells:Dictionary={}
	var unchanged_colliders:=0
	var detail_lod_ok:=true
	var invalid_occluder:=false
	var structural_lod_ok:=true
	for house:Node3D in houses:
		var body:=house.get_node_or_null("Body") as StaticBody3D
		var shape:=body.get_node_or_null("Collision") as CollisionShape3D if body!=null else null
		if shape!=null and shape.shape is BoxShape3D:
			unchanged_colliders+=1
			var block:=shape.shape as BoxShape3D
			check(body.collision_layer==1,"structural house collision preserved")
			check(block.size==Vector3(11,7,10),"original house collider unchanged")
		var facade:Node=house.get_node_or_null("Edificio")
		if facade is GeometryInstance3D:
			structural_lod_ok=structural_lod_ok and (facade as GeometryInstance3D).visibility_range_end>=700.0
		for node:Node in house.get_children():
			if not str(node.name).begins_with("Reuso_"):continue
			for visual:Node in node.find_children("*","GeometryInstance3D",true,false):
				detail_lod_ok=detail_lod_ok and (visual as GeometryInstance3D).visibility_range_end<=POLICY.DETAIL_LOD_METERS
		for oc:Node in house.find_children("*","OccluderInstance3D",true,false):
			occluder_count+=1
			var pos:Vector3=house.global_position
			var cell:=Vector2i(floori(pos.x/32.0),floori(pos.z/32.0))
			if cells.has(cell):invalid_occluder=true
			cells[cell]=true
			var instance:=oc as OccluderInstance3D
			var box:=instance.occluder as BoxOccluder3D
			if box==null:invalid_occluder=true
			elif shape!=null and shape.shape is BoxShape3D:
				var original:=shape.shape as BoxShape3D
				invalid_occluder=invalid_occluder or box.size!=original.size-Vector3.ONE*POLICY.OCCLUDER_INSET
			invalid_occluder=invalid_occluder or str(instance.get_meta("source_collider",""))!="FavelaV2CasaSolida"
	check(unchanged_colliders==houses.size(),"no house loses its real collider")
	check(structural_lod_ok,"house wall silhouettes visible at distance")
	check(detail_lod_ok,"every reused facade follows distance LOD")
	check(not invalid_occluder,"one conservative occluder per 32m cell")
	check(int(metrics.occluders)==occluder_count,"reported and actual occluder count agree")
	check(occluder_count<=houses.size(),"occluders capped by number of houses")
	check(occluder_count>20 if enabled else occluder_count==0,
		"default zero, opt-in sufficient closed-house occluders")
	check(world.get_viewport().use_occlusion_culling==enabled,"viewport culling enabled only for pilot")
	# Build a full separate authority-side copy, even with the CLI pilot
	# enabled. The server must preserve every house collider, but no
	# OccluderInstance3D or facade visual optimizations are constructed.
	var server:=Node3D.new()
	world.add_child(server)
	var server_map:Dictionary=WORLD.build(server,false)
	var server_root:=server.get_node("FavelaV2EstruturaAscensao") as Node3D
	var server_houses:=POLICY._houses(server_root)
	check(server_houses.size()==houses.size(),"server keeps same buildings and collision geometry")
	check(server_root.find_children("*","OccluderInstance3D",true,false).is_empty(),
		"dedicated authority adds no occluders")
	check(int(server_map["visual_policy"]["lod_details"])==0,
		"dedicated authority never configures visual LOD")
	check(int(server_map["terrain"]["collision_shapes"])==int(data["terrain"]["collision_shapes"]),
		"server terrain and rock collision shapes unchanged")
	print("FAVELA_V2_VISUAL_OPTIMIZATION_QA ",JSON.stringify({
		"pass":failures.is_empty(),"checks":checks,"enabled":enabled,
		"houses":houses.size(),"lod_visuals":metrics.lod_details,
		"occluders":occluder_count,"unique_32m_cells":cells.size(),
		"collision_houses":unchanged_colliders,"errors":failures.slice(0,16)}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
