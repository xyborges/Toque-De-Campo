extends SceneTree
const WRITER=preload("res://scripts/server_status_writer.gd")
class SlowWriter extends WRITER:
	var writes:=0
	func _write(path: String,data: Dictionary) -> Error:
		OS.delay_msec(40)
		writes+=1
		return super._write(path,data)

var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures.append(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var path:=NavalStorage.folder().path_join("server-status-test.json")
	var writer:=SlowWriter.new()
	var state:={"bots":28,"teams":[14,14],"updated":1}
	check(writer.submit(path,state)==OK,"server accepts an immutable status snapshot")
	state.teams[0]=99
	writer.close()
	var saved:=NavalStorage.read_json(path)
	check(saved.get("teams",[]).size()==2 and int(saved.teams[0])==14 and int(saved.teams[1])==14 and writer.error()==OK,"worker never observes later scene-state mutations: "+JSON.stringify(saved))
	var started:=Time.get_ticks_usec()
	for serial in 50:writer.submit(path,{"bots":28,"updated":serial,"phase":"active"})
	var enqueue_usec:=Time.get_ticks_usec()-started
	writer.close();saved=NavalStorage.read_json(path)
	check(saved.get("updated",-1)==49 and saved.get("bots",0)==28,"shutdown commits the newest queued status")
	check(writer.writes<=4,"slow storage coalesces status updates instead of building a backlog")
	check(enqueue_usec<40000,"submitting 50 updates does not wait for even one simulated 40 ms disk write")
	check(not writer.worker.is_started() and not FileAccess.file_exists(path+".tmp"),"shutdown joins the worker and keeps atomic JSON replacement")
	check(writer.submit(path,{"updated":50})==OK,"the same game can start its writer again")
	writer.close()
	check(NavalStorage.read_json(path).get("updated",-1)==50,"restarted writer flushes correctly")
	print("SERVER_STATUS_WRITER ",JSON.stringify({"failures":failures,"submits_50_usec":enqueue_usec,"writes":writer.writes}))
	quit(0 if failures.is_empty() else 1)
