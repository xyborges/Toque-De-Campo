extends SceneTree
## Dedicated-physics gate and cliffs using the same GameStepMotion as the game.
const T=preload("res://modes/war/scripts/favela_v2_terrain.gd")
const SPEED:=8.0
const DT:=1.0/60.0
const BODY_HEIGHT:=1.78
const BODY_RADIUS:=0.30
var failures: Array[String]=[]

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	var world:=Node3D.new()
	root.add_child(world)
	var metrics:=T.build(world,false)
	var walker:=CharacterBody3D.new()
	walker.name="SoldadoTesteFavelaV2"
	walker.collision_layer=1
	walker.collision_mask=1
	walker.floor_snap_length=.45
	var collider:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=BODY_RADIUS
	capsule.height=BODY_HEIGHT
	collider.shape=capsule
	collider.position.y=BODY_HEIGHT*.5
	walker.add_child(collider)
	world.add_child(walker)
	await physics_frame
	await physics_frame
	var cases: Array[Dictionary]=[
		{"id":"portao_liberado","start":Vector2(-140,15),"end":Vector2(-187,21),
			"frames":430,"allow":true,"threshold":27.0},
		{"id":"paredao_norte","start":Vector2(-310,-225),"end":Vector2(-310,-162),
			"frames":400,"allow":false,"threshold":37.0},
		{"id":"paredao_sul","start":Vector2(-300,119),"end":Vector2(-300,65),
			"frames":400,"allow":false,"threshold":38.0},
		{"id":"paredao_leste","start":Vector2(-174,-100),"end":Vector2(-237,-100),
			"frames":400,"allow":false,"threshold":33.0}
	]
	var records: Array[Dictionary]=[]
	for scenario: Dictionary in cases:
		var first: Vector2=scenario["start"]
		var last: Vector2=scenario["end"]
		var heading: Vector2=(last-first).normalized()
		walker.global_position=Vector3(first.x,T.height_at(first.x,first.y)+.48,first.y)
		walker.velocity=Vector3.ZERO
		for settle in 8:
			await physics_frame
			walker.velocity=Vector3(0,-.3,0)
			walker.move_and_slide()
		var begin: Vector3=walker.global_position
		var max_progress:=0.0
		var stalled:=0
		var last_position:=begin
		var max_y:=begin.y
		for tick in int(scenario["frames"]):
			await physics_frame
			walker.velocity.x=heading.x*SPEED
			walker.velocity.z=heading.y*SPEED
			if not walker.is_on_floor():walker.velocity.y-=9.81*DT
			GameStepMotion.move(walker,DT)
			var current: Vector3=walker.global_position
			var projected: float=(Vector2(current.x,current.z)-first).dot(heading)
			max_progress=maxf(max_progress,projected)
			max_y=maxf(max_y,current.y)
			if current.distance_squared_to(last_position)<.0004:stalled+=1
			last_position=current
		var advanced:float=(Vector2(last_position.x,last_position.z)-first).dot(heading)
		var succeeded: bool=advanced>=float(scenario["threshold"]) if bool(scenario["allow"]) else max_progress<float(scenario["threshold"])
		if not succeeded:failures.append(str(scenario["id"])+" progress="+str(max_progress))
		records.append({"case":scenario["id"],"pass":succeeded,
			"progress":advanced,"maximum_progress":max_progress,
			"max_y":max_y,"stalled":stalled,
			"final":last_position})
	print("FAVELA_V2_WEST_CLIFF_WALK_QA ",JSON.stringify({
		"pass":failures.is_empty(),"scenarios":records,
		"chunks":metrics.chunks,"errors":failures}))
	walker.queue_free()
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
