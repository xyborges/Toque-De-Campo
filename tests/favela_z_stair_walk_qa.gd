extends SceneTree
const Z=preload("res://modes/war/scripts/favela_z_stairway.gd")
const DT:=1.0/60.0
const SPEED:=3.7
const BODY_HEIGHT:=1.75
const BODY_RADIUS:=.30
var failures: Array[String]=[]
var checks:=0

func expect(ok: bool,label: String)->void:
	checks+=1
	if not ok: failures.append(label)

func _initialize()->void:
	run.call_deferred()

func run()->void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var world:=Node3D.new()
	root.add_child(world)
	WarWorld.build(world,false)
	await physics_frame
	await physics_frame
	var map:=world.get_node("FavelaWar") as WarFavelaMap
	var route: Array=WarFavelaMap.MINI_STREETS[WarFavelaMap.Z_STAIR_ROUTE_INDEX]
	var layout:=Z.plan(route,func(x: float,z: float)->float:return WarFavelaMap.height_at(x,z))
	var capsule:=CapsuleShape3D.new()
	capsule.radius=BODY_RADIUS
	capsule.height=BODY_HEIGHT
	var walker:=CharacterBody3D.new()
	walker.collision_layer=1
	walker.collision_mask=1
	walker.floor_snap_length=.45
	var collider:=CollisionShape3D.new()
	collider.shape=capsule
	collider.position.y=BODY_HEIGHT*.5
	walker.add_child(collider)
	root.add_child(walker)
	await physics_frame
	var ray_misses:=0
	var intrusions:=0
	var hits_by_name: Dictionary={}
	var space:=root.world_3d.direct_space_state
	var treads: Array=layout.steps
	for j in range(0,treads.size(),5):
		var item: Dictionary=treads[j]
		var center: Vector3=item.position
		var ray:=PhysicsRayQueryParameters3D.create(center+Vector3.UP*1.0,
			center-Vector3.UP*.50,1,[walker.get_rid()])
		var hit:=space.intersect_ray(ray)
		if hit.is_empty():
			ray_misses+=1
			continue
		var floor_y: float=(hit.position as Vector3).y
		var expected:=center.y+.12
		if absf(floor_y-expected)>.14:ray_misses+=1
		var body=hit.get("collider") as CollisionObject3D
		var label:=str(body.name) if body else "none"
		hits_by_name[label]=int(hits_by_name.get(label,0))+1
		var q:=PhysicsShapeQueryParameters3D.new()
		q.shape=capsule
		q.collision_mask=1
		q.transform.origin=Vector3(center.x,floor_y+BODY_HEIGHT*.5+.035,center.z)
		q.exclude=[walker.get_rid()]
		if not space.intersect_shape(q,5).is_empty():intrusions+=1
	expect(ray_misses==0,"stairway has floor at every sampled tread")
	expect(intrusions<=2,"player capsule clear of overlapping collision solids")
	var blocked_walks:=0
	var reverse_ticks:=0
	var runs:=0
	for segment in [0,2,4]:
		var a: Vector2=route[segment]
		var b: Vector2=route[segment+1]
		for forward in [true,false]:
			var begin: Vector2=a.lerp(b,.27 if forward else .73)
			var axis: Vector2=(b-a).normalized()*(1. if forward else -1.)
			walker.global_position=Vector3(begin.x,
				WarFavelaMap.height_at(begin.x,begin.y)+.30,begin.y)
			walker.velocity=Vector3.ZERO
			await physics_frame
			for settle in 9:
				walker.velocity=Vector3(0,-.24,0)
				walker.move_and_slide()
				await physics_frame
			var start:=walker.global_position
			var previous:=start
			for tick in 85:
				walker.velocity.x=axis.x*SPEED
				walker.velocity.z=axis.y*SPEED
				if not walker.is_on_floor():walker.velocity.y-=9.81*DT
				GameStepMotion.move(walker,DT)
				var delta_pos:=walker.global_position-previous
				if delta_pos.dot(Vector3(axis.x,0,axis.y))<-.013:reverse_ticks+=1
				previous=walker.global_position
				await physics_frame
			var advance:=(walker.global_position-start).dot(Vector3(axis.x,0,axis.y))
			if advance<2.15:blocked_walks+=1
			runs+=1
	expect(blocked_walks==0,"all ascending and descending walks move forward")
	expect(reverse_ticks<=4,"no persistent reverse ticks from stair collisions")
	print("FAVELA_Z_STAIR_WALK_QA ",JSON.stringify({
		"ok":failures.is_empty(),"checks":checks,
		"treads":treads.size(),"sampled":ceili(float(treads.size())/5.0),
		"ray_misses":ray_misses,"overlap_samples":intrusions,
		"blocked_walks":blocked_walks,"reverse_ticks":reverse_ticks,
		"walks":runs,"hits_by_name":hits_by_name,
		"failures":failures.slice(0,15)}))
	walker.queue_free()
	world.queue_free()
	quit(0 if failures.is_empty() else 1)
