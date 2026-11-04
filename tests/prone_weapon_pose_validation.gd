extends SceneTree
const FIXTURE=preload("res://tests/br_completion_fixture.gd")
var failures: Array[String]=[]
var checks:=0
var worst_stretch:=0.
var game: BattleRoyaleGame
var actor: BRPlayer
var observer: Camera3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func settle_posture(value: int) -> void:
	actor.set_posture(value,false,true)
	for step in 100:actor.stance.advance(actor,1./60.);actor._animate_walk()
func setup_weapon(weapon: String,optic: String) -> void:
	actor.weapon_id=weapon;actor.reload_left=0.;actor.reload_weapon="";actor.reload_total=0.;actor.pitch=0.;actor.recoil=0.
	actor.aiming=false;actor.iron_sights=false;actor.camera_pivot.rotation=Vector3.ZERO
	actor.set_meta("weapon_optics",{weapon:optic} if not optic.is_empty() else {});actor.remove_meta("weapon_attachments")
	actor._refresh_weapon();actor._update_view();actor._animate_walk()
func capture(name_text: String) -> void:
	if DisplayServer.get_name()=="headless":return
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	observer.global_position=Vector3(-2.3,1.7,-2.6);observer.look_at(Vector3(0,.55,-.45));observer.make_current()
	for frame in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/"+name_text+".png")
func run() -> void:
	game=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game);await process_frame;game.flat_world()
	game.third_person=true
	game.br_hud.hide();game.loading_screen.hide();game.ui_focus.close_all()
	actor=game._spawn_player(1,true,false,Vector3.ZERO) as BRPlayer;actor.set_physics_process(false);actor.set_process(false);actor.owned=["fal","ak","sniper","glock"];actor.loadout=actor.owned.duplicate()
	observer=Camera3D.new();observer.fov=52;game.world_root.add_child(observer)
	await physics_frame;await physics_frame
	setup_weapon("fal","");settle_posture(2)
	if "--capture-before" in OS.get_cmdline_user_args():
		# Reproduce the diagnosed pre-fix anchor for a matching reference image.
		var aim:=Basis(Vector3.RIGHT,actor.pitch);var upper:=GameInfantryPose.upper_transform(actor)
		actor.weapon_root.transform=actor.body_root.transform*Transform3D(aim,upper*Vector3(0,1.42,0)+aim*Vector3(.15,-.045,-.38))
		for side in ["L","R"]:
			var target:=actor.weapon_root.global_position if side=="R" else actor.weapon_root.to_global(FALModel.SUPPORT)
			actor._pose_arm(actor.avatar_parts["arm_"+side.to_lower()],target,"arm"+side)
		await capture("prone-weapon-before");print("BEFORE grip ",actor.weapon_root.global_position," eye ",actor.camera_pivot.global_position);game.leave_match();await create_timer(.1).timeout;game.free();quit();return
	var wall:=StaticBody3D.new();wall.name="SideWall";game.world_root.add_child(wall)
	var wall_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.15,3.,5.);wall_shape.shape=box;wall_shape.position=Vector3(.53,1.5,-.8);wall.add_child(wall_shape)
	for weapon in ["fal","ak","sniper","glock"]:
		for optic in (["","prism4x","pso4x"] if weapon in ["fal","ak"] else [""]):
			setup_weapon(weapon,optic);settle_posture(2)
			for ads in [false,true]:
				actor.aiming=ads;actor.iron_sights=ads;actor._update_view()
				for pitch in [-.38,0.,.50,1.25]:
					actor.pitch=pitch;actor.camera_pivot.rotation.x=pitch
					for progress in [0.,.25,.5,.85]:
						actor.reload_weapon=weapon;actor.reload_total=3.;actor.reload_left=(1.-progress)*3. if progress>0. else 0.
						actor._animate_walk();var label:="%s/%s ADS%s pitch%s reload%s"%[weapon,optic,ads,pitch,progress]
						check(actor.weapon_root.global_transform.is_finite() and actor.get_muzzle_position().is_finite(),"finite held weapon "+label)
						check((-actor.weapon_root.global_basis.z).dot(actor.global_basis*Basis(Vector3.RIGHT,pitch)*Vector3.FORWARD)>.999,"prone barrel follows actual aim "+label)
						for side in ["L","R"]:
							var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()];var mesh:=arm.get_node("Arm"+side+"Mesh") as Node3D
							var stretch:=mesh.scale.y;worst_stretch=maxf(worst_stretch,stretch)
							check(float(arm.get_meta("grip_error",1.))<.002,"hands remain on animated weapon "+label+side)
							if pitch==0. and progress==0.:check(stretch<1.3,"level prone arm keeps natural bone length "+label+side)
						if pitch==0. and progress==0.:check(actor.weapon_root.global_position.y<actor.camera_pivot.global_position.y+.12,"level prone grip stays below eyes "+label)
	setup_weapon("fal","");settle_posture(2);actor.aiming=false;actor.iron_sights=false;actor.pitch=0.;actor._animate_walk()
	if "--capture" in OS.get_cmdline_user_args():await capture("prone-weapon-after")
	for posture in [1,0,2,1,2,0]:
		settle_posture(posture);check(actor.weapon_root.global_transform.is_finite(),"posture transition remains finite "+str(posture))
	check(is_equal_approx(actor.clamp_aim_pitch(-2.),-1.3),"standing downward limit preserved")
	settle_posture(2);check(is_equal_approx(actor.clamp_aim_pitch(-2.),-.38),"prone downward limit preserved")
	# Local server equip used to leave the previous FPP copy until aiming.
	game.third_person=false
	for posture in [0,1,2]:
		settle_posture(posture)
		for weapon in ["fists","fal","fists","ak","fists","glock","fists","sniper","fists"]:
			setup_weapon(weapon,"");actor._animate_walk()
			check(is_instance_valid(actor.view_root) and str(actor.view_root.get_meta("weapon",""))==weapon and actor.view_root.visible,"local FPP equip immediately rebuilds "+weapon+" posture"+str(posture))
			if weapon=="fists":check(actor.view_root.get_node_or_null("Left")!=null and actor.view_root.get_node_or_null("Right")!=null and actor.view_root.find_children("*","MeshInstance3D",true,false).size()==4,"both fists and forearms remain present after firearm switch")
	for weapon in ["fal","fists","ak","fists"]:
		var orphan:=actor.view_root;orphan.get_parent().remove_child(orphan)
		setup_weapon(weapon,"")
		check(is_instance_valid(actor.view_root) and actor.view_root.get_parent()==actor.camera and actor.view_root!=orphan,"detached FPP copy is safely retired when selecting "+weapon)
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"maximum_arm_scale":worst_stretch,"scope":"Actual BR/shared human rig: prone hip/iron/optical ADS, pitch limits, four firearms/reloads and posture transitions near a wall. Captures optional Compatibility1280x800; no FPS claim."}
	NavalStorage.write_json("res://work/prone-weapon-pose-validation.json",report);print("PRONE_WEAPON_POSE_VALIDATION ",JSON.stringify(report));game.leave_match();await create_timer(.1).timeout;game.free();await process_frame;quit(0 if failures.is_empty() else 1)
