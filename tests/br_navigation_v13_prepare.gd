extends SceneTree
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
const NAV=preload("res://modes/battle_royale/navigation/navigation.gd")
const STAGE3=preload("res://modes/battle_royale/map/afghan_density_stage3.gd")
var world: Node3D
var map: Node3D
var navigation: RefCounted
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func candidate_points() -> Array[Vector3]:
	var result: Array[Vector3]=[];var seen: Dictionary={}
	var prepared: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NAV.DATA))
	for raw: Variant in prepared.get("outdoor_candidates",[]):
		var p:=NAV._vector(raw);var cell:=Vector2i(roundi(p.x/48.),roundi(p.z/48.))
		if not seen.has(cell):seen[cell]=true;result.append(p)
	for road: Dictionary in MAP.LAND.roads():
		for raw: Vector3 in road.points:
			var p:=MAP.point(raw.x,raw.z);var cell:=Vector2i(roundi(p.x/48.),roundi(p.z/48.))
			if seen.has(cell) or not MAP.accessible(p) or MAP.is_water(p):continue
			seen[cell]=true;result.append(p+Vector3.UP*.12)
	return result

func run() -> void:
	world=Node3D.new();root.add_child(world);map=MAP.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame;await physics_frame
	navigation=NAV.new()
	check(navigation.install(map,"--prepare-candidates" in OS.get_cmdline_user_args()),"baked navigation loads without runtime baking")
	if not navigation.ready:world.free();quit(1);return
	await physics_frame;await physics_frame
	print("NAV_MAP ",NavigationServer3D.map_get_iteration_id(navigation.navigation_map)," active ",NavigationServer3D.map_is_active(navigation.navigation_map))
	for probe in MAP.spawn_candidates().slice(0,4):
		var closest: Vector3=navigation.closest(probe)
		var query:=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*.6,probe-Vector3.UP*1.3,1)
		print("NAV_PROBE ",probe," closest ",closest," delta ",probe.distance_to(closest)," floor ",world.get_world_3d().direct_space_state.intersect_ray(query))
	var start:=Time.get_ticks_msec();var candidates:=candidate_points();var safe: Array[Vector3]=[]
	candidates.sort_custom(func(a: Vector3,b: Vector3):return a.distance_squared_to(MAP.VILLAGES[0])<b.distance_squared_to(MAP.VILLAGES[0]))
	for point in candidates:
		if navigation.safe_spawn(point):safe.append(point)
	print("NAV_SAFE ",safe.size()," / ",candidates.size()," in ",Time.get_ticks_msec()-start," ms")
	var connected: Array[Vector3]=[]
	var source_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NAV.DATA))
	var origin:=NAV._vector(source_data.get("origin",[]))
	for point in safe:
		if not origin.is_finite():origin=point
		var path: PackedVector3Array=navigation.path_to(origin,point)
		if not path.is_empty():connected.append(point)
	print("NAV_CONNECTED ",connected.size()," / ",safe.size()," ",Time.get_ticks_msec()-start," ms")
	check(connected.size()>=50,"at least fifty clear dry ground points in one connected infantry component")
	if "--prepare-candidates" in OS.get_cmdline_user_args():
		navigation.safe_points=connected;navigation.final_points=connected
		navigation.metrics.spawns=connected.size();navigation.metrics.zones=connected.size()
	for seed_value in [1,42,712907,713007,7130071]:
		var ids: Array=range(1,13);var chosen: Dictionary=navigation.choose_spawns(ids,seed_value)
		check(chosen.size()==12,"twelve physically clear separated spawns seed %d"%seed_value)
		for id in chosen:
			for other in chosen:
				if int(id)>=int(other):continue
				var a: Vector3=chosen[id];var b: Vector3=chosen[other]
				check(Vector2(a.x-b.x,a.z-b.z).length()>=89.99,"spawn separation at least ninety metres")
	var interiors:=0;var roofs:=0;var unreachable: Array=[]
	var reachable: Array[Vector3]=[]
	for record in MAP.building_layout():
		var prefab: Node3D=load(MAP.LIB+MAP.BUILDINGS[int(record.variant)]+".tscn").instantiate()
		var transform:=Transform3D(Basis(Vector3.UP,float(record.yaw)).scaled(record.scale),record.position)
		for marker: Node in prefab.get_children():
			if not marker is Marker3D or not str(marker.name).begins_with("Loot"):continue
			var at: Vector3=transform*marker.position
			var path: PackedVector3Array=navigation.path_to(origin,at)
			if not path.is_empty():
				reachable.append(at)
				if str(marker.name).contains("Roof"):roofs+=1
				else:interiors+=1
			else:unreachable.append({"variant":int(record.variant),"position":[at.x,at.y,at.z],"marker":str(marker.name)})
		prefab.free()
	print("NAV_INTERIORS ",interiors," roofs ",roofs," unreachable ",unreachable.size())
	check(interiors>=65,"majority of real building interiors reachable through doors")
	check(roofs>=20,"stair-accessible roofs included in baked navigation")
	for point in MAP.agricultural_loot_points():
		if not navigation.path_to(origin,point).is_empty():reachable.append(point)
	for point in MAP.settlement_loot_points():
		if not navigation.path_to(origin,point).is_empty():reachable.append(point)
	# V13 rural sheds contribute exactly twelve accessible storage anchors.
	# This preserves their availability in navigation-aware loot and bots.
	var v13_loot: Array[Vector3]=STAGE3.loot_points(map)
	var v13_reachable:=0
	for point in v13_loot:
		if not navigation.path_to(origin,point).is_empty():
			reachable.append(point)
			v13_reachable+=1
	check(v13_loot.size()==12,"V13 creates exactly twelve rural storage anchors")
	check(v13_reachable==v13_loot.size(),"V13 rural storage is reachable on baked navigation")
	print("NAV_V13_STORAGE ",v13_reachable," / ",v13_loot.size())
	if "--prepare-candidates" in OS.get_cmdline_user_args():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(NAV.DATA))
		data.spawns=[];data.zones=[];data.loot=[];data.complete=failures.is_empty();data.source_hash=NAV.source_hash()
		for point in connected:data.spawns.append([point.x,point.y,point.z]);data.zones.append([point.x,point.y,point.z])
		for point in reachable:data.loot.append([point.x,point.y,point.z])
		var file:=FileAccess.open(NAV.DATA,FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"metrics":navigation.metrics,"candidates":candidates.size(),"clear_candidates":safe.size(),"connected_candidates":connected.size(),"interiors":interiors,"roofs":roofs,"unreachable_loot":unreachable,"scope":"Offline baked Recast navmesh from complete Afghan physical colliders, water exclusions, connected endpoints, capsule/slope/clearance and 12-spawn separation. No FPS claim."}
	NavalStorage.write_json("res://work/br-navigation-validation.json",report);print("BR_NAVIGATION_VALIDATION ",JSON.stringify(report))
	navigation.close();navigation=null;world.free();await process_frame;quit(0 if failures.is_empty() else 1)
