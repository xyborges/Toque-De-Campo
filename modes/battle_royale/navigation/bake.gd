extends SceneTree
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
const OUT:="res://work/br-nav-bake-source/"
const TILE:=100.
const CELL:=.2
var source: NavigationMeshSourceGeometryData3D
var finished:=false
var world: Node3D
var map: Node3D
var records: Array=[]
var jobs: Array[Dictionary]=[]

func _initialize() -> void:run.call_deferred()

func settings() -> NavigationMesh:
	var mesh:=NavigationMesh.new()
	mesh.cell_size=CELL;mesh.cell_height=.1;mesh.agent_radius=.32;mesh.agent_height=1.8
	mesh.agent_max_climb=.4;mesh.agent_max_slope=40.
	mesh.geometry_collision_mask=1;mesh.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.filter_walkable_low_height_spans=true;mesh.filter_low_hanging_obstacles=false;mesh.filter_ledge_spans=true
	mesh.region_min_size=1.;mesh.region_merge_size=8.;mesh.edge_max_error=1.;mesh.edge_max_length=24.
	mesh.detail_sample_distance=3.;mesh.detail_sample_max_error=.3
	mesh.sample_partition_type=NavigationMesh.SAMPLE_PARTITION_LAYERS
	return mesh

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	world=Node3D.new();root.add_child(world)
	map=MAP.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame
	source=NavigationMeshSourceGeometryData3D.new()
	var spec:=settings();var start:=Time.get_ticks_msec()
	NavigationServer3D.parse_source_geometry_data(spec,source,map)
	print("NAV_SOURCE ",source.get_vertices().size()/3," ",Time.get_ticks_msec()-start," ms")
	# Ground at or below water is forbidden. Bridges remain above the volume.
	for z in range(-1000,1000,10):
		var a:=MAP.LAND.stream_center(z);var b:=MAP.LAND.stream_center(z+10)
		var vertices:=PackedVector3Array([Vector3(a-3.7,0,z),Vector3(b-3.7,0,z+10),Vector3(b+3.7,0,z+10),Vector3(a+3.7,0,z)])
		source.add_projected_obstruction(vertices,MAP.LAND.stream_water_height(z+5)-50.,50.2,false)
	var all:= "--all" in OS.get_cmdline_user_args()
	var count:=0
	for iz in 20:
		for ix in 20:
			# Probe the largest settlement first before baking the full map.
			if not all and Vector2(ix*100.-1000.,iz*100.-1000.).distance_to(Vector2(-400,500))>1.:continue
			var mesh:=settings();var margin:=2.00001
			mesh.filter_baking_aabb=AABB(Vector3(ix*TILE-1000-margin,-30,iz*TILE-1000-margin),Vector3(TILE+margin*2,500,TILE+margin*2));mesh.border_size=margin
			start=Time.get_ticks_msec()
			var path:=OUT+"tile_%02d_%02d.res"%[ix,iz]
			var job:={"mesh":mesh,"path":path,"started":start,"finished":false,"ix":ix,"iz":iz};jobs.append(job)
			NavigationServer3D.bake_from_source_geometry_data_async(mesh,source,func():job.finished=true)
			while jobs.size()>=4:await reap_jobs()
			count+=1
	while not jobs.is_empty():await reap_jobs()
	var file:=FileAccess.open(OUT+"source_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete":all,"cell":CELL,"cell_height":.1,"source_hash":preload("res://modes/battle_royale/navigation/navigation.gd").source_hash(),"tiles":records},"\t"));file.close()
	source=null;spec=null;jobs.clear();world.queue_free();map=null;world=null
	await process_frame;await process_frame;quit()

func reap_jobs() -> void:
	await process_frame
	for index in range(jobs.size()-1,-1,-1):
		var job: Dictionary=jobs[index]
		if not job.finished:continue
		var mesh: NavigationMesh=job.mesh
		ResourceSaver.save(mesh,job.path)
		records.append({"path":job.path,"polygons":mesh.get_polygon_count(),"vertices":mesh.get_vertices().size()})
		print("NAV_TILE ",job.ix," ",job.iz," polys=",mesh.get_polygon_count()," ms=",Time.get_ticks_msec()-int(job.started))
		jobs.remove_at(index)
