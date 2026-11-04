extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(condition: Callable, seconds := 3.0) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		if condition.call(): return true
	return false
func client_account() -> NavalAccounts:
	var client := NavalAccounts.new()
	client.client_key = Crypto.new().generate_rsa(2048)
	client.persist_session = false
	root.add_child(client)
	return client
func network(branch: String, service := false) -> NavalNetwork:
	var node := Node.new()
	node.name = branch
	root.add_child(node)
	var result := NavalNetwork.new()
	result.name = "Network"
	node.add_child(result)
	result.require_accounts = true
	if service:
		result.port = 0
		check(result.serve()==OK,"ENet authority bound")
	return result
func run() -> void:
	var account := client_account()
	var username := "qa_"+NavalCatalog.uid().left(18)
	var password := NavalCatalog.uid()+"Aa!"
	var registered := await account.sign_in("register",username,password)
	check(registered.get("ok",false),"HTTPS registration with device proof")
	if not registered.get("ok",false): print(registered);quit(1);return
	check(account.profile.coins==0 and account.profile.owned==["light"],"new account has authoritative initial balance")
	check(not NavalAccounts.verify_ticket(account.ticket,account.device_key().save_to_string(true).sha256_text()).is_empty(),"central signature and device binding valid")
	var forged := account.ticket.duplicate()
	forged.payload = Marshalls.utf8_to_base64('{"coins":999999}')
	check(NavalAccounts.verify_ticket(forged).is_empty(),"forged profile rejected")
	check(NavalAccounts.verify_ticket(account.ticket,"another-device").is_empty(),"ticket cannot authenticate a different device")
	var tx := NavalCatalog.uid()
	var bought := await account.call_api("buy",{"ship":"heavy","transaction":tx,"price":0,"coins":999999})
	await account.call_api("buy",{"ship":"light","transaction":tx})
	check(not bought.get("ok",false) and account.profile.coins==0 and "heavy" not in account.profile.owned,"server ignores client-supplied price and balance")
	await account.call_api("buy",{"ship":"light","transaction":tx})
	check(account.profile.coins==0,"duplicate transaction does not charge twice")
	var bad_tx := await account.call_api("buy",{"ship":"combat","transaction":tx})
	check(not bad_tx.get("ok",false),"transaction cannot be reused for another ship")
	await account.call_api("select",{"ship":"light"})
	var token := account.token
	await account.logout()
	check(account.token.is_empty(),"logout clears the local session")
	account.token = token
	var revoked := await account.call_api("profile")
	check(not revoked.get("ok",false),"revoked server session cannot be reused")
	var other := client_account()
	var wrong := await other.sign_in("login",username,password+"wrong")
	check(not wrong.get("ok",false),"wrong password rejected")
	var logged := await other.sign_in("login",username,password)
	check(logged.get("ok",false) and other.profile.selected=="light" and other.profile.coins==0,"same account on a different device reloads purchases and selected ship")
	var a := network("AuthorityA",true)
	var b := network("AuthorityB",true)
	var guest := network("Guest")
	guest.account_ticket = other.ticket
	guest.connect_server("127.0.0.1:"+str(a.port),"Ignored nickname")
	guest.key = other.device_key()
	check(await wait_for(func(): return guest.authenticated),"account authenticates to player-hosted server A")
	check(guest.account.selected=="light" and "light" in guest.account.owned,"server A uses central fleet")
	guest.close_connection()
	await create_timer(0.15).timeout
	guest.connect_server("127.0.0.1:"+str(b.port),"Ignored nickname")
	guest.key = other.device_key()
	check(await wait_for(func(): return guest.authenticated),"same account authenticates to player-hosted server B")
	check(guest.account.selected=="light" and guest.account.coins==0,"switching hosts preserves the same account and ship")
	await other.logout()
	for item in [a,b,guest]: item.get_parent().queue_free()
	account.queue_free()
	other.queue_free()
	await process_frame
	var result := {"checks":checks,"failures":failures}
	FileAccess.open("res://tests/naval-accounts-results.json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
