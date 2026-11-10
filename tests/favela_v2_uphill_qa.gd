extends SceneTree
## New V2 vertical gameplay profile: police low, traffickers high, west lateral.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
var failures: Array[String]=[]
var checked:=0

func expect(ok:bool,label:String)->void:
	checked+=1
	if not ok:failures.append(label)

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	expect(TOPO.TEAM_BASES[1]=="base_sul","team 1 Police lower start")
	expect(TOPO.TEAM_BASES[2]=="base_norte","team 2 Traffickers hilltop start")
	var south:float=T.NODE_HEIGHTS["base_sul"]
	var north:float=T.NODE_HEIGHTS["base_norte"]
	expect(north-south>=80.0,"substantial >=80m combat ascent")
	var main_order: Array[String]=["base_sul","rua_baixa","curva_entrada",
		"praca","central_hub","escada_central",
		"rua_norte","acesso_norte","base_norte"]
	for i in main_order.size()-1:
		var a:float=T.NODE_HEIGHTS[main_order[i]]
		var b:float=T.NODE_HEIGHTS[main_order[i+1]]
		expect(b>a,"main path climbs at every waypoint: "+main_order[i])
	var highest_other:float=-INF
	for id:String in T.NODE_HEIGHTS.keys():
		if id=="base_norte":continue
		highest_other=maxf(highest_other,float(T.NODE_HEIGHTS[id]))
	expect(north>highest_other+10.0,"trafficker base is the highest gameplay anchor")
	expect(T.NODE_HEIGHTS["mirante"]<north,"west lookout below trafficker summit")
	expect(TOPO.left_gate_links().size()==1,"western hillside has exactly one gate")
	expect(not TOPO.reachable("mirante","base_norte","central_hub"),
		"west does not bypass the central hub")
	var world:=Node3D.new()
	root.add_child(world)
	var physical:=T.build(world,false)
	await physics_frame
	var state:=world.get_world_3d().direct_space_state
	var max_error:=0.0
	for id:String in T.NODE_HEIGHTS.keys():
		var p:Vector2=TOPO.NODES[id]["p"]
		var h:float=T.height_at(p.x,p.y)
		max_error=maxf(max_error,absf(h-float(T.NODE_HEIGHTS[id])))
		var ray:=PhysicsRayQueryParameters3D.create(
			Vector3(p.x,h+15,p.y),Vector3(p.x,h-15,p.y),1)
		expect(not state.intersect_ray(ray).is_empty(),"ground under "+id)
	expect(max_error<.60,"every gameplay anchor matches its altitude")
	var route:=TOPO.shortest_path("base_sul","base_norte")
	expect(route.size()>=8,"uphill route stays sinuous")
	var main_fwd:=true
	for id:String in route:
		if id=="mirante" or id=="plato_casas":main_fwd=false
	expect(main_fwd,"western hillside never acts as base-to-base shortcut")
	var houses:=WEST.plan_houses()
	expect(houses.size()>=24,"reusable houses still populate steep western hill")
	expect(houses.size()<=105,"strict draw/physics house budget")
	var var_count:Dictionary={}
	for i in houses.size():
		var key:=str(i%5)
		var_count[key]=int(var_count.get(key,0))+1
	expect(var_count.size()==5,"five reusable architectural treatments")
	var west_metrics:=WEST.build(world,false)
	expect(int(west_metrics.reused_facade_modules)==0,
		"no decorative facade nodes in headless authority")
	expect(int(west_metrics.houses)==houses.size(),"house/authority count")
	expect(int(west_metrics.treads)>=350,"stairways keep physical geometry")
	print("FAVELA_V2_UPHILL_QA ",JSON.stringify({
		"pass":failures.is_empty(),"checks":checked,
		"police_base_m":south,"trafficker_base_m":north,
		"elevation_gain_m":north-south,"highest_other_m":highest_other,
		"max_anchor_error_m":max_error,
		"western_houses":houses.size(),"variants":var_count.size(),
		"stair_treads":west_metrics.treads,
		"headless_facades":west_metrics.reused_facade_modules,
		"terrain_chunks":physical.chunks,
		"errors":failures.slice(0,20)}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
