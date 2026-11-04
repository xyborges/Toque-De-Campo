extends SceneTree
## P1d: reload parity from the authoritative reload timer. The solver may use
## GameReloadPose.state(), but must not read the live weapon/model nodes.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")
const WEAPONS:=["g3","ak","fal","glock","sniper"]
const PROGRESS: Array[float]=[.03,.22,.48,.72,.88]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.players[2] as WarPlayer
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.deployed=true
	actor.hp=100.
	actor.owned=WEAPONS.duplicate()
	actor.loadout=actor.owned.duplicate()
	var checks:=0
	var rejected:=0
	var failures: Array[String]=[]
	var rows: Array[Dictionary]=[]
	for weapon: String in WEAPONS:
		actor.weapon_id=weapon
		actor.set_meta("weapon_optics",{})
		actor.set_meta("weapon_attachments",{weapon:{}})
		actor._refresh_weapon()
		actor.velocity=Vector3.ZERO
		actor.locomotion.reset(actor)
		actor.stance.reset(actor)
		actor.pitch=.16
		actor.lean=.18
		actor.recoil=0.
		actor.attack_anim=0.
		actor.fire_cooldown=0.
		actor.reload_left=0.
		actor.reload_total=0.
		actor.reload_weapon=""
		actor.aiming=false
		actor.iron_sights=false
		actor.next_pose_usec=0
		actor._animate_walk()
		var bind: Dictionary=Solver.bind(actor)
		var max_position:=0.
		var max_basis:=0.
		var max_muzzle:=0.
		var weapon_checks:=0
		for posture in [0,1,2]:
			actor.locomotion.moving=0.
			actor.locomotion.sprint=0.
			if not actor.set_posture(posture,false,true):
				failures.append(weapon+" posture rejected "+str(posture))
				continue
			actor.stance.advance(actor,1.)
			for move_weight in [0.,.55]:
				for progress: float in PROGRESS:
					actor.reload_total=2.6
					actor.reload_left=actor.reload_total*(1.-progress)
					actor.reload_weapon=weapon
					actor.locomotion.moving=move_weight
					actor.locomotion.sprint=0.
					actor.locomotion.grounded=move_weight>0.
					actor.locomotion.local_direction=Vector3(0,0,-1) if move_weight>0. else Vector3.ZERO
					actor.locomotion.phase=.7+progress*2.
					actor.next_pose_usec=0
					actor._animate_walk()
					var actual: Dictionary=Snapshot.capture(actor)
					var state: Dictionary=Solver.state(actor)
					var solved: Dictionary=Solver.solve(bind,state)
					if not bool(solved.get("supported",false)):
						failures.append(weapon+" posture="+str(posture)+" move="+str(move_weight)+" progress="+str(progress)+" unsupported: "+str(solved.get("reason","")))
						continue
					var diff: Dictionary=Snapshot.compare(actual,solved)
					max_position=maxf(max_position,float(diff.max_origin_m))
					max_basis=maxf(max_basis,float(diff.max_basis_delta))
					max_muzzle=maxf(max_muzzle,float(diff.muzzle_origin_m))
					if float(diff.max_origin_m)>=.001 or float(diff.max_basis_delta)>=.005 or float(diff.muzzle_origin_m)>=.001:
						var top_region:=""
						var top_error:=0.
						for region: String in diff.per_region:
							if float(diff.per_region[region].origin_m)>top_error:
								top_error=float(diff.per_region[region].origin_m)
								top_region=region
						failures.append(weapon+" posture="+str(posture)+" move="+str(move_weight)+" progress="+str(progress)+" region="+top_region+" pos="+str(diff.max_origin_m)+" basis="+str(diff.max_basis_delta)+" muzzle="+str(diff.muzzle_origin_m))
					checks+=1
					weapon_checks+=1
		var mismatch: Dictionary=Solver.state(actor)
		mismatch.reload_weapon="ak" if weapon!="ak" else "g3"
		if not bool(Solver.solve(bind,mismatch).get("supported",true)):rejected+=1
		var invalid_total: Dictionary=Solver.state(actor)
		invalid_total.reload_total=0.
		if not bool(Solver.solve(bind,invalid_total).get("supported",true)):rejected+=1
		rows.append({"weapon":weapon,"checks":weapon_checks,"position_m":max_position,"basis_delta":max_basis,"muzzle_m":max_muzzle})
		actor.reload_left=0.
		actor.reload_total=0.
		actor.reload_weapon=""
	var passed: bool=failures.is_empty() and checks==150 and rejected==10
	print("P1D_RELOAD ",JSON.stringify({"pass":passed,"checks":checks,"invalid_rejected":rejected,"rows":rows,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
