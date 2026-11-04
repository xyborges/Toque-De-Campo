extends "res://tests/join1103_faults_fixture.gd"
class LightweightVehicles extends WarVehicles:
	var created_in_batch:=0
	var largest_batch:=0
	var baseline_calls:=0
	func _ready() -> void:
		name="WarVehicles";tv.manager=self
	func _physics_process(_delta: float) -> void:pass
	func _process(_delta: float) -> void:pass
	func _input(_event: InputEvent) -> void:pass
	@rpc("authority","call_remote","reliable")
	func baseline_drone(state: Dictionary) -> void:
		if not drones.has(str(state.id)):created_in_batch+=1
		baseline_calls+=1
		super.baseline_drone(state)
	func finish_batch() -> void:
		largest_batch=maxi(largest_batch,created_in_batch);created_in_batch=0

var hold_first:=false
var first_chunk_held:=false
var drone_results: Dictionary={}
func _network_port() -> int:return 39623
func _enter_match_world() -> void:
	super._enter_match_world()
	world_root.name="World"
	if is_instance_valid(vehicle_system):return
	vehicle_system=LightweightVehicles.new();vehicle_system.game=self;world_root.add_child(vehicle_system)
@rpc("authority","call_remote","reliable")
func war_baseline_chunk(transfer: String,nonce: String,count: int,total: int) -> void:
	vehicle_system.finish_batch()
	if hold_first and not first_chunk_held:
		first_chunk_held=true
		rpc_id(1,"qa_mutate_drones")
		await get_tree().create_timer(.3).timeout
	await super.war_baseline_chunk(transfer,nonce,count,total)
func spawn_drone(key: String) -> WarDrone:
	var drone:=WarDrone.new();drone.drone_id=key;drone.owner_id=1;drone.position=Vector3(vehicle_system.drones.size()*2,3,0)
	vehicle_system.add_child(drone);vehicle_system.drones[key]=drone
	return drone
@rpc("any_peer","call_remote","reliable")
func qa_mutate_drones() -> void:
	var id:=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not loading_baselines.has(id):return
	if vehicle_system.drones.has("qa_b"):
		var old: WarDrone=vehicle_system.drones.qa_b
		vehicle_system.drones.erase("qa_b");old.queue_free()
		vehicle_system._broadcast("drone_removed",["qa_b"])
	var drone:=spawn_drone("qa_d")
	vehicle_system._broadcast("drone_state",[drone.snapshot()])
	qa.mutated_while_loading=loading_baselines.has(id)
@rpc("any_peer","call_remote","reliable")
func qa_drone_result(label: String,ids: Array,largest: int,calls: int) -> void:
	if multiplayer.is_server():drone_results[label]={"ids":ids,"largest":largest,"calls":calls}
