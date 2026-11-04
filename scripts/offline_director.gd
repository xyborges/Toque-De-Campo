extends RefCounted
class_name OfflineDirector

var game: Node3D
var grid := AStarGrid2D.new()
var cell := 0.65
var origin := Vector2(-14.2,-44.2)
var routes: Dictionary = {}
var random := RandomNumberGenerator.new()

func setup(owner_game: Node3D) -> void:
	game = owner_game
	random.randomize()
	if load("res://scripts/maps/navigation_cache.gd").install(self,game.map_kind):return
	var dimensions := Vector2(28.4,50.4)
	if game.map_kind == "desert":
		origin = Vector2(-148,-148)
		dimensions = Vector2(296,296)
		cell = 1.30
	grid.region = Rect2i(Vector2i.ZERO,Vector2i(ceil(dimensions.x/cell),ceil(dimensions.y/cell)))
	grid.cell_size = Vector2.ONE * cell
	grid.offset = origin
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	if game.map_kind=="office":
		for x in grid.region.size.x:
			for z in grid.region.size.y:
				var p := grid.get_point_position(Vector2i(x,z))
				if not OfficeMap.has_floor(p.x,p.y): grid.set_point_solid(Vector2i(x,z),true)
	else:
		for x in grid.region.size.x:
			for z in grid.region.size.y:
				var p := grid.get_point_position(Vector2i(x,z))
				if DesertTerrain.normal_at(p.x,p.y).y<.75: grid.set_point_solid(Vector2i(x,z),true)
	# Read the existing static collider bounds, without rebuilding the map or
	# repeatedly issuing thousands of broad-phase queries on every AI tick.
	for node in game.world_root.find_children("*","CollisionShape3D",true,false):
		if not node.get_parent() is StaticBody3D or node.disabled: continue
		var shape: Shape3D = node.shape
		var size := Vector3.ZERO
		var local_bounds := AABB()
		if shape is BoxShape3D: size = shape.size
		elif shape is CylinderShape3D: size = Vector3(shape.radius*2,shape.height,shape.radius*2)
		elif shape is ConvexPolygonShape3D:
			var points: PackedVector3Array = shape.points
			if points.is_empty(): continue
			local_bounds = AABB(points[0],Vector3.ZERO)
			for p in points: local_bounds = local_bounds.expand(p)
		else: continue
		if size!=Vector3.ZERO: local_bounds = AABB(-size*0.5,size)
		var bounds: AABB = node.global_transform * local_bounds
		var floor_y := DesertTerrain.height_at(bounds.get_center().x,bounds.get_center().z) if game.map_kind=="desert" else 0.0
		if bounds.end.y < floor_y+0.16 or bounds.position.y > floor_y+1.95: continue
		# Mark only cell centers inside the expanded collider; rounding both
		# bounds can incorrectly seal narrow but physically valid corridors.
		var low := Vector2i(ceil((bounds.position.x-0.36-origin.x)/cell),ceil((bounds.position.z-0.36-origin.y)/cell))
		var high := Vector2i(floor((bounds.end.x+0.36-origin.x)/cell),floor((bounds.end.z+0.36-origin.y)/cell))
		var rect := Rect2i(low,high-low+Vector2i.ONE).intersection(grid.region)
		if rect.has_area(): grid.fill_solid_region(rect,true)

func point_id(pos: Vector3) -> Vector2i:
	return Vector2i(round((pos.x-origin.x)/cell),round((pos.z-origin.y)/cell))

func world_point(id: Vector2i) -> Vector3:
	var p := grid.get_point_position(id)
	return Vector3(p.x,(DesertTerrain.height_at(p.x,p.y) if game.map_kind=="desert" else 0.0)+0.04,p.y)

func walkable(id: Vector2i) -> bool:
	return grid.is_in_boundsv(id) and not grid.is_point_solid(id)

func nearest(pos: Vector3) -> Vector2i:
	var center := point_id(pos)
	if walkable(center): return center
	for radius in range(1,7):
		var best := center
		var score := INF
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var candidate := center + Vector2i(x,y)
				if not walkable(candidate): continue
				var distance := world_point(candidate).distance_squared_to(pos)
				if distance < score:
					score = distance
					best = candidate
		if score < INF: return best
	return center

func direction_for(actor: GamePlayer, target: GamePlayer) -> Vector3:
	var direct := target.global_position-actor.global_position
	direct.y = 0.0
	if game.npc_line_clear(actor.global_position,target.global_position,0.36): return direct.normalized()
	var now := Time.get_ticks_msec()*0.001
	var record: Dictionary = routes.get(actor.peer_id,{})
	var goal := nearest(target.global_position)
	if record.is_empty() or now > float(record.get("until",0.0)) or record.goal != goal:
		var from := nearest(actor.global_position)
		var path: Array[Vector2i] = []
		if walkable(from) and walkable(goal): path = grid.get_id_path(from,goal,true)
		record = {"goal":goal,"path":path,"index":1 if path.size()>1 else 0,"until":now+0.65+posmod(actor.peer_id,5)*0.05}
		routes[actor.peer_id] = record
	var path: Array = record.path
	while int(record.index) < path.size():
		var direction := world_point(path[record.index])-actor.global_position
		direction.y = 0.0
		if direction.length() > 0.40: return direction.normalized()
		record.index = int(record.index)+1
	return Vector3.ZERO

func spawn_position() -> Variant:
	if not is_instance_valid(game.local_player): return null
	var player: GamePlayer = game.local_player
	var camera: Camera3D = player.camera
	var target := nearest(player.global_position)
	var best: Variant = null
	var best_score := -INF
	for attempt in range(180):
		# Sample the combat neighborhood, not the entire 300 m terrain: spawning
		# remains responsive and never needs thousands of empty-grid attempts.
		var around := player.global_position+Vector3(random.randf_range(-37,37),0,random.randf_range(-37,37))
		var id := point_id(around)
		if game.map_kind=="office": id = Vector2i(random.randi_range(0,grid.region.size.x-1),random.randi_range(0,grid.region.size.y-1))
		if not walkable(id): continue
		var candidate := world_point(id)
		var distance := candidate.distance_to(player.global_position)
		if distance < 6.5 or distance > (25.0 if game.map_kind == "office" else 40.0): continue
		var clear := true
		var nearest_npc := 20.0
		for npc in game.npcs:
			if not is_instance_valid(npc): continue
			var separation: float = npc.global_position.distance_to(candidate)
			nearest_npc = minf(nearest_npc,separation)
			if separation < 2.0:
				clear = false
				break
		if not clear: continue
		var offset := (candidate+Vector3.UP-camera.global_position).normalized()
		var visible: bool = offset.dot(-camera.global_basis.z)>0.65 and game.npc_line_clear(camera.global_position-Vector3.UP,candidate)
		if visible and distance<10.0: continue
		var score := nearest_npc + minf(distance,20.0)*0.04-(8.0 if visible else 0.0)
		if score <= best_score: continue
		if not walkable(target) or grid.get_id_path(id,target).is_empty(): continue
		best = candidate
		best_score = score
	return best
