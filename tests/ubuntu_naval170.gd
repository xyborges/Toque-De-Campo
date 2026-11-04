extends SceneTree
var checks:=0
var failures: Array[String]=[]
var clients: Array[NavalNetwork]=[]
var accounts: Array[NavalAccounts]=[]
var snapshots: Dictionary={}
var shots: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(condition: Callable,seconds:=10.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		if condition.call(): return true
	failures.append("condition timed out");return false
func received(kind: String,payload: Dictionary,index: int) -> void:
	if kind=="snapshot": snapshots[index]=payload
	if kind=="shot": shots[index]=int(shots.get(index,0))+1
func run() -> void:
	var private_credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	for index in 2:
		var credential: Dictionary=private_credentials.host if index==0 else private_credentials.guest
		var account:=NavalAccounts.new();account.persist_session=false;account.client_key=Crypto.new().generate_rsa(2048);root.add_child(account);accounts.append(account)
		var response:=await account.sign_in("login",str(credential.username),str(credential.password))
		check(bool(response.get("ok",false)) and account.validated_session,"real naval account authenticates over verified TLS")
		if not bool(response.get("ok",false)): await finish();return
		var branch:=Node.new();branch.name="Fleet"+str(index);root.add_child(branch)
		var client:=NavalNetwork.new();branch.add_child(client);clients.append(client);client.account_ticket=account.ticket
		client.event_received.connect(received.bind(index));client.connect_server(NavalCatalog.SERVER,str(account.profile.username));client.key=account.device_key()
		if not await wait_for(func():return client.authenticated): await finish();return
		check(client.require_accounts and not NavalAccounts.testing(),"production ENet validates the real signed account")
	var a:=clients[0];var b:=clients[1];var secret:=NavalCatalog.uid()
	a.request("create",{"name":"QA170","limit":2,"private":true,"password":secret,"late":false})
	if not await wait_for(func():return not a.room.is_empty()): await finish();return
	b.request("join",{"id":a.room.id,"password":secret})
	if not await wait_for(func():return a.room.members.size()==2): await finish();return
	a.request("start");await create_timer(.35).timeout
	check(a.room.state=="WAITING" and not snapshots.has(0),"two real accounts cannot start before confirming their fleets")
	var chosen:=str(a.account.owned.back());a.request("select",{"ship":chosen})
	if not await wait_for(func():return str(a.account.selected)==chosen): await finish();return
	a.request("ready");b.request("ready")
	if not await wait_for(func():
		for member in a.room.members:
			if not bool(member.get("ready",false)): return false
		return true
	): await finish();return
	check(a.room.members.size()==2,"both confirmed players appear in the same central lobby")
	a.request("start")
	if not await wait_for(func():return snapshots.has(0) and snapshots.has(1) and snapshots[0].ships.size()==2): await finish();return
	var body: Dictionary={}
	for state in snapshots[0].ships:
		if int(state.peer)==a.connection.get_unique_id(): body=state;break
	check(not body.is_empty() and str(body.kind)==chosen and int(body.ammo.lightMG)==600,"central authority deploys the selected owned ship with real finite ammunition")
	var until:=Time.get_ticks_msec()+2200
	while Time.get_ticks_msec()<until:
		a.send_control(0,0,Vector3(body.position)+Vector3(0,4,-200),"lightMG",true)
		await create_timer(.05).timeout
	a.stop_fire();await create_timer(.35).timeout
	check(int(shots.get(0,0))>0 and int(shots.get(0,0))==int(shots.get(1,0)),"every authoritative naval shot replicates to both real players")
	var fired:=int(shots.get(0,0));await create_timer(.5).timeout
	check(int(shots.get(0,0))==fired,"reliable release stops the trigger on production authority")
	a.request("leave");b.request("leave")
	if await wait_for(func():return a.room.is_empty() and b.room.is_empty()): check(true,"leaving clears both real players' room state")
	await finish()
func finish() -> void:
	for client in clients: client.close_connection();client.get_parent().queue_free()
	for account in accounts: account.queue_free()
	await create_timer(.25).timeout
	var result:={"checks":checks,"failures":failures,"source":"production Ubuntu; two signed real QA accounts; no authority fixture or test-account mode"}
	NavalStorage.write_json("res://tests/ubuntu-naval170-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
