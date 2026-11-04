extends SceneTree
class Probe:
	extends NavalAccounts
	var calls:=0
	var invalidate:=false
	var success_on_second:=true
	func _ready() -> void: pass
	func _call_api_once(_action: String,_values: Dictionary={}) -> Dictionary:
		calls+=1
		if invalidate: session_generation+=1
		return {"ok":true} if calls>1 and success_on_second else {"ok":false,"_retry_profile":true}
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var failures: Array[String]=[];var checks:=0
	for action in ["profile","purchase","login"]:
		var probe:=Probe.new();root.add_child(probe)
		var result:=await probe.call_api(action)
		var ok:=probe.calls==(2 if action=="profile" else 1) and not result.has("_retry_profile")
		checks+=1
		if not ok: failures.append(action)
		probe.queue_free()
	var invalid:=Probe.new();invalid.invalidate=true;root.add_child(invalid);await invalid.call_api("profile")
	checks+=1
	if invalid.calls!=1: failures.append("old session retried")
	invalid.queue_free()
	var bounded:=Probe.new();bounded.success_on_second=false;root.add_child(bounded);await bounded.call_api("profile")
	checks+=1
	if bounded.calls!=2: failures.append("unbounded retry")
	bounded.queue_free()
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/bugs187-accounts-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
