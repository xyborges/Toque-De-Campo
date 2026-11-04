extends SceneTree

var checks:=0
var failures: Array[String]=[]
var game: WarGame

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func run() -> void:
	game=WarGame.new()
	game.offline_operation=true
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+45000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready:
		push_error("War offline setup did not reach deployment")
		quit(1)
		return
	game.set_physics_process(false)
	if is_instance_valid(game.bot_director):
		game.bot_director.queue_free()
		game.bot_director=null
	var actor:=game.local_player as WarPlayer
	game.request_deploy(0,"soldier","fal","rpg","base")
	check(actor.hp>0 and actor.deployed,"test actor deploys into War")
	actor.hp=0
	actor.deployed=false
	actor._set_hitboxes_enabled(false)
	game._on_player_died(actor,0)
	var ready_at:=float(game.members[actor.peer_id].ready_at)
	check(is_equal_approx(ready_at-game.war_clock,8.0),"death starts the exact eight-second respawn delay")
	check(bool(game.members[actor.peer_id].respawn_pending),"server records an automatic respawn without a menu selection")
	game.war_ui._process(.11)
	check(game.war_ui.death_notice.visible and game.war_ui.death_notice_text.text=="VOCÊ MORREU","death notice is visible to the dead player")
	check("RETORNO EM 08" in game.war_ui.death_countdown_text.text,"death notice shows the eight-second countdown")
	var old_weapon:=actor.weapon_id
	var old_ammo:=int(actor.ammo.get(old_weapon,0))
	actor.equip_slot(4)
	actor.fire()
	check(actor.weapon_id==old_weapon and int(actor.ammo.get(old_weapon,0))==old_ammo,"dead player cannot switch or fire a weapon")
	var vehicle:=game.vehicle_system.vehicles.get("v_guarani") as WarVehicle
	actor.global_position=vehicle.global_position+Vector3(0,0,3)
	game.vehicle_system.command_for(actor.peer_id,"enter",{"id":vehicle.vehicle_id})
	check(actor.vehicle_id.is_empty() and vehicle.seat_of(actor.peer_id)<0,"server rejects vehicle entry while dead")
	var position_before:=actor.global_position
	actor.velocity=Vector3(4,0,4)
	actor._physics_process(.1)
	check(actor.velocity==Vector3.ZERO and actor.global_position.is_equal_approx(position_before),"dead body stays frozen")
	game.ui_focus.close_all()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var yaw_before:=actor.yaw
	actor._apply_dead_camera_look(Vector2(80,0))
	check(not is_equal_approx(actor.yaw,yaw_before),"dead player can rotate the camera")
	game.war_clock=ready_at-.01
	game._process_queued_deployments()
	check(actor.hp<=0 and not actor.deployed,"server does not respawn before eight seconds")
	game.war_clock=ready_at+.01
	game._process_queued_deployments()
	check(actor.hp==100 and actor.deployed and not bool(game.members[actor.peer_id].respawn_pending),"server automatically respawns at eight seconds using the saved loadout")
	check(actor.weapon_id==old_weapon,"automatic respawn preserves the saved weapon")
	game.members[actor.peer_id].ready_at=0.0
	game.members[actor.peer_id].respawn_pending=false
	var remote_state: Dictionary={"life":actor.life_id,"hp":0.0,"limbs":actor.limbs.duplicate(true),"region":"chest","direction":Vector3.ZERO,"weapon":"fal","detached":"","velocity":Vector3.ZERO,"death_sound":0,"dead":true,"killer":0,"kills":0}
	game.remote_damage(actor.peer_id,remote_state)
	check(actor.hp<=0 and bool(game.members[actor.peer_id].respawn_pending),"replicated online death schedules the local respawn countdown")
	check(is_equal_approx(float(game.members[actor.peer_id].ready_at)-game.war_clock,8.0),"replicated death uses the same eight-second delay")
	var deadline_before:=float(game.members[actor.peer_id].ready_at)
	var stale_state:=remote_state.duplicate(true);stale_state.life=actor.life_id-1
	game.remote_damage(actor.peer_id,stale_state)
	check(is_equal_approx(float(game.members[actor.peer_id].ready_at),deadline_before),"previous-life damage cannot restart the countdown")
	actor.deaths=2;actor.hp=0
	game.members[actor.peer_id].respawn_pending=false;game.members[actor.peer_id].ready_at=0.0
	game.war_ui._process(.11)
	check(not game.war_ui.death_notice.visible,"new-round staging does not show a previous death notice")
	var report: Dictionary={"checks":checks,"failures":failures,"note":"Headless authority-path regression including the client damage-replica method; advances the server clock directly for the eight-second boundary."}
	NavalStorage.write_json("res://tests/war-death-respawn-results.json",report)
	print(JSON.stringify(report))
	game.queue_free()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	quit(0 if failures.is_empty() else 1)
