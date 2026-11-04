extends SceneTree
var failures: Array[String]=[]
var checks:=0
class FakeAccounts extends NavalAccounts:
	var cloud: Dictionary={}
	var connected:=true
	var get_delay:=0.0
	func _ready() -> void: pass
	func call_api(action: String,values: Dictionary={}) -> Dictionary:
		if not connected: return {"ok":false}
		var id:=str(profile.get("id",""))
		if action=="preferences_get":
			var captured: Dictionary=cloud.get(id,{}).duplicate(true)
			if get_delay>0: await get_tree().create_timer(get_delay).timeout
			return {"ok":true,"settings":captured}
		if action=="preferences_set":
			if not cloud.has(id): cloud[id]={}
			for key in values.sections: cloud[id][key]=values.sections[key].duplicate(true)
			return {"ok":true}
		return {"ok":false}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var folder:=ProjectSettings.globalize_path("res://work/preferences197-test")
	DirAccess.make_dir_recursive_absolute(folder)
	NavalStorage._folder_path=folder;NavalStorage.preference_account="";NavalStorage.preference_changed=Callable()
	var a:="a".repeat(32);var b:="b".repeat(32)
	for id in [a,b]:
		var location:=folder.path_join("preferences").path_join(id);DirAccess.make_dir_recursive_absolute(location)
		for file in ["game-options.json","aim-sensitivity.json","audio-settings.json","pending.json","migration-done.json"]:
			if FileAccess.file_exists(location.path_join(file)): DirAccess.remove_absolute(location.path_join(file))
	var account:=FakeAccounts.new();root.add_child(account);account.validated_session=true;account.token="local-test"
	account.cloud[a]={"game":{"aa":2},"aim":{"schema":2,"profiles":{"weapon:fal":{"normal":.72,"aim":.65}}}}
	account.cloud[b]={"game":{"aa":1},"aim":{"schema":2,"profiles":{"weapon:fal":{"normal":.45,"aim":.50}}}}
	var sync:=GameAccountPreferences.new();sync.setup(account);account.add_child(sync);sync.set_process(false)
	account.profile={"id":a};await sync.activate(a,account.session_generation)
	check(int(GameOptions.number("aa",0))==2 and is_equal_approx(GameAimSensitivity.values("weapon:fal").normal,.72),"account A loads video and sensitivity from server")
	GameOptions.set_value("aa",0);GameOptions.flush();GameAimSensitivity.set_values("weapon:fal",.81,.55);GameAimSensitivity.flush()
	await sync._upload(a,account.session_generation)
	check(account.cloud[a].game.aa==0 and is_equal_approx(account.cloud[a].aim.profiles["weapon:fal"].normal,.81),"changes sync to account A")
	account.session_generation+=1;account.profile={"id":b};await sync.activate(b,account.session_generation)
	check(int(GameOptions.number("aa",0))==1 and is_equal_approx(GameAimSensitivity.values("weapon:fal").normal,.45),"account B loads only its own settings")
	GameOptions.set_value("aa",3);GameOptions.flush();await sync._upload(b,account.session_generation)
	check(account.cloud[a].game.aa==0 and account.cloud[b].game.aa==3,"accounts remain isolated on the same computer")
	account.connected=false;GameAimSensitivity.set_values("weapon:fal",.33,.44);GameAimSensitivity.flush();await sync._upload(b,account.session_generation)
	check(sync.pending.has("aim"),"offline changes remain queued")
	account.connected=true;await sync._pull(b,account.session_generation)
	check(is_equal_approx(GameAimSensitivity.values("weapon:fal").normal,.33),"reconnection does not overwrite pending local edits")
	await sync._upload(b,account.session_generation)
	check(sync.pending.is_empty() and is_equal_approx(account.cloud[b].aim.profiles["weapon:fal"].normal,.33),"pending changes upload after reconnect")
	account.get_delay=.15;sync._pull(b,account.session_generation)
	GameAimSensitivity.set_values("weapon:fal",.91,.71);GameAimSensitivity.flush()
	await create_timer(.25).timeout
	check(is_equal_approx(GameAimSensitivity.values("weapon:fal").normal,.91),"a late server response cannot overwrite newer local changes")
	account.session_generation+=1;account.profile={"id":a};sync.activate(a,account.session_generation)
	await create_timer(.03).timeout
	account.session_generation+=1;account.profile={"id":b};account.get_delay=0.;await sync.activate(b,account.session_generation)
	await create_timer(.2).timeout
	check(sync.account_id==b and is_equal_approx(GameAimSensitivity.values("weapon:fal").normal,.91),"response from old login cannot replace the new account's settings")
	sync.deactivate();account.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
