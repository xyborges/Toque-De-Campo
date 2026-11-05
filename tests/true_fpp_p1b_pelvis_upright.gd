extends SceneTree
## A prone-to-standing transition must not leave the pelvis/abdomen hit region
## rotated 90 degrees. This regression exercises the EXISTING WarPlayer rig.
const Fixture=preload("res://tests/war_optics_fixture.gd")

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
	actor.weapon_id="g3"
	actor.owned=["g3","glock"]
	actor.loadout=actor.owned.duplicate()
	actor._refresh_weapon()
	actor.velocity=Vector3.ZERO
	actor.locomotion.reset(actor)
	actor.pitch=.17
	actor.lean=.19
	actor.stance.crouch_weight=0.
	actor.stance.prone_weight=0.
	actor.set_posture(0,false,true)
	actor.next_pose_usec=0
	actor._animate_walk()
	var pelvis:=actor.body_root.get_node("Pelvis") as Node3D
	var area:=actor.hit_regions["abdomenPelvis"] as Area3D
	var neutral_basis: Basis=area.global_basis
	var checks: Array[Dictionary]=[]
	var passed:=true
	for route in [[2,0],[2,1,0]]:
		var prone_rotated:=false
		var standing_restored:=false
		var basis_delta:=0.
		for posture: int in route:
			var applied: bool=actor.set_posture(posture,false,true)
			actor.stance.advance(actor,1.)
			actor.next_pose_usec=0
			actor._animate_walk()
			if posture==2:
				prone_rotated=applied and actor.prone and absf(pelvis.rotation.x+PI*.5)<.001
			if posture==0:
				basis_delta=0.
				for i in 3:
					basis_delta=maxf(basis_delta,neutral_basis[i].distance_to(area.global_basis[i]))
				standing_restored=applied and not actor.prone and not actor.crouched and absf(pelvis.rotation.x)<.001 and basis_delta<.001
		var ok: bool=prone_rotated and standing_restored
		passed=passed and ok
		checks.append({"sequence":route,"prone_rotated":prone_rotated,"standing_restored":standing_restored,"basis_delta":basis_delta,"pass":ok})
	print("P1B_PELVIS_UPRIGHT ",JSON.stringify({"pass":passed,"cases":checks}))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
