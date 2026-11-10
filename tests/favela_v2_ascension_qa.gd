extends SceneTree
## Stage 1: validate real 3D hillside, compact S streets, reused prefabs.
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WORLD=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
var failures:Array[String]=[]
var checks:=0
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	expect(TOPO.TEAM_BASES[1]=="base_sul","police starts below")
	expect(TOPO.TEAM_BASES[2]=="base_norte","traffickers defend summit")
	expect(TOPO.BOUNDS.size==Vector2(640,670),"compact uphill footprint")
	expect(TOPO.left_gate_links().size()==1,"west ONLY connected to middle")
	expect(not TOPO.reachable("mirante","base_norte","central_hub"),
		"no upper-base shortcut through west")
	expect(TOPO.reachable("base_sul","base_norte","portal_oeste"),
		"main ascent never needs western district")
	var path:=TOPO.shortest_path("base_sul","base_norte")
	expect(path.size()>=8,"many bends on base-to-base climb")
	expect(TOPO.path_meters(path)>620,"main ascent S-route longer than straight")
	var pos:Vector2=TOPO.NODES["base_sul"]["p"]
	var top:Vector2=TOPO.NODES["base_norte"]["p"]
	expect(top.y<pos.y-500,"highest base is geometrically at NORTH/top")
	expect(T.NODE_HEIGHTS["base_norte"]-T.NODE_HEIGHTS["base_sul"]>=85,
		"significant 88m vertical gain")
	var climb_z:Array[float]=[250.0,165.0,80.0,0.0,-90.0,-180.0,-280.0]
	var heights:Array[float]=[]
	for z in climb_z:
		heights.append(T._natural(Vector2(-110,z)))
	for i in heights.size()-1:
		expect(heights[i+1]>heights[i]+5.0,"continuous uphill natural slope "+str(i))
	var begin:=Time.get_ticks_msec()
	var parent:=Node3D.new()
	root.add_child(parent)
	var stats:Dictionary=WORLD.build(parent,false)
	await physics_frame
	await physics_frame
	var terrain:Dictionary=stats["terrain"]
	var west:Dictionary=stats["west"]
	var urban:Dictionary=stats["main"]
	expect(int(terrain.chunks)==49,"49 terrain tiles on 640 x 670")
	expect(int(terrain.terrain_triangles)==34304,"terrain 34,304 triangles")
	expect(int(terrain.west_rock_faces)==5,"five OUTCROPS, no enclosing ring")
	expect(int(terrain.collision_shapes)==54,"terrain + five rock shape budget")
	expect(int(stats.western_gateways)==1,"west is cul-de-sac")
	expect(int(west.houses)>=20,"west houses remain in side sector")
	expect(int(urban.main_houses)>=35,"reused main-road houses appear")
	expect(int(urban.reused_modules)==0,"dedicated server no visuals")
	expect(int(stats.campinho)==1,"reused soccer field exists")
	var body:Node=parent.get_node("FavelaV2EstruturaAscensao")
	var west_root:Node=body.get_node("FavelaV2MorroEsquerdo")
	var central:Node=body.get_node("CasasAoLongoDaSubida")
	var field:Node=body.get_node("CampinhoV2")
	expect(central.get_child_count()==int(urban.main_houses),"actual house prefabs")
	expect(west_root.get_child_count()>=6,"stair groups and houses present")
	expect(field.get_node_or_null("ContatoQuadra")!=null,"field prefab physical")
	var space:=parent.get_world_3d().direct_space_state
	var misses:=0
	for id:String in TOPO.NODES.keys():
		var p:Vector2=TOPO.NODES[id]["p"]
		var h:=T.height_at(p.x,p.y)
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(p.x,h+21,p.y),
			Vector3(p.x,h-21,p.y),1)
		if space.intersect_ray(ray).is_empty():misses+=1
	expect(misses==0,"all 25 real anchor points have ground")
	for id in ["base_sul","base_norte"]:
		var p:Vector2=TOPO.NODES[id]["p"]
		var h:=T.height_at(p.x,p.y)
		expect(absf(h-float(T.NODE_HEIGHTS[id]))<.5,
			"flat spawn pad correct: "+id)
	var west_branches:int=TOPO.left_gate_links().size()
	var time_ms:=Time.get_ticks_msec()-begin
	print("FAVELA_V2_ASCENSAO_QA ",JSON.stringify({
		"pass":failures.is_empty(),"checks":checks,
		"size":str(TOPO.BOUNDS.size),"roads":TOPO.LINKS.size(),
		"main_route_m":TOPO.path_meters(path),
		"climb_m":T.NODE_HEIGHTS["base_norte"]-T.NODE_HEIGHTS["base_sul"],
		"spine_heights":heights,"west_gateways":west_branches,
		"terrain_chunks":terrain.chunks,"rock_outcrops":terrain.west_rock_faces,
		"west_houses":west.houses,"main_houses":urban.main_houses,
		"west_stair_treads":west.treads,
		"ground_ray_misses":misses,"build_ms":time_ms,
		"failures":failures.slice(0,20)}))
	parent.queue_free()
	quit(0 if failures.is_empty() else 1)
