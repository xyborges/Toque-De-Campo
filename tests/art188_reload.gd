extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/art188-reload-"+id+".png")
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);game.vehicle_system.set_process(false)
	var actor:=game.local_player as WarPlayer
	var camera:=Camera3D.new();game.world_root.add_child(camera);camera.position=Vector3(-1.8,1.7,-2.3);camera.look_at(Vector3(0,1.20,-.30))
	for weapon in ["fal","glock"]:
		actor.weapon_id=weapon;actor._refresh_weapon();actor.iron_sights=false;actor.aiming=false;actor.ammo[weapon]=0;actor.reserves[weapon]=60;actor.reload_weapon="";actor.reload_left=0;actor.fire_cooldown=0
		var duration: float=GameWeapons.ITEMS[weapon].reload
		actor.begin_reload(weapon,duration)
		var world:=actor.weapon_root.get_node("Imported_"+weapon) as Node3D
		game.third_person=true;actor._update_view();actor.body_root.show();actor.weapon_root.show();camera.make_current()
		for t in [.0,.20,.33,.48,.66,.85,.99]:
			actor.reload_left=duration*(1-t);actor._update_weapon_pose();actor._animate_walk()
			var pose:=GameReloadPose.state(weapon,actor.reload_left,actor.reload_total)
			check(world.get_node("Magazine").position.is_equal_approx(pose.magazine),weapon+" magazine follows synchronized progress %.2f"%t)
			check(world.get_node("Magazine").visible==pose.magazine_visible,weapon+" magazine visibility %.2f"%t)
			var hand:=actor.avatar_parts.arm_l.get_node("HandL") as MeshInstance3D
			check(hand.global_position.distance_to(world.to_global(pose.hand))<.003,weapon+" support hand follows reload %.2f"%t)
			if t in [.33,.66,.85]: await capture(weapon+"-world-"+str(t))
		actor.reload_left=duration*.67;game.third_person=false;actor.camera.make_current();actor._update_view();actor._update_weapon_pose();actor._animate_walk()
		var copy:=actor.view_root.get_node("Imported_"+weapon) as Node3D
		check(copy.get_node("Magazine").transform.is_equal_approx(world.get_node("Magazine").transform),weapon+" world and FPP use identical magazine movement")
		await capture(weapon+"-fpp")
		var ammo_before:=actor.ammo.duplicate();var reserve_before:=actor.reserves.duplicate()
		actor.fire();check(actor.ammo==ammo_before and actor.reserves==reserve_before,"animation cannot fire or transfer ammunition during "+weapon+" reload")
		actor.pause_reload();actor._update_weapon_pose()
		check(world.get_node("Magazine").visible and world.get_node("Magazine").position.is_equal_approx(GameReloadPose.state(weapon,0,0).magazine),weapon+" interruption restores its magazine")
		check(actor.resume_reload(weapon),weapon+" retains the existing paused reload semantics")
		actor.reload_left=.001;actor.complete_reload();actor._update_weapon_pose()
		check(actor.ammo[weapon]==GameWeapons.ITEMS[weapon].mag and actor.reserves[weapon]==60-int(GameWeapons.ITEMS[weapon].mag),weapon+" authority transfers exactly one magazine")
		check(actor.reload_weapon.is_empty() and world.rotation.is_equal_approx(Vector3.ZERO),weapon+" completion restores a clean pose")
		check(duration==(6. if weapon=="fal" else 4.),weapon+" gameplay duration remains unchanged")
		actor.cancel_reload()
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/art188-reload-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
