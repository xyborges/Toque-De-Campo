extends SceneTree
## Real GameStepMotion: walking short segments of the S-shaped main ascent.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const TOPO=preload("res://modes/war/scripts/favela_v2_topology.gd")
const WORLD=preload("res://modes/war/scripts/favela_v2_ascension_blockout.gd")
const DT:=1.0/60.0
const SPEED:=3.6
var failures:Array[String]=[]
func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	var world:=Node3D.new()
	root.add_child(world)
	var metrics:=WORLD.build(world,false)
	var actor:=CharacterBody3D.new()
	actor.name="QA_PlayerCapsule"
	actor.collision_layer=1
	actor.collision_mask=1
	actor.floor_snap_length=.50
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.30
	capsule.height=1.78
	var col:=CollisionShape3D.new()
	col.shape=capsule
	col.position.y=.89
	actor.add_child(col)
	world.add_child(actor)
	await physics_frame
	var scenarios: Array[Dictionary]=[]
	for id in ["s01","s03","c01","c02","c03","c04","c05","c06","r01"]:
		for edge: Dictionary in TOPO.LINKS:
			if str(edge["id"])!=id:continue
			var poly:=TOPO.polyline(edge)
			var a:Vector2=poly[0]
			var b:Vector2=poly[1]
			var axis:Vector2=(b-a).normalized()
			for forward in [true,false]:
				var start:Vector2=a.lerp(b,.28 if forward else .72)
				var dir:Vector2=axis*(1.0 if forward else -1.0)
				actor.global_position=Vector3(start.x,T.height_at(start.x,start.y)+.34,start.y)
				actor.velocity=Vector3.ZERO
				for settle in 10:
					await physics_frame
					actor.velocity=Vector3(0,-.24,0)
					actor.move_and_slide()
				var begin:=actor.global_position
				var last:=begin
				var reverse:=0
				var largest_y:=0.0
				var ground_frames:=0
				for tick in 100:
					await physics_frame
					actor.velocity.x=dir.x*SPEED
					actor.velocity.z=dir.y*SPEED
					if not actor.is_on_floor():
						actor.velocity.y-=9.81*DT
					GameStepMotion.move(actor,DT)
					var now:Vector3=actor.global_position
					var delta:=now-last
					if Vector2(delta.x,delta.z).dot(dir)<-.012:reverse+=1
					largest_y=maxf(largest_y,absf(delta.y))
					if actor.is_on_floor():ground_frames+=1
					last=now
				var traveled:=Vector2(last.x-begin.x,last.z-begin.z).dot(dir)
				var passed:=traveled>=3.6 and reverse<=3 and largest_y<.45 and ground_frames>=60
				scenarios.append({"road":id,"forward":forward,
					"pass":passed,"meters":snappedf(traveled,.01),
					"reverse":reverse,"max_y":snappedf(largest_y,.003),
					"grounded":ground_frames})
				if not passed:failures.append(id+("_up" if forward else "_down"))
	print("FAVELA_V2_ASCENSAO_WALK_QA ",JSON.stringify({
		"pass":failures.is_empty(),"runs":scenarios.size(),
		"houses":int(metrics["main"]["main_houses"])+int(metrics["west"]["houses"]),
		"failures":failures,"details":scenarios}))
	actor.queue_free()
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
