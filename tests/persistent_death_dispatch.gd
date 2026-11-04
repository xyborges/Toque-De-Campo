extends SceneTree
class AccountsFixture extends NavalAccounts:
	var requests: Array[Dictionary]=[]
	func call_api(action: String,values: Dictionary={}) -> Dictionary:
		requests.append({"action":action,"values":values.duplicate(true)})
		return {"ok":true}
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func run() -> void:
	var game=load("res://tests/combat_153_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.set_physics_process(false)
	var original: NavalAccounts=game.main_accounts;original.queue_free()
	var accounts:=AccountsFixture.new();game.add_child(accounts);accounts.service_auth=true;game.main_accounts=accounts
	var victim:=GamePlayer.new();victim.peer_id=42;victim.life_id=3;victim.set_meta("account_id","2".repeat(32));game.players[42]=victim
	game.dedicated_pvp=true;game.online=true;game.pvp_match_id="1".repeat(32)
	game._record_match_death(victim);await process_frame;await process_frame
	check(accounts.requests.size()==2,"dedicated authority submits registration and a death event")
	if accounts.requests.size()>=2:
		var registration:=accounts.requests[0];var death:=accounts.requests[1]
		check(registration.action=="match_register" and registration.values.mode=="infantry" and registration.values.players==["2".repeat(32)],"death registration includes the victim's verified account")
		check(death.action=="match_death" and death.values.event==game.pvp_match_id+":42:3" and death.values.victim=="2".repeat(32),"death event uses the same match/victim-life key as its possible reward")
		check(not death.values.has("killer") and not death.values.has("coins"),"a standalone death cannot invent a killer or money")
	game._record_match_death(victim);await process_frame
	check(accounts.requests.size()==2,"repeated death notification is not submitted twice")
	victim.life_id=4;game._record_match_death(victim);await process_frame;await process_frame
	check(accounts.requests.size()==4,"a new life produces a distinct death event")
	game.set_meta("war_mode",true);victim.life_id=5;game._record_match_death(victim);await process_frame;await process_frame
	check(accounts.requests.size()==6 and accounts.requests[4].values.mode=="war","War shares the authority path with the correct registered mode")
	game.online=false;victim.life_id=6;game._record_match_death(victim);await process_frame
	check(accounts.requests.size()==6,"offline training never sends lifetime deaths")
	game.online=true;accounts.service_auth=false;game._record_match_death(victim);await process_frame
	check(accounts.requests.size()==6,"ordinary player credentials cannot submit a lifetime death")
	accounts.service_auth=true;victim.is_npc=true;game._record_match_death(victim);await process_frame
	check(accounts.requests.size()==6,"NPC deaths do not change a human account ranking")
	game.online=false;game.players.clear();victim.free();game.queue_free();await process_frame;await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"fixture":"Real dispatch/authority guards; API transport is recorded locally. Real PHP/SQLite idempotency is tested separately."}
	NavalStorage.write_json("res://tests/persistent-death-dispatch-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
