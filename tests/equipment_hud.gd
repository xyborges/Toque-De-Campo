extends SceneTree
var checks:=0
var failures: Array[String]=[]
var captures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func key(actor: GamePlayer,code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;actor._unhandled_input(event)
func shot(label: String) -> void:
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	var path:="res://work/equipment-hud-"+label+".png"
	root.get_texture().get_image().save_png(path);captures.append(path)
func check_hud_bounds(game: Node,label: String) -> void:
	var rect: Rect2=game.infantry_hud.ammo.get_parent().get_parent().get_global_rect()
	var dimensions:=root.get_visible_rect().size
	check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=dimensions.x and rect.end.y<=dimensions.y,"equipment panel remains inside the viewport: "+label)
func run() -> void:
	var game=load("res://tests/late_join_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="sandbox";game._enter_match_world();game.set_physics_process(false)
	game._static_box(game.world_root,"Floor",Vector3(0,-.25,0),Vector3(100,.4,100),Color.GRAY)
	var actor: GamePlayer=game._spawn_player(1,true,false,Vector3.ZERO);actor.set_physics_process(false)
	actor.owned=["broom","squeegee","axe","glock","fal","sniper"];actor.loadout=actor.owned.duplicate()
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var slots:=GameInventorySlots.resolve(actor)
	check(GameUI.icon("grenade").get_image().get_data()!=GameUI.icon("unknown").get_image().get_data(),"grenade equipment uses its own reusable icon instead of the fallback cross")
	check(slots[1]=="glock" and slots[2]=="fal" and slots[3]=="grenade" and slots[4]=="squeegee","four numeric slots resolve from the real loadout")
	check(slots[5]=="sniper" and slots[6]=="broom" and slots[9]=="axe","additional weapons remain accessible without using special class keys 7/8")
	key(actor,KEY_1);check(actor.weapon_id=="glock","key 1 equips the pistol")
	actor.ammo.glock=4;actor.reserves.glock=17
	key(actor,KEY_2);check(actor.weapon_id=="fal","key 2 equips the rifle")
	key(actor,KEY_4);check(actor.weapon_id=="squeegee","key 4 equips the preferred available melee tool")
	actor.loadout=["broom","glock","sniper"];key(actor,KEY_4);check(actor.weapon_id=="broom","melee slot falls back to the equipped broom")
	key(actor,KEY_2);check(actor.weapon_id=="sniper","marksman-style loadout keeps sniper in primary slot")
	actor.loadout=["axe","glock","fal"];key(actor,KEY_4);check(actor.weapon_id=="axe","melee slot supports an axe-only loadout")
	key(actor,KEY_1);game.infantry_hud.refresh()
	check(actor.ammo.glock==4 and game.infantry_hud.slot_views[1].amount.text=="4 / 17","switching slots preserves and shows actual magazine/reserve")
	var selected: Dictionary=game.infantry_hud.slot_views[1]
	check(selected.label.get_theme_color("font_color")==FieldTheme.ON_ACCENT and selected.key_label.get_theme_color("font_color")==FieldTheme.ON_ACCENT and selected.icon.modulate==FieldTheme.ON_ACCENT,"selected equipment uses dark text and icons on the accent background")
	await shot("selected-pistol")
	check_hud_bounds(game,"selected weapon")
	actor.ammo.glock=0;game.infantry_hud.refresh()
	check(game.infantry_hud.low_ammo.visible and game.infantry_hud.low_ammo.text.contains("RECARREGAR"),"empty magazine has a readable reload prompt")
	await shot("empty-pistol")
	check_hud_bounds(game,"empty magazine warning")
	actor.loadout=["fal"];game.infantry_hud.refresh()
	check(game.infantry_hud.slot_views[1].button.disabled,"unavailable pistol is disabled rather than invented")
	key(actor,KEY_3);check(actor.grenade_selected and actor.grenade_held_id.is_empty(),"key 3 equips an unarmed grenade")
	game.prime_grenade(actor)
	check(not actor.grenade_held_id.is_empty(),"grenade preparation starts the shared authoritative fuse")
	var id:=actor.grenade_held_id
	actor.equip_quick_slot(2);check(actor.grenade_selected,"armed grenade prevents an invalid weapon switch")
	var grenades: GameGrenades=game.grenades_system;grenades.set_physics_process(false)
	grenades._physics_process(1)
	var packet: Dictionary=grenades.snapshots()[0]
	check(packet.has("server_stamp") and packet.has("deadline") and absf(float(packet.deadline)-float(packet.server_stamp)-float(packet.fuse))<.01,"network snapshot includes the server fuse deadline")
	game.infantry_hud.refresh();check(game.infantry_hud.fuse_bar.visible and is_equal_approx(game.infantry_hud.fuse_bar.value,4),"held timer bar reads the actual fuse")
	await shot("grenade-fuse")
	check_hud_bounds(game,"armed grenade")
	game.request_grenade(actor)
	var round: Dictionary=grenades.rounds[id]
	round.position=Vector3(0,1,-4);round.velocity=Vector3.ZERO;round.node.global_position=round.position
	game.third_person=false;actor._update_view();actor.camera_pivot.rotation=Vector3.ZERO
	await physics_frame;await physics_frame
	game.grenade_timers.refresh()
	check(game.grenade_timers.widgets[0].node.visible and game.grenade_timers.widgets[0].text.text=="4,0 s","visible nearby thrown grenade displays its authoritative seconds and tenths")
	game._static_box(game.world_root,"OcclusionWall",Vector3(0,1.5,-2),Vector3(4,3,.3),Color.GRAY)
	await physics_frame;await physics_frame;game.grenade_timers.refresh()
	check(not game.grenade_timers.widgets[0].node.visible,"timer cannot reveal a grenade behind a wall")
	round.position=Vector3(0,1,-40);round.node.global_position=round.position;game.grenade_timers.refresh()
	check(not game.grenade_timers.widgets[0].node.visible,"distant grenade does not produce a timer")
	grenades.present_explosion(id,round.position);game.grenade_timers.refresh()
	check(not game.grenade_timers.widgets[0].node.visible and not grenades.rounds.has(id),"explosion removes the timer immediately")
	game.show_menu();game.queue_free();await process_frame;await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures}
	NavalStorage.write_json("res://tests/equipment-hud-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
