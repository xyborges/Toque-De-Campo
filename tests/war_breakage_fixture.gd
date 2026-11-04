extends "res://tests/war_network_fixture.gd"

# Test-only integration with an actual WarGame session. It does not replace
# the game's tree or pole generators and must never be shipped as gameplay.
var breakage_lab: Node3D
var breakage_first:=0
var breakage_second:=0
var breakage_acks: Dictionary={}
var real_tree_index: RefCounted
var real_tree_acks: Dictionary={}
var real_tree_errors: Array[String]=[]
var real_tree_contact_verified:=false
var real_tree_contact_vehicles: Array[String]=[]
var real_tree_blast_events: Array[Dictionary]=[]
var qa_breakage_enabled:=true
var qa_seen_trees: Dictionary={}
var qa_camera: Camera3D
var qa_targets: Array[Vector3]=[]
var breakage_port:=0

func _build_desert() -> void:
	world_root.set_meta("qa_breakable_index",true)
	super._build_desert()

func _network_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--breakage-port="): return int(arg.trim_prefix("--breakage-port="))
	return 39569

func install_breakage_lab() -> void:
	if is_instance_valid(breakage_lab): return
	breakage_lab=load("res://tests/impact_breakage_visual_prototype.gd").new();breakage_lab.name="BreakageLab";world_root.add_child(breakage_lab)
	var p:=WarTerrain.point(30,-370);var cell: Vector2i=breakage_lab.model.cell_for(p)
	breakage_lab.add_cell(cell,[{"kind":"pole","position":p},{"kind":"thin","position":p+Vector3(4,0,0)}])

func install_tree_index() -> void:
	if real_tree_index: return
	real_tree_index=load("res://tests/war_tree_index.gd").new()
	var stats: Dictionary=real_tree_index.build(world_root,DisplayServer.get_name()!="headless")
	if int(stats.trees)<4000 or int(stats.unmatched_visuals)>0 or int(stats.ambiguous_ids)>0: real_tree_errors.append("tree index incomplete or ambiguous")
	if DisplayServer.get_name()!="headless":
		var debris: Node3D=load("res://tests/war_tree_debris.gd").new();debris.index=real_tree_index;debris.game=self;world_root.add_child(debris)
		real_tree_index.presentation=weakref(debris)

func environment_blast(point: Vector3,amount: float,radius: float) -> void:
	# Exercise the existing game explosion entry point. The energy parameter
	# remains a test value; weapon-specific calibre calibration is still open.
	super.environment_blast(point,amount,radius)
	if multiplayer.is_server() and real_tree_index and qa_breakage_enabled:
		real_tree_blast_events=real_tree_index.explosion(point,amount,radius)

func drive_into_real_tree(kind: String) -> Dictionary:
	# This test owns a vehicle that uses the regular simulate() and step logic;
	# its adapter records the contact without changing the production manager.
	await get_tree().physics_frame
	var space:=world_root.get_world_3d().direct_space_state
	var chosen: Dictionary={}
	var ordered: Array=real_tree_index.cells.keys()
	ordered.sort_custom(func(a: Vector2i,b: Vector2i):return a.x<b.x or (a.x==b.x and a.y<b.y))
	for cell: Vector2i in ordered:
		for i in real_tree_index.cells[cell].size():
			if real_tree_index.model.cells[cell][i].kind!="thin": continue
			if real_tree_index.model.broken.has(real_tree_index.model.key(cell,i)): continue
			if qa_seen_trees.has(real_tree_index.model.key(cell,i)): continue
			var entry: Dictionary=real_tree_index.cells[cell][i];var point: Vector3=entry.position
			if absf(point.x)>1000 or absf(point.z)>1000: continue
			var start:=point+Vector3(-7,0,0)
			if absf(WarTerrain.height_at(start.x,start.z)-point.y)>.15: continue
			if absf(WarTerrain.height_at(point.x-3.5,point.z)-point.y)>.15: continue
			var ray:=PhysicsRayQueryParameters3D.create(start+Vector3.UP*1.3,point+Vector3.UP*1.3,1)
			var hit:=space.intersect_ray(ray)
			if hit.is_empty() or not hit.collider is StaticBody3D: continue
			var body: StaticBody3D=hit.collider
			if body.shape_owner_get_owner(body.shape_find_owner(int(hit.shape)))!=entry.shape: continue
			chosen={"cell":cell,"index":i,"position":point};break
		if not chosen.is_empty(): break
	if chosen.is_empty(): real_tree_errors.append("no clear tree approach");return {}
	qa_targets.append(chosen.position)
	if is_instance_valid(qa_camera):
		qa_camera.global_position=Vector3(chosen.position)+Vector3(-14,6,18)
		qa_camera.look_at(Vector3(chosen.position)+Vector3.UP*2.)
	var adapter: Node3D=load("res://tests/war_tree_contact_parent.gd").new();adapter.game=self;adapter.tree_index=real_tree_index;adapter.apply_break=qa_breakage_enabled;world_root.add_child(adapter)
	var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="qa_tree_contact_"+kind;adapter.add_child(vehicle)
	var target: Vector3=chosen.position;var start:=target+Vector3(-7,0,0)
	start.y=WarTerrain.height_at(start.x,start.z)+.08;vehicle.global_position=start;vehicle.heading=-PI*.5;vehicle.speed=8.
	for tick in 120:
		await get_tree().physics_frame
		vehicle.simulate(1./60.,{"throttle":.4,"steer":0.,"aim":target+Vector3.UP})
		if not adapter.events.is_empty(): break
	var result: Dictionary=adapter.events[0] if not adapter.events.is_empty() else {}
	if result.is_empty(): real_tree_errors.append("vehicle failed to collide with tree")
	else:
		real_tree_contact_verified=true;real_tree_contact_vehicles.append(kind)
		qa_seen_trees[real_tree_index.model.key(result.cell,result.index)]=true
	adapter.queue_free()
	return result

@rpc("any_peer","call_remote","reliable")
func qa_breakage_ready() -> void:
	if not multiplayer.is_server(): return
	var sender:=multiplayer.get_remote_sender_id()
	if not members.has(sender): return
	install_breakage_lab()
	if breakage_first==0:
		breakage_first=sender
		install_tree_index()
		var p:=WarTerrain.point(30,-370);var cell: Vector2i=breakage_lab.model.cell_for(p)
		var event: Dictionary=breakage_lab.model.impact(cell,0,30000.,4.,Vector3.RIGHT)
		if event.is_empty(): return
		breakage_lab.accept(event);rpc_id(sender,"qa_breakage_event",event)
		for blast: Dictionary in breakage_lab.model.explosion(p+Vector3(4,0,0),200.,4.):
			breakage_lab.accept(blast);rpc_id(sender,"qa_breakage_event",blast)
		var ordered: Array=real_tree_index.cells.keys()
		ordered.sort_custom(func(a: Vector2i,b: Vector2i):return a.x<b.x or (a.x==b.x and a.y<b.y))
		for kind in ["guarani","bmp2","abrams","t90"]:
			var tree_event: Dictionary=await drive_into_real_tree(kind)
			if tree_event.is_empty(): real_tree_errors.append("tree impact failed: "+kind);return
			rpc_id(sender,"qa_real_tree_event",tree_event,real_tree_index.signature)
		var second: Dictionary={}
		for key: Vector2i in ordered:
			for i in real_tree_index.model.cells[key].size():
				if real_tree_index.model.cells[key][i].kind in ["thin","burnt"] and not real_tree_index.model.broken.has(real_tree_index.model.key(key,i)): second={"cell":key,"index":i};break
			if not second.is_empty(): break
		if second.is_empty(): real_tree_errors.append("no tree for blast");return
		var where: Vector3=real_tree_index.model.cells[second.cell][second.index].position
		vehicle_system.explode(0,where,200.,.2,"tank","qa:tree:blast")
		if real_tree_blast_events.size()!=1: real_tree_errors.append("tree blast failed");return
		rpc_id(sender,"qa_real_tree_event",real_tree_blast_events[0],real_tree_index.signature)
	elif breakage_second==0:
		breakage_second=sender;rpc_id(sender,"qa_breakage_snapshot",breakage_lab.model.snapshot())
		rpc_id(sender,"qa_real_tree_snapshot",real_tree_index.model.snapshot(),real_tree_index.signature)

@rpc("authority","call_remote","reliable")
func qa_breakage_event(event: Dictionary) -> void:
	install_breakage_lab()
	if breakage_lab.model.apply_event(event): breakage_lab.accept(event)
	rpc_id(1,"qa_breakage_ack",breakage_lab.model.broken.size())

@rpc("authority","call_remote","reliable")
func qa_breakage_snapshot(events: Array) -> void:
	install_breakage_lab()
	for event: Dictionary in events:
		if breakage_lab.model.apply_event(event): breakage_lab.accept(event)
	rpc_id(1,"qa_breakage_ack",breakage_lab.model.broken.size())

@rpc("any_peer","call_remote","reliable")
func qa_breakage_ack(count: int) -> void:
	if not multiplayer.is_server(): return
	var sender:=multiplayer.get_remote_sender_id();breakage_acks[sender]=count
	_maybe_first_ready(sender)

@rpc("authority","call_remote","reliable")
func qa_real_tree_event(event: Dictionary,expected_signature: String) -> void:
	install_tree_index()
	if real_tree_index.signature!=expected_signature: real_tree_errors.append("map signature mismatch")
	elif not real_tree_index.apply(event): real_tree_errors.append("tree event rejected")
	rpc_id(1,"qa_real_tree_ack",real_tree_index.model.broken.size(),real_tree_index.signature)

@rpc("authority","call_remote","reliable")
func qa_real_tree_snapshot(events: Array,expected_signature: String) -> void:
	install_tree_index()
	if real_tree_index.signature!=expected_signature: real_tree_errors.append("map signature mismatch")
	else:
		for event: Dictionary in events:
			if not real_tree_index.apply(event,false): real_tree_errors.append("tree snapshot rejected")
	rpc_id(1,"qa_real_tree_ack",real_tree_index.model.broken.size(),real_tree_index.signature)

@rpc("any_peer","call_remote","reliable")
func qa_real_tree_ack(count: int,client_signature: String) -> void:
	if not multiplayer.is_server(): return
	var sender:=multiplayer.get_remote_sender_id()
	if client_signature!=real_tree_index.signature: real_tree_errors.append("client tree signature mismatch")
	real_tree_acks[sender]=count;_maybe_first_ready(sender)

func _maybe_first_ready(sender: int) -> void:
	if sender==breakage_first and int(breakage_acks.get(sender,0))==2 and int(real_tree_acks.get(sender,0))==5:
		var file:=FileAccess.open("res://work/war-breakage-first-ready.txt",FileAccess.WRITE);file.store_string("ready");file.close()
