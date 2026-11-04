extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func member(id: int,local:=false) -> WarPlayer:
	var actor:=game._spawn_player(id,local,false,WarTerrain.point(-500 if id%2 else 500,50)) as WarPlayer;actor.set_physics_process(false)
	game.members[id]={"team":-1,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	return actor
func capture(label_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/war163-player-"+label_text+".png")
func run() -> void:
	game=load("res://tests/war163_player_fixture.gd").new();game.set_meta("war_host",true);game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	var actor:=member(701,true);var enemy:=member(702)
	check(game._deploy(701,0,"soldier","fal","rpg","base") and game._deploy(702,1,"soldier","fal","rpg","base"),"two normal deployments initialize the battle")
	game.join_ready=true;game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=true;actor._update_view()
	check(not actor.view_root.visible,"initial SpringArm state never exposes a first-person clone in TPP")
	actor.position=WarTerrain.point(-450,280)+Vector3.UP*.12;actor.pitch=0;actor.camera_pivot.rotation=Vector3.ZERO;actor.shoulder_arm.spring_length=.12
	await physics_frame;await physics_frame
	actor._update_camera_collision(0)
	check(actor.camera_close and not actor.view_root.visible and not actor.avatar_parts.head.visible,"shortened TPP arm hides overlapping head without switching to FPP")
	var leaked:=0
	for angle in [-1.1,-.6,0.,.6,1.1]:
		actor.pitch=angle;actor.camera_pivot.rotation.x=angle;actor.shoulder_arm.spring_length=.12
		await physics_frame;actor._update_camera_collision(1./60.)
		if actor.view_root.visible: leaked+=1
	check(leaked==0,"terrain-facing camera angles never activate FPP presentation while TPP is selected")
	actor.pitch=0;actor.camera_pivot.rotation.x=0;actor.shoulder_arm.spring_length=3.25
	await physics_frame;await physics_frame;actor._update_camera_collision(1./60.)
	check(actor.body_root.visible and not actor.view_root.visible,"unobstructed shoulder camera restores the world body while keeping the selected TPP view")
	await capture("tpp")
	game.third_person=false;actor._update_view()
	check(actor.view_root.visible,"explicit FPP selection still enables its own weapon presentation")
	game.third_person=true;actor._update_view()
	game.objective_states.A.owner=0
	check(game._deploy(701,0,"medic","fal","rpg","A"),"M-menu accepts an explicit next-life class and captured sector")
	check(actor.war_class=="soldier" and str(game.members[701].pending.role)=="medic","saving a pending deployment does not change the living actor")
	actor.equip_grenade();check(game.grenades_system.prime(actor,actor.life_id,200),"a real armed grenade is held before the death scenario")
	var held:=actor.grenade_held_id;var life:=actor.life_id;var started:=Time.get_ticks_msec()
	actor.take_damage(1000,"chest",702)
	var death_clock:=game.war_clock
	check(actor.hp==0 and not actor.deployed and not actor.view_root.visible and (not is_instance_valid(actor.grenade_view) or not actor.grenade_view.visible),"death disables personal weapon and grenade presentation immediately")
	check(game.grenades_system.rounds.has(held) and not bool(game.grenades_system.rounds[held].held),"dying drops the live grenade instead of deleting its fuse")
	var old_weapon:=actor.weapon_id;actor.equip_slot(4);actor.start_reload();actor.begin_reload("fal",6);actor.play_remote_reload("fal",6);game.remote_reload_started(701,"fal",6,6,life,999)
	actor.equip_grenade();actor._physics_process(.1)
	check(actor.weapon_id==old_weapon and actor.reload_weapon.is_empty() and not is_instance_valid(actor.reload_audio),"direct or late equip/reload actions cannot animate or reload a dead actor")
	game._server_reload(701,"fal");game._equip_server(actor,"glock")
	check(actor.weapon_id==old_weapon and actor.reload_weapon.is_empty(),"the server rejects dead equip and reload requests too")
	check(absf(game.deployment_wait_left()-4)<.02 and not game.deployment_ready(),"authoritative death begins the four-second deployment gate")
	game.war_clock=death_clock+2.9;game._process_queued_deployments()
	check(actor.hp==0,"queued deployment cannot bypass the death camera interval")
	await create_timer(3.12).timeout
	game.war_clock=death_clock+3.12
	check(game.war_ui.deployment.visible and game.deployment_wait_left()>.65 and not game.deployment_ready(),"after the three-second death camera the menu shows the remaining readiness interval")
	check(game.deployment_message().contains("REIMPLANTAÇÃO"),"death menu exposes an explicit countdown rather than accepting a blocked deploy click")
	await capture("countdown")
	game.objective_states.A.owner=1
	game.war_clock=death_clock+4.01;game._process_queued_deployments()
	check(actor.hp==100 and actor.life_id==life+1 and actor.war_class=="medic","the authority applies the explicitly saved class once readiness reaches four seconds")
	check(str(game.members[701].spawn)=="base" and game.members[701].pending.is_empty(),"a captured sector lost before respawn safely falls back to the team's base")
	check(actor.camera.current and (not is_instance_valid(game.death_view) or not game.death_view.active),"local deployment stops the cinematic and restores the personal camera")
	check(not game.war_ui.deployment.visible,"successful local deployment closes the menu and restores play")
	# No explicit pending selection means the player stays in the manual menu.
	actor.take_damage(1000,"chest",702);game.war_clock+=4.1;game._process_queued_deployments()
	check(actor.hp==0 and not actor.deployed,"a player without an explicit pending choice is not automatically assigned a class or spawn")
	check(game.deployment_ready(),"manual deployment becomes ready after the same authoritative four seconds")
	var ally_a:=member(703);var ally_b:=member(705)
	game.members[703].team=0;game.members[705].team=0;ally_a.war_team=0;ally_b.war_team=0
	check(game._deployment_team_allowed(701,0),"an existing reserved slot can respawn in its own team after opponents disconnect")
	check(game._deploy(701,0,"marksman","sniper","rpg","rally"),"reserved-team respawn respects the player's selected sniper and rally point")
	check(actor.war_class=="marksman" and actor.weapon_id=="sniper" and str(game.members[701].spawn)=="rally","manual selection is applied to the new life rather than reverting to defaults")
	member(707)
	check(not game._deployment_team_allowed(707,0),"a new player cannot use the reserved-slot exception to enter an already larger team")
	game._deploy(701,0,"medic","fal","rpg","base");game.reset_operation()
	check(game.members[701].pending.is_empty() and actor.hp==0 and not actor.deployed,"a new operation clears queued choices from the previous round")
	var timing: Dictionary={"death_menu_ms":Time.get_ticks_msec()-started,"death_camera_seconds":3.,"authority_ready_seconds":4.,"clock_gate_advanced_deterministically":true}
	game.show_menu();game.queue_free();await process_frame;await process_frame;await create_timer(.25).timeout
	var report: Dictionary={"checks":checks,"failures":failures,"timing":timing}
	NavalStorage.write_json("res://tests/war163-player-camera-respawn-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
