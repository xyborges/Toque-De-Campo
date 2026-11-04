extends SceneTree
const ACCOUNT_TEST=preload("res://tests/account_preferences197.gd")
class LoadoutContext extends Node:
	var main_accounts: NavalAccounts
	var profile: Dictionary={"owned":GameWeapons.INFANTRY_IDS}
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: errors.append(label);print("FAIL ",label)
func run() -> void:
	var account:=ACCOUNT_TEST.FakeAccounts.new();root.add_child(account)
	var sync:=GameAccountPreferences.new();sync.setup(account);account.add_child(sync);sync.set_process(false)
	account.validated_session=true;account.token="local-test"
	var token:=str(Time.get_ticks_usec()).sha256_text()
	var a:=token.substr(0,32);var b:=(token+"_other").sha256_text().substr(0,32)
	account.cloud[a]={"game":{"weapon_optics":{"fal":0,"ak":4}}}
	account.cloud[b]={"game":{"weapon_optics":{"fal":0,"ak":0}}}
	var context:=LoadoutContext.new();context.main_accounts=account;root.add_child(context)
	account.profile={"id":a};await sync.activate(a,account.session_generation)
	var loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"soldier",0);loadout.optic="scope4x"
	GameLoadouts.save(context,"war",loadout,"soldier",0);await sync._upload(a,account.session_generation)
	check(int(account.cloud[a].game.weapon_optics.fal)==4,"scope choice enters existing numeric account preference upload")
	check(GameLoadouts.saved(context,"war","soldier",0).slots.get("optic","")=="prism4x","saved scope restored for same account")
	account.session_generation+=1;account.profile={"id":b};await sync.activate(b,account.session_generation)
	check(not GameLoadouts.saved(context,"war","soldier",0).slots.has("optic"),"another account has its own scope preference")
	account.session_generation+=1;account.profile={"id":a};await sync.activate(a,account.session_generation)
	check(GameLoadouts.saved(context,"war","soldier",0).slots.get("optic","")=="prism4x","relogin restores account A optic")
	loadout.erase("optic");GameLoadouts.save(context,"war",loadout,"soldier",0);await sync._upload(a,account.session_generation)
	check(int(account.cloud[a].game.weapon_optics.fal)==0 and int(account.cloud[a].game.weapon_optics.ak)==4,"removing FAL scope preserves AK preference")
	GameOptions.set_value("weapon_optics",{"fal":"4","ak":INF,"sniper":4})
	check(GameLoadouts.optic_preferences()=={"sniper":4},"malformed entries rejected while valid sniper numeric preference remains")
	check(account.cloud[b].game.weapon_optics.fal==0,"changes never overwrite account B")
	var sniper_loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"marksman",0)
	sniper_loadout.optic="precision8x"
	GameLoadouts.save(context,"war",sniper_loadout,"marksman",0)
	check(GameLoadouts.saved(context,"war","marksman",0).slots.get("optic","")=="precision8x","8x scope survives save and reload")
	sniper_loadout.erase("optic")
	GameLoadouts.save(context,"war",sniper_loadout,"marksman",0)
	check(not GameLoadouts.saved(context,"war","marksman",0).slots.has("optic"),"sniper preference can persist iron sights without optic")
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors,"scope":"Existing account preference synchronizer with two mocked accounts; no real account API or production server accessed."}
	NavalStorage.write_json("res://work/optic-preferences.json",report);print("OPTIC_PREFERENCES ",JSON.stringify(report))
	sync.deactivate();context.queue_free();account.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
