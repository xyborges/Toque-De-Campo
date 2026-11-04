extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
var count:=0
var failures: Array[String]=[]
var rendered:=false
func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> void:
	count+=1
	if not value:
		failures.append(label)
		push_error("OPTICS_UNIVERSAL: "+label)

func settle() -> void:
	await process_frame
	await process_frame
	if rendered:await RenderingServer.frame_post_draw

func run() -> void:
	rendered=DisplayServer.get_name()!="headless"
	if rendered:root.content_scale_size=Vector2i(1280,720)
	var rifles:=["ak","fal","g3","sniper"]
	var scopes:=["prism4x","pso4x","hensoldt4x","precision8x"]
	check(GameAttachmentRegistry.ids("optic").size()==4,"four optics registered")
	check(GameWeapons.ITEMS.sniper.get("optic_fovs",[]).is_empty(),"sniper has no mandatory fixed zoom")
	for weapon in rifles:
		var profile:=GameAttachmentRegistry.profile(weapon)
		check(profile!=null,"weapon profile exists "+weapon)
		if not profile:continue
		check(GameAttachmentState.sockets(weapon).has("optic_top"),"top mounting socket exists "+weapon)
		for optic in scopes:
			check(GameOpticCatalog.compatible(optic,weapon),"supports "+weapon+"/"+optic)
			var config:=GameAttachmentState.from_legacy(weapon,optic)
			check(GameAttachmentState.validate(weapon,config).get("ok",false),"module state validates "+weapon+"/"+optic)
			var definition:=GameAttachmentRegistry.definition(optic)
			check(definition!=null and definition.scene_reference!=null,"optic scene resolves "+optic)
			check(is_equal_approx(GameOpticCatalog.magnification(optic,weapon),8. if optic=="precision8x" else 4.),"real zoom "+optic)
	check(not GameOpticCatalog.compatible("precision8x","glock"),"pistol not treated as rifle")
	for team in [0,1]:
		for role in ["soldier","marksman"]:
			var base:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,role,team)
			check(not base.has("optic"),"War starts without forced scope")
			for optic in scopes:
				var requested:=base.duplicate(true);requested.optic=optic
				check(GameLoadouts.validate(requested,"war",GameWeapons.INFANTRY_IDS,role,team).get("ok",false),"War loadout accepts "+role+"/"+str(team)+"/"+optic)
	check(GameLoadouts.validate({"primary":"sniper","optic":"precision8x"},"desert",GameWeapons.INFANTRY_IDS).get("ok",false),"standalone sniper8x allowed")
	check(GameLoadouts.validate({"primary":"sniper","optic":"scope4x"},"desert",GameWeapons.INFANTRY_IDS).get("ok",false),"legacy alias stays valid")
	check(not GameLoadouts.validate({"primary":"sniper","optic":"fake8x"},"desert",GameWeapons.INFANTRY_IDS).get("ok",false),"forged optic rejected")
	var game: WarGame=FIXTURE.new()
	root.add_child(game)
	await settle()
	var actor:=game.local_player as WarPlayer
	var remote:=game.players[2] as WarPlayer
	actor.set_process(false);actor.set_physics_process(false);actor.set_process_unhandled_input(false)
	remote.set_process(false);remote.set_physics_process(false)
	game.third_person=false
	actor.camera.make_current()
	for weapon in rifles:
		actor.set_meta("weapon_attachments",{})
		actor.set_meta("weapon_optics",{})
		actor.weapon_id=weapon
		actor.hp=100
		actor.deployed=true
		actor.iron_sights=false
		actor.aiming=false
		actor._refresh_weapon();actor._update_view()
		await settle()
		var tip_before:=actor.get_muzzle_position()
		if weapon=="sniper":
			check(actor.weapon_root.find_child("IronSightAssembly",true,false)!=null,"sniper has physical irons when unscoped")
			check(actor.weapon_root.find_child("RearIron",true,false)!=null,"rear iron sight exists")
			check(actor.weapon_root.find_child("FrontIron",true,false)!=null,"front iron sight exists")
			check(not actor.uses_telescopic_sight(),"no legacy zoom overlay on sniper")
			actor.iron_sights=true;actor.aiming=true
			actor._update_view();actor._update_weapon_pose()
			check(actor.view_root.visible,"sniper stays visible with irons")
			actor.iron_sights=false;actor.aiming=false
		for optic in scopes:
			var config:=GameAttachmentState.from_legacy(weapon,optic)
			actor.set_meta("weapon_attachments",{weapon:config})
			actor.set_meta("weapon_optics",{weapon:optic})
			actor.refresh_weapon_optics()
			actor._update_view()
			actor._update_weapon_pose()
			await settle()
			var scope:=actor.weapon_optics.world_scope as Node3D
			check(actor.weapon_optics.enabled(actor) and is_instance_valid(scope),"model attached "+weapon+"/"+optic)
			if not scope:continue
			check(str(scope.get_meta("attachment_id",""))==optic,"correct optic model "+weapon+"/"+optic)
			check(actor.weapon_root.find_children("Scope4x","Node3D",true,false).size()==1,"only one world scope "+weapon+"/"+optic)
			check(actor.view_root.find_children("Scope4x","Node3D",true,false).size()==1,"only one view scope "+weapon+"/"+optic)
			var mount:=scope.get_node_or_null("MountReference") as Node3D
			var socket:=actor.weapon_optics.mounting.markers.get_node_or_null("optic_top") as Node3D
			check(mount!=null and socket!=null and mount.global_position.distance_to(socket.global_position)<.003,"mount contacts socket "+weapon+"/"+optic)
			check(actor.get_muzzle_position().distance_to(tip_before)<.003,"muzzle does not move when optic is mounted "+weapon+"/"+optic)
			actor.iron_sights=true;actor.aiming=true;actor.reload_left=0.
			actor.weapon_optics.advance(actor,1.)
			check(is_equal_approx(actor.aim_sensitivity_scale(),.125 if optic=="precision8x" else .25),"aim sensitivity respects magnification "+weapon+"/"+optic)
			actor._update_view();actor._update_weapon_pose();actor.weapon_optics.update(actor)
			await settle()
			if rendered:
				check(actor.weapon_optics.active,"live optic when aiming "+weapon+"/"+optic)
				check(is_instance_valid(actor.weapon_optics.view) and actor.weapon_optics.view.size==Vector2i(384,384),"budgeted viewport "+weapon+"/"+optic)
				var camera:=actor.weapon_optics.camera as Camera3D
				check(camera.fov>0. and camera.fov<60.,"physical eye FOV "+weapon+"/"+optic)
				if optic=="precision8x":check(GameOpticCatalog.magnification(optic)==8.,"8x configured; real zoom measured separately")
			actor.iron_sights=false;actor.aiming=false
			actor.weapon_optics.update(actor)
			check(not actor.weapon_optics.active,"scope rendering pauses when lowered "+weapon+"/"+optic)
		actor.set_meta("weapon_attachments",{weapon:{}})
		actor.set_meta("weapon_optics",{})
		actor.refresh_weapon_optics();actor._update_view();await settle()
		check(not actor.weapon_optics.enabled(actor),"optic detached "+weapon)
		check(actor.weapon_root.find_child("Scope4x",true,false)==null,"no scope left after detach "+weapon)
	remote.weapon_id="sniper";remote._refresh_weapon()
	game.remote_weapon_optics(remote.peer_id,{"sniper":"precision8x"},remote.life_id)
	check(str(remote.get_meta("weapon_optics",{}).get("sniper",""))=="precision8x","remote network optic state preserved")
	check(remote.weapon_optics.selected_optic=="precision8x","remote 8x model selected")
	check(not is_instance_valid(remote.weapon_optics.view),"remote does not allocate extra lens viewport")
	var report:={"ok":failures.is_empty(),"checks":count,"failures":failures,"rendered":rendered,"rifles":rifles,"scopes":scopes}
	NavalStorage.write_json("res://work/optics-universal-validation.json",report)
	print("OPTICS_UNIVERSAL ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
