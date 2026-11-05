extends SceneTree
## P1c: soft aim and iron-sight parity without an attached optical module.
## Optical ADS stays gated for the later real-lens/PiP package.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const Snapshot=preload("res://modes/war/scripts/collision_pose_state.gd")
const Solver=preload("res://modes/war/scripts/collision_pose_solver.gd")
const WEAPONS:=["g3","ak","fal","glock","sniper"]
const AIM_MODES: Array[Dictionary]=[
	{"name":"soft","aiming":true,"iron":false},
	{"name":"iron","aiming":true,"iron":true}
]
const PHASES: Array[float]=[.55,1.60,3.20]

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
		actor.pitch=.18
		actor.lean=.22
		actor.recoil=0.
		actor.attack_anim=0.
		actor.reload_left=0.
		actor.reload_weapon=""
		actor.fire_cooldown=0.
		actor.aiming=false
		actor.iron_sights=false
		actor.next_pose_usec=0
		actor._animate_walk()
		var bind: Dictionary=Solver.bind(actor)
		var max_position:=0.
		var max_basis:=0.
		var max_muzzle:=0.
		var weapon_cases:=0
		for posture in [0,1,2]:
			actor.locomotion.moving=0.
			actor.locomotion.sprint=0.
			if not actor.set_posture(posture,false,true):
				failures.append(weapon+" posture rejected "+str(posture))
				continue
			actor.stance.advance(actor,1.)
			for mode: Dictionary in AIM_MODES:
				actor.aiming=bool(mode.aiming)
				actor.iron_sights=bool(mode.iron)
				for phase: float in PHASES:
					# ADS movement is precision movement: grounded, no sprint.
					actor.locomotion.moving=.62
					actor.locomotion.sprint=0.
					actor.locomotion.grounded=true
					actor.locomotion.local_direction=Vector3(0,0,-1)
					actor.locomotion.phase=phase
					actor.next_pose_usec=0
					actor._animate_walk()
					var state: Dictionary=Solver.state(actor)
					var actual: Dictionary=Snapshot.capture(actor)
					var solved: Dictionary=Solver.solve(bind,state)
					if not bool(solved.get("supported",false)):
						failures.append(weapon+" "+str(mode.name)+" posture="+str(posture)+" unsupported: "+str(solved.get("reason","")))
						continue
					var diff: Dictionary=Snapshot.compare(actual,solved)
					max_position=maxf(max_position,float(diff.max_origin_m))
					max_basis=maxf(max_basis,float(diff.max_basis_delta))
					max_muzzle=maxf(max_muzzle,float(diff.muzzle_origin_m))
					if float(diff.max_origin_m)>=.001 or float(diff.max_basis_delta)>=.005 or float(diff.muzzle_origin_m)>=.001:
						failures.append(weapon+" "+str(mode.name)+" posture="+str(posture)+" phase="+str(phase)+" pos="+str(diff.max_origin_m)+" basis="+str(diff.max_basis_delta)+" muzzle="+str(diff.muzzle_origin_m))
					checks+=1
					weapon_cases+=1
		var unsafe: Dictionary=Solver.state(actor)
		unsafe.iron=true
		unsafe.optic_enabled=true
		if not bool(Solver.solve(bind,unsafe).get("supported",true)):rejected+=1
		unsafe=Solver.state(actor)
		unsafe.scoped=true
		if not bool(Solver.solve(bind,unsafe).get("supported",true)):rejected+=1
		rows.append({"weapon":weapon,"cases":weapon_cases,"position_m":max_position,"basis_delta":max_basis,"muzzle_m":max_muzzle})
	var passed: bool=failures.is_empty() and checks==90 and rejected==10
	print("P1C_ADS_IRON ",JSON.stringify({"pass":passed,"checks":checks,"optical_rejected":rejected,"rows":rows,"failures":failures}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
