extends SceneTree
class Fixture extends WarVehicles:
 func _ready() -> void:pass
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label)
 print(("PASS " if ok else "FAIL ")+label)
func state(id:String) -> Dictionary:
 return {"id":id,"owner":2,"driver":2,"team":0,"position":Vector3(10,4,0),"velocity":Vector3.ZERO,"yaw":0.,"hp":60.,"battery":55.,"destroyed":false,"falling":false}
func run() -> void:
 var v:=Fixture.new();root.add_child(v)
 v.baseline_drone(state("drone_a"));v.baseline_drone(state("drone_b"))
 check(v.drones.size()==2 and v.drones.has("drone_a") and v.drones.has("drone_b"),"separate reliable batches retain both drones")
 v.baseline_vehicles([])
 check(v.drones.size()==2,"vehicle-only baseline does not erase drones")
 v.baseline_drone(state("drone_a"))
 check(v.drones.size()==2,"refresh updates existing drone without creating duplicates")
 v.snapshot([],[state("drone_b")])
 check(v.drones.size()==1 and v.drones.has("drone_b"),"ordinary full snapshot still removes missing drones")
 var result:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual vehicle receive methods with real drone nodes; verifies incremental join baseline and later full snapshot semantics, headless, no network."}
 NavalStorage.write_json("res://work/join1103-drone-validation.json",result);print(JSON.stringify(result));v.free();await process_frame;quit(0 if failures.is_empty() else 1)
