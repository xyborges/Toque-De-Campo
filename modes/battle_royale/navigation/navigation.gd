extends RefCounted
class_name BRNavigation
## Offline-baked, physical infantry surface. No rasterization during matches.
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
const DATA:="res://modes/battle_royale/navigation/prepared/manifest.json"
var ready:=false
var navigation_map:=RID()
var regions: Array[RID]=[]
var links: Array[RID]=[]
var world: Node3D
var safe_points: Array[Vector3]=[]
var final_points: Array[Vector3]=[]
var loot_points: Array[Vector3]=[]
var metrics: Dictionary={}

static func source_hash() -> String:
	var paths: Array[String]=["res://modes/battle_royale/map/afghan_map.gd","res://modes/battle_royale/map/afghan_landform.gd","res://modes/battle_royale/map/afghan_environment.gd","res://modes/battle_royale/map/afghan_context.gd","res://modes/battle_royale/scenes/map_additions.tscn"]
	paths.append("res://modes/battle_royale/map/afghan_field_cover.gd")
	paths.append("res://modes/battle_royale/map/afghan_tactical_density.gd")
	paths.append("res://modes/battle_royale/map/afghan_density_stage2.gd")
	paths.append("res://modes/battle_royale/map/afghan_density_stage3.gd")
	for file in DirAccess.get_files_at(MAP.LIB):
		if str(file).ends_with(".tscn"):paths.append(MAP.LIB+str(file))
	paths.sort()
	var signature:=""
	for path in paths:
		if FileAccess.file_exists(path):signature+=path+":"+FileAccess.get_sha256(path)+";"
	return signature.sha256_text()

func install(map_node: Node3D,allow_unvalidated:=false) -> bool:
	close();world=map_node
	if not FileAccess.file_exists(DATA):return false
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not parsed is Dictionary or (not bool(parsed.get("complete",false)) and not allow_unvalidated):return false
	var data: Dictionary=parsed
	# Export converts/encrypts scripts and scenes, so their source bytes are
	# intentionally unavailable there. Validate authored inputs in the editor;
	# exported builds consume the corresponding prepared resources as a unit.
	# The offline candidate preparation is allowed to load stale content while
	# it regenerates the manifest it is about to rewrite.
	if OS.has_feature("editor") and not allow_unvalidated and data.has("source_hash") and str(data.source_hash)!=source_hash():return false
	navigation_map=NavigationServer3D.map_create()
	NavigationServer3D.map_set_use_async_iterations(navigation_map,false)
	NavigationServer3D.map_set_cell_size(navigation_map,float(data.cell))
	NavigationServer3D.map_set_cell_height(navigation_map,float(data.cell_height))
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(navigation_map,.001)
	NavigationServer3D.map_set_use_edge_connections(navigation_map,false)
	NavigationServer3D.map_set_link_connection_radius(navigation_map,1.8)
	NavigationServer3D.map_set_edge_connection_margin(navigation_map,.30)
	NavigationServer3D.map_set_active(navigation_map,true)
	var polygons:=0
	var probe:=Vector3.INF
	for record: Dictionary in data.tiles:
		if not ResourceLoader.exists(str(record.path)):close();return false
		var mesh:=load(str(record.path)) as NavigationMesh
		if not mesh or mesh.get_polygon_count()==0:continue
		var region:=NavigationServer3D.region_create();regions.append(region)
		NavigationServer3D.region_set_navigation_mesh(region,mesh)
		NavigationServer3D.region_set_map(region,navigation_map)
		polygons+=mesh.get_polygon_count()
		if not probe.is_finite():probe=mesh.get_vertices()[mesh.get_polygon(0)[0]]
	for record: Dictionary in data.get("links",[]):
		var link:=NavigationServer3D.link_create();links.append(link)
		NavigationServer3D.link_set_map(link,navigation_map);NavigationServer3D.link_set_bidirectional(link,true)
		NavigationServer3D.link_set_start_position(link,_vector(record.a));NavigationServer3D.link_set_end_position(link,_vector(record.b))
	NavigationServer3D.map_force_update(navigation_map)
	# In 4.7, NavigationMesh builds its internal polygon/BVH data on native
	# workers even when map iterations are synchronous. An empty iteration 1
	# is not readiness. Wait only during loading, never during a match query.
	var deadline:=Time.get_ticks_msec()+5000
	while probe.is_finite() and NavigationServer3D.map_get_closest_point(navigation_map,probe).distance_to(probe)>1. and Time.get_ticks_msec()<deadline:
		OS.delay_msec(2);NavigationServer3D.map_force_update(navigation_map)
	ready=probe.is_finite() and NavigationServer3D.map_get_closest_point(navigation_map,probe).distance_to(probe)<1.
	for p: Variant in data.get("spawns",[]):safe_points.append(_vector(p))
	for p: Variant in data.get("zones",[]):final_points.append(_vector(p))
	for p: Variant in data.get("loot",[]):loot_points.append(_vector(p))
	metrics={"regions":regions.size(),"polygons":polygons,"spawns":safe_points.size(),"zones":final_points.size(),"source_hash":str(data.get("source_hash",""))}
	return ready

static func _vector(value: Variant) -> Vector3:
	if value is Vector3:return value
	if value is Array and value.size()==3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
	return Vector3.INF

func closest(point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(navigation_map,point) if ready and point.is_finite() else Vector3.INF

func path_to(from: Vector3,to: Vector3) -> PackedVector3Array:
	if not ready or not from.is_finite() or not to.is_finite():return PackedVector3Array()
	var start:=closest(from);var end:=closest(to)
	# Never silently replace a roof/room target with an unrelated nearby floor.
	if start.distance_to(from)>3. or end.distance_to(to)>2.:return PackedVector3Array()
	# The convenience API caps search at 4096 polygons in Godot 4.7. A
	# two-kilometre surface can legitimately need more, especially across a
	# bridge. A partial path must never be mistaken for disconnected ground.
	var query:=NavigationPathQueryParameters3D.new();var result:=NavigationPathQueryResult3D.new()
	query.map=navigation_map;query.start_position=start;query.target_position=end
	query.path_search_max_polygons=0;query.metadata_flags=0
	NavigationServer3D.query_path(query,result)
	var path:=result.get_path()
	if path.is_empty() or path[path.size()-1].distance_to(end)>.65:return PackedVector3Array()
	return path

func spawn_candidates() -> Array[Vector3]:return safe_points.duplicate()
func zone_candidates() -> Array[Vector3]:return final_points.duplicate()
func reachable_loot_points() -> Array[Vector3]:return loot_points.duplicate()

func safe_spawn(point: Vector3) -> bool:
	if not ready or not is_instance_valid(world) or not point.is_finite() or not MAP.accessible(point) or MAP.is_water(point):return false
	var surface:=closest(point)
	if surface.distance_to(point)>1.:return false
	var space:=world.get_world_3d().direct_space_state
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.6,point-Vector3.UP*1.3,1))
	if hit.is_empty() or Vector3(hit.normal).y<cos(deg_to_rad(38.)):return false
	var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.75
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.margin=.005
	query.transform=Transform3D(Basis.IDENTITY,Vector3(hit.position)+Vector3.UP*.905)
	return space.intersect_shape(query,1).is_empty()

func choose_spawns(ids: Array,seed_value: int,min_separation:=90.) -> Dictionary:
	var candidates:=spawn_candidates()
	# Spawns remain close to genuine authored loot, never in bare corners.
	if not loot_points.is_empty():
		var settled: Array[Vector3]=[]
		for point: Vector3 in candidates:
			for loot: Vector3 in loot_points:
				if Vector2(point.x-loot.x,point.z-loot.z).length_squared()<=120.*120.:
					settled.append(point)
					break
		if settled.size()>=ids.size():candidates=settled
	if candidates.size()<ids.size():return {}
	var ordered:=ids.duplicate()
	ordered.sort()
	# Different server rounds carry different seeds. Given the same seed the
	# authoritative outcome remains deterministic for tests and replays.
	for attempt in 4:
		var result: Dictionary={}
		var available:=candidates.duplicate()
		var rng:=RandomNumberGenerator.new()
		rng.seed=seed_value+attempt*17239
		var failed:=false
		for id: Variant in ordered:
			var ranked: Array[Dictionary]=[]
			for point: Vector3 in available:
				var separation:=INF
				for other: Vector3 in result.values():
					separation=minf(separation,Vector2(point.x-other.x,point.z-other.z).length())
				if not result.is_empty() and separation<min_separation:continue
				# The old sampler could repeatedly inspect the same candidate
				# and consistently choose the farthest corner. Cap the advantage
				# of extreme separation and add reproducible seeded variation.
				var score: float=rng.randf() if result.is_empty() else minf(separation,260.0)+rng.randf_range(-35.0,35.0)
				ranked.append({"point":point,"score":score})
			ranked.sort_custom(func(a: Dictionary,b: Dictionary):return float(a.score)>float(b.score))
			var selected:=Vector3.INF
			for item: Dictionary in ranked:
				var p: Vector3=item.point
				# Refuse stale/nav-blocked spawn cells; try the next candidate,
				# rather than rejecting the entire round on a single collider.
				if safe_spawn(p):
					selected=p
					break
			if not selected.is_finite():
				failed=true
				break
			result[id]=selected+Vector3.UP*.08
			available.erase(selected)
		if not failed and result.size()==ordered.size():return result
	return {}

func close() -> void:
	ready=false
	for region in regions:NavigationServer3D.free_rid(region)
	regions.clear()
	for link in links:NavigationServer3D.free_rid(link)
	links.clear()
	if navigation_map.is_valid():NavigationServer3D.free_rid(navigation_map);navigation_map=RID()
	safe_points.clear();final_points.clear();loot_points.clear()

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		for region in regions:NavigationServer3D.free_rid(region)
		for link in links:NavigationServer3D.free_rid(link)
		if navigation_map.is_valid():NavigationServer3D.free_rid(navigation_map)
