extends SceneTree
const BEFORE=preload("res://work/afghan_environment_preoptimization.gd")
const AFTER=preload("res://modes/battle_royale/map/afghan_environment.gd")
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
var errors: Array[String]=[]
var checks:=0
class Fixture extends Node3D:
	var render_visuals:=false
	var pieces: Array=[]
	var detail_count:=0
	func point(x: float,z: float) -> Vector3: return Vector3(x,0,z)
	func height_at(_x: float,_z: float) -> float: return 0.
	func add_piece(id: String,transform: Transform3D,_group: Dictionary,_color:=Color.WHITE) -> Node3D:
		pieces.append([id,transform]);return null
	func finish_static_batches(_groups: Dictionary,_reach: float,_shadows:=false) -> void: pass
	func finish_batches(groups: Dictionary,_reach: float,_shadows:=false) -> void:
		for value in groups.values(): detail_count+=value.transforms.size()
func _initialize() -> void: run.call_deferred()
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition: errors.append(message);push_error(message)
func run() -> void:
	LAND.building_layout()
	var rng:=RandomNumberGenerator.new();rng.seed=712907
	var points: Array[Vector3]=[]
	for i in 18000: points.append(Vector3(rng.randf_range(-1100,1100),rng.randf_range(-5,80),rng.randf_range(-1100,1100)))
	var before: Array[bool]=[]
	var start:=Time.get_ticks_usec()
	for p in points: before.append(BEFORE._near_path(p,8.))
	var baseline_usec:=Time.get_ticks_usec()-start
	start=Time.get_ticks_usec()
	for i in points.size(): check(before[i]==AFTER._near_path(points[i],8.),"Path decision differs at %s"%points[i])
	var optimized_usec:=Time.get_ticks_usec()-start
	# Exercise real placements as well as the path predicate. Old visual output
	# must match; server collision-bearing pieces must match the visual client.
	var old_visual:=Fixture.new();old_visual.render_visuals=true;root.add_child(old_visual)
	start=Time.get_ticks_usec();BEFORE.populate(old_visual);var baseline_populate:=Time.get_ticks_usec()-start
	var new_visual:=Fixture.new();new_visual.render_visuals=true;root.add_child(new_visual)
	start=Time.get_ticks_usec();AFTER.populate(new_visual);var optimized_populate:=Time.get_ticks_usec()-start
	var server:=Fixture.new();root.add_child(server)
	start=Time.get_ticks_usec();AFTER.populate(server);var authority_populate:=Time.get_ticks_usec()-start
	check(var_to_bytes(old_visual.pieces)==var_to_bytes(new_visual.pieces),"Optimized visual placements match reference")
	check(old_visual.detail_count==new_visual.detail_count,"Optimized visual detail count matches reference")
	check(var_to_bytes(new_visual.pieces)==var_to_bytes(server.pieces),"Headless authority and client collision placements agree")
	var report:={"checks":checks,"errors":errors,"baseline_query_ms":baseline_usec*.001,"optimized_query_ms":optimized_usec*.001,"baseline_visual_populate_ms":baseline_populate*.001,"optimized_visual_populate_ms":optimized_populate*.001,"authority_populate_ms":authority_populate*.001,"visual_piece_count":new_visual.pieces.size(),"visual_detail_count":new_visual.detail_count,"server_piece_count":server.pieces.size(),"limitations":"Headless synthetic fixture omits real terrain and GPU; timings do not measure full map load."}
	NavalStorage.write_json("res://work/afghan-environment-optimization.json",report)
	print("AFGHAN_ENVIRONMENT_OPTIMIZATION ",JSON.stringify(report))
	old_visual.free();new_visual.free();server.free();quit(0 if errors.is_empty() else 1)
