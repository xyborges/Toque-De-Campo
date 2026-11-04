extends SceneTree

class StateVehicle extends WarVehicle:
	var test_position:=Vector3.ZERO
	func snapshot() -> Dictionary:
		return {"id":vehicle_id,"position":test_position,"destroyed":destroyed,"seats_revision":seats_revision}

var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func run() -> void:
	var manager:=WarVehicles.new()
	var first:=StateVehicle.new();first.vehicle_id="first"
	var second:=StateVehicle.new();second.vehicle_id="second"
	var initial:=manager._vehicle_snapshot_for_send(first,1000000)
	check(int(initial.sequence)==1,"first pose has a sequence")
	check(manager._vehicle_snapshot_for_send(first,1499999).is_empty(),"unchanged state does not spam the network")
	var heartbeat:=manager._vehicle_snapshot_for_send(first,1500000)
	check(int(heartbeat.sequence)==2 and heartbeat.position==initial.position,"stopped vehicle repairs a lost final pose within 500ms")
	first.test_position=Vector3(4,0,0)
	check(int(manager._vehicle_snapshot_for_send(first,1550000).sequence)==3,"movement sends immediately at the existing snapshot cadence")
	check(int(manager._vehicle_snapshot_for_send(second,1550000).sequence)==1,"vehicles have independent sequence spaces")
	first.destroyed=true
	check(int(manager._vehicle_snapshot_for_send(first,1600000).sequence)==4,"destruction sends without waiting for the heartbeat")
	first.destroyed=false;first.test_position=Vector3(-100,0,0)
	check(int(manager._vehicle_snapshot_for_send(first,1650000).sequence)==5,"respawn keeps a monotonic sequence")
	first.seats_revision+=1
	check(int(manager._vehicle_snapshot_for_send(first,1700000).sequence)==6,"occupancy changes are also sent immediately")
	var result:={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/heartbeat191-results.json",result)
	print("HEARTBEAT191 "+JSON.stringify(result))
	first.free();second.free();manager.free()
	quit(0 if failures.is_empty() else 1)
