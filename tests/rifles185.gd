extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/rifles185-"+label+".png")
func run() -> void:
	var legacy: Dictionary={"owned":["glock","fal","sniper"],"loadout":["fal","glock"],"equipped":"fal"}
	GameWeapons.migrate_profile(legacy,1)
	check(legacy.equipped=="ak" and legacy.loadout==["ak","glock"] and "ak" in legacy.owned and "fal" in legacy.owned,"old rifle selection becomes AK and keeps both rifle entitlements")
	legacy.equipped="fal";GameWeapons.migrate_profile(legacy,2)
	check(legacy.equipped=="fal","new FAL selection is not remigrated")
	var path:=NavalStorage.folder().path_join("loadouts-v1.json")
	NavalStorage.write_json(path,{"qa:offline_training":{"primary":"fal"}})
	check(GameLoadouts._saved_file()["qa:offline_training"].primary=="ak","legacy saved loadout is renamed once")
	var file:=GameLoadouts._saved_file();file["qa:offline_training"].primary="fal";NavalStorage.write_json(path,file)
	check(GameLoadouts._saved_file()["qa:offline_training"].primary=="fal","subsequent saved FAL stays FAL")
	NavalStorage.write_json(NavalStorage.folder().path_join("aim-sensitivity.json"),{"schema":1,"profiles":{"weapon:fal":{"normal":.65,"aim":.3}}})
	GameAimSensitivity.cache_path=""
	check(is_equal_approx(GameAimSensitivity.factor("weapon:ak"),.65) and is_equal_approx(GameAimSensitivity.factor("weapon:ak",true),.195),"AK retains old normal and aimed sensitivity")
	check(is_equal_approx(GameAimSensitivity.factor("weapon:fal"),1),"new FAL starts with separate sensitivity")
	for role in WarRules.CLASSES:
		for team in 2:
			var allowed:=GameLoadouts.allowed("war",GameWeapons.INFANTRY_IDS,role,team)
			check(allowed.primary==(["sniper"] if role=="marksman" else ["fal" if team==0 else "ak"]),role+" team "+str(team)+" receives the proper rifle")
			var invalid: Dictionary={"primary":"ak" if team==0 else "fal"}
			check(not GameLoadouts.validate(invalid,"war",GameWeapons.INFANTRY_IDS,role,team).ok,"opposing rifle is rejected for "+role+" team "+str(team))
	for mode in ["offline_training","offline_desert","desert"]:
		var choices:=GameLoadouts.allowed(mode,GameWeapons.INFANTRY_IDS)
		check("ak" in choices.primary and "fal" in choices.primary,mode+" offers both rifles")
	check(GameWeapons.fresh_ammo().ak==30 and GameWeapons.fresh_ammo().fal==20,"independent AK 30 and FAL 20 magazines")
	check(CombatRules.fresh_reserves().ak==180 and CombatRules.fresh_reserves().fal==120,"independent reserve capacities")
	check(CombatRules.weapon("fal").mode=="auto" and CombatRules.weapon("ak").mode=="auto","both rifles support held automatic fire")
	check(GameWeaponAudio.PATHS.ak=="ak-005.wav" and GameWeaponAudio.PATHS.fal=="fal-098.wav","each rifle resolves its own shot sound")
	var sound:=load("res://audio/fal-098.wav") as AudioStreamWAV
	check(sound!=null and not sound.stereo and sound.mix_rate==44100 and sound.format==AudioStreamWAV.FORMAT_16_BITS and sound.loop_mode==AudioStreamWAV.LOOP_DISABLED,"supplied FAL sound imports as non-looping mono PCM")
	var model:=FALModel.create();root.add_child(model)
	check(model.get_node("Muzzle").position.is_equal_approx(FALModel.MUZZLE) and FALModel.MUZZLE.z<-.7,"FAL muzzle is on its forward barrel end")
	check(model.find_children("*","MeshInstance3D",false,false).size()==4,"detailed FAL is batched into four shared material meshes")
	for finish in FALModel.meshes:
		var arrays: Array=FALModel.meshes[finish].surface_get_arrays(0);var referenced: Dictionary={}
		for index in arrays[Mesh.ARRAY_INDEX]: referenced[index]=true
		check(referenced.size()==arrays[Mesh.ARRAY_VERTEX].size(),finish+" keeps every shell vertex in the final triangle indices")
	model.free()
	for kind in ["training","desert"]:
		var game=load("res://tests/combat_155_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
		game.profile.owned=GameWeapons.INFANTRY_IDS.duplicate()
		game._begin_offline(kind,{"primary":"fal","sidearm":"glock","grenade":"grenade"})
		game.set_physics_process(false);game.ui_focus.close_all()
		var actor: GamePlayer=game.local_player;actor.set_physics_process(false)
		for rifle in ["ak","fal"]:
			actor.owned=GameWeapons.INFANTRY_IDS.duplicate();actor.loadout=["ak","fal","glock"];actor.remove_meta("approved_loadout")
			actor.ammo=GameWeapons.fresh_ammo();actor.reserves=CombatRules.fresh_reserves()
			actor.weapon_id=rifle;actor._refresh_weapon();actor._update_view();actor.fire_cooldown=0;actor.trigger_held=true
			game.shot_clocks.clear();var ammo:=int(actor.ammo[rifle]);var start:=actor.shot_sequence
			for i in 48: actor._physics_process(1./60);await physics_frame
			actor.trigger_held=false
			check(actor.shot_sequence>=start+4 and int(actor.ammo[rifle])<=ammo-4,kind+" "+rifle+" held fire is accepted by offline authority")
			check(actor.muzzle_marker.global_position.distance_to(actor.weapon_root.global_position)>.6,kind+" "+rifle+" projectile origin remains at the barrel")
			actor.start_reload();check(actor.reload_weapon==rifle,kind+" "+rifle+" reload starts independently")
			actor.cancel_reload()
			if kind=="desert":
				actor.yaw=0;actor.rotation.y=0;actor.pitch=0;actor.recoil=0
				game.third_person=false;actor.aiming=false;actor.iron_sights=false;actor._update_view();actor._animate_walk();game.update_hud();await capture(rifle+"-fpp")
				actor.aiming=true;actor.iron_sights=true;actor._update_view();actor._animate_walk();await capture(rifle+"-ads")
				if rifle=="fal":
					var copy:=actor.view_root.get_node("Imported_fal") as Node3D
					for marker in ["RearAperture","FrontPost"]:
						var point:=actor.camera.unproject_position(copy.get_node(marker).global_position)
						check(point.distance_to(root.get_visible_rect().size*.5)<2,"3D iron sight "+marker+" aligns with the camera centre")
				actor.aiming=false;actor.iron_sights=false;game.third_person=true;actor._update_view();actor._animate_walk();await capture(rifle+"-tpp")
				var camera:=Camera3D.new();game.world_root.add_child(camera);camera.global_position=actor.global_position+Vector3(1.2,1.7,-.5);camera.look_at(actor.global_position+Vector3(0,1.4,-.4));camera.current=true
				await capture(rifle+"-world");camera.queue_free();actor.camera.current=true
		game.show_menu();game.queue_free();await create_timer(.3).timeout
	NavalStorage.write_json("res://tests/rifles185-results.json",{"checks":checks,"failures":failures});print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
