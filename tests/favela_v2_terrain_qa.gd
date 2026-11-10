extends SceneTree
## Test physical ground on dedicated authority; same mesh in Forward+ client.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
var failures: Array[String]=[]
var checks:=0

func expect(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	# Phase 1 structural invariant must survive a physical implementation.
	expect(TOPO.left_gate_links().size()==1,"single entrance of west hillside")
	expect(TOPO.reachable("base_sul","base_norte","portal_oeste"),
		"base-to-base path never depends on west barrio")
	expect(not TOPO.reachable("mirante","base_norte","central_hub"),
		"west cannot traverse to north base with center isolated")
	var begun:=Time.get_ticks_msec()
	var world:=Node3D.new()
	root.add_child(world)
	var metrics: Dictionary=T.build(world,false)
	await physics_frame
	await physics_frame
	for prefab_id in ["favela_v2_terrain_chunk","favela_v2_rock_barrier"]:
		expect(WarPrefabFactory.ITEMS.has(prefab_id),"V2 module in editor catalog: "+prefab_id)
		var template:=WarPrefabFactory.create(prefab_id)
		expect(template!=null,"V2 prefab can be loaded: "+prefab_id)
		if template!=null:
			expect(template.get_meta("library_id","")==prefab_id,"V2 prefab metadata: "+prefab_id)
			template.free()
	expect(int(metrics.chunks)==54,"54 terrain chunks, not single giant mesh")
	expect(int(metrics.collision_shapes)==70,"54 chunk physics plus 16 impassable rock faces")
	expect(int(metrics.west_rock_faces)==16,"all 16 rock barriers present on authority")
	expect(int(metrics.grid_vertices)==20691,"heightfield vertex budget")
	expect(int(metrics.terrain_triangles)==40800,"40,800 triangles in base terrain")
	expect(int(metrics.road_visual_triangles)==0,"headless server no decorative road mesh")
	expect(int(metrics.west_cliff_segments)==16,"west perimeter split into two ridges with one gate")
	var scene:=world.get_node("FavelaV2Terreno")
	expect(scene.get_child_count()==70,"54 physical tiles plus 16 rock faces")
	var ray_misses:=0
	var ray_error:=0.0
	var visited:=0
	var unique: Dictionary={}
	var state:=world.get_world_3d().direct_space_state
	for node_id: String in TOPO.NODES.keys():
		var point: Vector2=TOPO.NODES[node_id]["p"]
		var floor_h:float=T.height_at(point.x,point.y)
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,floor_h+18.0,point.y),
			Vector3(point.x,floor_h-18.0,point.y),1)
		var contact: Dictionary=state.intersect_ray(ray)
		if contact.is_empty():
			ray_misses+=1
			continue
		var y:float=contact["position"].y
		ray_error=maxf(ray_error,absf(y-floor_h))
		var body: Object=contact["collider"]
		if body is Node:unique[str((body as Node).name)]=true
		visited+=1
	expect(ray_misses==0,"all 25 graph nodes have physical ground")
	expect(ray_error<.16,"height samples agree with trimesh physics")
	var max_regular_grade:=0.0
	var max_stairs_grade:=0.0
	var checked_pieces:=0
	for edge: Dictionary in TOPO.LINKS:
		var poly:=TOPO.polyline(edge)
		for i in poly.size()-1:
			var a: Vector2=poly[i]
			var b: Vector2=poly[i+1]
			var portions:=maxi(1,ceili(a.distance_to(b)/4.0))
			var oldp:=a
			for j in range(1,portions+1):
				var p: Vector2=a.lerp(b,float(j)/float(portions))
				var grade:=absf(T.height_at(p.x,p.y)-T.height_at(oldp.x,oldp.y))/p.distance_to(oldp)
				if str(edge["kind"])=="escada":
					max_stairs_grade=maxf(max_stairs_grade,grade)
				else:
					max_regular_grade=maxf(max_regular_grade,grade)
				oldp=p
				checked_pieces+=1
	expect(max_regular_grade<.58,"normal roads and alleys have passable grade")
	expect(max_stairs_grade<.90,"stair corridors not near-vertical cliffs")
	var west_gate: Vector2=TOPO.NODES["portal_oeste"]["p"]
	var gate_h:=T.height_at(west_gate.x,west_gate.y)
	expect(absf(gate_h-float(T.NODE_HEIGHTS["portal_oeste"]))<.25,
		"the only authorized gate is physically flat")
	# A wall north of the west houses must stand between left terraces
	# and the north base, not between the north base and its road.
	var ridge:=T.height_at(-310,-203)
	var inner:=T.height_at(-310,-170)
	var outside:=T.height_at(-310,-230)
	var barrier_rise:=ridge-maxf(inner,outside)
	expect(barrier_rise>7.0,"northwest cliff physically divides the left sector")
	var right_base:=TOPO.NODES["base_norte"]["p"]
	expect(absf(T.height_at(right_base.x,right_base.y)-float(T.NODE_HEIGHTS["base_norte"]))<.4,
		"north base still has a flat spawn pad")
	var duration:=Time.get_ticks_msec()-begun
	print("FAVELA_V2_TERRAIN_QA ",JSON.stringify({
		"pass":failures.is_empty(),"checks":checks,"chunks":metrics.chunks,
		"triangles":metrics.terrain_triangles,"grid_points":metrics.grid_vertices,
		"road_segments":TOPO.LINKS.size(),"samples_grade":checked_pieces,
		"terrain_raycasts":visited,"ray_misses":ray_misses,
		"max_ray_error":ray_error,"ordinary_max_grade":max_regular_grade,
		"stairs_max_grade":max_stairs_grade,
		"west_north_barrier_rise_m":barrier_rise,"west_gate_m":gate_h,
		"build_ms":duration,"errors":failures.slice(0,12)}))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
