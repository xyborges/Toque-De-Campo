extends SceneTree

# Functional Jolt contact checks only. Not a moving-route benchmark, network
# acceptance, or a reason to generate visual grass on a production headless server.
const FIXTURE=preload("res://tests/war_optics_fixture.gd")
const STREAM=preload("res://modes/war/scripts/grass_stream.gd")
const ASSETS=preload("res://modes/war/scripts/grass_assets.gd")
const KINDS:=["guarani","bmp2","abrams","t90"]
var game: WarGame
var floor_body: StaticBody3D
var bodies: Array[CharacterBody3D]=[]
var starts: Array[Transform3D]=[]
var failures: Array[String]=[]
var checks:=0
var samples: Array[Dictionary]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)

func contact_objects(parent: Node) -> int:
	var count:=1 if parent is CollisionObject3D or parent is CollisionShape3D or parent is CollisionPolygon3D else 0
	for node in parent.get_children(): count+=contact_objects(node)
	return count

func add_floor() -> void:
	floor_body=StaticBody3D.new();floor_body.name="GrassContactFloor"
	floor_body.collision_layer=1;floor_body.collision_mask=0
	floor_body.position=Vector3(200,-.25,200)
	var shape:=BoxShape3D.new();shape.size=Vector3(140,.5,40)
	var volume:=CollisionShape3D.new();volume.shape=shape;floor_body.add_child(volume)
	game.world_root.add_child(floor_body)

func prepare_body(body: CharacterBody3D,point: Vector3) -> void:
	body.set_physics_process(false);body.set_process(false)
	body.global_transform=Transform3D(Basis.IDENTITY,point)
	body.velocity=Vector3.ZERO;body.reset_physics_interpolation()
	bodies.append(body);starts.append(body.global_transform)

func sweep(index: int,label: String) -> Dictionary:
	var body:=bodies[index]
	body.global_transform=starts[index];body.velocity=Vector3.ZERO
	var contact:=body.move_and_collide(Vector3.DOWN*2.0)
	check(contact!=null,label+": supported by physical floor")
	if contact==null: return {"hit":false,"body":str(body.name)}
	check(contact.get_collider()==floor_body,label+": grass is never support collider")
	check(contact.get_normal().y>.99,label+": floor normal remains upward")
	check(absf(contact.get_position().y)<.005,label+": hit is at terrain surface, below blade tips")
	return {"hit":true,"body":str(body.name),"origin":body.global_position,"travel":contact.get_travel(),"position":contact.get_position(),"normal":contact.get_normal(),"collider":contact.get_collider_id()}

func run() -> void:
	game=FIXTURE.new();root.add_child(game)
	await process_frame;await physics_frame;await process_frame
	game.set_physics_process(false);game.set_process(false)
	game.vehicle_system.set_physics_process(false);game.vehicle_system.set_process(false)
	add_floor()
	var actor:=game.local_player as WarPlayer
	actor.stance.reset(actor);actor.body_collision.disabled=false
	prepare_body(actor,Vector3(150,1,200))
	var bot:=game.players[2] as WarPlayer
	bot.set_meta("war_bot",true);bot.stance.reset(bot);bot.body_collision.disabled=false
	prepare_body(bot,Vector3(170,1,200))
	for i in KINDS.size():
		var vehicle:=WarVehicle.new();vehicle.kind=KINDS[i];vehicle.vehicle_id="grass_contact_"+KINDS[i]
		vehicle.position=Vector3(190+i*20,1,200)
		game.vehicle_system.add_child(vehicle)
		prepare_body(vehicle,vehicle.position)
	await physics_frame;await process_frame
	var count_before:=contact_objects(game.world_root)
	var original: Array[Dictionary]=[]
	for i in bodies.size(): original.append(sweep(i,"before "+str(bodies[i].name)))
	# Restore all starts before attaching the actual runtime grass cell.
	for i in bodies.size(): bodies[i].global_transform=starts[i]
	var stream:=STREAM.new();game.world_root.add_child(stream)
	stream.world=game.world_root;stream.mesh=ASSETS.blade_mesh(2);stream.material=ASSETS.grass_material(2)
	var poses: Array[Transform3D]=[]
	for start in starts:
		# Cover the contact footprint rather than relying on one central blade.
		for x in range(-2,3):
			for z in range(-3,4): poses.append(Transform3D(Basis.IDENTITY,Vector3(start.origin.x+x*2,0,start.origin.z+z*2)))
	var patch:=ASSETS.create_cell(stream.mesh,stream.material,poses.size())
	for i in poses.size():patch.multimesh.set_instance_transform(i,poses[i])
	game.world_root.add_child(patch)
	check(is_instance_valid(patch),"real runtime grass cell is present")
	if is_instance_valid(patch): check(contact_objects(patch)==0,"runtime grass has no bodies, areas or collision shapes")
	check(contact_objects(game.world_root)==count_before,"adding dense grass leaves physics object count unchanged")
	await physics_frame;await process_frame
	for i in bodies.size():
		var after:=sweep(i,"after "+str(bodies[i].name));var before:=original[i]
		if bool(before.get("hit",false)) and bool(after.get("hit",false)):
			check(Vector3(before.origin).distance_to(after.origin)<.0001,"same resting height "+str(bodies[i].name))
			check(Vector3(before.travel).distance_to(after.travel)<.0001,"same swept movement "+str(bodies[i].name))
			check(int(before.collider)==int(after.collider),"same physical support "+str(bodies[i].name))
			check(Vector3(before.normal).distance_to(after.normal)<.0001,"same support normal "+str(bodies[i].name))
		samples.append({"body":str(bodies[i].name),"before":before,"after":after})
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"grass_instances":poses.size(),"contact_objects_before":count_before,"contact_objects_after":contact_objects(game.world_root),"physics_engine":ProjectSettings.get_setting("physics/3d/physics_engine"),"note":"Real player/bot/four vehicle CharacterBody sweeps onto a static floor before/after actual grass MultiMesh. No moving-route, headless production-allocation or multiplayer claim."}
	NavalStorage.write_json("res://work/nova-grass-contact-physics.json",report)
	print("NOVA_GRASS_CONTACT_PHYSICS ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures.size(),"bodies":bodies.size()}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
