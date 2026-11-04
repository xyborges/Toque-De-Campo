extends RefCounted
## Field boundaries, dry drainage edges and roadside remnants, not random props.
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const CONTEXT=preload("res://modes/battle_royale/map/afghan_context.gd")
const LIB:="res://modes/battle_royale/library/"

static func layout(map: Node3D) -> Array[Dictionary]:
	var candidates: Array[Dictionary]=[];var result: Array[Dictionary]=[]
	for road: Dictionary in LAND.roads():
		if road.kind=="village":continue
		var travelled:=0.
		for i in range(1,road.points.size()-1):
			travelled+=(road.points[i]-road.points[i-1]).length()
			if travelled<42.:continue
			travelled=0.
			var p: Vector3=road.points[i];var direction: Vector3=(road.points[i+1]-road.points[i-1]).normalized();var across:=Vector3(-direction.z,0,direction.x).normalized()
			for side in [-1.,1.]:
				var offset: float=21.+float(i%3)*8.
				candidates.append({"p":p+across*offset*side,"yaw":atan2(-direction.z,direction.x),"context":"track"})
	# Uncultivated strips between parcels become low retained boundaries. This
	# also gives a shrinking zone cover away from roads without filling crops.
	for z in range(-900,901,75):
		for x in range(-900,901,75):
			var p:=Vector3(x+sin(z*.023)*18.,0,z+cos(x*.017)*16.)
			var road:=LAND._near_road(Vector2(p.x,p.z));var water_distance:=absf(p.x-LAND.stream_center(p.z))
			if float(road.distance)>150. and water_distance>410.:continue
			var slope:=CONTEXT.gradient(map,p)
			candidates.append({"p":p,"yaw":atan2(slope.x,slope.y),"context":"boundary"})
	for item: Dictionary in candidates:
		var p: Vector3=item.p;p.y=map.height_at(p.x,p.z)
		if not CONTEXT.clear(p,12.,27.) or map.is_water(p) or not map.accessible(p):continue
		if LAND.in_farmland(Vector2(p.x,p.z),9.) or absf(p.x-LAND.stream_center(p.z))<22.:continue
		if CONTEXT.gradient(map,p).length()>.40:continue
		# A bank must sit on a continuous shoulder, never across a sharp lip
		# where the centre slope alone would hide its collision underground.
		var support:=CONTEXT.on_ground(map,p,item.yaw);var uneven:=false
		for offset: Vector3 in [Vector3(-4.2,0,-1.4),Vector3(4.2,0,-1.4),Vector3(-4.2,0,1.4),Vector3(4.2,0,1.4),Vector3(0,0,-2),Vector3(0,0,2)]:
			var q: Vector3=support*offset
			if absf(map.height_at(q.x,q.z)-q.y)>.30:uneven=true;break
		if uneven:continue
		var near:=false
		for previous: Dictionary in result:
			if previous.position.distance_squared_to(p)<46.*46.:near=true;break
		if near:continue
		item.position=p;item.erase("p");result.append(item)
	return result

static func populate(map: Node3D,details: Dictionary,detail: Callable) -> void:
	var records:=layout(map);map.set_meta("afghan_cover_layout",records)
	var groups: Dictionary={};var plants: Dictionary={};var count:=0;var shrubs:=0
	if "--afghan-cover-before" in OS.get_cmdline_user_args():
		map.set_meta("afghan_cover",{"groups":0,"pieces":0,"shrubs":0});return
	for item: Dictionary in records:
		var p: Vector3=item.position;var basis:=Basis(Vector3.UP,float(item.yaw));var index:=count
		var id: String="field_wall_v10" if count%4==0 else "field_bank_v10"
		map.add_piece(id,CONTEXT.on_ground(map,p,item.yaw),groups,Color(.95,.94,.89))
		count+=1
		for i in 5:
			var q: Vector3=p+basis*Vector3(-5.+i*2.55,0,(2.7 if index%2==0 else -2.7)+sin(i*1.7)*.8)
			if not CONTEXT.clear(q,8.,22.) or LAND.in_farmland(Vector2(q.x,q.z),2.):continue
			q.y=map.height_at(q.x,q.z)
			if map.is_water(q):continue
			var scale:=.65+float((index+i)%4)*.12
			var shrub: Node3D=map.add_piece("tamarisk_v10",Transform3D(Basis(Vector3.UP,index*.71+i).scaled(Vector3.ONE*scale),q),plants,Color(.92,1.,.83));shrub.free();shrubs+=1
			if map.render_visuals:
				detail.call(details,"wild_margin_v9",CONTEXT.on_ground(map,q,i).scaled_local(Vector3(1.1,.46,1.1)),Color(.70,.76,.52))
				if i%2==0:detail.call(details,"pebble_patch_v3",CONTEXT.on_ground(map,q+Vector3(1.8,0,1.3),i),Color(.83,.79,.69))
	# Collision is grouped per cell by add_piece, always present on authority.
	# Cover silhouettes have no distance cull inside the 2 km playable map.
	map.finish_batches(groups,3000.,false)
	if map.render_visuals:
		var far: Node3D=load(LIB+"tamarisk_far_v10.tscn").instantiate();var mesh: Mesh=far.get_node("Geometry").mesh;far.free()
		for data: Dictionary in plants.values():data.far_mesh=mesh
		map.finish_batches(plants,3000.,false)
	map.set_meta("afghan_cover",{"groups":records.size(),"pieces":count,"shrubs":shrubs,"cover_render_cells":groups.size(),"plant_render_cells":plants.size(),"persistent_collision":true,"foliage_collision":false})
