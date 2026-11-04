extends SceneTree
const CATALOG=preload("res://scripts/optic_catalog.gd")
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var checks:=0
var failures: Array[String]=[]
var game: WarGame
var render_checks:=false

func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle() -> void:
	await process_frame;await process_frame
	if render_checks:await RenderingServer.frame_post_draw
func visible_tip(actor: WarPlayer) -> Vector3:
	var model:=actor.view_root.get_node("Imported_"+actor.weapon_id) as Node3D
	return model.get_node("Muzzle").global_position if actor.weapon_id=="fal" else model.to_global(Vector3(.502,.084,0))

func run() -> void:
	render_checks=DisplayServer.get_name()!="headless"
	if render_checks:root.title="Toque de Campo — ópticas · verificação";root.content_scale_size=Vector2i(1280,720)
	check(CATALOG.resolve("scope4x","fal")=="prism4x" and CATALOG.resolve("scope4x","ak")=="pso4x","legacy choices retain original weapon-specific models")
	check(not CATALOG.valid("thermal") and not CATALOG.compatible("prism4x","glock"),"unknown and incompatible attachments rejected")
	for id in ["prism4x","pso4x"]:
		check(CATALOG.model(id)!=null and CATALOG.magnification(id)==4.,"loose item has reusable scene and4x data: "+id)
	game=FIXTURE.new();root.add_child(game);await settle()
	var actor:=game.local_player as WarPlayer;var remote:=game.players[2] as WarPlayer
	actor.set_process(false);actor.set_physics_process(false);actor.set_process_unhandled_input(false)
	remote.set_process(false);remote.set_physics_process(false)
	game.third_person=false;actor.camera.make_current();actor.yaw=0.;actor.pitch=0.;actor.rotation=Vector3.ZERO
	for weapon in ["fal","ak"]:
		actor.weapon_id=weapon;actor.hp=100.;actor.deployed=true;actor.aiming=true;actor.iron_sights=true;actor.reload_left=0.
		for id in ["prism4x","pso4x"]:
			var old:=actor.weapon_optics.world_scope as Node3D
			actor.set_meta("weapon_optics",{weapon:id});actor.refresh_weapon_optics() if is_instance_valid(actor.weapon_root.get_node_or_null("Imported_"+weapon)) else actor._refresh_weapon()
			actor._update_view();actor._update_weapon_pose();actor.weapon_optics.update(actor);await settle()
			var scope:=actor.weapon_optics.world_scope as Node3D
			check(actor.weapon_optics.enabled(actor) and is_instance_valid(scope) and scope.get_meta("optic_id")==id,"equips selected model "+weapon+"/"+id)
			check(not is_instance_valid(old) or old!=scope,"same firearm replaces previous attachment model "+weapon+"/"+id)
			check(actor.weapon_root.find_children("Scope4x","Node3D",true,false).size()==1 and actor.view_root.find_children("Scope4x","Node3D",true,false).size()==1,"one world and one presentation attachment "+weapon+"/"+id)
			var view_scope:=actor.view_root.find_child("Scope4x",true,false) as Node3D
			var world_material: Material=scope.get_node("Lens").material_override
			var view_material: Material=view_scope.get_node("Lens").material_override
			check(world_material!=view_material,"FPP lens material isolated from world resource "+weapon+"/"+id)
			var lens_local:=actor.camera.to_local(view_scope.get_node("Lens").global_position)
			check(absf(lens_local.x)<.002 and absf(lens_local.y)<.002 and lens_local.z<-.09,"ocular centred on actual camera "+weapon+"/"+id)
			check(actor.get_muzzle_position().distance_to(visible_tip(actor))<.002,"projectile origin remains at visible barrel "+weapon+"/"+id)
			remote.weapon_id=weapon;remote.set_meta("weapon_optics",{weapon:id});remote._refresh_weapon();remote.weapon_optics.update(remote)
			check(not is_instance_valid(remote.weapon_optics.view),"remote actor never renders optical viewport "+weapon+"/"+id)
			if render_checks:
				check(actor.weapon_optics.active and actor.weapon_optics.view.size==Vector2i(384,384),"live384square optical view "+weapon+"/"+id)
				check(actor.find_children("OpticalLens4x","SubViewport",true,false).size()==1,"attachment swap reuses a single viewport "+weapon+"/"+id)
				var expected:=rad_to_deg(2.*atan(.032/maxf(.04,-lens_local.z)/4.))
				check(absf(actor.weapon_optics.camera.fov-expected)<.001,"4x FOV calibrated to physical lens "+weapon+"/"+id)
				var first:=actor.weapon_optics.view.get_texture().get_image()
				actor.yaw=.3;actor.rotation.y=actor.yaw;actor._update_view();actor._update_weapon_pose();actor.weapon_optics.update(actor);await settle()
				var second:=actor.weapon_optics.view.get_texture().get_image()
				check(first.get_data()!=second.get_data(),"optical scene updates while aiming moves "+weapon+"/"+id)
				root.get_texture().get_image().save_png("res://work/optic-"+weapon+"-"+id+".png")
				actor.yaw=0.;actor.rotation.y=0.;actor._update_view();actor._update_weapon_pose()
			actor.hp=0.;actor.weapon_optics.update(actor)
			check(not actor.weapon_optics.active and (not is_instance_valid(actor.weapon_optics.view) or actor.weapon_optics.view.render_target_update_mode==SubViewport.UPDATE_DISABLED),"death stops optical rendering "+weapon+"/"+id)
			actor.hp=100.
		actor.set_meta("weapon_optics",{});actor.refresh_weapon_optics();actor._update_view();actor.weapon_optics.update(actor)
		check(not actor.weapon_optics.enabled(actor) and actor.weapon_root.find_child("Scope4x",true,false)==null and not actor.weapon_optics.active,"unequip restores iron sights and stops viewport "+weapon)
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"rendered":render_checks,"scope":"Both prism4x andpso4x on FAL/AK; sameweapon swap, old aliases, ocular/muzzle alignment, isolated FPP materials, death/unequip. Graphical mode checks live movement and single384square viewport."}
	NavalStorage.write_json("res://work/optic-catalog-validation.json",report);print("OPTIC_CATALOG ",JSON.stringify(report))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
