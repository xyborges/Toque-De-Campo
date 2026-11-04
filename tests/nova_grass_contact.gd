extends SceneTree

# Real rig regression, independent of grass appearance. No production physics
# is disabled or altered to make the soles meet the terrain.
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
const GRASS=preload("res://modes/war/library/grama_baixa_2m.tscn")
const STREAM=preload("res://modes/war/scripts/grass_stream.gd")
const SCALES:=[1.0,.85,.65,1.5]
var game: WarGame
var actor: WarPlayer
var checks:=0
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
var baseline: Dictionary={}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("FAIL ",label)

func sole_bounds(subject: WarPlayer) -> Dictionary:
	# Measure the real boot and nested sole geometry, not a guessed limb
	# length or its hitbox. Corners are transformed into the actor's frame.
	var result: Dictionary={}
	for side in ["L","R"]:
		var boot:=subject.avatar_parts["leg_"+side.to_lower()].find_child("Shoe"+side,true,false) as MeshInstance3D
		var low:=INF;var high:=-INF;var meshes: Array[MeshInstance3D]=[]
		if is_instance_valid(boot):
			meshes.append(boot)
			for mesh: MeshInstance3D in boot.find_children("*","MeshInstance3D",true,false): meshes.append(mesh)
		for mesh in meshes:
			if mesh.mesh==null: continue
			var bounds:=mesh.get_aabb()
			var pose:=subject.global_transform.affine_inverse()*mesh.global_transform
			for corner in 8:
				var point:=pose*bounds.get_endpoint(corner)
				low=minf(low,point.y);high=maxf(high,point.y)
		result[side]={"min_y":low,"max_y":high,"mesh_count":meshes.size()}
	return result

func collision_state() -> Dictionary:
	var capsule:=actor.body_collision.shape as CapsuleShape3D
	return {"shape":actor.body_collision.shape,"pose":actor.body_collision.transform,"disabled":actor.body_collision.disabled,"height":capsule.height,"radius":capsule.radius,"actor":actor.global_transform}

func same_collision(before: Dictionary,label: String,resource_identity:=true) -> void:
	var after:=collision_state()
	check(after.actor==before.actor,label+": appearance does not move authoritative actor")
	check(after.pose==before.pose and after.height==before.height and after.radius==before.radius and after.disabled==before.disabled,label+": collision geometry remains unchanged")
	if resource_identity: check(after.shape==before.shape,label+": appearance does not replace collision shape")

func appearance(scale: float,label: String) -> void:
	var before:=collision_state()
	actor.apply_body_proportions({"head":.9,"torso":.9,"arms":.95,"legs":scale})
	same_collision(before,label)

func pose(posture: int) -> void:
	# Use the actual posture and presentation path without moving the actor.
	actor.set_posture(posture,false,true)
	actor.velocity=Vector3.ZERO;actor.pitch=0.;actor.lean=0.;actor.network_lean=0.
	actor.locomotion.moving=0.;actor.locomotion.sprint=0.;actor.locomotion.phase=0.
	actor.next_pose_usec=0
	for tick in 120:
		actor.stance.advance(actor,1./60.)
		actor._animate_walk()

func inspect_rig(scale: float,posture: int,label: String) -> void:
	var feet:=sole_bounds(actor)
	var head_y:=actor.to_local(actor.avatar_parts.head.global_position).y
	var camera_gap:=actor.camera_pivot.position.y-head_y
	var record:={"label":label,"legs":scale,"posture":posture,"feet":feet,"body_y":actor.body_root.position.y,"head_y":head_y,"camera_y":actor.camera_pivot.position.y,"camera_head_gap":camera_gap,"actor_y":actor.global_position.y}
	measurements.append(record)
	# Print diagnostics before assertions: the old broken rig is expected to
	# fail here at .85/.65, revealing hover independently of any grass mesh.
	print("CONTACT_DIAGNOSTIC ",JSON.stringify(record))
	for side in ["L","R"]:
		var floor_y:=float(feet[side].min_y)
		check(is_finite(floor_y) and int(feet[side].mesh_count)>=2,label+": real boot and sole measured "+side)
		if posture==0:
			check(absf(floor_y-float(baseline.feet[side].min_y))<=.03,label+": standing sole remains on original foot plane "+side)
		elif posture==1:
			check(floor_y>-.15 and floor_y<.14,label+": crouched sole stays near ground "+side)
		else:
			check(floor_y>-.15 and floor_y<.45,label+": prone boot remains near ground "+side)
	check(actor.body_root.transform.is_finite() and actor.camera_pivot.transform.is_finite(),label+": finite presentation transforms")
	if posture==0: check(absf(camera_gap-float(baseline.camera_head_gap))<=.03,label+": camera follows the same visual head height")

func no_grass_contact(root_node: Node,label: String) -> void:
	var nodes: Array[Node]=[root_node]
	nodes.append_array(root_node.find_children("*","Node",true,false))
	for node in nodes:
		check(not node is CollisionObject3D and not node is CollisionShape3D and not node is CollisionPolygon3D,label+": no contact object "+str(node.name))

func walking_contact(scale: float) -> void:
	pose(0)
	var before:=collision_state()
	actor.locomotion.initialized=true;actor.locomotion.moving=1.;actor.locomotion.grounded=true
	actor.locomotion.local_direction=Vector3.FORWARD;actor.locomotion.phase=PI*.5
	actor.velocity=Vector3(0,0,-3.)
	# A fixed supported stride must leave at least one sole planted. Test
	# repeated evaluation too: a presentation offset must not accumulate.
	var previous_floor:=INF
	for repeat in 3:
		actor._animate_walk()
		var feet:=sole_bounds(actor)
		var floor_y:=minf(float(feet.L.min_y),float(feet.R.min_y))
		var reference:=minf(float(baseline.feet.L.min_y),float(baseline.feet.R.min_y))
		measurements.append({"label":"walking "+str(scale),"repeat":repeat,"feet":feet,"lowest_sole_y":floor_y,"body_y":actor.body_root.position.y})
		print("CONTACT_WALK ",JSON.stringify(measurements.back()))
		check(is_finite(floor_y) and absf(floor_y-reference)<=.03,"walking "+str(scale)+": one sole remains planted")
		var model:=actor.weapon_root.get_node_or_null("Imported_fal")
		if is_instance_valid(model):
			for side in ["L","R"]:
				var hand: Node3D=actor.avatar_parts["arm_"+side.to_lower()].get_node("Hand"+side)
				var target: Node3D=model.get_node("SupportGrip" if side=="L" else "GripRight")
				check(hand.global_position.distance_to(target.global_position)<.002,"walking grounding preserves hand contact "+side)
		if is_finite(previous_floor): check(absf(floor_y-previous_floor)<.001,"walking offset does not accumulate")
		previous_floor=floor_y
	same_collision(before,"walking presentation")
	actor.velocity=Vector3.ZERO;actor.locomotion.moving=0.;actor.locomotion.phase=0.
	pose(0)

func sight_contact(scale: float) -> void:
	game.third_person=false;actor.aiming=true;actor.iron_sights=true
	for weapon in ["fal","glock"]:
		actor.weapon_id=weapon;actor._refresh_weapon();actor._update_view();actor._animate_walk()
		var model:=actor.view_root.get_node("Imported_"+weapon)
		for marker in (["RearAperture","FrontPost"] if weapon=="fal" else ["RearSight","FrontSight"]):
			var point: Vector2=actor.camera.unproject_position(model.get_node(marker).global_position)
			check(point.distance_to(root.get_visible_rect().size*.5)<2.,"corrected leg height preserves iron sight "+weapon+" "+str(scale))
	actor.iron_sights=false;actor.aiming=false;game.third_person=true
	actor.weapon_id="fal";actor._refresh_weapon();actor._update_view()

func run() -> void:
	game=FIXTURE.new();root.add_child(game)
	await process_frame;await process_frame
	actor=game.local_player
	actor.set_physics_process(false);actor.set_process(false)
	var original_pose:=actor.global_transform
	appearance(1.,"baseline appearance");actor.stance.reset(actor);pose(0)
	baseline={"feet":sole_bounds(actor),"camera_head_gap":actor.camera_pivot.position.y-actor.to_local(actor.avatar_parts.head.global_position).y}
	var original_collision:=collision_state()
	for scale: float in SCALES:
		appearance(scale,"legs "+str(scale))
		actor.stance.reset(actor);pose(0)
		inspect_rig(scale,0,"standing "+str(scale))
		for posture in [1,2,0]:
			pose(posture)
			var stable:=collision_state()
			appearance(scale,"appearance refresh in posture "+str(posture))
			pose(posture)
			same_collision(stable,"same posture refresh",true)
			inspect_rig(scale,posture,"posture "+str(posture)+" legs "+str(scale))
		actor.stance.reset(actor);pose(0)
		inspect_rig(scale,0,"reset "+str(scale))
		walking_contact(scale)
		sight_contact(scale)
		check(actor.global_transform==original_pose,"posture changes never translate authoritative actor")
		# Reset may intentionally recreate a capsule, but the standing shape
		# and foot plane must remain the original gameplay dimensions.
		same_collision(original_collision,"standing reset",false)
	var grass:=GRASS.instantiate();root.add_child(grass)
	no_grass_contact(grass,"reusable grass scene")
	var stream:=STREAM.new();game.world_root.add_child(stream)
	# Exercise the real runtime cell commit without loading a terrain/map or
	# starting a streamer. This path must also remain contact-free headless.
	stream.world=game.world_root;stream.mesh=load("res://modes/war/scripts/grass_assets.gd").blade_mesh(2)
	stream.material=load("res://modes/war/scripts/grass_assets.gd").grass_material(2)
	var poses: Array[Transform3D]=[Transform3D(Basis.IDENTITY,Vector3(3,0,3))]
	var patch=load("res://modes/war/scripts/grass_assets.gd").create_cell(stream.mesh,stream.material,poses.size())
	for i in poses.size():patch.multimesh.set_instance_transform(i,poses[i])
	game.world_root.add_child(patch)
	check(is_instance_valid(patch),"runtime commits a real grass MultiMesh cell")
	if is_instance_valid(patch): no_grass_contact(patch,"runtime grass cell")
	check(actor.global_transform==original_pose,"creating grass never moves actor")
	grass.queue_free();stream.queue_free()
	if is_instance_valid(patch): patch.queue_free()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"baseline":baseline,"measurements":measurements,"note":"Real War rig soles; presentation only. Does not simulate a moving vehicle or certify frame performance."}
	NavalStorage.write_json("res://work/nova-grass-contact.json",report)
	print("NOVA_GRASS_CONTACT ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures.size()}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
