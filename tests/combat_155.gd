extends SceneTree
var failures: Array[String]=[]
var checks:=0
var game: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func key(actor: GamePlayer,code: Key,pressed:=true) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=pressed;actor._unhandled_input(event)
func click(actor: GamePlayer,pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;actor._unhandled_input(event)
func tick(system: GameGrenades,seconds: float) -> void:
	for i in int(seconds*60): system._physics_process(1.0/60)
func run() -> void:
	game=load("res://tests/combat_155_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game);game.start_offline("desert")
	game.set_physics_process(false)
	var actor: GamePlayer=game.local_player;actor.set_physics_process(false)
	var other: GamePlayer=game._spawn_player(2,false,false,DesertMap.spawn_pad(1));other.set_physics_process(false)
	var grenades: GameGrenades=game.grenades_system;grenades.set_physics_process(false)
	var objective: DesertDomination=game.domination;objective.set_physics_process(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await physics_frame;await physics_frame
	for entry in [["glock",150.],["fal",260.],["sniper",160.]]:
		var weapon:=CombatRules.weapon(entry[0]);check(is_equal_approx(float(weapon.speed),float(entry[1])*1.05),str(entry[0])+" launch speed increases exactly five percent")
		var initial:=Vector3.FORWARD*float(weapon.speed)
		var result:=GameBulletPhysics.advance(Vector3.ZERO,initial,float(weapon.gravity),float(weapon.drag),1)
		check(Vector2(result.velocity.x,result.velocity.z).length()<initial.length(),str(entry[0])+" horizontal speed decreases with drag")
		check(result.position.y<0 and result.velocity.y<0,str(entry[0])+" gravity curves the launch downward without upward impulse")
		var point:=Vector3.ZERO;var velocity:=initial
		for i in 120:
			var step:=GameBulletPhysics.advance(point,velocity,float(weapon.gravity),float(weapon.drag),1.0/120);point=step.position;velocity=step.velocity
		check(point.distance_to(result.position)<.002 and velocity.distance_to(result.velocity)<.002,str(entry[0])+" physics is independent of integration frame size")
	var pads_clear:=true
	for i in DesertMap.SPAWN_PADS.size():
		var pad:=DesertMap.spawn_pad(i);pads_clear=pads_clear and game._spawn_capsule_clear(pad) and pad.y>DesertTerrain.height_at(pad.x,pad.z)+.1
	check(pads_clear,"all spawn capsule footprints clear the real dune terrain")
	actor.position=DesertTerrain.point(80,-52)-Vector3.UP*2;actor.velocity=Vector3.DOWN*8
	check(game.recover_terrain_position(actor) and actor.position.y>DesertTerrain.height_at(actor.position.x,actor.position.z) and actor.velocity==Vector3.ZERO,"buried character is recovered above the real terrain")
	actor.position=Vector3(0,.16,10);actor.yaw=0;actor.rotation=Vector3.ZERO;actor.pitch=0
	key(actor,KEY_G);key(actor,KEY_G,false)
	check(actor.grenade_selected and actor.grenade_held_id.is_empty() and actor.grenades==2,"G equips an unarmed grenade and releasing G does not throw")
	grenades._physics_process(6)
	check(actor.grenades==2 and grenades.rounds.is_empty(),"equipped grenade can remain in the hand without a fuse")
	game.third_person=true
	for heading in [0.,PI/2,PI,-PI/2]:
		for pitch in [-1.,0.,1.]:
			actor.yaw=heading;actor.rotation.y=heading;actor.pitch=pitch;actor.camera_pivot.rotation.x=pitch
			actor._animate_walk();actor._update_view();actor._update_grenade_pose()
			var grip: Vector3=actor.grenade_hand_position()
			if pitch==0: check((-actor.global_basis.z).dot(grip-actor.camera_pivot.global_position)>.35,"TPP grenade is ahead of the torso at heading="+str(heading))
			check(actor.grenade_prop.global_position.distance_to(grip)<.001,"TPP prop tracks the actual hand at heading/pitch="+str(heading)+"/"+str(pitch))
			game.third_person=false;actor._update_view();actor._update_grenade_pose()
			check(actor.grenade_view.global_position.distance_to(grip)<.001,"FPP grenade shares TPP world grip")
			game.third_person=true
	actor.yaw=0;actor.rotation.y=0;actor.pitch=0;actor.camera_pivot.rotation=Vector3.ZERO;actor._animate_walk();actor._update_view();actor._update_grenade_pose()
	var probe:=Camera3D.new();game.world_root.add_child(probe);probe.position=actor.position+Vector3(2.5,1.8,1.6);probe.look_at(actor.position+Vector3.UP*1.25);probe.current=true
	await create_timer(.15).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/update-155-grenade-tpp.png")
	actor.camera.current=true;probe.queue_free();game.third_person=false;actor._update_view();actor._update_grenade_pose()
	var launch:=grenades.launch_state(actor,Vector3.FORWARD)
	var before:=launch.duplicate();before.velocity=Vector3.FORWARD*18
	var old_guide:=grenades.guide_prediction(before,5)
	var new_guide:=grenades.guide_prediction(launch,5)
	check(Vector3(new_guide.position).distance_to(launch.origin)>Vector3(old_guide.position).distance_to(before.origin),"grenade physical throw and simple guide reach further")
	click(actor,true)
	var id:=actor.grenade_held_id
	check(not id.is_empty() and is_equal_approx(actor.grenade_fuse_left,5) and actor.grenades==1,"left click starts a five-second server fuse")
	actor.fire_cooldown=0;var shots: int=game.projectiles.size();actor.fire();actor.start_reload()
	check(game.projectiles.size()==shots and actor.reload_left==0,"armed grenade blocks gun fire and reload")
	tick(grenades,1.5);click(actor,false)
	check(grenades.rounds.has(id) and not grenades.rounds[id].held and absf(float(grenades.rounds[id].left)-3.5)<.02,"release throws with the remaining cooked fuse")
	tick(grenades,3.6);check(grenades.events.has(id),"cooked grenade detonates at five seconds total")
	actor.grenade_throw_left=0;actor.grenades=1;actor.set_meta("grenade_at",-100.);key(actor,KEY_G);click(actor,true);id=actor.grenade_held_id;tick(grenades,5.1)
	check(actor.hp==0 and grenades.events.has(id),"five seconds held explodes in hand")
	actor.respawn();actor.set_physics_process(false);actor.position=Vector3(-3.35,.16,-5.3)
	for weapon in actor.ammo: actor.ammo[weapon]=0;actor.reserves[weapon]=0
	actor.grenades=0
	var response:=objective.replenish(actor,actor.life_id)
	check(response.contains("COMPLETA") and actor.ammo.fal==30 and actor.ammo.glock==12 and actor.ammo.sniper==5 and actor.reserves.fal==180 and actor.grenades==2,"physical supply crate restores all magazines, reserves and grenades")
	check(objective.replenish(actor,actor.life_id).contains("20"),"supply cooldown is authoritative and per player")
	objective.supplies.clear();actor.position=Vector3(-1.75,.16,-8.8)
	check(objective.replenish(actor,actor.life_id).contains("obstáculo"),"partition blocks supply interaction through a wall")
	actor.position=Vector3(0,.16,30)
	check(not objective.replenish(actor,actor.life_id).contains("COMPLETA"),"remote supply request cannot refill from outside the house")
	game.mode="pvp";game.online=true;actor.position=Vector3(0,.16,-7);other.position=Vector3(20,.16,20)
	objective.step(6);check(objective.owner_id==actor.peer_id,"six seconds alone captures the house")
	objective.step(2);check(int(objective.scores[actor.peer_id])==2,"only the sole owner inside receives one point per second")
	other.position=Vector3(0,.16,-5);objective.step(3)
	check(objective.contested and int(objective.scores[actor.peer_id])==2,"two opponents inside contest and stop scoring")
	actor.position=Vector3(0,.16,20);objective.step(6);objective.step(2)
	check(objective.owner_id==2 and int(objective.scores[2])==2,"another player can capture and score individually")
	check(not DesertDomination.inside(Vector3(0,3.8,-7)) and not DesertDomination.inside(Vector3(0,-1,-7)),"roof and buried positions never capture the interior")
	other.hp=0;objective.step(2);check(int(objective.scores[2])==2,"dead occupants cannot score")
	other.hp=100;other.position=Vector3(20,.16,20);actor.position=Vector3(0,.16,-7);objective.owner_id=actor.peer_id;objective.scores[actor.peer_id]=119;objective.step(1)
	check(objective.phase=="finished" and objective.winner_id==actor.peer_id,"120 control points wins the round")
	check(not game.gameplay_input_allowed(),"round result blocks combat during the short intermission")
	game.infantry_hud.refresh();game.update_hud();actor._update_view()
	await create_timer(.15).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/update-155-domination.png")
	objective.step(12.1);check(objective.scores.is_empty() and objective.remaining==600 and actor.hp==100,"next round resets scores, lives and timer")
	game.players.erase(2);other.queue_free();objective.step(2)
	check(objective.phase=="waiting" and objective.remaining==600,"domination pauses when fewer than two participants remain")
	game.show_menu();game.queue_free();await create_timer(.2).timeout
	var result: Dictionary={"checks":checks,"failures":failures};NavalStorage.write_json("res://tests/combat-155-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
