extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func run() -> void:
	var accounts:=NavalAccounts.new();root.add_child(accounts)
	var credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var result: Dictionary=await accounts.sign_in("login",str(credentials.host.username),str(credentials.host.password))
	check(bool(result.get("ok",false)) and accounts.validated_session,"central account login uses verified TLS and a signed profile")
	if failures.is_empty():
		var response: Dictionary=await accounts.call_api("rankings")
		check(bool(response.get("ok",false)) and GameGlobalRanking.valid_payload(response.get("rankings",{})),"live ranking response matches the shared UI schema")
		var data: Dictionary=response.get("rankings",{})
		for kind in ["kills","kd","deaths","coins"]:
			check(data.get(kind,[]) is Array and data.get(kind,[]).size()<=10,"bounded top ten: "+kind)
		response=await accounts.call_api("rankings")
		check(bool(response.get("ok",false)) and bool(response.get("cached",false)),"second ranking request reuses the central hourly cache")
		var status: Dictionary={"code":0}
		accounts.connection_state.connect(func(_transport: int,code: int):status.code=code)
		for action in ["match_register","reward","match_wallet","match_death"]:
			response=await accounts.call_api(action,{"mode":"war"})
			check(not bool(response.get("ok",false)) and int(status.code)==403,"ordinary player credentials cannot call "+action)
	var report: Dictionary={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/ubuntu-ranking-results.json",report);print(JSON.stringify(report))
	accounts.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
