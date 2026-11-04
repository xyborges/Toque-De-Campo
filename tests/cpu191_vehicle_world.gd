extends SceneTree

# One process, actual complete authority map and original four vehicle kinds.
# Copies unchanged into baseline191-src; this file never needs the new probe.
class Authority extends Node3D:
	var game: WarGame
	var floods:=0
	func flood_vehicle(vehicle: WarVehicle) -> void:
		floods+=1;vehicle.destroyed=true

class GroundTimer extends WarVehicleGround:
	var elapsed_usec:=0
	func align(vehicle: WarVehicle,delta: float) -> void:
		var started:=Time.get_ticks_usec()
		super.align(vehicle,delta)
		elapsed_usec+=Time.get_ticks_usec()-started

var game: WarGame
var stage: Node3D
var authority: Authority
var vehicles: Array[WarVehicle]=[]
var grounds: Array[GroundTimer]=[]
var scenario:="benchmark"
var label:="current"
var report_path:="res://work/perf181/cpu191-vehicle-world-current-benchmark.json"
var elapsed:=0.
var duration:=28.
var measure_after:=3.
var running:=false
var activated:=false
var last_tick_usec:=0
var frame_gaps: Array[float]=[]
var simulate_times: Array[float]=[]
var align_times: Array[float]=[]
var per_vehicle: Dictionary={}
var spikes: Array[Dictionary]=[]
var topology: Dictionary={}
var checkpoint: Array[Dictionary]=[]
var build_usec:=0
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world-scenario="): scenario=arg.trim_prefix("--world-scenario=")
		if arg.begins_with("--world-label="): label=arg.trim_prefix("--world-label=")
		if arg.begins_with("--world-report="): report_path=arg.trim_prefix("--world-report=")
	run.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var ordered:=values.duplicate();ordered.sort()
	var total:=0.
	for value in values: total+=value
	return {"calls":values.size(),"total_ms":total*.001,"mean_ms":total*.001/values.size(),"p50_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.5))]*.001,"p95_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.95))]*.001,"max_ms":ordered.back()*.001}

func inventory() -> void:
	var shapes: Dictionary={};var bodies:=0;var total:=0;var triangles:=0;var largest: Array[Dictionary]=[]
	for body: StaticBody3D in stage.find_children("*","StaticBody3D",true,false):
		bodies+=1
		var count:=0
		for node: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
			if node.shape==null: continue
			total+=1;count+=1
			var kind:=node.shape.get_class();shapes[kind]=int(shapes.get(kind,0))+1
			if node.shape is ConcavePolygonShape3D: triangles+=node.shape.get_faces().size()/3
		largest.append({"path":str(body.get_path()),"shapes":count})
	largest.sort_custom(func(a,b): return int(a.shapes)>int(b.shapes))
	topology={"static_bodies":bodies,"collision_shapes":total,"shape_types":shapes,"concave_triangles":triangles,"largest_bodies":largest.slice(0,12)}

func overlaps(vehicle: WarVehicle) -> Array[Dictionary]:
	var found: Dictionary={}
	for node: CollisionShape3D in vehicle.find_children("*","CollisionShape3D",true,false):
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=node.shape;query.transform=node.global_transform;query.collision_mask=1;query.exclude=[vehicle.get_rid()]
		for hit in vehicle.get_world_3d().direct_space_state.intersect_shape(query,256):
			var collider:=hit.collider as CollisionObject3D
			var owner:=collider.shape_find_owner(int(hit["shape"]))
			var shape_node:=collider.shape_owner_get_owner(owner) as CollisionShape3D
			var key:=str(collider.get_path())+":"+str(hit["shape"])
			if not found.has(key): found[key]={"body":str(collider.get_path()),"shape":str(shape_node.name) if shape_node else "","type":shape_node.shape.get_class() if shape_node else "","surface":str(shape_node.get_meta("surface",collider.get_meta("surface",""))) if shape_node else ""}
	var result: Array[Dictionary]=[]
	for entry: Dictionary in found.values(): result.append(entry)
	return result

func poses(include_overlaps:=false) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for vehicle in vehicles:
		var entry: Dictionary={"kind":vehicle.kind,"position":str(vehicle.global_position),"heading":vehicle.heading,"velocity":str(vehicle.velocity),"speed":vehicle.speed,"slides":vehicle.get_slide_collision_count()}
		if include_overlaps: entry.overlaps=overlaps(vehicle)
		result.append(entry)
	return result

func initial_point(kind: String,_index: int) -> Vector3:
	var spec: Dictionary=WarRules.VEHICLES[kind];var base: Vector3=WarRules.BASES[int(spec.team)]
	return WarTerrain.point(base.x+(8 if kind in ["guarani","bmp2"] else -8),base.z-12)

func initial_heading(kind: String,_index: int) -> float:
	return -PI*.5 if int(WarRules.VEHICLES[kind].team)==0 else PI*.5

func control_for(_vehicle: WarVehicle,_index: int) -> Dictionary:
	return {"throttle":.35 if int(elapsed)%8<4 else -.25,"steer":.12*sin(elapsed),"aim":WarTerrain.point(0,-80)+Vector3.UP*2,"fire":true,"at":game.war_clock}

func validate_route() -> void:
	pass

func run() -> void:
	Engine.max_fps=60
	game=WarGame.new();game.offline_operation=true;game.war_clock=100.;WarWeather.seed=0
	stage=Node3D.new();stage.name="FullAuthorityWorld";root.add_child(stage)
	var before:=Time.get_ticks_usec()
	WarWorld.build(stage,false)
	for node in stage.get_children():
		if node is WarWeather:
			node.game=game;node.set_process(false)
	var grid:=WarPowerGrid.new();grid.game=game;stage.add_child(grid);grid.set_process(false)
	authority=Authority.new();authority.game=game;stage.add_child(authority)
	for kind in ["guarani","bmp2","abrams","t90"]:
		var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="single_"+kind
		vehicle.position=initial_point(kind,vehicles.size())
		vehicle.heading=initial_heading(kind,vehicles.size());vehicle.rotation.y=vehicle.heading
		var ground:=GroundTimer.new();vehicle.ground_support=ground;grounds.append(ground)
		authority.add_child(vehicle);vehicles.append(vehicle)
		var values: Array[float]=[];per_vehicle[kind]=values
	build_usec=Time.get_ticks_usec()-before
	# Let static broadphase creation complete before any measurement.
	await physics_frame;await physics_frame
	inventory()
	checkpoint.append({"elapsed":0.,"phase":"initial","vehicles":poses(true)})
	print("CPU191_WORLD_READY ",JSON.stringify({"label":label,"scenario":scenario,"build_ms":build_usec*.001,"topology":topology}))
	last_tick_usec=Time.get_ticks_usec();running=true

func _physics_process(_delta: float) -> bool:
	if not running: return false
	var now_usec:=Time.get_ticks_usec()
	var gap:=now_usec-last_tick_usec;last_tick_usec=now_usec
	elapsed+=1./60.;game.war_clock+=1./60.
	if elapsed>=8 and not activated:
		activated=true
		if scenario=="benchmark":
			for index in vehicles.size():
				var vehicle:=vehicles[index]
				vehicle.global_position=WarTerrain.point(index*10-15,-175)+Vector3.UP*.2
				vehicle.driver=100+index
		else:
			for index in vehicles.size(): vehicles[index].driver=100+index
		checkpoint.append({"elapsed":elapsed,"phase":"activation","vehicles":poses(true)})
	var before:=Time.get_ticks_usec();var align_before:=0
	for ground in grounds: align_before+=ground.elapsed_usec
	for index in vehicles.size():
		var vehicle:=vehicles[index]
		var control: Dictionary={}
		if activated: control=control_for(vehicle,index)
		var call_started:=Time.get_ticks_usec();vehicle.simulate(1./60.,control);var call_time:=Time.get_ticks_usec()-call_started
		if elapsed>measure_after: per_vehicle[vehicle.kind].append(float(call_time))
		if call_time>5000 and spikes.size()<200: spikes.append({"elapsed":elapsed,"kind":vehicle.kind,"simulate_ms":call_time*.001,"position":str(vehicle.global_position),"slides":vehicle.get_slide_collision_count()})
	var simulate:=Time.get_ticks_usec()-before;var align:=0
	for ground in grounds: align+=ground.elapsed_usec
	if elapsed>measure_after:
		frame_gaps.append(float(gap));simulate_times.append(float(simulate));align_times.append(float(align-align_before))
	if int(elapsed*60)%300==0: checkpoint.append({"elapsed":elapsed,"phase":"route","vehicles":poses()})
	if elapsed>=duration:
		running=false;finish.call_deferred()
	return false

func finish() -> void:
	validate_route()
	var kinds: Dictionary={}
	for kind in per_vehicle: kinds[kind]=stats(per_vehicle[kind])
	checkpoint.append({"elapsed":elapsed,"phase":"final","vehicles":poses(true)})
	var result: Dictionary={"label":label,"scenario":scenario,"scope":"one isolated headless process; full unchanged WarWorld/power-grid collision; four actual WarVehicles; no players/network/GPU; 60 Hz deterministic simulation","measure_begin_simulated_seconds":measure_after,"duration_simulated_seconds":duration,"build_ms_outside_measurement":build_usec*.001,"tick_gap_wall":stats(frame_gaps),"four_simulate_wall":stats(simulate_times),"four_align_inclusive_wall":stats(align_times),"vehicles":kinds,"spikes":spikes,"checkpoints":checkpoint,"topology":topology,"floods":authority.floods,"failures":failures}
	NavalStorage.write_json(report_path,result)
	print("CPU191_WORLD_RESULT ",JSON.stringify({"label":label,"scenario":scenario,"tick_gap_wall":result.tick_gap_wall,"four_simulate_wall":result.four_simulate_wall,"four_align_inclusive_wall":result.four_align_inclusive_wall,"spikes":spikes.size()}))
	stage.queue_free();await process_frame;game.free();quit(0 if failures.is_empty() else 1)
