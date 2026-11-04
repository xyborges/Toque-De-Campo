extends SceneTree
const BR_FIXTURE=preload("res://tests/br_completion_fixture.gd")
var checks:=0
var errors: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);print("FAIL ",label)

func _initialize() -> void:run.call_deferred()

func verify_grips(actor: GamePlayer,label: String) -> void:
	for side in ["L","R"]:
		var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
		var hand: MeshInstance3D=arm.get_node("Hand"+side)
		check(hand.global_position.distance_to(actor.weapon_hand_target(side=="L"))<.001,label+": world grip "+side)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://work/weapon-presentation-"+label+".png")

func run() -> void:
	root.size=Vector2i(1280,800)
	var main: Node=load("res://scripts/main.gd").new();main.set_meta("test_mode",true);root.add_child(main)
	await process_frame;await process_frame
	var menu: GameMainMenu=main.main_menu
	main.profile.owned=GameWeapons.INFANTRY_IDS.duplicate()
	menu._select_mode("desert")
	var editor: GameLoadoutEditor=menu.preparation_editor
	for id in ["ak","fal","sniper"]:
		editor.slots.primary=id;editor.preview_slot="primary";editor._update_preview()
		menu.preparation_preview._process(.2)
		check(editor.preview.actor.weapon_id==id,"menu swaps primary "+id)
		verify_grips(editor.preview.actor,"menu "+id)
		await capture("menu-"+id)
	for slot in ["sidearm","melee","primary"]:
		if not editor.slots.has(slot):continue
		editor._select(slot);menu.preparation_preview._process(.2)
		check(editor.preview.actor.weapon_id==editor.slots[slot],"clicked slot is held: "+slot)
		check(editor.preview.held_slot==slot,"held item opens its own options: "+slot)
		verify_grips(editor.preview.actor,"menu selected "+slot)
		await capture("menu-"+slot)
	var before: Transform3D=editor.preview.actor.weapon_root.transform
	menu.preparation_preview._process(.5)
	check(not before.is_equal_approx(editor.preview.actor.weapon_root.transform),"idle animation continues after selection")
	main.queue_free();await process_frame
	var game: BattleRoyaleGame=BR_FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
	await process_frame;game.flat_world()
	var actor:=game._spawn_player(1,true,false,Vector3.ZERO) as BRPlayer
	var observer:=game._spawn_player(2,false,false,Vector3(5,0,0)) as BRPlayer
	for p in [actor,observer]:p.set_physics_process(false);p.set_process(false);game.br_inventory.add_player(p.peer_id)
	game.br_round.begin([1,2],game._now());game.br_generation=1
	game.hud_layer.hide();game.menu_layer.hide()
	actor.owned=["fists","ak","fal","glock","sniper","ak_br2","fal_br2","rpg","stinger","binoculars"]
	actor.loadout=actor.owned.filter(func(id):return id!="fists" and id!="binoculars")
	actor.ammo=GameWeapons.fresh_ammo();actor.reserves=CombatRules.fresh_reserves()
	for round_index in 3:
		for id in ["fists","fal","ak","sniper","glock","ak_br2","fal_br2","rpg","stinger","binoculars","fists"]:
			actor.cancel_reload();game._equip_server(actor,id);actor._animate_walk()
			check(actor.weapon_id==id,"BR production equip "+id)
			game.remote_equipped(1,id);actor._animate_walk()
			check(actor.camera.get_children().filter(func(node):return node is Node3D and node.has_meta("weapon")).size()==1,"repeated equip keeps one FPP rig "+id)
			if id=="fists":
				for side in ["L","R"]:
					var hand: MeshInstance3D=actor.view_root.get_node("Left" if side=="L" else "Right")
					var world: MeshInstance3D=actor.avatar_parts["arm_"+side.to_lower()].get_node("Hand"+side)
					check(hand.mesh==world.mesh and hand.material_override==world.material_override,"fists match body "+side)
				continue
			verify_grips(actor,"BR "+id)
			var stages: Array=[0.,.15,.35,.60,.85,1.] if GameWeapons.ITEMS[id].kind=="firearm" else [1.]
			for progress: float in stages:
				actor.reload_weapon=id;actor.reload_total=6.;actor.reload_left=(1.-progress)*6.;actor._animate_walk()
				verify_grips(actor,"BR reload "+id)
				for side in ["L","R"]:
					var support: bool=side=="L"
					var world_arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
					var world_hand: MeshInstance3D=world_arm.get_node("Hand"+side)
					var hand: MeshInstance3D=actor.view_root.get_node("SupportHand" if support else "GripHand")
					var forearm: MeshInstance3D=actor.view_root.get_node("LeftForearm" if support else "RightForearm")
					var world_forearm: MeshInstance3D=world_arm.get_node("Forearm"+side+"Mesh")
					check(hand.mesh==world_hand.mesh and hand.material_override==world_hand.material_override,"same hands during reload "+id+side)
					check(forearm.mesh==world_forearm.mesh and forearm.material_override==world_forearm.material_override,"same sleeves "+id+side)
					check(hand.transform.is_finite() and forearm.transform.is_finite(),"finite rig after switching "+id+side)
			if round_index==0:
				actor.reload_left=0.;actor._animate_walk();await capture("br-"+id)
	actor.apply_body_colors({"skin":"8e644b","shirt":"647048"});actor._animate_walk()
	check(actor.view_root.get_node("Left").material_override==actor.avatar_parts.arm_l.get_node("HandL").material_override,"fist color follows character after changing equipment")
	game.leave_match();game.queue_free();await process_frame
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors,"graphical":DisplayServer.get_name()!="headless","scope":"Production menu selection and idle pose, three repeated authoritative/reliable equip cycles in BR, duplicate weapon IDs, reload stages, exact hand/sleeve resources, grip attachment and bounded presentation nodes."}
	NavalStorage.write_json("res://work/weapon-presentation-validation.json",report)
	print("WEAPON_PRESENTATION_VALIDATION ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
