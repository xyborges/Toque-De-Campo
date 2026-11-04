extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(condition: Callable,seconds:=12.) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		if condition.call(): return true
	failures.append("timeout");push_error("Naval UI condition timed out");return false
func find_button(parent: Node,label: String) -> Button:
	for candidate: Button in parent.find_children("*","Button",true,false):
		if candidate.text==label: return candidate
	return null
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(.35).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/deployment170-naval-"+label+".png")
func run() -> void:
	var server:=NavalMode.new();server.dedicated=true;root.add_child(server)
	var mode: NavalMode=load("res://tests/deployment170_naval_mode_fixture.gd").new();mode.nickname="Comandante";root.add_child(mode);mode.address_field.text="127.0.0.1:39583";mode._connect();mode.network.key=Crypto.new().generate_rsa(2048)
	mode.network.event_received.connect(func(kind,payload): if kind in ["error","authenticated"]: print("QA COMMANDER ",kind," ",payload))
	var guest:=NavalNetwork.new();root.add_child(guest);guest.port=39583;guest.connect_server("127.0.0.1","Visitante");guest.key=Crypto.new().generate_rsa(2048)
	guest.event_received.connect(func(kind,payload): if kind in ["error","authenticated"]: print("QA GUEST ",kind," ",payload))
	print("QA CONNECT ",NavalAccounts.testing()," ",mode.network.server_host," ",mode.network.port)
	if not await wait_for(func():return mode.network.authenticated and guest.authenticated): quit(1);return
	mode._open("create");find_button(mode.pages.create,"CRIAR").pressed.emit()
	if not await wait_for(func():return not mode.network.room.is_empty()): quit(1);return
	guest.request("join",{"id":mode.network.room.id})
	if not await wait_for(func():return mode.network.room.members.size()==2): quit(1);return
	var room: Dictionary=server.network.rooms.values()[0]
	check(room.simulation==null and mode.world==null,"two connected commanders do not create ships before deployment confirmation")
	check(find_button(mode.pages.lobby,"INICIAR PARTIDA").disabled,"start remains disabled until both players confirm their fleet")
	await capture("lobby")
	mode.naval_deploy_button.pressed.emit();guest.request("ready")
	if not await wait_for(func():return not find_button(mode.pages.lobby,"INICIAR PARTIDA").disabled): quit(1);return
	check(mode._deployment_confirmed(),"actual ready button confirms the selected ship")
	find_button(mode.pages.lobby,"INICIAR PARTIDA").pressed.emit()
	if not await wait_for(func():return mode.ships.size()==2 and is_instance_valid(mode._own_ship())): quit(1);return
	var battle:=room.simulation as NavalMatch;var own:=mode._own_ship();var owner_id:=mode.network.connection.get_unique_id()
	check(own.kind==str(mode.network.account.selected) and own.hp==float(own.spec.hp),"confirmed fleet determines the spawned ship")
	check(is_instance_valid(mode.audio_listener) and mode.audio_listener.is_current() and GameWeaponAudio.listener_position(root).distance_to(own.global_position)<5,"naval hearing stays on the ship instead of following the distant zoom camera")
	mode.fire_held=true;mode._open("pause");check(not mode.fire_held,"pause reliably releases the naval trigger")
	var time_before:=battle.time;await create_timer(.3).timeout;check(battle.time>time_before+.2,"naval pause leaves multiplayer simulation running")
	mode.shared_settings.present();check(mode.shared_settings.tabs.get_tab_count()==5 and mode.shared_settings.tabs.get_tab_title(3)=="Interface","Naval settings omit infantry-only gameplay while keeping shared interface controls")
	var stack:=mode.focus.stack.size()
	var late:=NavalNetwork.new();root.add_child(late);late.port=39583;late.connect_server("127.0.0.1","Tardio");late.key=Crypto.new().generate_rsa(2048)
	if not await wait_for(func():return late.authenticated): quit(1);return
	late.request("join",{"id":mode.network.room.id})
	if not await wait_for(func():return mode.network.room.members.size()==3): quit(1);return
	check(battle.ships.size()==2 and mode.focus.stack.size()==stack and mode.shared_settings.visible,"late unconfirmed commander has no ship and cannot close another player's settings")
	late.request("ready");if not await wait_for(func():return battle.ships.size()==3 and mode.ships.size()==3): quit(1);return
	check(mode.shared_settings.visible,"another player's deployment preserves open settings")
	var original_life:=own.life;var actual:=battle.ships[owner_id] as NavalShip
	battle._destroy(actual,guest.connection.get_unique_id())
	if not await wait_for(func():return mode.pages.lobby.visible and is_instance_valid(mode.naval_deploy_button),5): quit(1);return
	check(mode.naval_deploy_button.disabled and actual.dead,"death opens fleet deployment with the real respawn countdown")
	await create_timer(4.0).timeout
	check(actual.dead and actual.life==original_life,"naval death never automatically respawns without confirmation")
	if not await wait_for(func():return not mode.naval_deploy_button.disabled): quit(1);return
	mode.naval_deploy_button.pressed.emit()
	if not await wait_for(func():return mode._own_ship().life>original_life and not mode._own_ship().dead and not mode.focus.blocked()): quit(1);return
	check(mode._own_ship().ammo.lightMG==600,"confirmed naval respawn restores its finite ship loadout")
	await capture("respawn")
	mode._close_mode();guest.close_connection();late.close_connection()
	if not await wait_for(func():return server.network.rooms.is_empty()): quit(1);return
	check(server.network.users.is_empty(),"leaving clears room membership and all associated ships")
	var result:={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/deployment170-naval-ui-results.json",result);print(JSON.stringify(result));server.queue_free();mode.queue_free();guest.queue_free();late.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
