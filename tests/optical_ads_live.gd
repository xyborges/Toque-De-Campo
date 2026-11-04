extends SceneTree
## Real input dispatch and unfrozen character physics; only room/map bootstrap is a fixture.
var failures: Array[String]=[]
var checks:=0
var cases: Array=[]
var game: Node3D
var actor: GamePlayer

func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func ticks(count: int) -> void:
	for i in count:await physics_frame
	await process_frame
func click() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=false
	Input.parse_input_event(event)
func equip(weapon: String,optic: String) -> void:
	actor.clear_aim();actor.cancel_reload();actor.weapon_id=weapon
	actor.owned=["fists","fal","ak","g3","sniper","sniper_br2"];actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{weapon:optic})
	actor.set_meta("weapon_attachments",{weapon:GameAttachmentState.from_legacy(weapon,optic)})
	actor._refresh_weapon();actor._update_view()
	await ticks(2)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=60
	for mode_key in ["br","war"]:
		game=load("res://tests/br_completion_fixture.gd" if mode_key=="br" else "res://tests/war_optics_fixture.gd").new()
		game.set_meta("test_mode",true);root.add_child(game);await process_frame
		game.set_physics_process(false);game.set_process(false)
		if mode_key=="br":
			game.flat_world();game.offline_operation=true;game.online=false
			actor=game._spawn_player(1,true,false,Vector3.ZERO);game.br_inventory.add_player(1);game.br_round.begin([1],game._now())
		else:
			actor=game.local_player
			var body:=StaticBody3D.new();game.world_root.add_child(body)
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,1,80);shape.shape=box;shape.position.y=-.5;body.add_child(shape)
		actor.hp=100.;actor.position=Vector3.ZERO;actor.body_collision.disabled=false
		actor.set_physics_process(true);actor.set_process(true);actor.set_process_unhandled_input(true)
		game.ui_focus.close_all();game.hud_layer.hide();actor.camera.make_current()
		game.third_person=false
		await equip("g3","")
		await click();await click();await ticks(2)
		var rear:=actor.view_root.get_node("Imported_g3/RearSight") as Node3D
		var front:=actor.view_root.get_node("Imported_g3/FrontSight") as Node3D
		check(actor.iron_sights and actor.view_root.is_visible_in_tree(),mode_key+" G3 iron sights through input")
		var centre:=root.get_visible_rect().size*.5
		check(actor.camera.unproject_position(rear.global_position).distance_to(centre)<1. and actor.camera.unproject_position(front.global_position).distance_to(centre)<1.,mode_key+" G3 diopter and blade share screen axis")
		for third in [false,true]:
			game.third_person=third
			for weapon in ["sniper","g3","ak","fal"]:
				for optic in ["precision8x","hensoldt4x"]:
					await equip(weapon,optic)
					var label:="%s/%s/%s/%s"%[mode_key,weapon,optic,"tpp" if third else "fpp"]
					Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
					check(game.gameplay_input_allowed(),label+" production input gate")
					await click();await ticks(4)
					check(actor.iron_sights,label+" right click enters ADS")
					var weight:=actor.weapon_optics.aim_weight;var middle:=actor.view_root.position
					check(weight>0. and weight<1.,label+" intermediate animation pose")
					check(not actor.weapon_optics.active,label+" lens waits for eye alignment")
					await ticks(20)
					check(actor.view_root.is_visible_in_tree(),label+" visible after normal physics")
					check(actor.weapon_optics.active,label+" live lens after normal physics")
					check(middle.distance_to(actor.view_root.position)>.005,label+" weapon actually moves")
					var lens:=actor.weapon_optics.lens
					if is_instance_valid(lens):
						var local:=actor.camera.to_local(lens.global_position)
						check(absf(local.x)<.004 and absf(local.y)<.004 and local.z<-.08,label+" centred lens")
					var contacts: Array=actor.weapon_optics.world_scope.get_meta("support_contacts",[])
					check(contacts.size()>=2,label+" feet seated against real weapon triangles")
					if mode_key=="br" and not third:
						var measured: Array=preload("res://tests/optical_support_probe.gd").measure(actor.weapon_optics.world_scope,actor.weapon_root)
						for contact: Dictionary in measured:check(contact.valid,label+" actual contact "+str(contact))
					cases.append({"case":label,"contacts":contacts,"lens_active":actor.weapon_optics.active})
					await click();await ticks(3)
					check(not actor.iron_sights and actor.weapon_optics.aim_weight>0.,label+" lowering is animated")
					var before:=actor.view_root.position
					await click();await ticks(1)
					check(before.distance_to(actor.view_root.position)<.15,label+" reversal has no jump")
					await ticks(20)
					actor.clear_aim();await ticks(20)
					check(not actor.weapon_optics.active and actor.weapon_optics.aim_weight==0.,label+" lowered renderer stops")
		await equip("sniper","precision8x")
		if mode_key=="br":
			actor.set_meta("weapon_attachments",{"sniper":GameAttachmentState.from_legacy("sniper","hensoldt4x"),"sniper_br2":GameAttachmentState.from_legacy("sniper_br2","precision8x")})
			actor.weapon_id="sniper_br2";actor._refresh_weapon();await click();await ticks(22)
			check(actor.weapon_optics.active and actor.weapon_optics.selected_optic=="precision8x","BR second sniper keeps its independent 8x")
			await equip("sniper","precision8x")
		for posture in [0,1,2]:
			actor.set_posture(posture,false,true);await ticks(20)
			Input.action_press("move_forward");Input.action_press("lean_right")
			await click();await ticks(22)
			check(actor.weapon_optics.active,mode_key+" moving/posture/lean "+str(posture))
			Input.action_release("move_forward");Input.action_release("lean_right")
			actor.clear_aim();await ticks(20)
		await click();await ticks(22)
		actor.ammo[actor.weapon_id]=0;actor.reserves[actor.weapon_id]=10;actor.start_reload();await ticks(3)
		check(not actor.weapon_optics.active and actor.weapon_optics.aim_weight==0.,mode_key+" reload cancels optics")
		actor.cancel_reload();await equip("sniper","precision8x")
		await click();await ticks(22);actor.grenade_selected=true;actor._update_view();await ticks(2)
		check(not actor.weapon_optics.active,mode_key+" grenade cancels optics")
		actor.grenade_selected=false;actor.clear_aim();await ticks(2)
		await click();await ticks(22);actor.vehicle_id="qa_vehicle";actor.weapon_optics.advance(actor,1.)
		check(not actor.weapon_optics.active and actor.weapon_optics.aim_weight==0.,mode_key+" vehicle cancels optics")
		actor.vehicle_id="";actor.clear_aim();await ticks(2)
		await click();await ticks(22);actor.hp=0.;await ticks(2)
		check(not actor.weapon_optics.active and actor.weapon_optics.aim_weight==0.,mode_key+" death cancels optics")
		game.queue_free();await ticks(2)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"Live BR and War characters, actual input dispatch, physics and rendering; flat offline QA maps, no account or matchmaking."}
	NavalStorage.write_json("res://work/optical-ads-live.json",report)
	print("OPTICAL_ADS_LIVE ",JSON.stringify({"ok":report.ok,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
