extends SceneTree
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const ENV=preload("res://modes/battle_royale/map/afghan_environment.gd")
var failures: Array[String]=[]
var checks:=0
class Fixture extends Node3D:
	var render_visuals:=false
	var pieces: Array=[]
	func point(x: float,z: float) -> Vector3:return Vector3(x,0,z)
	func height_at(_x: float,_z: float) -> float:return 0.
	func add_piece(id: String,t: Transform3D,_groups: Dictionary,_color:=Color.WHITE) -> Node3D:pieces.append([id,t]);return null
	func finish_static_batches(_g: Dictionary,_r: float,_s:=false) -> void:pass
	func finish_batches(_g: Dictionary,_r: float,_s:=false) -> void:pass
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func run() -> void:
	var farms:=LAND.farmland_layout()
	check(farms.size()>=12,"connected agricultural parcels")
	for farm: Dictionary in farms:
		check(farm.has("gate") and farm.has("access"),"parcel has an access")
		if farm.get("source","stream")=="stream":check(LAND.channel_distance(Vector2(farm.position.x-farm.side*(farm.size.x*.5+3.),farm.position.z))<.1,"supply ditch reaches parcel boundary")
	for house: Dictionary in LAND.building_layout():check(not LAND.in_farmland(Vector2(house.position.x,house.position.z),house.radius),"house does not occupy a reserved field")
	var server:=Fixture.new();root.add_child(server);ENV.populate(server)
	var visual:=Fixture.new();visual.render_visuals=true;root.add_child(visual);ENV.populate(visual)
	check(var_to_bytes(server.pieces)==var_to_bytes(visual.pieces),"authority/client colliders have identical placement")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"fields":farms.size(),"channels":LAND.irrigation_layout().size(),"buildings":LAND.building_layout().size(),"collision_pieces":server.pieces.size(),"scope":"Deterministic territory plan and environment placement; no FPS or live battle claim."}
	NavalStorage.write_json("res://work/afghan-territory-plan.json",report);print("TERRITORY ",JSON.stringify(report));server.free();visual.free();quit(0 if failures.is_empty() else 1)
