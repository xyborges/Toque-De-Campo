extends SceneTree
## Geometry acceptance, not a frame-rate benchmark. Runs on the same Jolt
## collision generated for server/client, independently of the Ukraine map.
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const LIB:="res://modes/battle_royale/library/"
var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}
var world: Node3D
var map: Node3D

func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)

func ray_floor(p: Vector3,up:=.05,down:=1.) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*up,p-Vector3.UP*down,1))

func capsule_clear(p: Vector3,height:=1.75,radius:=.32) -> bool:
	var shape:=CapsuleShape3D.new();shape.height=height;shape.radius=radius
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.transform.origin=p+Vector3.UP*(height*.5+.05)
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func run() -> void:
	world=Node3D.new();root.add_child(world)
	map=MAP.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame;await physics_frame
	var first_layout: Array=MAP.building_layout();var second_layout: Array=MAP.building_layout()
	check(var_to_bytes(first_layout)==var_to_bytes(second_layout),"Building layout deterministic")
	check(first_layout.size()>=70,"Settlement density retained")
	check(map.find_children("*","MultiMeshInstance3D",true,false).is_empty(),"Authority creates no decorative MultiMeshes")
	check(map.find_children("*","MeshInstance3D",true,false).is_empty(),"Authority skips visual meshes")
	var spawns: Array=MAP.spawn_candidates()
	check(spawns.size()>=18,"Distributed spawn candidates")
	var smallest_separation:=INF
	for i in spawns.size():
		var point: Vector3=spawns[i]
		check(MAP.accessible(point),"Spawn terrain slope accessible %s"%point)
		check(capsule_clear(point),"Spawn capsule unobstructed %s"%point)
		check(not ray_floor(point,.2,1.).is_empty(),"Spawn supported %s"%point)
		if map.has_method("is_water"): check(not map.call("is_water",point),"Spawn outside water %s"%point)
		for j in range(i+1,spawns.size()): smallest_separation=minf(smallest_separation,point.distance_to(spawns[j]))
	measurements.spawn_min_separation=smallest_separation
	check(smallest_separation>2.,"Spawn anchors do not overlap")
	var loot: Array=MAP.loot_points()
	check(loot.size()>100,"Authored loot anchors present")
	for point: Vector3 in loot:
		check(not ray_floor(point,.06,.8).is_empty(),"Loot supported by floor, roof or crate %s"%point)
		var nearby_building:=false
		for record: Dictionary in first_layout:
			if point.distance_to(record.position)<25.: nearby_building=true;break
		if not nearby_building and map.has_method("agricultural_loot_points"):
			for farm_point: Vector3 in map.call("agricultural_loot_points"):
				if point.distance_to(farm_point)<1.: nearby_building=true;break
		check(nearby_building,"Loot belongs to a building or farm container %s"%point)
	# Random rays ignore structures: only terrain hits are compared, preserving
	# the exact same triangle diagonal/interpolation used by the server.
	var rng:=RandomNumberGenerator.new();rng.seed=712907
	var comparisons:=0;var max_error:=0.
	for i in 500:
		var x:=rng.randf_range(-985,985);var z:=rng.randf_range(-985,985)
		var p:=Vector3(x,MAP.height_at(x,z),z)
		var hit:=ray_floor(p,50.,50.)
		if hit.is_empty() or not str(hit.collider.name).begins_with("AfghanTerrain"): continue
		comparisons+=1;max_error=maxf(max_error,absf(hit.position.y-p.y))
		check(absf(hit.position.y-p.y)<.06,"Visual/physics triangle-height agreement %s"%p)
	measurements.terrain_comparisons=comparisons;measurements.terrain_max_error_m=max_error
	check(comparisons>400,"Terrain covered by random collision checks")
	for p in [Vector3(1005,0,0),Vector3(-1005,0,0),Vector3(0,0,1005),Vector3(0,0,-1005),Vector3(1400,0,1400)]:
		check(not MAP.accessible(p),"No spawn outside play boundary")
		check(ray_floor(p,900.,900.).is_empty(),"No physical scenery beyond boundary %s"%p)
	validate_roads()
	validate_connectivity(spawns)
	await validate_library()
	# Create only the otherwise skipped horizon to inspect edge stitching.
	if map.has_method("_horizon"):
		map.call("_horizon")
		validate_horizon()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"scope":"Jolt geometry, loot support, prefab entrances, route slopes and coarse terrain connectivity; no FPS or baked navmesh claim."}
	NavalStorage.write_json("res://work/afghan-revision-validation.json",report)
	print("AFGHAN_REVISION_VALIDATION ",JSON.stringify(report))
	world.free();quit(0 if failures.is_empty() else 1)

func validate_roads() -> void:
	var maximum:=0.;var samples:=0;var bad: Array[Dictionary]=[]
	for road: Dictionary in LAND.roads():
		var points: Array=road.points
		for i in range(1,points.size()):
			var a: Vector3=points[i-1];var b: Vector3=points[i]
			var distance:=Vector2(a.x-b.x,a.z-b.z).length()
			var count:=maxi(1,ceili(distance/5.))
			var previous:=Vector3(a.x,MAP.height_at(a.x,a.z),a.z)
			for part in range(1,count+1):
				var next:=a.lerp(b,float(part)/count);next.y=MAP.height_at(next.x,next.z)
				var horizontal:=Vector2(next.x-previous.x,next.z-previous.z).length()
				var degrees:=rad_to_deg(atan2(absf(next.y-previous.y),maxf(.001,horizontal)))
				maximum=maxf(maximum,degrees);samples+=1
				if degrees>42.: bad.append({"kind":road.get("kind","road"),"from":str(previous),"to":str(next),"degrees":degrees,"creek_distance":absf(next.x-LAND.stream_center(next.z))})
				check(degrees<=42.,"Road grade <=42 degrees (%s, %.1f deg, %s -> %s)"%[str(road.get("kind","road")),degrees,str(previous),str(next)])
				previous=next
	measurements.road_samples=samples;measurements.maximum_road_grade_degrees=maximum
	measurements.bad_road_samples=bad
	check(samples>100,"Inter-village routes sampled every 5m")

func validate_connectivity(spawns: Array) -> void:
	# Coarse navigability is diagnostic and intentionally not labelled a baked
	# navmesh. It catches isolated spawn plateaus and vertical route cuts.
	var step:=20.;var bound:=48
	var heights: Dictionary={};var walkable: Dictionary={}
	for z in range(-bound,bound+1):
		for x in range(-bound,bound+1):
			var key:=Vector2i(x,z);var p:=Vector3(x*step,0,z*step);p.y=MAP.height_at(p.x,p.z)
			heights[key]=p.y
			if MAP.accessible(p): walkable[key]=true
	var start:=Vector2i(roundi(spawns[0].x/step),roundi(spawns[0].z/step))
	if not walkable.has(start):
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if walkable.has(start+offset): start+=offset;break
	var queue: Array[Vector2i]=[start];var seen: Dictionary={start:true};var head:=0
	while head<queue.size():
		var key:=queue[head];head+=1
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i=key+offset
			if not walkable.has(next) or seen.has(next) or not heights.has(key): continue
			if absf(float(heights[next])-float(heights[key]))>step: continue
			seen[next]=true;queue.append(next)
	var reachable:=0
	for spawn: Vector3 in spawns:
		var key:=Vector2i(roundi(spawn.x/step),roundi(spawn.z/step));var found:=false
		for x in range(-1,2):
			for z in range(-1,2):
				if seen.has(key+Vector2i(x,z)): found=true
		if found: reachable+=1
	measurements.coarse_walkable_cells=walkable.size();measurements.connected_cells=seen.size();measurements.connected_spawns=reachable
	# A 20m lattice can miss an engineered 5m-wide hillside street. Keep its
	# result diagnostic, then validate the actual road-centre sample graph.
	validate_road_connections(spawns)

func validate_road_connections(spawns: Array) -> void:
	var nodes: Array[Vector3]=[];var links: Array=[];var cells: Dictionary={}
	for road: Dictionary in LAND.roads():
		var previous:=-1
		for segment in range(1,road.points.size()):
			var a: Vector3=road.points[segment-1];var b: Vector3=road.points[segment]
			var count:=maxi(1,ceili(Vector2(a.x-b.x,a.z-b.z).length()/4.))
			for part in range(0,count+1):
				var p:=a.lerp(b,float(part)/count);p.y=MAP.height_at(p.x,p.z)
				var index:=nodes.size();nodes.append(p);links.append([])
				var cell:=Vector2i(floori(p.x/8.),floori(p.z/8.))
				if not cells.has(cell): cells[cell]=[]
				cells[cell].append(index)
				if previous>=0:
					var delta:=p-nodes[previous];var d:=Vector2(delta.x,delta.z).length()
					if d<.001 or absf(delta.y)<=d*tan(deg_to_rad(42.))+.02:
						links[index].append(previous);links[previous].append(index)
				previous=index
	for index in nodes.size():
		var p:=nodes[index];var cell:=Vector2i(floori(p.x/8.),floori(p.z/8.))
		for x in range(-1,2):
			for z in range(-1,2):
				for other: int in cells.get(cell+Vector2i(x,z),[]):
					if other<=index: continue
					var delta:=nodes[other]-p;var d:=Vector2(delta.x,delta.z).length()
					if d<=6. and absf(delta.y)<=maxf(.02,d*tan(deg_to_rad(42.))):
						links[index].append(other);links[other].append(index)
	var first:=0;var best:=INF
	for i in nodes.size():
		var d:=nodes[i].distance_squared_to(spawns[0])
		if d<best: best=d;first=i
	var queue: Array[int]=[first];var seen: Dictionary={first:true};var head:=0
	while head<queue.size():
		var index:=queue[head];head+=1
		for other: int in links[index]:
			if not seen.has(other): seen[other]=true;queue.append(other)
	var reached:=0
	for spawn: Vector3 in spawns:
		var found:=false;var cell:=Vector2i(floori(spawn.x/8.),floori(spawn.z/8.))
		for x in range(-1,2):
			for z in range(-1,2):
				for index: int in cells.get(cell+Vector2i(x,z),[]):
					if seen.has(index) and nodes[index].distance_to(spawn)<8.: found=true
		if found: reached+=1
		check(found,"Spawn linked through accessible authored road network %s"%spawn)
	measurements.road_graph_samples=nodes.size();measurements.road_graph_connected=seen.size();measurements.road_graph_spawns=reached

func validate_library() -> void:
	for id in ["adobe_house_v2","terrace_house_v2","farm_store_v2","qala_compound_v2","stone_ruin_v2"]:
		var path: String=LIB+id+".tscn"
		check(ResourceLoader.exists(path),"Reusable prefab exists "+id)
		if not ResourceLoader.exists(path): continue
		var piece: Node3D=load(path).instantiate();world.add_child(piece)
		piece.position=Vector3(0,700,0)
		await physics_frame;await physics_frame
		for marker in ["Entrance","LootInterior","FoundationTop"]: check(piece.get_node_or_null(marker)!=null,id+" has "+marker)
		var entry:=piece.get_node_or_null("Entrance") as Marker3D
		if entry: check(capsule_clear(entry.global_position),id+" entrance capsule clear")
		for child in piece.get_children():
			if child is Marker3D and str(child.name).begins_with("Loot"):
				check(not ray_floor(child.global_position,.04,.8).is_empty(),id+" loot marker supported: "+str(child.name))
		piece.free()
		await physics_frame

func validate_horizon() -> void:
	var horizon:=map.get_node_or_null("DistantMountainsNoCollision") as MeshInstance3D
	check(horizon!=null,"Horizon mesh exists")
	if horizon==null: return
	check(horizon.find_children("*","CollisionShape3D",true,false).is_empty(),"Horizon has no colliders")
	var edge: Dictionary={};var maximum_error:=0.
	for surface in horizon.mesh.get_surface_count():
		var arrays:=horizon.mesh.surface_get_arrays(surface)
		for local: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var p:=horizon.to_global(local)
			if absf(maxf(absf(p.x),absf(p.z))-1000.)>.01: continue
			var key:=Vector2i(roundi(p.x/MAP.STEP),roundi(p.z/MAP.STEP))
			edge[key]=true;maximum_error=maxf(maximum_error,absf(p.y-MAP.height_at(p.x,p.z)))
	measurements.horizon_boundary_vertices=edge.size();measurements.horizon_edge_error_m=maximum_error
	check(edge.size()>=4*roundi(2000./MAP.STEP),"Horizon matches every physical boundary vertex")
	check(maximum_error<.02,"Horizon edge and playable terrain agree")
