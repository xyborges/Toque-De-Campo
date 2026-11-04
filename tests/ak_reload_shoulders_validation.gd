extends SceneTree
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var max_grip_error:=0.
var captures:=false
func _initialize() -> void:
	captures=DisplayServer.get_name()!="headless"
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name_text: String) -> void:
	if not captures:return
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://work/ak-reload-"+name_text+".png")
func closed(mesh: Mesh) -> bool:
	var edges: Dictionary={}
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():for i in vertices.size():indices.append(i)
		for i in range(0,indices.size(),3):
			var triangle: Array=[]
			for j in 3:
				var point:=vertices[indices[i+j]];triangle.append(Vector3i(roundi(point.x*100000),roundi(point.y*100000),roundi(point.z*100000)))
			if triangle[0]==triangle[1] or triangle[1]==triangle[2] or triangle[2]==triangle[0]:continue
			for j in 3:
				var a:=str(triangle[j]);var b:=str(triangle[(j+1)%3]);var key:=a+":"+b if a<b else b+":"+a
				edges[key]=int(edges.get(key,0))+1
	for count in edges.values():
		if int(count)!=2:return false
	return true
func run() -> void:
	if captures:root.content_scale_size=Vector2i(1280,800);DisplayServer.window_set_size(Vector2i(1280,800))
	game=FIXTURE.new();root.add_child(game);await process_frame;game.set_physics_process(false);game.vehicle_system.set_process(false)
	game.hud_layer.hide()
	for player: GamePlayer in game.players.values():player.set_process(false);player.set_physics_process(false)
	var actor:=game.local_player as WarPlayer
	actor.weapon_id="ak";actor._refresh_weapon();actor.aiming=false;actor.iron_sights=false;actor.recoil=0.;actor.attack_anim=0.;actor.yaw=0.;actor.rotation=Vector3.ZERO
	var model:=actor.weapon_root.get_node("Imported_ak") as Node3D
	var assembly:=model.get_node_or_null("MagazineAssembly") as Node3D
	check(is_instance_valid(assembly) and assembly.find_child("MagazineGeometry",true,false)!=null,"original AK magazine is separate movable original geometry")
	check(model.find_child("ReceiverGeometry",true,false)!=null and model.get_node_or_null("ReloadBolt")!=null,"receiver retained with charging handle")
	check(float(GameWeapons.ITEMS.ak.reload)==6.,"all modes preserve 6 second authoritative reload")
	for side in ["L","R"]:
		var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
		check(closed(arm.get_node("Arm"+side+"Mesh").mesh),"upper sleeve is closed including shoulder "+side)
		check(closed(arm.get_node("Forearm"+side+"Mesh").mesh),"forearm has no hollow end "+side)
	var original:=GameReloadPose.state("ak",0.,6.)
	var mag_rest:=GameAKReload.PIVOT
	for posture in [0,1,2]:
		actor.set_posture(posture,false,true);actor.stance.advance(actor,1.)
		for lean_value in [-1.,0.,1.]:
			actor.lean=lean_value;actor.camera_pivot.position.x=lean_value*GameInfantryPose.LEAN_DISTANCE
			for pitch_value in [-.2,0.,.6]:
				actor.pitch=pitch_value;actor.camera_pivot.rotation=Vector3(pitch_value,0,-lean_value*GameInfantryPose.LEAN_ROLL)
				for progress in [0.,.12,.24,.36,.47,.60,.74,.81,.90,.97]:
					actor.reload_weapon="ak";actor.reload_total=6.;actor.reload_left=(1.-progress)*6.;actor._update_view();actor._animate_walk()
					var pose:=GameReloadPose.state("ak",actor.reload_left,6.)
					check(actor.get_muzzle_position().is_finite(),"finite reload muzzle")
					for side in ["L","R"]:
						var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
						var error:=float(arm.get_meta("grip_error",99.));max_grip_error=maxf(max_grip_error,error)
						check(error<.003,"TPP hand follows reload target "+side)
					check(assembly.position.distance_to(mag_rest+Vector3(pose.magazine_offset))<.0001,"magazine follows authoritative timer")
	actor.set_posture(0,false,true);actor.stance.advance(actor,1.);actor.lean=0.;actor.pitch=0.;actor.camera_pivot.rotation=Vector3.ZERO;actor.camera_pivot.position.x=0.
	game.third_person=false;actor.camera.make_current();actor._update_view()
	for pair in [[.24,"mag-release"],[.36,"mag-out"],[.65,"mag-in"],[.78,"mag-lock"],[.90,"charging"]]:
		actor.reload_left=(1.-float(pair[0]))*6.;actor._animate_walk();await capture("fpp-"+str(pair[1]))
	for progress in [.24,.36,.65,.74]:
		var pose:=GameReloadPose.state("ak",(1.-progress)*6.,6.)
		var expected:=GameAKReload.PIVOT+Vector3(pose.magazine_offset)+Basis(Vector3.BACK,float(pose.magazine_tilt))*Vector3(.055,-.112,-.035)
		check(Vector3(pose.hand).distance_to(expected)<.001,"support hand grasps moving magazine during extraction/insertion")
	actor.reload_left=0.;actor.reload_weapon="";actor._animate_walk()
	var view_magazines:=actor.view_root.find_children("MagazineGeometry","MeshInstance3D",true,false)
	check(view_magazines.size()==1 and view_magazines[0].get_parent().name=="MagazineAssembly","FPP contains one runtime magazine without instancing a static duplicate")
	check(assembly.position.is_equal_approx(mag_rest) and assembly.visible,"completed/cancelled reload restores original magazine dock")
	game.third_person=true;actor._update_view();var observer:=Camera3D.new();game.world_root.add_child(observer);observer.fov=48.;observer.position=Vector3(-2.1,1.8,-2.3);observer.look_at(Vector3(0,1.28,-.3));observer.make_current()
	actor.reload_weapon="ak";actor.reload_left=6.*.64;actor._animate_walk();await capture("tpp-mag-out")
	for optic in ["prism4x","pso4x"]:
		actor.set_meta("weapon_optics",{"ak":optic});actor.refresh_weapon_optics();actor.aiming=true;actor.iron_sights=true;game.third_person=false;actor.camera.make_current();actor._update_view();actor._animate_walk();actor.weapon_optics.update(actor)
		check(actor.weapon_optics.enabled(actor),"optics preserved after reload "+optic)
	game.world_root.hide()
	var plain_game: BattleRoyaleGame=load("res://tests/br_completion_fixture.gd").new();plain_game.offline_operation=false;plain_game.set_meta("test_mode",true);root.add_child(plain_game);plain_game.flat_world();plain_game.set_physics_process(false);plain_game.hud_layer.hide()
	var plain:=plain_game._spawn_player(1,true,false,Vector3.ZERO) as BRPlayer;plain.set_physics_process(false);plain.set_process(false);plain_game.third_person=true;plain.weapon_id="ak";plain.loadout=["ak"];plain.owned=["ak"];plain._refresh_weapon();plain._update_view();plain._animate_walk()
	for side in ["L","R"]:check(closed(plain.avatar_parts["arm_"+side.to_lower()].get_node("Arm"+side+"Mesh").mesh),"actual plain BR shoulder shares closed geometry "+side)
	for progress in [.24,.36,.65,.90]:
		plain.reload_weapon="ak";plain.reload_total=6.;plain.reload_left=(1.-progress)*6.;plain._animate_walk()
		var plain_mag:=plain.weapon_root.get_node("Imported_ak/MagazineAssembly") as Node3D
		check(plain_mag.position.distance_to(GameAKReload.PIVOT+Vector3(GameReloadPose.state("ak",plain.reload_left,6.).magazine_offset))<.0001,"BR uses the same actual AK reload")
	plain.reload_weapon="";plain.reload_left=0.;plain._animate_walk()
	var plain_observer:=Camera3D.new();plain_game.world_root.add_child(plain_observer);plain_observer.fov=48.;plain_observer.position=Vector3(0,1.85,2.4);plain_observer.look_at(Vector3(0,1.32,-.12));plain_observer.make_current();await capture("plain-closed-shoulders")
	plain_game.leave_match();plain_game.queue_free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"maximum_grip_error":max_grip_error,"reload_seconds":6.,"scope":"Shared AK original magazine partition, hand/bolt motion from authoritative timer, all crouch/prone/lean/pitch combinations, closed shoulder/forearm surfaces and optical attachments. Graphical run also captures reload phases and plain BR clothing."}
	NavalStorage.write_json("res://work/ak-reload-shoulders-validation.json",report);print("AK_RELOAD_SHOULDERS ",JSON.stringify(report))
	game.show_menu();game.queue_free();await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
