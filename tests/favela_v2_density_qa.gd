extends SceneTree
## Physical density/alleys/rock crest invariant, not merely screenshots.
const W=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
const DETAILS=preload("res://modes/war/scripts/favela_v2_neighborhood_details.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
var failures:Array[String]=[]
var checks:=0
func expect(cond:bool,msg:String)->void:
	checks+=1
	if not cond:failures.append(msg)
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	var main:=W.plan_houses()
	var west:=WEST.plan_houses()
	var alleys:=W.plan_alleys()
	expect(main.size()>=310,"more than 310 central houses")
	expect(main.size()+west.size()>=350,"densified district")
	expect(alleys.size()>=12,"pedestrian dead end alleys between houses")
	expect(TOPO.left_gate_links().size()==1,"one western access remains")
	expect(not TOPO.reachable("mirante","base_norte","central_hub"),
		"western hillside cannot provide north shortcut in route graph")
	var variants:Dictionary={}
	var rows:Dictionary={}
	var min_center:=INF
	var min_alley_gap:=INF
	var all:Array[Dictionary]=main.duplicate()
	all.append_array(west)
	for i in main.size():
		var h:Dictionary=main[i]
		variants[h["variant"]]=true
		rows[h["row"]]=true
		for j in range(i+1,main.size()):
			min_center=minf(min_center,h["pos"].distance_to(main[j]["pos"]))
		for path:Dictionary in alleys:
			var dist:float=h["pos"].distance_to(Geometry2D.get_closest_point_to_segment(
				h["pos"],path["a"],path["to"]))
			min_alley_gap=minf(min_alley_gap,dist)
	expect(variants.size()>=7,"seven or more visibly different facades")
	expect(rows.size()==3,"three residential terrace rows")
	expect(min_center>=W.HOUSE_CLEARANCE-.01,"no overlapping house centers")
	expect(min_alley_gap>=5.65,"2.65m alleys remain free of house boxes")
	var nearest_road_failures:=0
	for lane:Dictionary in alleys:
		var a:Vector2=lane["a"]
		var b:Vector2=lane["to"]
		if a.distance_to(b)<20 or W._left_district(b):nearest_road_failures+=1
	expect(nearest_road_failures==0,"all pedestrian alley ends are walkable cul-de-sacs")
	var max_ridge_grade:=0.0
	for x in [-265.0,-235.0,-200.0,-165.0]:
		for z in range(-254,-211,5):
			var height:=T.height_at(x,float(z))
			var neighbor:=T.height_at(x,float(z)+5)
			max_ridge_grade=maxf(max_ridge_grade,absf(height-neighbor)/5.0)
	expect(max_ridge_grade>=1.0,"rocky mountains feature an unwalkably steep flank")
	for id in ["base_sul","central_hub","base_norte","portal_oeste"]:
		var pos:Vector2=TOPO.NODES[id]["p"]
		expect(absf(T.height_at(pos.x,pos.y)-float(T.NODE_HEIGHTS[id]))<=2.0,
			"official road anchor height unchanged: "+id)
	var root3d:=Node3D.new()
	root.add_child(root3d)
	var built:Dictionary=W.build(root3d,false)
	await physics_frame
	expect(int(built["main"]["main_houses"])==main.size(),"real main house bodies match layout")
	expect(int(built["west"]["houses"])==west.size(),"west prefab bodies unchanged")
	expect(int(built["alleys_and_details"]["rock_crest_colliders"])==4,
		"four authoritative mountain colliders")
	expect(int(built["alleys_and_details"]["decorative_colliders"])==0,
		"alley/foliage do not create physics")
	expect(int(built["terrain"]["collision_shapes"])==54,
		"existing 49 chunks and 5 rocks unchanged")
	var skyline:=root3d.get_node("FavelaV2EstruturaAscensao/BecosEEncostasV2")
	var bodies:=skyline.find_children("CristaRochosaNorte_*","StaticBody3D",true,false)
	expect(bodies.size()==4,"actual mountain collision bodies exist on dedicated server")
	var invalid_shapes:=0
	for node:Node in bodies:
		var collider:CollisionShape3D=node.get_node("ParedeFisica")
		if not collider.shape is ConcavePolygonShape3D:invalid_shapes+=1
	expect(invalid_shapes==0,"rock facade collision uses same irregular mesh")
	print("FAVELA_V2_DENSITY_QA ",JSON.stringify({
		"pass":failures.is_empty(),"checks":checks,"main_houses":main.size(),
		"west_houses":west.size(),"total_houses":all.size(),
		"alleys":alleys.size(),"house_variants":variants.size(),
		"rows":rows.keys(),"closest_houses_m":snappedf(min_center,.01),
		"min_alley_center_clearance_m":snappedf(min_alley_gap,.02),
		"mountain_max_grade":snappedf(max_ridge_grade,.02),
		"ridge_physical_bodies":bodies.size(),
		"failures":failures}))
	root3d.queue_free()
	quit(0 if failures.is_empty() else 1)
