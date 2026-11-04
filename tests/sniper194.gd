extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1;print(("PASS " if value else "FAIL ")+label)
	if not value: failures.append(label)
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame
	root.add_child(game);game.vehicle_system.set_process(false)
	var actor:=game.local_player as WarPlayer
	actor.weapon_id="sniper";actor._refresh_weapon();actor.iron_sights=false;actor.aiming=false
	actor.ammo.sniper=0;actor.reserves.sniper=30;actor.reload_weapon="";actor.reload_left=0;actor.fire_cooldown=0
	var duration: float=GameWeapons.ITEMS.sniper.reload
	actor.begin_reload("sniper",duration)
	var world:=actor.weapon_root.get_node("Imported_sniper") as Node3D
	var camera:=Camera3D.new();game.world_root.add_child(camera);camera.position=Vector3(-1.6,1.65,-2.2);camera.look_at(Vector3(0,1.15,-.3))
	game.third_person=true;actor._update_view();actor.body_root.show();actor.weapon_root.show();camera.make_current()
	var start_l:=Vector3.ZERO;var start_r:=Vector3.ZERO
	for t in [.01,.30,.46,.68,.83,.98]:
		actor.reload_left=duration*(1-t);actor._update_weapon_pose();actor._animate_walk()
		var pose:=GameReloadPose.state("sniper",actor.reload_left,duration)
		var left: Node3D=actor.avatar_parts.arm_l.get_node("HandL")
		var right: Node3D=actor.avatar_parts.arm_r.get_node("HandR")
		check(left.global_position.distance_to(actor.weapon_root.to_global(GameReloadPose.sniper_hand(world,pose.hand)))<.004,"world support hand tracks reload at %.2f"%t)
		check(right.global_position.distance_to(actor.weapon_root.to_global(GameReloadPose.sniper_hand(world,pose.right_hand)))<.004,"world grip hand tracks reload at %.2f"%t)
		if t<.02: start_l=left.global_position;start_r=right.global_position
		if t==.46: check(left.global_position.distance_to(start_l)>.15,"support hand reaches the magazine area")
		if t==.83: check(right.global_position.distance_to(start_r)>.08,"grip hand cycles the bolt")
		if DisplayServer.get_name()!="headless" and t in [.30,.46,.83]:
			await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/sniper194-world-%s.png"%str(t))
	actor.reload_left=duration*.54;game.third_person=false;actor.camera.make_current();actor._update_view();actor._update_weapon_pose();actor._animate_walk()
	var copy:=actor.view_root.get_node("Imported_sniper") as Node3D
	var pose:=GameReloadPose.state("sniper",actor.reload_left,duration)
	check(copy.transform.is_equal_approx(world.transform),"first person and world rifle follow the same reload pose")
	check(actor.view_root.get_node("SupportHand").position.distance_to(GameReloadPose.sniper_hand(copy,pose.hand))<.004,"first person support hand follows rifle")
	if DisplayServer.get_name()!="headless":
		await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/sniper194-fpp.png")
	var ammo_before:=actor.ammo.duplicate();actor.fire();check(actor.ammo==ammo_before,"reload presentation cannot fire")
	actor.pause_reload();actor._update_weapon_pose();check(actor.resume_reload("sniper"),"interrupted reload resumes")
	actor.reload_left=.001;actor.complete_reload();actor._update_weapon_pose()
	check(actor.ammo.sniper==5 and actor.reserves.sniper==25 and actor.reload_weapon.is_empty(),"authority completes one sniper reload")
	check(is_equal_approx(duration,4.5),"sniper reload time remains 4.5 seconds")
	actor.ammo.sniper=0;actor.scope_level=1;actor.iron_sights=true;actor.aiming=true
	actor.begin_reload("sniper",duration)
	check(not actor.iron_sights and not actor.aiming and actor.scope_level==0,"reload exits scope so the animation is visible")
	actor.cancel_reload()
	actor.pitch=-1.2;actor.network_pitch=-1.2;actor.set_posture(2,false,true)
	check(is_equal_approx(actor.pitch,-.38) and is_equal_approx(actor.network_pitch,-.38),"prone immediately clamps local and network pitch")
	check(is_equal_approx(actor.clamp_aim_pitch(-1.2),-.38) and is_equal_approx(actor.clamp_aim_pitch(.7),.7),"prone limits downward aim and preserves upward aim")
	actor.set_posture(0,false,true);check(is_equal_approx(actor.clamp_aim_pitch(-1.2),-1.2),"standing restores ordinary aim range")
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/sniper194-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
