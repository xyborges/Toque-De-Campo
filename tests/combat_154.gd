extends SceneTree
var game: Node3D
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1;print(("PASS " if value else "FAIL ")+message)
	if not value: failures.append(message)
func press_g() -> void:
	game.local_player.equip_grenade()
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;game.local_player._unhandled_input(event)
func release_g() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;game.local_player._unhandled_input(event)
func tick(seconds: float) -> void:
	for index in int(seconds*60): game.grenades_system._physics_process(1.0/60)
func run() -> void:
	game=load("res://tests/combat_154_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="desert";game._enter_match_world();game.set_physics_process(false)
	var player: GamePlayer=game._spawn_player(1,true,false,Vector3(0,0,8));player.set_physics_process(false)
	var enemy: GamePlayer=game._spawn_player(2,false,false,Vector3(4,0,0));enemy.set_physics_process(false)
	var system: GameGrenades=game.grenades_system;system.set_physics_process(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=false
	await physics_frame;await physics_frame
	for ads in [false,true]:
		enemy.iron_sights=ads;enemy._update_view()
		for part in enemy.avatar_parts.values(): check(part.visible,"remote body remains visible in local FPP / remote ADS="+str(ads))
	game.remote_damage(2,{"hp":0,"limbs":CombatRules.fresh_limbs(),"region":"head","killer":1,"kills":1,"dead":true,"life":enemy.life_id,"direction":Vector3.FORWARD,"weapon":"fal","detached":"","death_sound":0})
	game.remote_player_respawn(2,Vector3(4,0,0),2)
	check(enemy.body_root.visible and enemy.avatar_parts.head.visible and enemy.avatar_parts.arm_l.visible,"remote respawn restores complete body in FPP")
	check(is_equal_approx(GameDayNight.PERIOD,840),"one day lasts exactly fourteen minutes")
	check(is_equal_approx(GameDayNight.sample(0).hour,GameDayNight.sample(840).hour),"cycle repeats after 840 seconds")
	check(GameDayNight.sample(0).daylight>.9 and GameDayNight.sample(240).daylight<.05,"day and night occur twelve game hours apart")
	check(is_instance_valid(game.day_night.clouds),"infantry map has a cloud layer")
	game.day_night.apply_time(240,true)
	check(game.day_night.sun.light_energy<.01 and game.day_night.moon.light_energy>0,"night dims sun and enables moon")
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/update-154-night.png")
	game.day_night.apply_time(0,true)
	var physical: int=game.projectiles.size()
	for index in 4: game._spawn_projectile(1,Vector3(30,8,0),Vector3.FORWARD,"fal",false,true,"1:1:"+str(index+1))
	check(game.projectiles.size()==physical+4,"every shot still creates a physical projectile")
	var visible_count:=0
	for shot: Dictionary in game.projectiles:
		if not shot.visual.is_empty(): visible_count+=1
	check(visible_count==2,"automatic firearm renders one tracer per two shots")
	check(GameTracerStyle.visible_for("sniper","1:1:1") and GameTracerStyle.visible_for("glock","1:1:1"),"single-shot weapons retain visible projectiles")
	var lights: int=game.world_root.find_children("*","Light3D",true,false).size()
	for index in 60: game._muzzle_flash(Vector3(0,2,-2))
	check(game.world_root.find_children("*","Light3D",true,false).size()==lights,"rapid firing creates no additional dynamic lights")
	check(game.combat_visuals.fx_active.size()<=64,"muzzle/smoke effects have a fixed active limit")
	check(GameTracerStyle.ENERGY<1,"tracers use saturated colors without white emission clipping")
	var number_system: GameDamageNumbers=game.damage_numbers
	for distance in [20.0,200.0]:
		for fov in [70.0,14.0]:
			player.camera.fov=fov
			var point: Vector3=player.camera.global_position-player.camera.global_basis.z*float(distance)
			number_system.show_damage("zoom:"+str(distance)+":"+str(fov),point,42,false,true)
			number_system._process(0)
			var label: Label3D=number_system.active.back().label
			var top:=label.global_position+player.camera.global_basis.y*label.font_size*label.pixel_size*label.scale.y
			var pixels:=player.camera.unproject_position(top).distance_to(player.camera.unproject_position(label.global_position))
			check(absf(pixels-18)<.2,"damage number stays 18 pixels at distance="+str(distance)+" FOV="+str(fov))
			check(label.modulate.r>.8 and label.modulate.g<.3,"damage numbers are red")
	player.camera.fov=76
	player.grenades=2;player.grenade_throw_left=0;player.equip_grenade()
	check(player.grenade_selected and player.grenade_held_id.is_empty() and player.grenades==2,"slot 7 equips an unarmed grenade without starting the fuse")
	player.fire_cooldown=0
	var before_fire: int=game.projectiles.size();player.fire()
	check(game.projectiles.size()==before_fire,"selected grenade cannot fire the retained gun")
	player.set_meta("grenade_at",-100.0)
	press_g()
	var id:=player.grenade_held_id
	check(not id.is_empty() and system.rounds[id].held and player.grenades==1,"pressing left click arms and reserves exactly one grenade")
	check(is_equal_approx(player.grenade_fuse_left,5),"left click starts a five-second fuse immediately")
	player._animate_walk();player._update_grenade_pose();system._process(.1);game.infantry_hud.refresh()
	check(player.grenade_view.visible and player.grenade_view_mesh.visible and not player.view_root.visible and not player.weapon_root.visible,"FPP holds a grenade instead of the firearm")
	check(system.guide.visible and system.guide_mesh.get_surface_count()==1 and system.guide.get_aabb().size.x>.001,"grenade guide is a thick ribbon, not a one-pixel line")
	check(system.guide.material_override.albedo_color==Color("155e6b"),"grenade guide uses darker teal")
	check(system.preview_points.size()<=33,"simple preview stops at first contact with at most 32 segments")
	check(game.infantry_hud.grenade_text.text.replace(",",".").contains("5.0"),"HUD displays the armed fuse in the current locale")
	await create_timer(.15).timeout
	check(not player.weapon_root.visible and not player.view_root.visible,"gun remains hidden across render frames while grenade is armed")
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/update-154-cook.png")
	tick(4.5)
	check(system.rounds.has(id) and absf(float(system.rounds[id].left)-.5)<.02,"cooking spends fuse time before release")
	release_g()
	check(system.rounds.has(id) and not system.rounds[id].held and float(system.rounds[id].left)<.52,"release preserves the remaining fuse")
	check(player.grenade_throw_left>.7 and player.grenades==1,"throw starts animation without spending another grenade")
	player._animate_walk();player._update_grenade_pose()
	check(not player.grenade_view_mesh.visible,"grenade leaves the animated FPP hand on release")
	tick(.6)
	check(system.events.has(id) and not system.rounds.has(id),"cooked grenade explodes once at the original deadline")
	player.grenade_throw_left=0;player.set_meta("grenade_at",-100.0);press_g();id=player.grenade_held_id
	check(player.grenades==0 and not id.is_empty(),"last grenade can be armed")
	release_g()
	check(system.rounds.has(id) and not system.rounds[id].held,"last grenade can be thrown with zero stock remaining")
	system.present_explosion(id,Vector3(60,0,0))
	player.grenade_throw_left=0;player.grenades=2;player.set_meta("grenade_at",-100.0);press_g();id=player.grenade_held_id
	tick(5.1)
	check(player.hp==0 and system.events.has(id),"holding past five seconds explodes lethally in the hand")
	player.respawn();player.set_physics_process(false);player.set_meta("grenade_at",-100.0);press_g();id=player.grenade_held_id
	tick(2)
	player.take_damage(200,"chest",2)
	check(system.rounds.has(id) and not system.rounds[id].held and system.rounds[id].drop,"death drops the same armed grenade")
	check(absf(float(system.rounds[id].left)-3)<.03,"death does not reset the fuse")
	tick(3.1)
	check(system.events.has(id) and not system.rounds.has(id),"dropped grenade explodes on the original timer")
	game.show_menu();game.queue_free();await create_timer(.2).timeout
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/combat-154-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
