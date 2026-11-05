extends SceneTree
## P1f: authority must use one logical sight origin for FPP and TPP.
## The real camera origin is still validated, but must not move the accepted
## aim point. Cases cover open range, a side corner and a narrow window.
class ShotFixture extends "res://tests/war_optics_fixture.gd":
	var accepted_shot: Dictionary={}
	func _present_shot(packet: Dictionary) -> bool:
		accepted_shot=packet.duplicate(true)
		return true

var game: ShotFixture
var actor: WarPlayer
var fixtures: Array[Node]=[]
var failures: Array[String]=[]
var checks:=0
var shot_serial:=0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures.append(label)
		push_error(label)

func box(name_text: String,centre: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=name_text
	body.collision_layer=1
	body.collision_mask=0
	var shape:=CollisionShape3D.new()
	var geometry:=BoxShape3D.new()
	geometry.size=size
	shape.shape=geometry
	body.add_child(shape)
	body.position=centre
	game.world_root.add_child(body)
	fixtures.append(body)
	return body

func clear_case_geometry() -> void:
	for node: Node in fixtures:
		if is_instance_valid(node):node.queue_free()
	fixtures.clear()
	await physics_frame

func prepare_actor() -> void:
	actor=game.local_player as WarPlayer
	actor.hp=100.
	actor.deployed=true
	actor.position=Vector3.ZERO
	actor.rotation=Vector3.ZERO
	actor.yaw=0.
	actor.pitch=0.
	actor.lean=0.
	actor.network_lean=0.
	actor.camera_pivot.position.x=0.
	actor.camera_pivot.rotation=Vector3.ZERO
	actor.weapon_id="fal"
	actor.owned=["fal","glock"]
	actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor.set_meta("weapon_attachments",{"fal":{}})
	actor._refresh_weapon()
	actor.set_posture(0,false,true)
	actor.stance.advance(actor,1.)
	actor.velocity=Vector3.ZERO
	actor.locomotion.reset(actor)
	actor.aiming=false
	actor.iron_sights=false
	actor.reload_left=0.
	actor.reload_weapon=""
	actor.fire_cooldown=0.
	actor.ammo["fal"]=50
	game.members[1].shield=0.
	game.shot_clocks.clear()
	game.shot_sequences[1]=0
	actor.next_pose_usec=0
	actor._animate_walk()

func camera_sample(third_person: bool) -> Dictionary:
	game.third_person=third_person
	actor.aiming=false
	actor.iron_sights=false
	actor._update_view()
	actor._update_camera_collision(1.)
	return {
		"origin":actor.camera.global_position,
		"direction":-actor.camera.global_basis.z.normalized(),
		"eye":actor.camera_pivot.global_position
	}

func accepted(sample: Dictionary) -> Dictionary:
	# Reuse one deterministic shot id/seed for the FPP/TPP geometry pair.
	# The fixture bypasses duplicate presentation tracking, while resetting
	# the authority sequence before each call keeps the server gate valid.
	shot_serial=1
	game.accepted_shot.clear()
	game.shot_clocks.clear()
	game.shot_sequences[1]=0
	actor.fire_cooldown=0.
	actor.ammo["fal"]=50
	game._server_accept_shot(1,shot_serial,actor.life_id,Vector3(sample.origin),Vector3(sample.direction),"fal",0)
	return game.accepted_shot.duplicate(true)

func logical_target(sample: Dictionary) -> String:
	var eye:=actor.camera_pivot.global_position
	var query:=PhysicsRayQueryParameters3D.create(eye,eye+Vector3(sample.direction)*110.0,1,[actor.get_rid()])
	query.collide_with_areas=true
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	return "" if hit.is_empty() else str((hit.collider as Node).name)

func compare_case(label: String) -> void:
	var fpp:=camera_sample(false)
	var tpp:=camera_sample(true)
	var expected_target: String={"open":"Backstop","corner":"Corner","window":"Backstop"}.get(label,"")
	check(logical_target(fpp)==expected_target,label+" FPP logical ray reaches expected coverage target")
	check(logical_target(tpp)==expected_target,label+" TPP logical ray reaches expected coverage target")
	check(Vector3(fpp.origin).distance_to(Vector3(tpp.origin))>.5,label+" cameras are genuinely separated")
	check(Vector3(fpp.direction).dot(Vector3(tpp.direction))>.9999,label+" cameras share look direction")
	check(actor.shot_camera_valid(Vector3(tpp.origin),Vector3(tpp.direction)),label+" real TPP camera is accepted by envelope")
	var first:=accepted(fpp)
	var second:=accepted(tpp)
	check(str(first.get("weapon",""))=="fal" and str(second.get("weapon",""))=="fal",label+" both perspectives accepted")
	if first.is_empty() or second.is_empty():return
	var origin_delta:=Vector3(first.origin).distance_to(Vector3(second.origin))
	var direction_delta:=Vector3(first.direction).distance_to(Vector3(second.direction))
	check(origin_delta<.00001,label+" same muzzle origin")
	check(direction_delta<.0001,label+" same accepted ballistic direction")
	check(bool(first.get("blocked",false))==bool(second.get("blocked",false)),label+" same coverage blocking result")
	print("P1F_CASE ",JSON.stringify({
		"case":label,
		"camera_separation_m":Vector3(fpp.origin).distance_to(Vector3(tpp.origin)),
		"origin_delta_m":origin_delta,
		"direction_delta":direction_delta,
		"blocked_fpp":first.get("blocked",false),
		"blocked_tpp":second.get("blocked",false),
		"fpp_direction":first.direction,
		"tpp_direction":second.direction
	}))

func run() -> void:
	game=ShotFixture.new()
	root.add_child(game)
	await process_frame
	prepare_actor()
	# A distant backstop gives both camera rays an explicit aim point.
	box("Backstop",Vector3(0,2,-30),Vector3(12,6,.2))
	await physics_frame
	compare_case("open")
	await clear_case_geometry()

	# Corner: the logical eye/muzzle are behind the near wall while the
	# shoulder camera can sit to its right and see the distant backstop.
	box("Backstop",Vector3(0,2,-30),Vector3(12,6,.2))
	box("Corner",Vector3(0,1.6,-5),Vector3(.60,3.2,7.0))
	await physics_frame
	compare_case("corner")
	await clear_case_geometry()

	# Window: the logical eye looks through the centre gap; the shoulder
	# camera is laterally offset and its own ray intersects the right panel.
	box("Backstop",Vector3(0,2,-30),Vector3(12,6,.2))
	box("WindowLeft",Vector3(-2.15,1.7,-7),Vector3(3.7,3.4,.25))
	box("WindowRight",Vector3(2.15,1.7,-7),Vector3(3.7,3.4,.25))
	await physics_frame
	compare_case("window")
	await clear_case_geometry()

	var result:={"pass":failures.is_empty(),"checks":checks,"failures":failures}
	print("P1F_SHOT_COVERAGE ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
