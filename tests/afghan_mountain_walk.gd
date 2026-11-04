extends SceneTree
const MAP=preload("res://modes/battle_royale/map/afghan_map.gd")
var world: Node3D
var failures: Array[String]=[]
class Walker extends CharacterBody3D:
	var target:=Vector3.ZERO
	func _ready() -> void:
		floor_snap_length=.45;floor_constant_speed=true;floor_max_angle=deg_to_rad(45.);collision_layer=4;collision_mask=1
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.75;capsule.radius=.32;shape.shape=capsule;shape.position.y=.875;add_child(shape)
	func _physics_process(delta: float) -> void:
		var offset:=target-global_position;offset.y=0
		var travel:=offset.normalized() if offset.length()>.45 else Vector3.ZERO
		velocity.x=travel.x*5.;velocity.z=travel.z*5.
		if not is_on_floor():velocity.y-=9.81*delta
		GameStepMotion.move(self,delta)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	world=Node3D.new();root.add_child(world);var map:=MAP.new();map.render_visuals=false;world.add_child(map);map.build()
	await physics_frame;await physics_frame
	var routes: Array=[]
	for road: Dictionary in MAP.LAND.roads():
		if road.kind!="mountain":continue
		var walker:=Walker.new();var first: Vector3=road.points[0];walker.position=MAP.point(first.x,first.z)+Vector3.UP*.3;walker.target=walker.position;world.add_child(walker)
		await physics_frame;await physics_frame
		var start:=walker.position;var maximum:=start.y;var reached:=0
		for point: Vector3 in road.points:
			walker.target=MAP.point(point.x,point.z)
			# Bridges are deliberately above the creek bed. Validate arrival
			# against the traversable surface, not the terrain under the bridge.
			var query:=PhysicsRayQueryParameters3D.create(walker.target+Vector3.UP*10.,walker.target-Vector3.UP*2.,1,[walker.get_rid()])
			var floor_hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			if not floor_hit.is_empty():walker.target.y=floor_hit.position.y
			var arrived:=false
			for frame in 230:
				await physics_frame
				maximum=maxf(maximum,walker.position.y)
				if Vector2(walker.position.x-point.x,walker.position.z-point.z).length()<.8 and absf(walker.position.y-walker.target.y)<1.0:arrived=true;break
			if not arrived:failures.append("Blocked on mountain route at %s, actor %s"%[point,walker.position]);break
			reached+=1
		routes.append({"start":str(start),"peak_m":maximum,"gain_m":maximum-start.y,"reached":reached,"waypoints":road.points.size()})
		walker.free();await physics_frame
	var report:={"ok":failures.is_empty() and routes.size()==2,"routes":routes,"failures":failures,"scope":"Two complete mountain paths walked by the real capsule and GameStepMotion, 60 Hz fixed simulation; not an FPS benchmark or vehicle test."}
	NavalStorage.write_json("res://work/afghan-mountain-walk.json",report);print("MOUNTAIN_WALK ",JSON.stringify(report))
	world.queue_free();await process_frame;await physics_frame;quit(0 if report.ok else 1)
