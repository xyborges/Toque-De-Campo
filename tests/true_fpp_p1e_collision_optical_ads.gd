extends SceneTree
## P1e: optical ADS pose parity. This validates physical transforms only:
## body hit regions, arms/hands and muzzle while the optic raises/lowers.
## It does NOT claim that the PiP SubViewport itself renders correctly.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")

const WEAPONS:=["g3","ak","fal","sniper"]
const OPTICS:=["hensoldt4x","precision8x"]
const WEIGHTS: Array[float]=[0.,.22,.50,.78,1.]

func _initialize() -> void:
	run.call_deferred()

func configure(actor: WarPlayer,weapon: String,optic: String) -> bool:
	actor.clear_aim()
	actor.cancel_reload()
	actor.weapon_id=weapon
	actor.owned=["g3","ak","fal","glock","sniper"]
	actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{weapon:optic})
	actor.set_meta("weapon_attachments",{weapon:GameAttachmentState.from_legacy(weapon,optic)})
	actor._refresh_weapon()
	actor.weapon_optics.aim_weight=0.
	actor.aiming=false
	actor.iron_sights=false
	actor.recoil=0.
	actor.fire_cooldown=0.
	actor.attack_anim=0.
	actor.velocity=Vector3.ZERO
	actor.locomotion.reset(actor)
	actor.stance.reset(actor)
	actor.pitch=.18
	actor.lean=.22
	actor.next_pose_usec=0
	actor._animate_walk()
	return actor.weapon_optics.enabled(actor) and actor.weapon_optics.selected_optic==optic and not actor.weapon_optics.optical.is_empty()

func run() -> void:
	var game:=Fixture.new()
	root.add_child(game)
	await process_frame
	var actor:=game.players[2] as WarPlayer
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.deployed=true
	actor.hp=100.
	var checks:=0
	var rejected:=0
	var failures: Array[String]=[]
	var rows: Array[Dictionary]=[]
	for weapon: String in WEAPONS:
		for optic: String in OPTICS:
			if not configure(actor,weapon,optic):
				failures.append(weapon+"/"+optic+" could not mount")
				continue
			var bind: Dictionary=Solver.bind(actor)
			var max_position:=0.
			var max_basis:=0.
			var max_muzzle:=0.
			var pair_checks:=0
			for posture in [0,1,2]:
				actor.locomotion.moving=0.
				actor.locomotion.sprint=0.
				if not actor.set_posture(posture,false,true):
					failures.append(weapon+"/"+optic+" posture rejected "+str(posture))
					continue
				actor.stance.advance(actor,1.)
				# Em jogo, GameInfantryPose.advance() atualiza o olho lateral
				# a cada physics tick a partir do lean. O fixture dirige o
				# estado diretamente e precisa reproduzir esse passo.
				actor.camera_pivot.position.x=actor.lean*GameInfantryPose.LEAN_DISTANCE
				actor.camera_pivot.rotation.z=-actor.lean*GameInfantryPose.LEAN_ROLL
				actor.locomotion.moving=.58
				actor.locomotion.sprint=0.
				actor.locomotion.grounded=true
				actor.locomotion.local_direction=Vector3(0,0,-1)
				actor.locomotion.phase=1.37
				for weight: float in WEIGHTS:
					actor.aiming=weight>0.
					actor.iron_sights=weight>0.
					actor.weapon_optics.aim_weight=weight
					actor.next_pose_usec=0
					actor._animate_walk()
					var actual: Dictionary=Snapshot.capture(actor)
					var state: Dictionary=Solver.state(actor)
					var solved: Dictionary=Solver.solve(bind,state)
					if not bool(solved.get("supported",false)):
						failures.append(weapon+"/"+optic+" posture="+str(posture)+" weight="+str(weight)+" unsupported: "+str(solved.get("reason","")))
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
						failures.append(weapon+"/"+optic+" posture="+str(posture)+" weight="+str(weight)+" region="+top_region+" pos="+str(diff.max_origin_m)+" basis="+str(diff.max_basis_delta)+" muzzle="+str(diff.muzzle_origin_m))
					checks+=1
					pair_checks+=1
			var mismatch: Dictionary=Solver.state(actor)
			mismatch.optic_id="precision8x" if optic!="precision8x" else "hensoldt4x"
			if not bool(Solver.solve(bind,mismatch).get("supported",true)):rejected+=1
			var invalid_weight: Dictionary=Solver.state(actor)
			invalid_weight.optic_weight=1.25
			if not bool(Solver.solve(bind,invalid_weight).get("supported",true)):rejected+=1
			rows.append({"weapon":weapon,"optic":optic,"checks":pair_checks,"position_m":max_position,"basis_delta":max_basis,"muzzle_m":max_muzzle})
	var passed: bool=failures.is_empty() and checks==120 and rejected==16
	print("P1E_OPTICAL_ADS ",JSON.stringify({"pass":passed,"checks":checks,"invalid_rejected":rejected,"rows":rows,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
