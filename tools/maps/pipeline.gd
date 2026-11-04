extends SceneTree
const ADAPTER=preload("res://tools/maps/adapter.gd")
const DEFINITIONS=preload("res://scripts/maps/definition.gd")
const GRASS=preload("res://scripts/maps/grass_data.gd")
const NAV=preload("res://scripts/maps/navigation_data.gd")
const GRASS_ASSETS=preload("res://modes/war/scripts/grass_assets.gd")
class Context extends Node3D:
	var world_root: Node3D
	var map_kind:="office"
var operation:="audit"
var selected:="all"
var output:="res://work/maps"
var input_path:="res://work/maps-input.json"
var adapter: ADAPTER
var report: Dictionary
var obstacles: Dictionary={}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--operation="):operation=arg.trim_prefix("--operation=")
		if arg.begins_with("--map="):selected=arg.trim_prefix("--map=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--input="):input_path=arg.trim_prefix("--input=")
	run.call_deferred()

func save_json(path: String,data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if not f:push_error("Cannot write "+path);quit(2);return
	f.store_string(JSON.stringify(data,"\t"));f.close()

func run() -> void:
	if operation not in ["audit","prepare","validate"] or (selected!="all" and selected not in DEFINITIONS.IDS):quit(2);return
	var input: Variant=JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if not input is Dictionary:push_error("Use tools/maps.py");quit(2);return
	var failed:=false
	for id: String in DEFINITIONS.IDS:
		if selected!="all" and selected!=id:continue
		var started:=Time.get_ticks_msec()
		adapter=ADAPTER.new();adapter.configure(id)
		adapter.build(root)
		await physics_frame;await physics_frame;await physics_frame
		report={"map":id,"operation":operation,"checks":0,"errors":[],"warnings":[],"build_ms":Time.get_ticks_msec()-started,"variants":5 if id=="naval" else 1}
		inventory()
		if operation=="prepare":await prepare(input[id])
		else:validate(operation=="validate")
		report["elapsed_ms"]=Time.get_ticks_msec()-started
		save_json(output+"/"+id+"-"+operation+".json",report)
		print("MAP_REPORT ",JSON.stringify(report))
		failed=failed or not report.errors.is_empty()
		adapter.world.free();adapter=null
		await process_frame
	quit(1 if failed else 0)

func check(ok: bool,message: String) -> void:
	report.checks+=1
	if not ok:report.errors.append(message)

func inventory() -> void:
	var shapes:=adapter.world.find_children("*","CollisionShape3D",true,false)
	var visuals:=adapter.world.find_children("*","GeometryInstance3D",true,false)
	var materials: Dictionary={}
	for v in visuals:
		if v.material_override:materials[v.material_override]=true
	report["inventory"]={"nodes":adapter.world.find_children("*","Node",true,false).size(),"shapes":shapes.size(),"visual_nodes":visuals.size(),"override_materials":materials.size(),"note":"Headless inventory; draw calls require graphical measurement."}

func surface(p: Vector3,up:=1.0,down:=2.0) -> Dictionary:
	return adapter.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*up,p-Vector3.UP*down,1))

func validate(prepared: bool) -> void:
	if prepared:
		check(DEFINITIONS.current(adapter.id),"Prepared content is missing or stale")
		var manifest:=DEFINITIONS.get_definition(adapter.id)
		for record: Dictionary in manifest.get("artifacts",[]):check(FileAccess.file_exists(record.path) and FileAccess.get_sha256(record.path)==record.sha256,"Prepared artifact changed: "+str(record.path))
		check(not manifest.get("source_hash","").is_empty(),"Map identity absent")
	var spawns: Array[Vector3]=adapter.spawns()
	check(not spawns.is_empty(),"No spawn anchors")
	var good:=0;var bad: Array=[]
	var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.75
	for p in spawns:
		if adapter.id=="naval":
			check(NavalCatalog.safe_point(p,25.),"Naval anchor too close to island: "+str(p));good+=1;continue
		var hit:=surface(p,2.,4.)
		var ok:=not hit.is_empty()
		if ok:
			ok=Vector3(hit.normal).y>=cos(deg_to_rad(40.))
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.margin=.005
			query.transform=Transform3D(Basis.IDENTITY,Vector3(hit.position)+Vector3.UP*.895)
			ok=ok and adapter.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
		if ok:good+=1
		else:bad.append([p.x,p.y,p.z])
	# Candidate lists can intentionally include rejected points; actual admission
	# must select validated anchors. Report all defects rather than hiding them.
	report["spawn_audit"]={"candidates":spawns.size(),"clear":good,"rejected":bad}
	check(good>0,"No physically valid spawn")
	if not bad.is_empty():report.warnings.append("Unusable candidate anchors: "+str(bad.size()))
	var holes: Array=[];var tested:=0;var rect: Rect2=adapter.limits
	var spacing:=50. if adapter.id in ["ukraine","afghan"] else 8.
	if adapter.id!="naval":
		for z in range(int(rect.position.y+spacing),int(rect.end.y),int(spacing)):
			for x in range(int(rect.position.x+spacing),int(rect.end.x),int(spacing)):
				if adapter.id=="office" and not OfficeMap.has_floor(x,z):continue
				var y: float=adapter.height_at(x,z);tested+=1
				if surface(Vector3(x,y,z),.5,1.).is_empty():holes.append([x,z])
	check(holes.is_empty(),"Missing physical surface samples: "+str(holes.size()))
	report["surface_audit"]={"samples":tested,"missing":holes,"coverage":"Sample grid, not an exhaustive proof of all collision triangles."}
	if prepared and adapter.id in ["ukraine","desert","office"]:navigation_validation()
	if adapter.id=="afghan":
		var navigation=load("res://modes/battle_royale/navigation/navigation.gd").new()
		check(navigation.install(adapter.world),"Afghan prepared navigation does not match sources")
		report["navigation"]=navigation.metrics.duplicate();navigation.close()

func source_info(input: Dictionary) -> Dictionary:
	var paths: Array=input.sources
	return {"id":adapter.id,"version":1,"bounds":[adapter.limits.position.x,adapter.limits.position.y,adapter.limits.size.x,adapter.limits.size.y],"sources":paths,"source_hash":DEFINITIONS.source_hash(paths),"grass_approved":false,"status":"validation_pending","artifacts":[],"spawns":[],"objectives":[],"loot":[],"reservations":input.get("reservations",[]),"benchmark":input.get("benchmark",{}),"stages":["concept","terrain","navigation","layout","biomes","props","atmosphere","budget","match"]}

func prepare(input: Dictionary) -> void:
	var info:=source_info(input);var dir:=DEFINITIONS.ROOT+adapter.id
	# Activation is a release choice, separate from performance approval.
	info.grass_enabled=adapter.id in ["ukraine","desert"]
	DirAccess.make_dir_recursive_absolute(dir)
	for p: Vector3 in adapter.spawns():info.spawns.append([p.x,p.y,p.z])
	if adapter.id=="ukraine":
		for key: String in WarRules.OBJECTIVES:
			var p: Vector3=WarRules.OBJECTIVES[key].position;info.objectives.append({"id":key,"position":[p.x,p.y,p.z]})
	if adapter.id=="afghan":
		for p: Vector3 in ADAPTER.AFGHAN.loot_points():info.loot.append([p.x,p.y,p.z])
	if adapter.id in ["ukraine","desert","office"]:prepare_navigation(dir,info.source_hash)
	if adapter.id in ["ukraine","afghan","desert"]:await prepare_grass(dir,info.source_hash)
	for variant in (5 if adapter.id=="naval" else 1):
		adapter.mountain=variant
		await prepare_cartography(dir,variant)
	if adapter.id=="naval":await prepare_naval(dir,info.source_hash)
	for file in DirAccess.get_files_at(dir):
		if str(file).ends_with(".res"):info.artifacts.append({"path":dir+"/"+str(file),"sha256":FileAccess.get_sha256(dir+"/"+str(file))})
	info.artifacts.sort_custom(func(a: Dictionary,b: Dictionary):return str(a.path)<str(b.path))
	var content: String=info.source_hash
	for record: Dictionary in info.artifacts:content+=";"+str(record.path)+":"+str(record.sha256)
	info.content_hash=content.sha256_text()
	var previous:=DEFINITIONS.get_definition(adapter.id)
	info.version=maxi(1,int(previous.get("version",0))+(1 if previous.get("content_hash","")!=info.content_hash else 0))
	save_json(dir+"/manifest.json",info);DEFINITIONS.cache.erase(adapter.id);DEFINITIONS.checked.erase(adapter.id)
	report["identity"]=DEFINITIONS.identity(adapter.id)
	validate(true)

func prepare_navigation(dir: String,signature: String) -> void:
	var context:=Context.new();context.world_root=adapter.world;context.map_kind=adapter.id;root.add_child(context)
	var director: RefCounted
	if adapter.id=="ukraine":director=WarBotDirector.BotRoutes.new()
	else:director=OfflineDirector.new()
	director.setup(context)
	var data:=NAV.new();data.map_id=adapter.id;data.source_hash=signature
	data.region=director.grid.region;data.offset=director.grid.offset;data.cell_size=director.grid.cell_size
	var count:=data.region.size.x*data.region.size.y;data.blocked.resize(count);data.weights.resize(count)
	for z in data.region.size.y:
		for x in data.region.size.x:
			var index:=z*data.region.size.x+x;var p:=data.region.position+Vector2i(x,z)
			data.blocked[index]=int(director.grid.is_point_solid(p));data.weights[index]=director.grid.get_point_weight_scale(p)
	if adapter.id=="ukraine":data.heights=director.heights
	# Small islands inside furniture/rocks are not valid destinations. Keep
	# navigation connected without changing any authored geometry.
	var components:=grid_components(data)
	if not components.is_empty():
		var largest: PackedInt32Array=components[0]
		for group: PackedInt32Array in components:
			if group.size()>largest.size():largest=group
		for group: PackedInt32Array in components:
			if group.size()!=largest.size() and group.size()<12:
				for index in group:data.blocked[index]=1
	check(ResourceSaver.save(data,dir+"/navigation.res",ResourceSaver.FLAG_COMPRESS)==OK,"Navigation save failed")
	context.free()

func navigation_validation() -> void:
	var data: Resource=ResourceLoader.load(DEFINITIONS.ROOT+adapter.id+"/navigation.res", "",ResourceLoader.CACHE_MODE_IGNORE)
	if not data:check(false,"Missing navigation");return
	var groups:=grid_components(data);var components: Array[int]=[]
	for group: PackedInt32Array in groups:components.append(group.size())
	components.sort();components.reverse()
	check(not components.is_empty(),"No connected navigation")
	report["navigation"]={"cells":data.blocked.size(),"components":components,"note":"Ukraine retains its road transit graph outside the fine central grid." if adapter.id=="ukraine" else "Static grid prepared from final physical geometry."}

func grid_components(data: Resource) -> Array[PackedInt32Array]:
	var visited:=PackedByteArray();visited.resize(data.blocked.size());var components: Array[PackedInt32Array]=[]
	var width: int=data.region.size.x;var height: int=data.region.size.y
	for start in visited.size():
		if visited[start] or data.blocked[start]:continue
		var queue:=PackedInt32Array([start]);visited[start]=1;var cursor:=0
		while cursor<queue.size():
			var index:=queue[cursor];cursor+=1
			for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var p:=Vector2i(index%width,index/width)+offset
				if p.x<0 or p.y<0 or p.x>=width or p.y>=height:continue
				var next:=p.y*width+p.x
				if not visited[next] and not data.blocked[next]:visited[next]=1;queue.append(next)
		components.append(queue)
	return components

func index_obstacles() -> void:
	obstacles.clear()
	for node: CollisionShape3D in adapter.world.find_children("*","CollisionShape3D",true,false):
		if node.disabled or not node.get_parent() is StaticBody3D:continue
		var shape:=node.shape;var size:=Vector3.ZERO;var box:=AABB()
		if shape is BoxShape3D:size=shape.size
		elif shape is CylinderShape3D:size=Vector3(shape.radius*2,shape.height,shape.radius*2)
		elif shape is SphereShape3D:size=Vector3.ONE*shape.radius*2
		elif shape is ConvexPolygonShape3D:
			if shape.points.is_empty():continue
			box=AABB(shape.points[0],Vector3.ZERO)
			for p: Vector3 in shape.points:box=box.expand(p)
		else:continue
		if size!=Vector3.ZERO:box=AABB(-size*.5,size)
		box=(node.global_transform*box).grow(1.4)
		for z in range(floori(box.position.z/20.),floori(box.end.z/20.)+1):
			for x in range(floori(box.position.x/20.),floori(box.end.x/20.)+1):
				var key:=Vector2i(x,z)
				if not obstacles.has(key):obstacles[key]=[]
				obstacles[key].append(box)

func prepare_grass(dir: String,signature: String) -> void:
	index_obstacles()
	var data:=GRASS.new();data.source_hash=signature;data.map_id=adapter.id
	var rect: Rect2=adapter.limits;var started:=Time.get_ticks_msec()
	for z in range(floori(rect.position.y/20.),ceili(rect.end.y/20.)):
		for x in range(floori(rect.position.x/20.),ceili(rect.end.x/20.)):
			var id:=Vector2i(x,z);var origin:=Vector3(x*20.,0,z*20.)
			var rng:=RandomNumberGenerator.new();rng.seed=x*71231+z*93187+329
			var buffer:=PackedFloat32Array();buffer.resize(1200);var count:=0;var bounds:=AABB()
			for ix in 10:
				for iz in 10:
					var p:=Vector2(origin.x+(ix+.5)*2.,origin.z+(iz+.5)*2.)
					if not adapter.grass_allowed(p):continue
					var y: float=adapter.height_at(p.x,p.y);var point:=Vector3(p.x,y,p.y);var blocked:=false
					for box: AABB in obstacles.get(id,[]):
						if box.has_point(point+Vector3.UP*.25) and box.end.y>y+1.45:blocked=true;break
					if blocked:continue
					var normal:=Vector3(adapter.height_at(p.x-.4,p.y)-adapter.height_at(p.x+.4,p.y),.8,adapter.height_at(p.x,p.y-.4)-adapter.height_at(p.x,p.y+.4)).normalized()
					if normal.y<cos(deg_to_rad(40.)):continue
					var basis:=Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,rng.randi_range(0,3)*PI*.5)*Basis.from_scale(Vector3(1.,rng.randf_range(.88,1.),1.))
					var pos:=point-origin;var offset:=count*12
					var values:=[basis.x.x,basis.y.x,basis.z.x,pos.x,basis.x.y,basis.y.y,basis.z.y,pos.y,basis.x.z,basis.y.z,basis.z.z,pos.z]
					for i in 12:buffer[offset+i]=values[i]
					var patch:=AABB(pos-Vector3(1.35,.1,1.35),Vector3(2.7,.6,2.7));bounds=patch if count==0 else bounds.merge(patch)
					count+=1
			if count:
				data.buffers[id]=buffer;data.counts[id]=count;data.bounds[id]=bounds;data.patches+=count
		if posmod(z,10)==0:print("MAP_GRASS ",adapter.id," row=",z," patches=",data.patches);await process_frame
	# Coarse 80 m cells reuse a deterministic subset of accepted patches.
	# No new terrain samples; exclusions and terrain alignment are inherited.
	for id: Vector2i in data.buffers:
		var coarse:=Vector2i(floori(id.x/4.),floori(id.y/4.))
		if not data.far_buffers.has(coarse):
			var empty:=PackedFloat32Array();empty.resize(1200);data.far_buffers[coarse]=empty;data.far_counts[coarse]=0
		var source: PackedFloat32Array=data.buffers[id];var target: PackedFloat32Array=data.far_buffers[coarse]
		var count: int=data.far_counts[coarse];var offset:=Vector3(id.x*20.-coarse.x*80.,0,id.y*20.-coarse.y*80.)
		for index in range(0,int(data.counts[id]),16):
			if count>=100:break
			for component in 12:target[count*12+component]=source[index*12+component]
			target[count*12+3]+=offset.x;target[count*12+11]+=offset.z
			var pos:=Vector3(target[count*12+3],target[count*12+7],target[count*12+11])
			var box:=AABB(pos-Vector3(1.35,.1,1.35),Vector3(2.7,.6,2.7))
			data.far_bounds[coarse]=box if count==0 else AABB(data.far_bounds[coarse]).merge(box);count+=1
		data.far_buffers[coarse]=target;data.far_counts[coarse]=count
	check(ResourceSaver.save(data,dir+"/grass.res",ResourceSaver.FLAG_COMPRESS)==OK,"Grass save failed")
	check(ResourceSaver.save(GRASS_ASSETS.blade_mesh(2),dir+"/grass_mesh.res",ResourceSaver.FLAG_COMPRESS)==OK,"Grass mesh save failed")
	check(ResourceSaver.save(GRASS_ASSETS.blade_mesh(1),dir+"/grass_mesh_low.res",ResourceSaver.FLAG_COMPRESS)==OK,"Grass low mesh save failed")
	check(ResourceSaver.save(GRASS_ASSETS.blade_mesh(3),dir+"/grass_mesh_high.res",ResourceSaver.FLAG_COMPRESS)==OK,"Grass high mesh save failed")
	check(ResourceSaver.save(GRASS_ASSETS.grass_material(2),dir+"/grass_material.res")==OK,"Grass material save failed")
	check(ResourceSaver.save(GRASS_ASSETS.distant_mesh(),dir+"/grass_far_mesh.res",ResourceSaver.FLAG_COMPRESS)==OK,"Grass distant mesh save failed")
	report["grass"]={"cells":data.buffers.size(),"far_cells":data.far_buffers.size(),"patches":data.patches,"buffer_bytes":(data.buffers.size()+data.far_buffers.size())*4800,"prepare_ms":Time.get_ticks_msec()-started,"runtime_pool":49,"runtime_far_pool":49,"detail_range_m":60,"range_m":220}

func prepare_cartography(dir: String,variant: int) -> void:
	var resolution:=384;var image:=Image.create(resolution,resolution,true,Image.FORMAT_RGB8)
	var rect: Rect2=adapter.limits
	for z in resolution:
		for x in resolution:
			var p:=rect.position+Vector2(x+.5,z+.5)/resolution*rect.size
			var h: float=adapter.height_at(p.x,p.y)
			var delta:=2.;var slope:=Vector3(adapter.height_at(p.x-delta,p.y)-adapter.height_at(p.x+delta,p.y),delta*2,adapter.height_at(p.x,p.y-delta)-adapter.height_at(p.x,p.y+delta)).normalized()
			var color: Color=adapter.ground_colour(p,h);color*=clampf(.73+slope.dot(Vector3(-.45,1.,-.3).normalized())*.3,.45,1.15)
			# Rasterize final collisions (including authored buildings), not the
			# unedited landform. Naval variants use their own height lattice.
			if adapter.id!="naval":
				var hit:=surface(Vector3(p.x,h,p.y),400.,450.)
				if not hit.is_empty() and hit.position.y>h+1.5:color=Color("aab0a5")
			if adapter.id=="ukraine" and WarRoads.distance(p)<4.:color=Color("a69d83")
			if adapter.id=="afghan":
				var road:=ADAPTER.LAND._near_road(p)
				if road.distance<road.width*.5:color=Color("b7ad94")
				if absf(p.x-ADAPTER.LAND.stream_center(p.y))<3.5:color=Color("355664")
			image.set_pixel(x,z,color)
		if z%64==0:await process_frame
	image.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(image)
	check(ResourceSaver.save(texture,dir+"/cartography"+("_"+str(variant) if adapter.id=="naval" else "")+".res",ResourceSaver.FLAG_COMPRESS)==OK,"Cartography save failed")

func prepare_naval(dir: String,signature: String) -> void:
	# Store exact existing collision/visual terrain lattice for all five seeds.
	for variant in 5:
		var samples: Dictionary={}
		for index in NavalCatalog.ISLANDS.size():
			var extent: float=NavalCatalog.RADII[index]*1.25;var step:=extent*2./48.;var heights:=PackedFloat32Array()
			for z in 49:
				for x in 49:heights.append(NavalIslands.height_at(Vector2(x*step-extent,z*step-extent),index,variant))
			samples[index]=heights
		var data:=GRASS.new();data.map_id="naval";data.source_hash=signature;data.buffers=samples
		check(ResourceSaver.save(data,dir+"/islands_"+str(variant)+".res",ResourceSaver.FLAG_COMPRESS)==OK,"Naval samples save failed")
		await process_frame
