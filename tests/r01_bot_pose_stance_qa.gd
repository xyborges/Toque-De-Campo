extends SceneTree

# 28 WarPlayer remote bots, deterministic geometric parity of all 13
# authoritative hit regions across crouch/prone/stand/aim and weapon swaps.
var errors: Array[String]=[]
var report: Dictionary={}
var checksum:=0.0
var checks:=0

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	var actors: Array[WarPlayer]=[]
	actors.append(game.players[2] as WarPlayer)
	for i in 27:
		actors.append(game.make_actor(3+i,false,i%2,"soldier",Vector3(float(i%7)*5,0,-15-float(i/7)*6)))
	for actor in actors:
		actor.set_meta("war_bot",true)
		actor.set_process(false);actor.set_physics_process(false)
		actor.hp=100;actor.deployed=true;actor.velocity=Vector3.ZERO
		actor.locomotion.speed=0.
		actor.locomotion.moving=0.
		actor.owned=["fal","ak","glock","g3"]
		actor.loadout=actor.owned.duplicate()
	await process_frame
	for weapon in ["fal","ak","glock","g3"]:
		for pose in [0,1,2,1,0]:
			for actor in actors:
				actor.weapon_id=weapon
				actor._refresh_weapon();actor._update_view()
				actor.set_posture(pose,false,true)
				actor.stance.advance(actor,1.)
			for pitch in [-.3,.1,.56]:
				for index in actors.size():
					var actor:=actors[index]
					actor.pitch=pitch
					actor.lean=0. if index%2==0 else .3
					actor.next_pose_usec=0
					actor._animate_walk()
					for key in ["head","chest","abdomen","armL","armR","forearmL","forearmR","handL","handR","legL","legR","shinL","shinR"]:
						var area: Area3D=actor.hit_regions.get(key)
						if not is_instance_valid(area) or not area.global_transform.is_finite():
							errors.append("invalid physical region "+key)
							continue
						var local: Transform3D=actor.global_transform.affine_inverse()*area.global_transform
						checksum+=local.origin.x*.13+local.origin.y*.23+local.origin.z*.31
						for column in 3:
							checksum+=(local.basis[column].x*.17+local.basis[column].y*.19+local.basis[column].z*.29)*.001
						checks+=1
					for side in ["L","R"]:
						var arm: Node3D=actor.avatar_parts["arm_"+side.to_lower()]
						var error: float=float(arm.get_meta("grip_error",0.))
						if not is_finite(error) or error>.005: errors.append("grip "+side)
						checks+=1
	var result={"mode":"on" if GamePlayer.r01_bot_pose_dirty_guard else "off",
		"actors":actors.size(),"combinations":4*5*3,"checks":checks,"checksum":checksum,
		"errors":errors,"scope":"13 authoritative hit regions and 2 hands, 28 bots, weapon FAL AK Glock G3, stand crouch prone, pitch/lean; deterministic static geometry"}
	print("R01_BOT_STANCE_QA ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
