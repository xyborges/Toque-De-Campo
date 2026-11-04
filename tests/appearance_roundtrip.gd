extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,text: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures.append(text)
func run() -> void:
	var game=load("res://scripts/main.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	var first: NavalAccounts=game.main_accounts
	first.persist_session=false
	var username:="qa_look_"+NavalCatalog.uid().left(12)
	var secret:=NavalCatalog.uid()+"Aa!"
	var registered: Dictionary=await first.sign_in("register",username,secret)
	check(registered.get("ok",false),"real central registration succeeds")
	if not registered.get("ok",false): quit(1);return
	var look: Dictionary={"skin":"8ca16c","proportions":{"head":.8,"torso":1.1,"arms":1.25,"legs":.95}}
	var saved: Dictionary=await first.call_api("appearance",{"appearance":look})
	check(saved.get("ok",false),"central server saves appearance")
	check(first.profile.get("appearance",{})==look,"returned profile includes every appearance field")
	var verified:=NavalAccounts.verify_ticket(first.ticket)
	check(verified.get("appearance",{})==look,"appearance is covered by the signed account ticket")
	game._apply_account_profile()
	check(game.profile.skin==look.skin and game.profile.proportions==look.proportions,"main game restores account appearance without array/type errors")
	var second:=NavalAccounts.new()
	second.client_key=Crypto.new().generate_rsa(2048)
	second.persist_session=false
	root.add_child(second)
	var login: Dictionary=await second.sign_in("login",username,secret)
	check(login.get("ok",false) and second.profile.get("appearance",{})==look,"another device reloads the same character")
	var invalid: Dictionary=await second.call_api("appearance",{"appearance":{"skin":"123456","proportions":{"head":20,"torso":1,"arms":1,"legs":1}}})
	check(not invalid.get("ok",false),"real backend rejects oversized character proportions")
	var reload_result: Dictionary=await second.call_api("profile")
	check(reload_result.get("ok",false) and second.profile.appearance==look and second.profile.coins==0,"invalid update leaves saved character and wallet intact")
	await first.logout();await second.logout()
	game.queue_free();second.queue_free()
	await process_frame
	var report: Dictionary={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/appearance-roundtrip-results.json",report);print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
