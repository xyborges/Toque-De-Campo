extends SceneTree

const OUT="res://work/realismo-r1c-physics.json"
const DT:=1.0/60.0

class Actor extends GamePlayer:
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _process(_delta: float) -> void: pass
	func in_water() -> bool: return false

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)

func make_floor(stage: Node3D) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name="R1CFloor"
	body.position=Vector3(0,-.15,0)
	body.collision_layer=1
	var shape_node:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(20,.30,20)
	shape_node.shape=shape
	body.add_child(shape_node)
	stage.add_child(body)
	return body

func make_actor(stage: Node3D) -> Actor:
	var actor:=Actor.new()
	actor.name="R1CPhysicalActor"
	actor.is_local=true
	actor.hp=100.
	actor.deployed=true
	actor.vehicle_id=""
	actor.collision_layer=4
	actor.collision_mask=1
	actor.floor_snap_length=.45
	var shape_node:=CollisionShape3D.new()
	shape_node.name="BodyCollision"
	var shape:=CapsuleShape3D.new()
	shape.radius=.32
	shape.height=1.75
	shape_node.shape=shape
	shape_node.position.y=.87
	actor.add_child(shape_node)
	stage.add_child(actor)
	return actor

func run_drop(actor: Actor,height: float) -> Dictionary:
	actor.position=Vector3(0,height,0)
	actor.velocity=Vector3.ZERO
	actor.locomotion.tactical_motion_pilot=true
	actor.locomotion.reset(actor)
	var seen_air:=false
	var first_ground_frame:=-1
	var trigger_frame:=-1
	var trigger_grounded:=false
	var tracked_fall_peak:=0.
	var peak_weight:=0.
	var airborne_weight_peak:=0.
	var recovered_frame:=-1
	for frame in 360:
		actor.locomotion.advance(actor,DT)
		tracked_fall_peak=maxf(tracked_fall_peak,actor.locomotion.presentation_fall_speed)
		if not actor.is_on_floor():
			seen_air=true
			airborne_weight_peak=maxf(airborne_weight_peak,actor.locomotion.presentation_landing)
		if actor.locomotion.presentation_landing>peak_weight:
			peak_weight=actor.locomotion.presentation_landing
			trigger_frame=frame
			trigger_grounded=actor.is_on_floor()
		if not actor.is_on_floor():
			actor.velocity.y-=9.81*DT
		GameStepMotion.move(actor,DT)
		if seen_air and actor.is_on_floor() and first_ground_frame<0:
			first_ground_frame=frame
		if trigger_frame>=0 and actor.locomotion.presentation_landing<=.00001 and frame>trigger_frame:
			recovered_frame=frame
			break
		await physics_frame
	var expected:=WarLocomotion.landing_target(tracked_fall_peak)
	return {
		"height_m":height,
		"seen_air":seen_air,
		"first_ground_frame":first_ground_frame,
		"trigger_frame":trigger_frame,
		"trigger_grounded":trigger_grounded,
		"tracked_fall_peak_mps":tracked_fall_peak,
		"peak_weight":peak_weight,
		"expected_weight":expected,
		"airborne_weight_peak":airborne_weight_peak,
		"recovered_frame":recovered_frame,
		"final_y":actor.position.y,
		"final_grounded":actor.is_on_floor()
	}

func run() -> void:
	var stage:=Node3D.new()
	root.add_child(stage)
	var floor_body:=make_floor(stage)
	var actor:=make_actor(stage)
	await physics_frame
	await physics_frame

	var ray:=PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-2,0),1,[actor.get_rid()])
	var floor_hit:=stage.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not floor_hit.is_empty() and floor_hit.collider==floor_body,"physical fixture ray sees the test floor")

	var normal:=await run_drop(actor,1.15)
	check(bool(normal.seen_air),"real CharacterBody becomes airborne before landing")
	check(int(normal.first_ground_frame)>=0 and bool(normal.final_grounded),"real CharacterBody reaches and remains on the physical floor")
	check(float(normal.tracked_fall_peak_mps)>WarLocomotion.PRESENTATION_LANDING_THRESHOLD,"normal physical fall exceeds the R1C impact threshold")
	check(float(normal.airborne_weight_peak)<.00001,"R1C emits no landing presentation while still airborne")
	check(int(normal.trigger_frame)>int(normal.first_ground_frame),"R1C impulse appears only on the tick after physical ground contact")
	check(bool(normal.trigger_grounded),"R1C impulse is emitted while the CharacterBody reports grounded")
	check(absf(float(normal.peak_weight)-float(normal.expected_weight))<.03,"physical landing weight matches the stored fall-speed target")
	check(float(normal.peak_weight)>.45 and float(normal.peak_weight)<.80,"1.15 m physical drop produces a restrained normal-to-firm impact")
	check(int(normal.recovered_frame)>int(normal.trigger_frame),"landing presentation recovers after the physical impact")

	var report:={"checks":checks,"failures":failures,"normal_drop":normal}
	var out:=FileAccess.open(OUT,FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(report,"\t"))
		out.close()
	print("REALISMO_R1C_PHYSICS "+JSON.stringify(report))
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
