extends SceneTree
## Real capsule + GameStepMotion up/down the first three west stair flights.
const TERRAIN=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const WEST=preload("res://modes/war/scripts/favela_v2_west_hillside.gd")
const DT:=1.0/60.0
const SPEED:=3.8
var failed: Array[String]=[]
func _initialize()->void:
	_run.call_deferred()
func _run()->void:
	var world:=Node3D.new()
	root.add_child(world)
	TERRAIN.build(world,false)
	var metrics:Dictionary=WEST.build(world,false,false)
	if int(metrics.get("houses",-1))!=0:failed.append("headless no-houses flag failed")
	var actor:=CharacterBody3D.new()
	actor.collision_layer=1
	actor.collision_mask=1
	actor.floor_snap_length=.50
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.30
	capsule.height=1.78
	var collision:=CollisionShape3D.new()
	collision.shape=capsule
	collision.position.y=.89
	actor.add_child(collision)
	world.add_child(actor)
	await physics_frame
	var records: Array[Dictionary]=[]
	for flight:Dictionary in WEST.plan_steps():
		if not str(flight["id"]) in ["l02","l03","l04"]:continue
		var poly:PackedVector2Array=flight["route"]
		var a:=poly[0]
		var b:=poly[1]
		var axis:Vector2=(b-a).normalized()
		for forward in [true,false]:
			var start_2d:Vector2=a.lerp(b,.34 if forward else .66)
			var direction:Vector2=axis*(1.0 if forward else -1.0)
			actor.global_position=Vector3(start_2d.x,
				TERRAIN.height_at(start_2d.x,start_2d.y)+.28,start_2d.y)
			actor.velocity=Vector3.ZERO
			for settle in 12:
				await physics_frame
				actor.velocity=Vector3(0,-.25,0)
				actor.move_and_slide()
			var start:Vector3=actor.global_position
			var previous:Vector3=start
			var reverse:=0
			var max_jitter:=0.0
			var grounded:=0
			var tick_count:=95
			for tick in tick_count:
				await physics_frame
				actor.velocity.x=direction.x*SPEED
				actor.velocity.z=direction.y*SPEED
				if not actor.is_on_floor():
					actor.velocity.y-=9.81*DT
				GameStepMotion.move(actor,DT)
				if actor.is_on_floor():grounded+=1
				var move_delta:=actor.global_position-previous
				if Vector2(move_delta.x,move_delta.z).dot(direction)<-.012:reverse+=1
				max_jitter=maxf(max_jitter,absf(move_delta.y))
				previous=actor.global_position
			var advance:=Vector2(previous.x-start.x,previous.z-start.z).dot(direction)
			var good:=advance>3.1 and reverse<=3 and max_jitter<.60 and grounded>=60
			if not good:failed.append(str(flight["id"])+("_up" if forward else "_down"))
			records.append({"id":flight["id"],"forward":forward,
				"good":good,"advance":snappedf(advance,.01),
				"reverse_ticks":reverse,"peak_vertical_delta":snappedf(max_jitter,.001),
				"grounded":grounded})
	print("FAVELA_V2_WEST_WALK_QA ",JSON.stringify({
		"pass":failed.is_empty(),"runs":records,
		"failures":failed}))
	actor.queue_free()
	world.queue_free()
	quit(0 if failed.is_empty() else 1)
