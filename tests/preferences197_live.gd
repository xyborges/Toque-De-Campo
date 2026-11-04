extends SceneTree
var failures: Array[String]=[]
var checks:=0
var role:="writer"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var account:=NavalAccounts.new();root.add_child(account)
	var credentials_key:="guest" if role=="other" else "host"
	var login: Dictionary=await account.sign_in("login",str(credentials[credentials_key].username),str(credentials[credentials_key].password))
	check(bool(login.get("ok",false)) and account.validated_session,"authenticated account with HTTPS")
	if failures.is_empty():
		var sync:=account.preferences_sync
		check(sync.ready_to_send,"server preferences loaded before continuing")
		if role in ["writer","other"]:
			var wanted_aa:=2 if role=="writer" else 1
			var wanted_sensitivity:=.83 if role=="writer" else .51
			GameOptions.set_value("aa",wanted_aa);GameOptions.flush()
			GameAimSensitivity.set_values("weapon:fal",wanted_sensitivity,.47);GameAimSensitivity.flush()
			GameAudioSettings.set_volume("Music",.55);GameAudioSettings.flush()
			NavalStorage.write_json(NavalStorage.settings_folder().path_join("war-camera.json"),{"distance":3.5,"side":.8})
			var until:=Time.get_ticks_msec()+15000
			while not sync.pending.is_empty() and Time.get_ticks_msec()<until: await process_frame
			check(sync.pending.is_empty(),"all preference categories confirmed by server")
		else:
			var values:=GameAimSensitivity.values("weapon:fal")
			check(int(GameOptions.number("aa",0))==2,"new computer restores the account antialiasing")
			check(is_equal_approx(values.normal,.83) and is_equal_approx(values.aim,.47),"new computer restores the account sensitivity")
			check(is_equal_approx(GameAudioSettings.get_volume("Music"),.55),"new computer restores account audio")
			check(is_equal_approx(float(NavalStorage.read_json(NavalStorage.settings_folder().path_join("war-camera.json")).get("distance",0)),3.5),"new computer restores account camera")
	await account.logout();account.queue_free();await process_frame
	print(JSON.stringify({"role":role,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
