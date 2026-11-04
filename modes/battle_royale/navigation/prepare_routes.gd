extends SceneTree
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
const STAGE3=preload("res://modes/battle_royale/map/afghan_density_stage3.gd")
const OUT:="res://modes/battle_royale/navigation/prepared/"
const SOURCE:="res://work/br-nav-bake-source/"
const STEP:=8.
var world: Node3D
var map: Node3D
var tiles: Dictionary={}
var coarse_vertices:=PackedVector3Array()
var coarse_cells: Dictionary={}
var manifest: Dictionary={}
var used_polygons: Dictionary={}
var edge_uses: Dictionary={}

func _initialize() -> void:run.call_deferred()
func run() -> void:
	world=Node3D.new();root.add_child(world);map=MAP.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame
	var start:=Time.get_ticks_msec()
	var mesh:=outdoor_mesh()
	ResourceSaver.save(mesh,OUT+"outdoor.res")
	print("NAV_OUTDOOR ",mesh.get_polygon_count()," ",Time.get_ticks_msec()-start," ms")
	manifest={"complete":false,"cell":.2,"cell_height":.1,"source_hash":preload("res://modes/battle_royale/navigation/navigation.gd").source_hash(),"tiles":[{"path":OUT+"outdoor.res","polygons":mesh.get_polygon_count()}],"links":[],"spawns":[],"zones":[],"loot":[]}
	manifest.outdoor_candidates=[]
	var main_cells:=largest_component()
	for cell: Vector2i in coarse_cells:
		if cell.x%8!=0 or cell.y%8!=0 or not main_cells.has(cell):continue
		var p:=MAP.point((cell.x+.5)*STEP-1000.,(cell.y+.5)*STEP-1000.)+Vector3.UP*.12
		manifest.outdoor_candidates.append([p.x,p.y,p.z])
	var origin:=Vector3.INF;var distance:=INF
	for raw: Array in manifest.outdoor_candidates:
		var p:=Vector3(raw[0],raw[1],raw[2]);var d:=p.distance_squared_to(MAP.VILLAGES[0])
		if d<distance:origin=p;distance=d
	manifest.origin=[origin.x,origin.y,origin.z]
	var coarse_map:=NavigationServer3D.map_create();NavigationServer3D.map_set_use_async_iterations(coarse_map,false);NavigationServer3D.map_set_cell_size(coarse_map,.2);NavigationServer3D.map_set_cell_height(coarse_map,.1)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(coarse_map,.001);NavigationServer3D.map_set_active(coarse_map,true)
	var region:=NavigationServer3D.region_create();NavigationServer3D.region_set_navigation_mesh(region,mesh);NavigationServer3D.region_set_map(region,coarse_map);NavigationServer3D.map_force_update(coarse_map)
	var probe:=mesh.get_vertices()[mesh.get_polygon(0)[0]]
	while NavigationServer3D.map_get_closest_point(coarse_map,probe).distance_to(probe)>1.:
		await process_frame;NavigationServer3D.map_force_update(coarse_map)
	print("NAV_COARSE_SYNC ",NavigationServer3D.map_get_iteration_id(coarse_map)," ",Time.get_ticks_msec()-start," ms")
	var index:=0
	for record: Dictionary in MAP.building_layout():
		var prefab: Node3D=load(MAP.LIB+MAP.BUILDINGS[int(record.variant)]+".tscn").instantiate()
		var transform:=Transform3D(Basis(Vector3.UP,float(record.yaw)).scaled(record.scale),record.position)
		var bounds:=house_bounds(prefab,transform).grow(3.)
		var local_mesh:=crop_mesh(bounds)
		var path:=OUT+"building_%03d.res"%index
		ResourceSaver.save(local_mesh,path)
		manifest.tiles.append({"path":path,"polygons":local_mesh.get_polygon_count()})
		# Exact fine door/stair surface connects to a clear outdoor edge.
		var markers: Array[Vector3]=[]
		for child in prefab.get_children():
			if child is Marker3D and (str(child.name) in ["Door","Entrance","StairFoot"]):markers.append(transform*child.position)
		if markers.is_empty():markers.append(record.position)
		for marker in markers:
			var nearest:=Vector3.INF;var best:=INF
			for angle in 16:
				var outside:=marker+Vector3(sin(angle*TAU/16.),0,cos(angle*TAU/16.))*12.
				var p:=NavigationServer3D.map_get_closest_point(coarse_map,outside)
				# Move off the fine/coarse seam so the endpoint belongs to the
				# intended outdoor polygon, never a nearby overlapping room.
				var cell:=Vector2i(floori((p.x+1000.)/STEP),floori((p.z+1000.)/STEP))
				if coarse_cells.has(cell):
					var center:=MAP.point((cell.x+.5)*STEP-1000.,(cell.y+.5)*STEP-1000.)
					p=p.lerp(center,.20)
				var gap:=p.distance_to(marker)
				if gap>=best or gap>24.:continue
				var blocked:=false
				for height in [.45,1.,1.5]:
					var ray:=PhysicsRayQueryParameters3D.create(marker+Vector3.UP*height,p+Vector3.UP*height,1)
					if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():blocked=true;break
				if not blocked:nearest=p;best=gap
			if nearest.is_finite():manifest.links.append({"a":[nearest.x,nearest.y,nearest.z],"b":[marker.x,marker.y,marker.z]})
		# Recast intentionally erodes narrow treads for a capsule. Preserve
		# the reusable asset's authored stair centreline as explicit links,
		# only where a standing infantry corridor is physically clear.
		for prefix in ["","Upper"]:
			var names: Array[String]=[prefix+"StairFoot",prefix+"StairTurn",prefix+"StairLanding"]
			for n in 2:
				if not prefab.has_node(names[n]) or not prefab.has_node(names[n+1]):continue
				var a: Vector3=transform*prefab.get_node(names[n]).position
				var b: Vector3=transform*prefab.get_node(names[n+1]).position
				if corridor_clear(a,b):manifest.links.append({"a":[a.x,a.y,a.z],"b":[b.x,b.y,b.z],"stair":true})
		prefab.free();index+=1
		if index%15==0:print("NAV_HOUSES ",index)
	var placed: Array[Vector3]=[]
	for road: Dictionary in MAP.LAND.roads():
		for i in road.points.size()-1:
			var a: Vector3=road.points[i];var b: Vector3=road.points[i+1]
			var da:=a.x-MAP.LAND.stream_center(a.z);var db:=b.x-MAP.LAND.stream_center(b.z)
			if da*db>0 or absf(da-db)<.01:continue
			var p:=a.lerp(b,clampf(da/(da-db),0,1));p.y=MAP.LAND.stream_water_height(p.z)+.7
			if placed.any(func(other):return Vector3(other).distance_to(p)<18.):continue
			placed.append(p)
			var bounds:=AABB(p-Vector3(22,10,22),Vector3(44,25,44));var bridge_mesh:=crop_mesh(bounds)
			var path:=OUT+"bridge_%02d.res"%placed.size();ResourceSaver.save(bridge_mesh,path);manifest.tiles.append({"path":path,"polygons":bridge_mesh.get_polygon_count()})
			var direction: Vector3=(b-a).normalized()
			for sign_value in [-1.,1.]:
				var marker: Vector3=p+direction*sign_value*7.;marker.y=MAP.height_at(marker.x,marker.z)+.15
				var near:=NavigationServer3D.map_get_closest_point(coarse_map,p+direction*sign_value*24.)
				manifest.links.append({"a":[near.x,near.y,near.z],"b":[marker.x,marker.y,marker.z]})
	# V13 open-front rural sheds need fine navigation and explicit links.
	# The coarse outdoor grid excludes cells occupied by authored static colliders.
	# Without these regions, all 12 storage anchors project 4-10m away.
	var v13_sheds: Array=map.get_meta("afghan_density_stage3_layout",[])
	var storage_points: Array[Vector3]=STAGE3.loot_points(map)
	var shed_meshes:=0;var shed_links:=0
	for shed_index in v13_sheds.size():
		var shed: Dictionary=v13_sheds[shed_index]
		var center: Vector3=shed.position
		var bounds:=AABB(center-Vector3(13,3,13),Vector3(26,10,26))
		var shed_mesh:=crop_mesh(bounds)
		var count: int=shed_mesh.get_polygon_count()
		if count==0:
			push_error("V13 shed has no baked navigation: "+str(shed_index))
			quit(2);return
		var path:=OUT+"shed_%03d.res"%shed_index
		if ResourceSaver.save(shed_mesh,path)!=OK:
			push_error("Failed to save V13 shed navigation "+path)
			quit(2);return
		manifest.tiles.append({"path":path,"polygons":count})
		shed_meshes+=1
		# Use a point inside a walkable polygon, not the world-space mesh origin.
		var vertices: PackedVector3Array=shed_mesh.get_vertices()
		var interior:=Vector3.INF;var best_inside:=INF
		for polygon_index in count:
			var polygon: PackedInt32Array=shed_mesh.get_polygon(polygon_index)
			var point:=Vector3.ZERO
			for vertex_index in polygon:point+=vertices[vertex_index]
			point/=float(polygon.size())
			var candidate_distance: float=point.distance_squared_to(storage_points[shed_index])
			if candidate_distance<best_inside:best_inside=candidate_distance;interior=point
		var outward: Vector3=shed.entrance-center;outward.y=0.
		if outward.length_squared()<.01:continue
		outward=outward.normalized()
		var best_outside:=Vector3.INF;var score:=INF
		for angle in [0.,-.35,.35,-.7,.7]:
			var direction: Vector3=Basis(Vector3.UP,angle)*outward
			for advance in [0.,3.,7.,12.,18.,24.,30.]:
				var sample: Vector3=Vector3(shed.entrance)+direction*advance
				var outside:=NavigationServer3D.map_get_closest_point(coarse_map,sample)
				var gap:=outside.distance_to(interior)
				if gap>31. or outside.distance_to(sample)>11. or not corridor_clear(interior,outside):continue
				# Avoid isolated outdoor islands: the endpoint must have a real path
				# to the original village network before creating a new V13 link.
				if not coarse_connected(coarse_map,origin,outside):continue
				var rank:=gap+outside.distance_to(shed.entrance)*.1
				if rank<score:score=rank;best_outside=outside
		if best_outside.is_finite():
			manifest.links.append({"a":[best_outside.x,best_outside.y,best_outside.z],"b":[interior.x,interior.y,interior.z],"v13_shed":shed_index})
			shed_links+=1
		else:print("NAV_SHED_LINK_MISSING ",shed_index," polygons=",count)
	print("NAV_V13_SHEDS ",shed_meshes," / ",v13_sheds.size()," linked=",shed_links)
	if shed_meshes!=12 or shed_links!=12:
		push_error("V13 shelter navigation requires twelve meshes and twelve open links")
		quit(2);return
	var file:=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"\t"));file.close()
	NavigationServer3D.free_rid(region);NavigationServer3D.free_rid(coarse_map);tiles.clear()
	world.queue_free();world=null;map=null;mesh=null
	await process_frame;await process_frame;print("NAV_ROUTES_PREPARED ",Time.get_ticks_msec()-start," ms");quit()

func coarse_connected(map_id: RID,origin: Vector3,target: Vector3) -> bool:
	var query:=NavigationPathQueryParameters3D.new()
	var result:=NavigationPathQueryResult3D.new()
	query.map=map_id
	query.start_position=NavigationServer3D.map_get_closest_point(map_id,origin)
	query.target_position=target
	query.path_search_max_polygons=0
	query.metadata_flags=0
	NavigationServer3D.query_path(query,result)
	var route:=result.get_path()
	return not route.is_empty() and route[route.size()-1].distance_to(target)<=.65

func outdoor_mesh() -> NavigationMesh:
	var space:=world.get_world_3d().direct_space_state
	var size:=250;var heights:=PackedFloat32Array();heights.resize((size+1)*(size+1))
	for z in size+1:
		for x in size+1:
			var point:=MAP.point(-1000+x*STEP,-1000+z*STEP)
			coarse_vertices.append(point);heights[z*(size+1)+x]=point.y
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.margin=.02
	var shape:=BoxShape3D.new();query.shape=shape
	var slope_limit:=cos(deg_to_rad(40.))
	for z in size:
		for x in size:
			var a:=z*(size+1)+x;var b:=a+1;var c:=a+size+1;var d:=c+1
			var points: Array[Vector3]=[coarse_vertices[a],coarse_vertices[b],coarse_vertices[c],coarse_vertices[d]]
			var center: Vector3=(points[0]+points[1]+points[2]+points[3])*.25
			if absf(center.x)>960 or absf(center.z)>960:continue
			if absf((points[1]-points[0]).cross(points[2]-points[0]).normalized().y)<slope_limit or absf((points[2]-points[3]).cross(points[1]-points[3]).normalized().y)<slope_limit:continue
			var wet:=false
			for point in points:
				if MAP.is_water(point):wet=true;break
			if wet or MAP.is_water(center):continue
			var low:=minf(minf(points[0].y,points[1].y),minf(points[2].y,points[3].y))
			var high:=maxf(maxf(points[0].y,points[1].y),maxf(points[2].y,points[3].y))
			shape.size=Vector3(STEP+.8,high-low+1.8,STEP+.8)
			query.transform=Transform3D(Basis.IDENTITY,Vector3(center.x,(low+high)*.5+.92,center.z))
			var blocked:=false
			for result in space.intersect_shape(query,24):
				if not str(result.collider.name).begins_with("AfghanTerrain_"):blocked=true;break
			if not blocked:coarse_cells[Vector2i(x,z)]=PackedInt32Array([a,b,c,d])
	var mesh:=NavigationMesh.new();mesh.cell_size=.2;mesh.cell_height=.1;mesh.agent_radius=.4
	mesh.set_vertices(coarse_vertices)
	for indices: PackedInt32Array in coarse_cells.values():mesh.add_polygon(PackedInt32Array([indices[0],indices[2],indices[3],indices[1]]))
	return mesh

func corridor_clear(a: Vector3,b: Vector3) -> bool:
	var space:=world.get_world_3d().direct_space_state
	for h in [.45,1.,1.55]:
		var ray:=PhysicsRayQueryParameters3D.create(a+Vector3.UP*h,b+Vector3.UP*h,1)
		if not space.intersect_ray(ray).is_empty():return false
	return true

func largest_component() -> Dictionary:
	var seen: Dictionary={};var largest: Dictionary={}
	for start: Vector2i in coarse_cells:
		if seen.has(start):continue
		var component: Dictionary={start:true};var queue: Array[Vector2i]=[start];seen[start]=true;var cursor:=0
		while cursor<queue.size():
			var cell:=queue[cursor];cursor+=1
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=cell+offset
				if seen.has(next) or not coarse_cells.has(next):continue
				seen[next]=true;component[next]=true;queue.append(next)
		if component.size()>largest.size():largest=component
	print("NAV_MAIN_COMPONENT ",largest.size()," / ",coarse_cells.size())
	return largest

func house_bounds(prefab: Node3D,transform: Transform3D) -> AABB:
	var bounds:=AABB(transform.origin,Vector3.ZERO)
	for shape: Node in prefab.get_children():
		if not shape is CollisionShape3D or not shape.shape is BoxShape3D:continue
		var half: Vector3=shape.shape.size*.5
		for x in [-1,1]:
			for y in [-1,1]:
				for z in [-1,1]:bounds=bounds.expand(transform*shape.transform*Vector3(half.x*x,half.y*y,half.z*z))
	return bounds

func crop_mesh(bounds: AABB) -> NavigationMesh:
	var result:=NavigationMesh.new();result.cell_size=.2;result.cell_height=.1;result.agent_radius=.4
	var vertices:=PackedVector3Array();var polygons: Array[PackedInt32Array]=[];var unique: Dictionary={}
	var low:=Vector2i(clampi(floori((bounds.position.x+1000.)/100.),0,19),clampi(floori((bounds.position.z+1000.)/100.),0,19))
	var high:=Vector2i(clampi(floori((bounds.end.x+1000.)/100.),0,19),clampi(floori((bounds.end.z+1000.)/100.),0,19))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var key:=Vector2i(x,z)
			if not tiles.has(key):tiles[key]=load(SOURCE+"tile_%02d_%02d.res"%[x,z])
			var tile: NavigationMesh=tiles[key];var source_vertices:=tile.get_vertices()
			for index in tile.get_polygon_count():
				var polygon:=tile.get_polygon(index);var center:=Vector3.ZERO
				for vertex in polygon:center+=source_vertices[vertex]
				center/=polygon.size()
				if not bounds.has_point(center):continue
				var cell:=Vector2i(floori((center.x+1000.)/STEP),floori((center.z+1000.)/STEP))
				if coarse_cells.has(cell) and absf(center.y-MAP.height_at(center.x,center.z))<1.:continue
				var signature: Array[String]=[]
				var ring: Array[String]=[]
				for vertex in polygon:
					var point:=source_vertices[vertex]
					var value:="%d,%d,%d"%[roundi(point.x*1000.),roundi(point.y*1000.),roundi(point.z*1000.)]
					signature.append(value);ring.append(value)
				signature.sort();var key_string:=";".join(signature)
				if used_polygons.has(key_string):continue
				var edge_keys: Array[String]=[];var invalid:=false
				for edge in ring.size():
					var endpoints: Array[String]=[ring[edge],ring[(edge+1)%ring.size()]];endpoints.sort()
					var edge_key:="/".join(endpoints);edge_keys.append(edge_key)
					if endpoints[0]==endpoints[1] or int(edge_uses.get(edge_key,0))>=2:invalid=true
				if invalid:continue
				used_polygons[key_string]=true
				for edge_key in edge_keys:edge_uses[edge_key]=int(edge_uses.get(edge_key,0))+1
				var new_polygon:=PackedInt32Array()
				for vertex in polygon:
					var point:=source_vertices[vertex];var hashed:=Vector3i(roundi(point.x*1000.),roundi(point.y*1000.),roundi(point.z*1000.))
					if not unique.has(hashed):unique[hashed]=vertices.size();vertices.append(point)
					new_polygon.append(unique[hashed])
				if new_polygon.size()>=3:polygons.append(new_polygon)
	result.set_vertices(vertices)
	for polygon in polygons:result.add_polygon(polygon)
	return result
