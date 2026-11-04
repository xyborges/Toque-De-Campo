extends SceneTree

var game: BattleRoyaleGame
var system: BRMotorbikes
var checks:=0
var failures: Array[String]=[]
var metrics: Dictionary={}

func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func box(at: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var volume:=BoxShape3D.new()
	volume.size=size;shape.shape=volume;body.position=at;body.add_child(shape);game.world_root.add_child(body)
	return body
func frames(count: int) -> void:
	for _index in count:await physics_frame
func settle(bike: WarVehicle,count:=20) -> void:
	for _index in count:await physics_frame;bike.simulate(1./60.,{})
func enter(actor: GamePlayer,bike: WarVehicle) -> void:
	game.network_guard.clear();system._interact(actor.peer_id,bike.vehicle_id,actor.life_id,game.br_generation)
	await physics_frame
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://work/br-motorbikes-"+label+".png")
func run() -> void:
	game=load("res://tests/br_completion_fixture.gd").new();game.set_meta("br_host",true);game.set_meta("test_mode",true);root.add_child(game)
	game.flat_world();game.online=false;game.phase="active";game.br_generation=3
	system=load("res://tests/br_motorbikes_fixture.gd").new();system.game=game;game.motorbikes=system;game.world_root.add_child(system)
	var bike: WarVehicle=system.bikes.br_bike_00;var other_bike: WarVehicle=system.bikes.br_bike_01
	var actor:=game._spawn_player(1,true,false,Vector3(1.6,.08,0));actor.hp=100;actor.life_id=7;actor.set_physics_process(false);actor.set_process(false)
	var rival:=game._spawn_player(2,false,false,Vector3(-1.6,.08,0));rival.hp=100;rival.life_id=7;rival.set_physics_process(false);rival.set_process(false)
	game.ui_focus.close_all();game.third_person=false;actor._update_view()
	await settle(bike);await settle(other_bike)
	check(bike.position.y>-.1 and bike.position.y<.15,"parked bike settles on its physical contact plane")
	system._interact(1,bike.vehicle_id,6,3);system._interact(1,bike.vehicle_id,7,2)
	check(bike.driver==0,"old life and old round cannot board")
	actor.position=Vector3(8,.08,0);await enter(actor,bike)
	check(bike.driver==0,"distant boarding rejected")
	actor.position=Vector3(1.6,.08,0)
	var barrier:=box(Vector3(.8,1.5,0),Vector3(.18,3,4));await frames(2);await enter(actor,bike)
	check(bike.driver==0,"a nearby bike cannot be boarded through a wall")
	barrier.queue_free();await frames(2)
	actor._animate_walk();actor.set_posture(2,false,true);actor.stance.prone_weight=1.;actor.stance.pose(actor)
	await enter(actor,bike)
	check(bike.driver==1 and system.occupied(actor) and actor.body_collision.disabled,"boarding has one authoritative rider and disables its movement capsule")
	check(not actor.prone and not actor.crouched and actor.stance.prone_weight==0. and actor.body_root.get_node("Pelvis").rotation.is_zero_approx(),"boarding from prone resets on-foot hip and head displacement before the seated pose")
	check(not actor.view_root.visible and actor.camera.global_position.distance_to(actor.camera_pivot.global_position)>2.8 and not game.third_person,"riding uses an external camera while preserving the selected on-foot FPP mode")
	await enter(rival,bike)
	check(bike.driver==1 and rival.vehicle_id.is_empty(),"second rider cannot steal the occupied single seat")
	var current_epoch:=bike.control_epoch
	system._accept_control(1,1,7,3,1.,.4,bike.vehicle_id,current_epoch)
	check(system.controls.has(1) and system.controls[1].throttle==1.,"current operator control accepted")
	for data in [[2,6,3,1.,0.,bike.vehicle_id,current_epoch],[2,7,2,1.,0.,bike.vehicle_id,current_epoch],[2,7,3,NAN,0.,bike.vehicle_id,current_epoch],[2,7,3,1.,0.,other_bike.vehicle_id,current_epoch],[2,7,3,1.,0.,bike.vehicle_id,current_epoch-1]]:
		system._accept_control(1,int(data[0]),int(data[1]),int(data[2]),float(data[3]),float(data[4]),str(data[5]),int(data[6]))
	check(int(system.sequences[1])==1,"wrong life, round, bike, occupancy epoch and nonfinite control are rejected")
	system._accept_control(2,100,7,3,1.,1.,bike.vehicle_id,current_epoch)
	check(not system.controls.has(2),"another peer cannot drive a foreign rider's bike")
	rival.position=Vector3(30,.08,15)
	system.pose(actor);actor.camera_pivot.rotation.y=.8
	check(system.release(1) and not system.occupied(actor),"rider can leave a clear bike")
	await frames(2)
	check(not actor.body_collision.disabled and actor.camera_pivot.rotation.y==0. and actor.camera_pivot.position.y>1.6 and actor.view_root.visible,"exit restores on-foot collision, camera orbit, eye height and FPP presentation")
	check(not system.controls.has(1) and not system.sequences.has(1),"exit clears throttle and sequence reservations")
	actor.position=Vector3(1.6,.08,0);await enter(actor,bike)
	system._accept_control(1,10,7,3,1.,0.,bike.vehicle_id,current_epoch)
	check(not system.controls.has(1),"delayed control from a previous boarding cannot restart the bike")
	var wall:=box(Vector3(1.3,1.5,0),Vector3(.3,3,5));await frames(2)
	var exit: Dictionary=system.safe_exit(bike,actor)
	check(not exit.is_empty() and Vector3(exit.position).x<0.,"exit checks the full capsule and finds the unobstructed opposite side")
	wall.queue_free();await frames(2)
	var cage: Array[Node]=[]
	for x in [-.78,.78]:cage.append(box(Vector3(x,1.5,0),Vector3(.15,3,4)))
	for z in [-1.18,1.18]:cage.append(box(Vector3(0,1.5,z),Vector3(4,3,.15)))
	await frames(2)
	check(not system.release(1) and bike.driver==1 and system.occupied(actor),"blocked exit retains the seat instead of teleporting through a wall")
	var death_position:=actor.global_position;actor.hp=0
	check(system.release(1,true) and bike.driver==0 and actor.global_position.is_equal_approx(death_position),"forced death exit frees the reservation without relocating the corpse")
	await frames(2)
	check(actor.body_collision.disabled and not actor.view_root.visible,"dead exit cannot restore a living capsule or first-person hands")
	for item in cage:item.queue_free()
	await frames(2);actor.hp=100;actor.position=Vector3(30,.08,20);rival.position=Vector3(35,.08,20)
	bike.position=Vector3.ZERO;bike.speed=0;bike.velocity=Vector3.ZERO;bike.heading=0;bike.ground_support.tilt=Basis.IDENTITY;bike._wake_ground_rest()
	await settle(bike)
	for _index in 60:await physics_frame;bike.simulate(1./60.,{"throttle":1.,"steer":0.})
	metrics.travel_one_second=-bike.position.z
	check(bike.position.z< -3. and bike.speed>6.,"throttle produces real forward physical travel")
	var before:=bike.heading
	for _index in 20:await physics_frame;bike.simulate(1./60.,{"throttle":1.,"steer":1.})
	check(bike.heading<before,"right steering rotates the forward path to the right")
	before=bike.heading
	for _index in 20:await physics_frame;bike.simulate(1./60.,{"throttle":1.,"steer":-1.})
	check(bike.heading>before,"left steering rotates the forward path to the left")
	bike.position=Vector3.ZERO;bike.heading=0;bike.rotation=Vector3.ZERO;bike.speed=0;bike.velocity=Vector3.ZERO;bike._wake_ground_rest()
	wall=box(Vector3(0,1.5,-6),Vector3(10,3,.2));await frames(2)
	for _index in 160:await physics_frame;bike.simulate(1./60.,{"throttle":1.,"steer":0.})
	metrics.blocked_position_z=bike.position.z
	check(bike.position.z> -5.2 and bike.position.y<.2 and absf(bike.speed)<1.,"continuous collision stops the bike at a wall without tunneling or vertical launch")
	wall.queue_free();await frames(2)
	for _index in 220:await physics_frame;bike.simulate(1./60.,{})
	check(bike.resting and bike.speed==0.,"idle motorcycle reuses existing sleeping support instead of repeating full physics forever")
	var packet: Dictionary=bike.snapshot();packet.rotation=Vector3(0,PI*.5,0);packet.position=Vector3(10,.05,0);packet.seats={0:1};packet.driver=1;packet.seats_revision=bike.seats_revision+1
	other_bike.receive(packet);other_bike.render(1.);actor.vehicle_id=other_bike.vehicle_id;system.pose(actor)
	check(absf(angle_difference(other_bike.heading,other_bike.rotation.y))<.001 and absf(angle_difference(actor.rotation.y,other_bike.rotation.y))<.001,"remote interpolation uses the visible hull heading for the seated rider")
	await capture("rider")
	var original: Vector3=other_bike.spawn_position
	system.reset_round();await frames(2)
	check(other_bike.driver==0 and other_bike.seats.is_empty() and actor.vehicle_id.is_empty() and other_bike.position.is_equal_approx(original) and other_bike.hp==220.,"round reset clears every reservation and restores original bike position and health")
	var batch: Array=[]
	for _index in 6:batch.append(bike.network_state())
	metrics.snapshot_batch_bytes=var_to_bytes([1,game.br_generation,batch]).size()
	check(int(metrics.snapshot_batch_bytes)<1200,"a full six-bike update stays below the UDP MTU with RPC overhead reserved")
	var first: Array=bike.network_state();first[1]=Vector3(1,.05,0)
	var second: Array=other_bike.network_state();second[1]=Vector3(11,.05,0)
	system.remote_state(40,game.br_generation,[first]);system.remote_state(39,game.br_generation,[second])
	check(bike.destination==Vector3(1,.05,0) and other_bike.destination==Vector3(11,.05,0),"independent snapshot batches may arrive out of order without dropping untouched bikes")
	first[1]=Vector3(3,.05,0);system.remote_state(38,game.br_generation,[first])
	check(bike.destination==Vector3(1,.05,0),"an older movement packet cannot rewind the same bike")
	system.remote_state(41,game.br_generation-1,[first])
	check(bike.destination==Vector3(1,.05,0),"previous-round snapshots cannot move reset bikes")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"measurements":metrics,"scope":"Physical flat fixture with real character capsules, bike movement, walls, safe dismount, camera restoration and authority control validation. Network tested separately."}
	NavalStorage.write_json("res://work/br-motorbikes-validation.json",report);print("BR_MOTORBIKES_VALIDATION ",JSON.stringify(report))
	game.online=false;game.free();await process_frame;quit(0 if failures.is_empty() else 1)
