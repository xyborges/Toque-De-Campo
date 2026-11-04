extends SceneTree
var game: Node3D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func actor(id: int,pos: Vector3,local:=false) -> GamePlayer:
	var result: GamePlayer=game._spawn_player(id,local,false,pos)
	result.set_physics_process(false)
	return result
func run() -> void:
	game=load("res://tests/combat_153_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="desert";game._enter_match_world();game.set_physics_process(false)
	var player:=actor(1,Vector3(0,0,8),true)
	var target:=actor(2,Vector3(0,0,-3))
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await physics_frame;await physics_frame
	var sniper:=CombatRules.weapon("sniper")
	check(sniper.speed>105.8,"sniper projectile speed increases")
	for distance in [50.0,100.0,150.0]:
		var drop: float=.5*float(sniper.gravity)*pow(distance/float(sniper.speed),2)
		var old: float=.5*8.3385*pow(distance/105.8,2)
		check(drop<old,"sniper accumulated drop reduced at "+str(distance)+" m")
		for other in ["fal","glock"]:
			var item:=CombatRules.weapon(other)
			check(float(sniper.gravity)>float(item.gravity),"long-range sniper retains stronger gravity than "+other+" while the new speed reduces its required elevation")
	var colors: Dictionary={}
	for id in GameTracerStyle.COLORS: colors[GameTracerStyle.color_for(id).to_html()]=true
	check(colors.size()==GameTracerStyle.COLORS.size(),"all firearm and naval weapons have distinct tracer colors")
	var eye:=player.camera_pivot.global_position
	check(game.combat_feedback.near_miss(eye+Vector3(5,0,-6),eye+Vector3(5,0,6),player,2),"near miss audible five meters from listener")
	check(not game.combat_feedback.near_miss(eye+Vector3(7,0,-6),eye+Vector3(7,0,6),player,2),"near miss outside six meters rejected")
	check(not game.combat_feedback.near_miss(eye+Vector3(1,0,-6),eye+Vector3(1,0,6),player,1),"own bullet has no near miss")
	game._confirm_impact(1,{"collider":game.world_root.get_node("Ground"),"position":Vector3(0,-.05,0),"normal":Vector3.UP},{"id":"fal","damage":55},"earth-test",Vector3.DOWN)
	check(game.combat_feedback.impact_at>0,"ground impact uses earth sample")
	game._apply_hit(1,{"collider":target.hit_regions.chest,"position":target.global_position+Vector3.UP},10,"chest","fal")
	check(game.damage_numbers.active.back().amount==10,"floating damage uses actual confirmed health loss")
	await process_frame
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/combat-153-damage-numbers.png")
	game._apply_hit(1,{"collider":target.hit_regions.head,"position":target.global_position+Vector3.UP*1.7},500,"head","sniper")
	check(game.damage_numbers.active.back().amount==90,"fatal hit number is capped to remaining health")
	game.damage_feedback(80);check(game.damage_overlay.color.a>.2,"damage immediately flashes screen")
	await create_timer(.45).timeout
	check(game.damage_overlay.color.a<.01 and game.feedback_hp==80,"screen returns to normal despite low health")
	game.damage_feedback(60);check(game.damage_overlay.color.a>.2,"subsequent hit triggers another flash")
	game.damage_feedback(100);check(game.damage_overlay.color.a==0,"respawn clears screen pulse")
	player.weapon_id="sniper";player._refresh_weapon();player.aiming=true;player.iron_sights=true;player._update_view()
	check(game.scope_overlay.visible,"sniper scope active before death")
	target.hp=100;target._update_view();check(game.scope_overlay.visible,"other avatar view update does not hide local sniper scope")
	player.take_damage(200,"chest",2)
	check(not game.scope_overlay.visible and not player.iron_sights and player.camera.fov!=14,"death closes scope and restores field of view immediately")
	player.respawn();player.set_physics_process(false)
	check(not game.scope_overlay.visible and player.grenades==2,"respawn resets grenade allowance and scope")
	game._configure_loadout(player,["glock","invalid"],false)
	check(player.active_weapons()==["glock"] and player.grenades==0,"loadout filters unknown weapons and can disable grenades")
	player.loadout=[];player.grenades_enabled=true;player.grenades=2
	game.online=true;game.mode="pvp";game.dedicated_pvp=true;game.players.erase(2);target.hide()
	game.infantry_hud.refresh()
	await process_frame
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/combat-153-waiting.png")
	check(game.infantry_hud.waiting.visible and not game.gameplay_input_allowed(),"one-player PvP shows waiting notice and locks combat")
	for weapon in ["fal","sniper"]:
		player.weapon_id=weapon;player._refresh_weapon()
		var sequence:=100 if weapon=="fal" else 200
		player.pending_shots[sequence]=weapon
		game._server_accept_shot(1,sequence,player.life_id,player.camera_pivot.global_position,Vector3.FORWARD,weapon)
		check(int(game.shot_sequences[1])==sequence,"rejected waiting shot acknowledged: "+weapon)
		var mags: Dictionary=player.ammo.duplicate();mags[weapon]=int(GameWeapons.ITEMS[weapon].mag)
		game.remote_inventory(1,mags,player.reserves,int(game.shot_sequences[1]),"",0)
		check(player.pending_shots.is_empty() and int(player.ammo[weapon])==int(GameWeapons.ITEMS[weapon].mag),"waiting rejection restores magazine without stale prediction: "+weapon)
	game.players[2]=target;target.hp=100;target.global_position=Vector3(12,0,8);target.show()
	game.infantry_hud.refresh();check(not game.infantry_hud.waiting.visible,"second player dismisses waiting notice")
	for weapon in ["fal","sniper"]:
		player.weapon_id=weapon;player._refresh_weapon();player.grenade_throw_left=0
		player.ammo[weapon]=0;player.reserves[weapon]=50
		game._server_reload(1,weapon)
		check(player.reload_weapon==weapon,"reload accepted after another participant joins: "+weapon)
		player.complete_reload();game.shot_clocks.clear()
		game._server_accept_shot(1,int(game.shot_sequences[1])+1,player.life_id,player.camera_pivot.global_position,Vector3.FORWARD,weapon)
		check(int(player.ammo[weapon])==int(GameWeapons.ITEMS[weapon].mag)-1,"firing resumes after waiting: "+weapon)
	game.online=false;game.dedicated_pvp=false;game.mode="training"
	player.global_position=Vector3(0,0,12);player.hp=100
	target.global_position=Vector3(3,0,0);target.hp=100
	var exposed:=actor(3,Vector3(-3,0,0))
	var far:=actor(4,Vector3(0,0,-10))
	var wall: Node3D=game._static_box(game.world_root,"BlastCover",Vector3(1.5,1.5,0),Vector3(.2,3,4),Color.GRAY).get_parent()
	await physics_frame;await physics_frame
	game.grenades_system._damage({"owner":1,"position":Vector3(0,.12,0)})
	check(target.hp==100,"solid wall completely blocks blast damage")
	check(exposed.hp<100 and exposed.hp>0,"exposed enemy receives distance-scaled blast damage")
	check(far.hp==100,"enemy outside blast radius takes no damage")
	var full_damage:=100-exposed.hp
	wall.position.y=.25;(wall.get_child(1).shape as BoxShape3D).size.y=.5
	target.hp=100
	await physics_frame;await physics_frame
	game.grenades_system._damage({"owner":1,"position":Vector3(0,.12,0)})
	check(target.hp<100 and 100-target.hp<full_damage,"partial cover reduces blast according to exposed body samples")
	wall.queue_free();await physics_frame;await physics_frame
	var system: GameGrenades=game.grenades_system;system.set_physics_process(false)
	player.grenades=2;player.grenade_throw_left=0;player.velocity=Vector3(4,0,6);player.pitch=.3;player.rotation.y=0;player.yaw=0;player.camera_pivot.rotation.x=.3
	system.prime(player,player.life_id,1)
	var direction: Vector3=-player.camera.global_basis.z.normalized()
	var launch:=system.launch_state(player,direction)
	check(Vector3(launch.velocity).distance_to(direction*GameGrenades.THROW_SPEED+player.velocity*.35)<.001,"grenade guide and throw inherit every movement axis")
	var predicted:=system.predict(launch)
	check(system.accept(player,player.life_id,1,player.camera.global_position,direction),"server accepts legal grenade throw")
	var round: Dictionary=system.rounds.values()[0]
	for i in int(GameGrenades.FUSE*60): system.advance(round,1.0/60)
	check(Vector3(round.position).distance_to(predicted.position)<.001,"guide endpoint matches the actual simulated bouncing grenade")
	check(round.position.y>=-.05,"grenade sweep keeps grenade above physical ground")
	check(not system.accept(player,player.life_id,1,player.camera.global_position,direction),"duplicate grenade command cannot spend or spawn twice")
	check(player.grenades==1,"grenade consumes exactly one finite charge")
	player.set_meta("grenade_at",-100.0);system.prime(player,player.life_id,2)
	player.grenade_selected=true;player.grenade_aiming=true;player.grenade_throw_left=0;system._process(.1)
	await process_frame
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/combat-153-grenade-guide.png")
	check(system.guide.visible and system.marker.visible,"grenade-only trajectory appears while holding G")
	player.grenade_aiming=false;system._process(.1)
	check(not system.guide.visible and not system.marker.visible,"trajectory disappears outside grenade aim")
	game.show_menu();await process_frame
	game.main_menu.show_page("arsenal");await create_timer(.2).timeout
	await process_frame
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/combat-153-loadout.png")
	game.queue_free();await create_timer(.15).timeout
	var report: Dictionary={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/combat-153-results.json",report);print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
