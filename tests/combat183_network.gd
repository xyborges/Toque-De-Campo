extends SceneTree
var game: Node3D
var role:="server"
var failures: Array[String]=[]
var checks:=0
var measurements: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func wait_for(test: Callable,seconds:=12.0) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if test.call(): return true
		await process_frame
	failures.append("timeout "+role+":"+str(game.phase));return false
func phase(value: String) -> void:
	game.phase=value;game._broadcast("qa_phase",[value])
func report(value: String) -> void: game.rpc_id(1,"qa_report",value)
func click(actor: GamePlayer,pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;actor._unhandled_input(event)
func burst(actor: GamePlayer,label: String,seconds:=.8) -> void:
	actor.fire_cooldown=0
	var before:=actor.shot_sequence
	click(actor,true);await create_timer(seconds).timeout
	var count:=actor.shot_sequence-before
	measurements[label]=count
	check(count>=4 and actor.trigger_held,label+": one held press continues through authoritative acknowledgements")
	click(actor,false);before=actor.shot_sequence;await create_timer(.2).timeout
	check(actor.shot_sequence==before and not actor.trigger_held,label+": release stops the burst")
func run() -> void:
	game=load("res://tests/combat183_network_fixture.gd").new();root.add_child(game)
	game.nickname_input.text=role;game.profile.nickname=role;game.profile.owned=["fal","glock","sniper"];game.address_input.text="127.0.0.1"
	if role=="server": await server_flow()
	else:
		await game.join_game("pvp")
		if await wait_for(func():return game.players.size()==2 and game.deployment_panel.visible): await client_flow()
	var result: Dictionary={"role":role,"checks":checks,"failures":failures,"measurements":measurements}
	NavalStorage.write_json("res://tests/combat183-network-"+role+".json",result);print(JSON.stringify(result))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
func server_flow() -> void:
	if not await wait_for(func():return game.players.size()==2): return
	var named: Dictionary={}
	for actor: GamePlayer in game.players.values(): named[str(actor.name)]=actor
	var alpha:=named.alpha as GamePlayer;var bravo:=named.bravo as GamePlayer
	if not await wait_for(func():return alpha.hp>0 and bravo.hp>0): return
	phase("exercise")
	if not await wait_for(func():return game.reports.has("alpha-exercised"),22): return
	check(int(alpha.ammo.fal)<=20,"authority accepted repeated FAL shots from a held trigger")
	check(int(alpha.ammo.glock)==11,"authority accepted Glock after grenade selection cancellation")
	check(alpha.grenade_held_id.is_empty() and not alpha.grenade_selected,"authority exits grenade preparation after throwing")
	var life:=bravo.life_id
	game._apply_hit(alpha.peer_id,{"collider":bravo.hit_regions.chest},1000,"chest","fal")
	check(bravo.hp==0 and alpha.kills>0,"FAL damage records opponent death and awards the attacker")
	phase("killed")
	if not await wait_for(func():return game.reports.has("alpha-after-kill") and game.reports.has("bravo-respawn"),15): return
	check(bravo.hp>0 and bravo.life_id==life+1,"victim redeploys with a fresh life")
	phase("respawn-burst")
	if not await wait_for(func():return game.reports.has("alpha-final") and game.reports.has("bravo-final")): return
	check(alpha.ammo.fal<20 and bravo.ammo.fal<30,"authority accepts sustained fire from both players after a kill and respawn")
	phase("done");await create_timer(.7).timeout
func client_flow() -> void:
	var actor:=game.local_player as GamePlayer
	var panel:=game.deployment_panel as GameInfantryDeployment
	panel.editor.slots={"primary":"fal","sidearm":"glock","grenade":"grenade"};panel.editor._rebuild();panel.editor._changed();panel.confirm.pressed.emit()
	if not await wait_for(func():return actor.hp>0 and not game.ui_focus.blocked() and game.phase=="exercise"): return
	if role=="alpha":
		await burst(actor,"initial FAL burst")
		actor.equip_grenade();await physics_frame;await physics_frame;actor.equip_slot(4);await create_timer(.2).timeout
		var before:=actor.shot_sequence;actor.fire_cooldown=0;click(actor,true);click(actor,false)
		check(actor.shot_sequence==before+1 and not actor.grenade_aiming,"Glock fires after cancelling unarmed grenade")
		actor.equip_grenade();await physics_frame;click(actor,true)
		if not await wait_for(func():return not actor.grenade_held_id.is_empty()): return
		before=actor.shot_sequence;actor.fire()
		check(actor.shot_sequence==before,"firearm stays blocked during an armed grenade")
		click(actor,false)
		if not await wait_for(func():return actor.grenade_held_id.is_empty() and actor.grenade_throw_left<=0): return
		actor.equip_slot(6);await create_timer(.2).timeout
		await burst(actor,"FAL after grenade",.6);report("alpha-exercised")
		if not await wait_for(func():return game.phase=="killed"): return
		check(actor.hp>0,"killer remains alive and controllable")
		await burst(actor,"FAL while opponent is dead",.55);report("alpha-after-kill")
	else:
		if not await wait_for(func():return game.phase=="killed",22): return
		if not await wait_for(func():return actor.hp==0): return
		var before:=actor.shot_sequence;click(actor,true);actor.equip_slot(4);actor.start_reload()
		check(actor.shot_sequence==before and actor.weapon_id=="fal" and actor.reload_weapon.is_empty(),"dead victim cannot fire, swap or reload")
		if not await wait_for(func():return panel.visible,8): return
		panel.confirm.pressed.emit()
		if not await wait_for(func():return actor.hp>0 and not game.ui_focus.blocked()): return
		check(not actor._grenade_active() and not actor.grenade_aiming,"respawn clears grenade blocking flags")
		report("bravo-respawn")
	if not await wait_for(func():return game.phase=="respawn-burst"): return
	actor.equip_slot(6);await create_timer(.2).timeout;await burst(actor,role+" final burst",.65)
	report(role+"-final")
	await wait_for(func():return game.phase=="done")

