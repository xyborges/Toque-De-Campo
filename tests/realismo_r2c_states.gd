extends "res://tests/realismo_r2c_world_pilot.gd"

var scenarios: Array[Dictionary]=[]

class StateGame:
	extends "res://tests/war_optics_fixture.gd"
	# Headless cannot capture an OS pointer. Admit simulated QA controls while
	# keeping the actual shot, ammo, cooldown and damage methods unchanged.
	func gameplay_input_allowed() -> bool:
		return join_ready and is_instance_valid(local_player) and local_player.deployed and local_player.hp>0 and not ui_focus.blocked()

func inspect_regions(actor: WarPlayer,label: String) -> void:
	check(actor.hit_regions.size()==16,label+" keeps all 16 regions")
	var finite:=true
	var active:=0
	for area: Area3D in actor.hit_regions.values():
		var pose:=area.global_transform
		finite=finite and pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite() and absf(pose.basis.determinant())>.001
		if area.collision_layer!=0: active+=1
	check(finite,label+" has finite nondegenerate physical transforms")
	scenarios.append({"state":label,"regions":actor.hit_regions.size(),"active":active,"finite":finite})

func prepare(actor: WarPlayer) -> void:
	configure(actor)
	actor.attack_anim=0.;actor.recoil=0.;actor.reaction=0.
	actor.cancel_reload()
	actor.limbs=CombatRules.fresh_limbs()
	actor._set_hitboxes_enabled(true)
	actor.body_collision.disabled=false
	actor.body_root.show();actor.weapon_root.show()

func run() -> void:
	var game:=StateGame.new() as WarGame
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	actor.set_process(false);actor.set_physics_process(false)
	actor.weapon_id="g3";actor._refresh_weapon()
	for entry in [["normal",0.,0.,0.],["acceleration",1.,0.,0.],["braking",-1.,0.,0.],["strafe-left",0.,-1.,0.],["strafe-right",0.,1.,0.],["sprint",.8,.4,0.],["landing",0.,0.,1.],["combined",1.,-1.,1.],["invalid-signal",NAN,INF,-INF]]:
		prepare(actor)
		actor.locomotion.presentation_longitudinal=entry[1]
		actor.locomotion.presentation_lateral=entry[2]
		actor.locomotion.presentation_landing=entry[3]
		if entry[0]=="sprint":actor.locomotion.sprint=1.
		var off:=snapshot(actor,false)
		var on:=snapshot(actor,true)
		inspect_regions(actor,entry[0])
		check((on.muzzle as Transform3D).is_equal_approx(off.muzzle),str(entry[0])+" preserves true muzzle")
		var restored:=snapshot(actor,false)
		unchanged(off,restored,str(entry[0])+" reversible")
	for posture in [1,2,0]:
		prepare(actor)
		snapshot(actor,true)
		actor.set_posture(posture,false,true)
		for tick in 12:
			actor.stance.advance(actor,1./60.)
			actor._animate_walk()
			inspect_regions(actor,"posture-"+str(posture)+"-tick-"+str(tick))
		if posture!=0:check(not WORLD.eligible(actor,actor.locomotion),"low posture remains gated")
	prepare(actor);snapshot(actor,true)
	actor.iron_sights=true;actor._animate_walk()
	check(not actor.locomotion.world_pelvis_dirty,"ADS transition clears R2C")
	inspect_regions(actor,"ADS")
	prepare(actor);snapshot(actor,true)
	actor.ammo["g3"]=0
	actor.start_reload();actor._animate_walk()
	check(actor.reload_left>0. and not actor.locomotion.world_pelvis_dirty,"real reload starts and clears R2C")
	inspect_regions(actor,"reload")
	actor.complete_reload();actor._animate_walk()
	check(actor.reload_left<=0.,"reload completes through gameplay API")
	prepare(actor);snapshot(actor,true)
	actor.ammo["g3"]=20
	game.ui_focus.close_all()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(game.gameplay_input_allowed(),"fixture admits ordinary local fire input")
	actor.fire()
	actor._animate_walk()
	check(actor.fire_cooldown>0. and not actor.locomotion.world_pelvis_dirty,"real shot cooldown clears R2C")
	inspect_regions(actor,"fire")
	prepare(actor);snapshot(actor,true)
	actor.vehicle_id="r2c-qa-seat"
	actor._physics_process(1./60.)
	check(not actor.locomotion.world_pelvis_dirty,"vehicle physics exit path restores R2C base")
	inspect_regions(actor,"vehicle")
	actor.vehicle_id=""
	actor.restore_infantry_presentation_after_vehicle_exit()
	actor._animate_walk()
	check(actor.weapon_root.visible and actor.body_root.visible,"vehicle exit restores body and weapon")
	prepare(actor);snapshot(actor,true)
	var previous_life:=actor.life_id
	actor.take_damage(10000.,"head",2)
	actor._physics_process(1./60.)
	check(actor.hp<=0. and not actor.locomotion.world_pelvis_dirty,"real death clears active frame")
	for area: Area3D in actor.hit_regions.values():check(area.collision_layer==0,"dead region disabled: "+str(area.name))
	game.spawn_ragdoll(actor.global_position,2,actor)
	await process_frame
	var corpses:=get_nodes_in_group("death_ragdolls")
	check(not corpses.is_empty(),"production ragdoll is constructed from the dead actor")
	actor.respawn()
	check(actor.life_id>previous_life,"respawn changes actor life identity")
	check(not actor.locomotion.world_pose_frame.valid_for(Engine.get_physics_frames(),actor.life_id),"respawn never accepts previous-life frame")
	print("REALISMO_R2C_STATES ",JSON.stringify({"checks":checks,"failures":failures,"scenarios":scenarios,"physics_hz":Engine.physics_ticks_per_second}))
	game.queue_free()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	quit(0 if failures.is_empty() else 1)
