extends SceneTree

# Small deterministic physics world. Both paths below execute the actual
# WarVehicles authority loop, without loading the map, art or a GPU fixture.
class Authority extends WarVehicles:
	var packets:=0
	func _ready() -> void:
		tv.manager=self
		set_process(false);set_physics_process(false);set_process_input(false)
	func _broadcast(_method: String,_args: Array) -> void: packets+=1

var failures: Array[String]=[]
var checks:=0
var records: Array[Dictionary]=[]
var stage: Node3D
var authority: Authority
var game: WarGame
var mirror: WarVehicle
var max_y:=0.0
var max_tick_motion:=0.0
var deepest:=0.0
var deepest_contact: Dictionary={}
var probe:=KinematicCollision3D.new()

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func block(point: Vector3,size: Vector3) -> StaticBody3D:
	var result:=StaticBody3D.new();result.position=point;result.collision_layer=1;result.collision_mask=0
	var node:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;node.shape=box;result.add_child(node);stage.add_child(result)
	return result

func setup(kind: String,mode: String) -> WarVehicle:
	stage=Node3D.new();root.add_child(stage)
	game=WarGame.new();game.offline_operation=mode=="offline";game.online=mode=="online_authority"
	authority=Authority.new();authority.game=game;stage.add_child(authority)
	var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="mobility_"+kind;vehicle.position=Vector3(0,10.1,6);authority.add_child(vehicle)
	vehicle.driver=77;authority.vehicles[vehicle.vehicle_id]=vehicle
	mirror=WarVehicle.new();mirror.kind=kind;mirror.vehicle_id="observer_"+kind;stage.add_child(mirror);mirror.collision_layer=0;mirror.collision_mask=0
	max_y=vehicle.position.y;max_tick_motion=0;deepest=0;deepest_contact={}
	return vehicle

func tick(vehicle: WarVehicle,throttle: float,count: int) -> void:
	for frame in count:
		var before:=vehicle.global_position
		game.war_clock+=1./60.
		authority.controls[77]={"throttle":throttle,"aim":Vector3(0,11,-500),"at":game.war_clock}
		authority._physics_process(1./60.)
		max_y=maxf(max_y,vehicle.global_position.y)
		var moved:=vehicle.global_position-before
		max_tick_motion=maxf(max_tick_motion,Vector2(moved.x,moved.z).length())
		if vehicle.test_move(vehicle.global_transform,Vector3.ZERO,probe,.0001,true) and probe.get_depth()>deepest:
			deepest=probe.get_depth();deepest_contact={"position":str(vehicle.position),"normal":str(probe.get_normal()),"collider":str(probe.get_collider()),"local_shape":str(probe.get_local_shape()),"point":str(probe.get_position())}
		mirror.receive(vehicle.snapshot());mirror.collision_layer=0;mirror.render(1./60.)
		await physics_frame

func finish(vehicle: WarVehicle,label: String) -> void:
	records.append({"scenario":label,"position":str(vehicle.position),"peak_y":max_y,"max_tick_motion":max_tick_motion,"penetration":deepest,"packets":authority.packets,"deepest_contact":deepest_contact})
	check(deepest<.015,label+": complete hull remains outside solids")
	check(max_tick_motion<=float(vehicle.spec.speed)/60.+.006,label+": no extra horizontal speed/teleport")
	check(mirror.destination.distance_to(vehicle.position)<.0001 and mirror.destination_rotation.is_finite() and authority.packets>0,label+": observer receives authoritative pose")
	stage.queue_free();await physics_frame;await physics_frame;game.free()

func scenario(kind: String,mode: String,which: String) -> void:
	var vehicle:=setup(kind,mode)
	var floor_body:=block(Vector3(0,9.5,0),Vector3(40,1,100))
	var label:=mode+" / "+kind+" / "+which
	match which:
		"curb", "roof_blocked", "roof_clear":
			var height:=.18 if which=="roof_clear" else .30
			block(Vector3(0,10+height*.5,-12),Vector3(14,height,24))
			if which.begins_with("roof"):
				var bottom:=10+float(vehicle.spec.size.y)+.05+(.25 if which=="roof_clear" else .13)
				block(Vector3(0,bottom+.125,0),Vector3(18,.25,55))
			await tick(vehicle,0,25);await tick(vehicle,.4,210)
			if which=="roof_blocked":
				check(vehicle.position.z>1.5 and max_y<10.21,label+": curb without turret clearance is blocked")
			else:
				check(vehicle.position.z<-6 and vehicle.position.y>10+height-.13,label+": climbs low edge with actual headroom")
		"reverse":
			block(Vector3(0,10.15,12),Vector3(14,.30,24));vehicle.position.z=-6
			await tick(vehicle,0,25);await tick(vehicle,-.8,250)
			check(vehicle.position.z>6 and vehicle.position.y>10.17,label+": reverse crosses the same 30 cm edge")
		"rubble":
			block(Vector3(0,10.20,0),Vector3(1.2,.40,1.2))
			await tick(vehicle,0,25);await tick(vehicle,.4,210)
			check(vehicle.position.z<-6 and max_y>10.20,label+": central 40 cm rubble passes under running gear")
		"wall":
			block(Vector3(0,10.60,0),Vector3(14,1.20,1.0))
			await tick(vehicle,0,25);await tick(vehicle,.8,180)
			check(vehicle.position.z>2 and max_y<10.21,label+": 1.2 m wall cannot become suspension support")
		"thin_wall":
			block(Vector3(0,11.5,0),Vector3(14,3,.04))
			await tick(vehicle,0,25);vehicle.speed=float(vehicle.spec.speed);await tick(vehicle,1,90)
			check(vehicle.position.z>1.5 and max_y<10.21,label+": thin wall blocks maximum speed")
		"vehicle":
			vehicle.position.z=9
			var other:=WarVehicle.new();other.kind="bmp2";other.vehicle_id="other_hull";other.position=Vector3(0,9.94,0);authority.add_child(other)
			await tick(vehicle,0,25);await tick(vehicle,.7,160)
			check(vehicle.position.z>4 and max_y<10.21,label+": another hull never becomes a stair")
		"slope", "strong_slope":
			floor_body.rotation=Vector3(.52,0,.08) if which=="strong_slope" else Vector3(.20,0,.12)
			var normal:=floor_body.basis.y
			var plane_y:=9.5+.5/normal.y-(normal.z*6)/normal.y
			var running_gear_rise: float=(absf(normal.x)*float(vehicle.spec.size.x)*.41+absf(normal.z)*float(vehicle.spec.size.z)*.35)/normal.y
			vehicle.position.y=plane_y+running_gear_rise+.03 if which=="strong_slope" else plane_y+.25
			await physics_frame;await physics_frame
			await tick(vehicle,0,45);await tick(vehicle,.25,180 if which=="strong_slope" else 120)
			check(vehicle.position.z<1 and vehicle.basis.y.dot(normal)>.995,label+": continuous incline retains support and tilt")
		"authored_rubble":
			var rubble:=load("res://modes/war/library/entulho_tijolos.tscn").instantiate() as Node3D
			rubble.position=Vector3(0,10,0);stage.add_child(rubble)
			await tick(vehicle,0,25);await tick(vehicle,.4,210)
			check(vehicle.position.z<-6,label+": actual reusable brick-rubble collision is traversable")
	await finish(vehicle,label)

func run() -> void:
	if "--quick-walls" in OS.get_cmdline_user_args(): Engine.physics_ticks_per_second=240
	for mode in ["offline","online_authority"]:
		if mode=="online_authority":
			var peer:=ENetMultiplayerPeer.new()
			var error:=peer.create_server(28991,1)
			check(error==OK,"dedicated authority opens its real ENet server")
			if error!=OK: break
			root.multiplayer.multiplayer_peer=peer
		for kind in ["guarani","bmp2","abrams","t90"]:
			for which in ["curb","reverse","rubble","wall","thin_wall","roof_blocked","roof_clear","vehicle","slope","strong_slope","authored_rubble"]:
				if "--quick-walls" in OS.get_cmdline_user_args() and which not in ["wall","thin_wall","roof_blocked","vehicle"]: continue
				await scenario(kind,mode,which)
		if mode=="online_authority": root.multiplayer.multiplayer_peer.close();root.multiplayer.multiplayer_peer=null
	var result: Dictionary={"checks":checks,"failures":failures,"scenarios":records,"fixture":"Actual WarVehicles authority loop, ENet server mode and snapshot observer; 60 Hz fixed deterministic physics, no map or GPU load."}
	if "--quick-walls" not in OS.get_cmdline_user_args(): NavalStorage.write_json("res://tests/mobility191-results.json",result)
	print(JSON.stringify({"checks":checks,"failures":failures,"scenarios":records.size()}));quit(0 if failures.is_empty() else 1)
