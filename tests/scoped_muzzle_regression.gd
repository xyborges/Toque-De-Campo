extends SceneTree
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
class ShotFixture extends "res://tests/war_optics_fixture.gd":
	var accepted_shot: Dictionary={}
	func _present_shot(packet: Dictionary) -> bool:
		accepted_shot=packet.duplicate(true)
		return super._present_shot(packet)
var checks:=0
var errors: Array[String]=[]
var largest_error:=0.
var game: WarGame
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: errors.append(label)
func visible_tip(actor: WarPlayer) -> Vector3:
	var model:=actor.view_root.get_node("Imported_"+actor.weapon_id) as Node3D
	return model.get_node("Muzzle").global_position if actor.weapon_id=="fal" else model.to_global(Vector3(.502,.084,0))
func run() -> void:
	game=ShotFixture.new();root.add_child(game);await process_frame
	var actor:=game.local_player as WarPlayer
	var authority:=game.players[2] as WarPlayer
	for weapon in ["fal","ak"]:
		actor.attack_anim=0.;actor.recoil=0.;authority.attack_anim=0.;authority.recoil=0.
		actor.weapon_id=weapon;actor.set_meta("weapon_optics",{weapon:"scope4x"});actor._refresh_weapon()
		authority.weapon_id=weapon;authority.set_meta("weapon_optics",{weapon:"scope4x"});authority._refresh_weapon()
		for posture in [0,1,2]:
			actor.set_posture(posture,false,true);actor.stance.advance(actor,1.)
			for yaw_value in [-2.5,0.,1.7]:
				for pitch_value in [-.2,0.,.6]:
					for lean_value in [-1.,0.,1.]:
						actor.yaw=yaw_value;actor.rotation=Vector3(0,yaw_value,0);actor.pitch=pitch_value;actor.recoil=0.;actor.lean=lean_value
						actor.camera_pivot.rotation=Vector3(pitch_value,0,-lean_value*GameInfantryPose.LEAN_ROLL)
						actor.aiming=true;actor.iron_sights=true;actor._update_view();actor._animate_walk();actor._update_weapon_pose()
						var origin:=actor.get_muzzle_position();var visual:=visible_tip(actor)
						var difference:=origin.distance_to(visual);largest_error=maxf(largest_error,difference)
						check(difference<.002,"muzzle matches FPP %s posture %d yaw %.1f pitch %.1f lean %.1f: %.4fm"%[weapon,posture,yaw_value,pitch_value,lean_value,difference])
						check(origin.is_finite(),"finite actual muzzle")
						authority.position=actor.position;authority.rotation=actor.rotation;authority.pitch=actor.pitch;authority.yaw=actor.yaw;authority.lean=actor.lean
						authority.camera_pivot.position=actor.camera_pivot.position;authority.iron_sights=true;authority.aiming=true
						authority.stance.crouch_weight=actor.stance.crouch_weight;authority.stance.prone_weight=actor.stance.prone_weight
						check(authority.get_muzzle_position().distance_to(visual)<.002,"remote/server pose uses same actual muzzle")
		actor.set_posture(0,false,true);actor.stance.advance(actor,1.);actor.recoil=0.;actor.pitch=0.;actor.yaw=0.;actor.lean=0.
		actor.rotation=Vector3.ZERO;actor.camera_pivot.rotation=Vector3.ZERO;actor.iron_sights=true;actor.aiming=true;actor._update_view()
		actor.owned=["fal","ak"];actor.loadout=actor.owned.duplicate();actor.ammo[weapon]=10;game.shot_clocks.clear()
		var visual_before:=visible_tip(actor);actor._update_weapon_pose();visual_before=visible_tip(actor)
		var sequence:=int(game.shot_sequences.get(1,0))+1
		game._server_accept_shot(1,sequence,actor.life_id,actor.camera.global_position,-actor.camera.global_basis.z,weapon,2)
		check(str(game.accepted_shot.get("weapon",""))==weapon,"authority accepts real scoped firearm shot")
		check(Vector3(game.accepted_shot.get("origin",Vector3.INF)).distance_to(visual_before)<.002,"accepted projectile packet starts at visible barrel")
		actor.set_posture(0,false,true);actor.stance.advance(actor,1.)
	var report:={"ok":errors.is_empty(),"checks":checks,"largest_error_m":largest_error,"errors":errors}
	NavalStorage.write_json("res://work/scoped-muzzle-regression.json",report)
	print("SCOPED_MUZZLE ",JSON.stringify({"ok":report.ok,"checks":checks,"errors":errors.size(),"largest_error_m":largest_error}))
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
