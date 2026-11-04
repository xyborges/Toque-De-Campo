extends SceneTree
var checks:=0
var failures: Array[String]=[]
var stage: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func block(point: Vector3,size: Vector3,surface:="concrete") -> StaticBody3D:
	var b:=StaticBody3D.new();b.position=point;b.collision_layer=1;b.set_meta("surface",surface)
	var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;c.shape=shape;b.add_child(c);stage.add_child(b);return b
func move(actor: CharacterBody3D,speed: float,frames: int) -> void:
	for i in frames:
		actor.velocity=Vector3(speed,actor.velocity.y-9.81/60,0)
		GameStepMotion.move(actor,1./60)
		await physics_frame
func run() -> void:
	stage=Node3D.new();root.add_child(stage);block(Vector3(0,-.5,0),Vector3(50,1,20))
	for i in 3: block(Vector3(2.5+i,(i+1)*.1,0),Vector3(1,(i+1)*.2,4))
	block(Vector3(6.5,.3,0),Vector3(3,.6,4));block(Vector3(10,1,0),Vector3(1,2,4))
	var actor:=CharacterBody3D.new();actor.collision_mask=1;actor.floor_snap_length=.45
	var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.75
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=.875;actor.add_child(collision);stage.add_child(actor);actor.position=Vector3(0,.1,0)
	await move(actor,0,30);await move(actor,2.5,150)
	check(actor.position.x>5.7 and actor.position.y>.55,"capsule climbs three real 20cm steps without jumping")
	print("STAIRS_POSITION ",actor.position)
	await move(actor,-2.5,145)
	check(actor.position.x<1 and actor.position.y<.05,"capsule descends to the lower floor")
	actor.position=Vector3(8.5,.65,0);await move(actor,2.5,100)
	check(actor.position.x<9.25,"step helper cannot climb a two-metre wall")
	actor.position=Vector3(.5,.05,0);actor.velocity=Vector3.ZERO
	var ceiling:=block(Vector3(2.5,1.95,0),Vector3(2,.2,4))
	await move(actor,2.5,95)
	check(actor.position.x<1.8,"step helper refuses a step without capsule headroom")
	ceiling.queue_free()
	var sound:=WarSoundscape.new();var game:=WarGame.new();sound.game=game;stage.add_child(sound)
	for index in 4:
		var tag: String=["grass","mud","asphalt","rock"][index]
		var tile:=block(Vector3(index*3,0,12),Vector3(2,.2,2),tag)
		await physics_frame
		check(sound.contact_surface(tile.position+Vector3.UP*.12)==("stone" if tag=="rock" else tag),"foot contact resolves "+tag+" from the actual collider")
	var hashes: Dictionary={}
	for surface in ["grass","mud","asphalt","stone"]:
		var path: String="res://audio/war/step-"+surface+"-0.wav"
		var sample:=load(path) as AudioStreamWAV
		check(sample!=null and sample.get_length()>.1,"footstep sample imports for "+surface)
		hashes[FileAccess.get_sha256(path)]=true
	check(hashes.size()==4,"grass, mud, asphalt and stone use different recordings")
	var slope:=block(Vector3(0,-.5,55),Vector3(45,1,45));slope.rotation=Vector3(.25,0,.18)
	await physics_frame;await physics_frame
	var expected: Vector3=slope.global_basis.y
	for kind in ["abrams","t90","guarani","bmp2"]:
		var tank:=WarVehicle.new();tank.kind=kind;tank.vehicle_id="ground_"+kind;stage.add_child(tank)
		for heading in [0.,PI*.5,PI,-PI*.5]:
			tank.heading=heading;tank.position=Vector3(0,.1,55);tank.ground_support=WarVehicleGround.new()
			for i in 100: tank.ground_support.align(tank,1./60)
			check(tank.global_basis.y.dot(expected)>.995,kind+" follows both axes of a slope at yaw "+str(heading))
			var min_gap:=INF;var max_gap:=-INF
			for p in tank.ground_support.contacts:
				var foot: Vector3=tank.to_global(Vector3(p.x,.09,p.z))
				var ray:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*2,foot-Vector3.UP*2,1,[tank.get_rid()])
				var hit:=stage.get_world_3d().direct_space_state.intersect_ray(ray)
				var gap: float=foot.y-Vector3(hit.get("position",foot+Vector3.DOWN*10)).y;min_gap=minf(min_gap,gap);max_gap=maxf(max_gap,gap)
			print("GROUND_GAP ",kind," ",heading," ",min_gap," ",max_gap)
			check(min_gap>-.015 and max_gap<.08,kind+" running-gear footprint stays against the ground")
		tank.queue_free()
		await physics_frame;await physics_frame
	sound.queue_free();game.free()
	NavalStorage.write_json("res://tests/movement184-results.json",{"checks":checks,"failures":failures})
	stage.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)
