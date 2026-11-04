extends SceneTree
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var failures: Array[String]=[]
var mounts: Array=[]
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func shot(path: String) -> void:
	await settle()
	var status:=root.get_texture().get_image().save_png(path)
	if status!=OK:failures.append("cannot save "+path)
	print("SHOT ",path," status=",status)
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("rendering required");quit(2);return
	root.content_scale_size=Vector2i(1280,720)
	var game: WarGame=FIXTURE.new();root.add_child(game)
	await settle()
	game.hud_layer.hide()
	var actor:=game.local_player as WarPlayer
	actor.set_process(false);actor.set_physics_process(false);actor.set_process_unhandled_input(false)
	game.third_person=false
	var observer:=Camera3D.new();observer.fov=38.;observer.near=.01;game.world_root.add_child(observer)
	var reviews:=[["sniper",""],["sniper","precision8x"],["sniper","hensoldt4x"],["g3",""],["g3","hensoldt4x"],["g3","precision8x"],["ak","precision8x"],["ak","hensoldt4x"],["fal","precision8x"],["fal","hensoldt4x"],["fal","pso4x"]]
	for pair in reviews:
		var weapon:=str(pair[0]);var optic:=str(pair[1])
		actor.weapon_id=weapon;actor.hp=100;actor.deployed=true;actor.aiming=false;actor.iron_sights=false
		actor.yaw=0.;actor.pitch=0.;actor.rotation=Vector3.ZERO
		var configuration: Dictionary=GameAttachmentState.from_legacy(weapon,optic) if not optic.is_empty() else {}
		actor.set_meta("weapon_attachments",{weapon:configuration})
		actor.set_meta("weapon_optics",{weapon:optic} if not optic.is_empty() else {})
		actor._refresh_weapon();actor._update_view();actor._update_weapon_pose()
		await settle()
		var target:=actor.weapon_root.global_position
		var scope:=actor.weapon_optics.world_scope as Node3D
		if scope:mounts.append({"weapon":weapon,"optic":optic,"contacts":scope.get_meta("support_contacts",[])})
		if scope:target=scope.global_position
		actor.view_root.hide();actor.weapon_root.show()
		observer.global_position=target+Vector3(.83,.22,.40);observer.look_at(target+Vector3(0,-.045,-.08));observer.make_current()
		await shot("res://work/optics-review-"+weapon+"-"+(optic if not optic.is_empty() else "iron")+"-world.png")
		if weapon=="sniper" and optic=="precision8x":
			observer.global_position=target+Vector3(.32,.12,-.60)
			observer.look_at(target+Vector3(0,0,-.11))
			await shot("res://work/optics-review-sniper-precision8x-front.png")
			var ocular:=scope.to_global(Vector3(0,0,.184))
			observer.projection=Camera3D.PROJECTION_ORTHOGONAL
			observer.size=.18
			observer.global_position=ocular+scope.global_basis.x.normalized()*.5
			observer.look_at(ocular,scope.global_basis.y.normalized())
			await shot("res://work/optics-review-sniper-precision8x-ocular-side.png")
			observer.projection=Camera3D.PROJECTION_PERSPECTIVE
		actor.camera.make_current();actor.iron_sights=true;actor.aiming=true
		# Stationary model capture. Live input/transition is covered by optical_ads_live.
		actor.weapon_optics.advance(actor,1.);actor._update_view();actor._update_weapon_pose()
		actor.weapon_optics.update(actor)
		await shot("res://work/optics-review-"+weapon+"-"+(optic if not optic.is_empty() else "iron")+"-ads.png")
		actor.iron_sights=false;actor.aiming=false;actor.weapon_optics.stop()
	var result={"ok":failures.is_empty(),"failures":failures,"configurations":reviews,"mounts":mounts}
	NavalStorage.write_json("res://work/optics-review-screenshots.json",result)
	print("OPTICS_REVIEW ",JSON.stringify(result))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
