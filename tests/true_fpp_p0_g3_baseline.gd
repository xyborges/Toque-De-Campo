extends SceneTree
## P0 baseline only: no runtime gameplay mutations are persisted.
class ShotFixture extends "res://tests/war_optics_fixture.gd":
	var latest_shot: Dictionary={}
	func _present_shot(packet: Dictionary) -> bool:
		latest_shot=packet.duplicate(true)
		return super._present_shot(packet)

var game: WarGame

func _initialize() -> void:
	run.call_deferred()

func read_variant(actor: WarPlayer, label: String, third: bool, ads: bool, sequence: int) -> Dictionary:
	game.third_person=third
	actor.aiming=ads
	actor.iron_sights=ads
	actor.recoil=0.0
	actor.pitch=0.0
	actor.yaw=0.0
	actor.rotation=Vector3.ZERO
	actor.camera_pivot.rotation=Vector3.ZERO
	actor._update_view()
	actor._animate_walk()
	actor._update_weapon_pose()
	actor._update_camera_collision(1.0/60.0)
	var camera_origin: Vector3=actor.camera.global_position
	var camera_direction: Vector3=-actor.camera.global_basis.z.normalized()
	var muzzle: Vector3=actor.get_muzzle_position()
	var from_eye: Vector3=actor.camera_pivot.global_position
	var presentation: Node3D=actor.view_root.get_node_or_null("Imported_g3") as Node3D
	var world_model: Node3D=actor.weapon_root.get_node_or_null("Imported_g3") as Node3D
	var view_muzzle: Node3D=presentation.get_node_or_null("Muzzle") if presentation else null
	var world_muzzle: Node3D=world_model.get_node_or_null("Muzzle") if world_model else null
	var ret: Dictionary={
		"label":label, "preference_tpp":third, "ads":ads,
		"effective_view":"TPP" if actor.camera.get_parent()==actor.shoulder_arm else "FPP",
		"camera_origin":str(camera_origin), "eye_origin":str(from_eye),
		"camera_eye_offset_m":camera_origin.distance_to(from_eye),
		"muzzle_origin":str(muzzle),
		"view_copy_exists":presentation!=null,
		"world_model_exists":world_model!=null,
		"world_muzzle_error_m":world_muzzle.global_position.distance_to(muzzle) if world_muzzle else -1.0,
		"fpp_copy_muzzle_error_m":view_muzzle.global_position.distance_to(muzzle) if view_muzzle else -1.0
	}
	actor.ammo["g3"]=20
	game.shot_clocks.clear()
	game.latest_shot.clear()
	game._server_accept_shot(1,sequence,actor.life_id,camera_origin,camera_direction,"g3",2 if ads else 0)
	var packet: Dictionary=game.latest_shot
	ret["accepted"]=str(packet.get("weapon",""))=="g3"
	ret["shot_blocked"]=bool(packet.get("blocked",false))
	ret["shot_origin"]=str(packet.get("origin",Vector3.INF))
	ret["shot_direction"]=str(packet.get("direction",Vector3.INF))
	ret["shot_origin_delta_m"]=Vector3(packet.get("origin",Vector3.INF)).distance_to(muzzle) if ret.accepted else -1.0
	return ret

func run() -> void:
	game=ShotFixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	actor.weapon_id="g3"
	actor.owned=["g3","glock"]
	actor.loadout=["g3","glock"]
	actor.set_meta("weapon_optics",{})
	actor._refresh_weapon()
	actor.set_process(false)
	actor.set_physics_process(false)
	var values: Array[Dictionary]=[]
	values.append(read_variant(actor,"G3 hip FPP",false,false,51001))
	values.append(read_variant(actor,"G3 hip TPP",true,false,51002))
	values.append(read_variant(actor,"G3 ADS prefers TPP",true,true,51003))
	var g3_model: Node3D=G3Model.create()
	var handle:=g3_model.get_node_or_null("ChargingHandle") as Node3D
	var initial: Vector3=handle.position if handle else Vector3.ZERO
	var active: Dictionary=GameReloadPose.state("g3",1.0,4.0)
	GameReloadPose.apply(g3_model,"g3",active)
	var handle_motion_m: float=initial.distance_to(handle.position) if handle else -1.0
	var handle_exists: bool=handle!=null
	g3_model.free()
	var result: Dictionary={"variants":values,"charging_handle_found":handle_exists,"charging_handle_motion_m":handle_motion_m}
	var p:=values[0]
	var q:=values[1]
	result["camera_offset_change_m"]=Vector3.ZERO.distance_to(Vector3.ZERO)+absf(float(p.camera_eye_offset_m)-float(q.camera_eye_offset_m))
	result["both_hip_shots_accepted"]=bool(p.accepted) and bool(q.accepted)
	result["effective_view_flip"]=p.effective_view!=q.effective_view
	result["ads_forces_fpp"]=values[2].effective_view=="FPP"
	result["ok"]=result.both_hip_shots_accepted and result.effective_view_flip and result.ads_forces_fpp
	var out:=FileAccess.open("res://work/fpp-tpp-p0-20261104/g3-baseline.json",FileAccess.WRITE)
	if out: out.store_string(JSON.stringify(result,"\t"));out.close()
	print("TRUE_FPP_P0_G3 ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if bool(result.ok) else 1)
