extends "res://tests/war_network_fixture.gd"

# Reads the real grid but never changes its poles, circuits or wiring. All
# fracture state and visuals below are a test-only mirror at y + 40 metres.
const PoleModel=preload("res://tests/pole_fracture_model.gd")
const PoleLab=preload("res://tests/pole_fracture_visual_lab.gd")
var pole_model: RefCounted
var pole_lab: Node3D
var pole_ids: Array=[]
var pole_lookup: Dictionary={}
var pole_signature:=""
var pole_original:=""
var pole_first:=0
var pole_late:=0
var pole_acks: Dictionary={}
var pole_errors: Array[String]=[]

func _network_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pole-port="): return int(arg.trim_prefix("--pole-port="))
	return 39571

func init_pole_mirror() -> bool:
	if pole_model: return true
	if not is_instance_valid(power_grid): return false
	var circuit: Dictionary={}
	for candidate: Dictionary in power_grid.circuits:
		if bool(candidate.powered) and candidate.ids.size()>=3: circuit=candidate;break
	if circuit.is_empty(): pole_errors.append("no powered real circuit with three poles");return false
	pole_ids=circuit.ids.duplicate();pole_model=PoleModel.new();pole_model.authoritative=multiplayer.is_server()
	var grouped: Dictionary={};var points: Array=[];var connections: Array=[];var signature_text:="powered="+str(circuit.powered)+";"
	for id: String in pole_ids:
		var pole: WarPowerPole=power_grid.poles.get(id) as WarPowerPole
		if not is_instance_valid(pole): pole_errors.append("missing real pole "+id);return false
		var point: Vector3=pole.global_position
		var cell:=Vector2i(floori(point.x/90.),floori(point.z/90.))
		if not grouped.has(cell): grouped[cell]=[]
		var index: int=grouped[cell].size();grouped[cell].append(point);points.append(point)
		pole_lookup[id]={"cell":cell,"index":index,"position":point}
		signature_text+="%s:%d,%d,%d,%d,%d,%d,%d;"%[id,cell.x,cell.y,index,roundi(point.x*100),roundi(point.y*100),roundi(point.z*100),int(pole.functional)]
	for cell: Vector2i in grouped:
		if not pole_model.register(cell,grouped[cell]): pole_errors.append("model registration");return false
	for i in pole_ids.size()-1:
		var a: Dictionary=pole_lookup[pole_ids[i]];var b: Dictionary=pole_lookup[pole_ids[i+1]]
		connections.append([a.cell,a.index,b.cell,b.index])
	pole_signature=signature_text.sha256_text();pole_original=real_power_state()
	pole_lab=PoleLab.new();pole_lab.name="QA_RealPoleMirror";world_root.add_child(pole_lab);pole_lab.position=Vector3.UP*40.
	if not pole_lab.setup(points,connections): pole_errors.append("mirror presentation setup");return false
	for group: Dictionary in pole_lab.cells.values(): group.body.collision_layer=0
	return true

func real_power_state() -> String:
	# Compare the original circuit before and after the mirror event.
	var state: Array=[]
	for id: String in pole_ids:
		var pole:=power_grid.poles.get(id) as WarPowerPole
		if not is_instance_valid(pole): return "missing"
		state.append([id,pole.broken,pole.hp,pole.energized,pole.functional])
	return JSON.stringify(state)

func mirror_power_state() -> Array:
	var result: Array=[];var connected:=true
	for id: String in pole_ids:
		var ref: Dictionary=pole_lookup[id]
		connected=connected and not pole_model.broken.has(pole_model.key(ref.cell,ref.index))
		result.append(connected)
	return result

func make_pole_event(id: String,height: float) -> Dictionary:
	var ref: Dictionary=pole_lookup[id];var point: Vector3=ref.position+Vector3.UP*height
	var event: Dictionary=pole_model.shot(ref.cell,ref.index,120.,point,Vector3.RIGHT)
	if not event.is_empty() and not pole_lab.present(event): pole_errors.append("local mirror presentation")
	return event

@rpc("any_peer","call_remote","reliable")
func qa_real_poles_ready() -> void:
	if not multiplayer.is_server(): return
	var sender:=multiplayer.get_remote_sender_id()
	if not members.has(sender) or not init_pole_mirror(): return
	if pole_first==0:
		pole_first=sender
		var low:=make_pole_event(pole_ids[1],1.5);var high:=make_pole_event(pole_ids[2],6.2)
		if low.is_empty() or high.is_empty(): pole_errors.append("authority did not create mirror events");return
		rpc_id(sender,"qa_real_poles_event",low,pole_signature)
		rpc_id(sender,"qa_real_poles_event",high,pole_signature)
	elif pole_late==0:
		pole_late=sender;rpc_id(sender,"qa_real_poles_snapshot",pole_model.snapshot(),pole_signature)

@rpc("authority","call_remote","reliable")
func qa_real_poles_event(event: Dictionary,expected_signature: String) -> void:
	if not init_pole_mirror() or pole_signature!=expected_signature: pole_errors.append("real circuit signature differs");return
	if not pole_model.apply_event(event) or not pole_lab.present(event): pole_errors.append("mirror event rejected")
	_send_pole_ack()

@rpc("authority","call_remote","reliable")
func qa_real_poles_snapshot(events: Array,expected_signature: String) -> void:
	if not init_pole_mirror() or pole_signature!=expected_signature: pole_errors.append("late circuit signature differs");return
	for event: Dictionary in events:
		if not pole_model.apply_event(event) or not pole_lab.present(event,false): pole_errors.append("mirror snapshot rejected")
	_send_pole_ack()

func _send_pole_ack() -> void:
	if pole_model.broken.size()!=2: return
	var report: Dictionary=pole_report()
	rpc_id(1,"qa_real_poles_ack",report)

func pole_report() -> Dictionary:
	var heights: Array=[]
	if pole_model:
		for event: Dictionary in pole_model.snapshot(): heights.append(int(event.height_cm))
	heights.sort()
	var power: Array=mirror_power_state() if pole_model else []
	return {"heights":heights,"signature":pole_signature,"source_intact":real_power_state()==pole_original,"power":power,"errors":pole_errors.duplicate(),"source_poles":pole_ids.size()}

@rpc("any_peer","call_remote","reliable")
func qa_real_poles_ack(report: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender:=multiplayer.get_remote_sender_id()
	if sender!=pole_first and sender!=pole_late: return
	pole_acks[sender]=report
	if sender==pole_first and report.get("heights",[])==[150,620] and report.get("source_intact",false):
		var file:=FileAccess.open("res://work/real-pole-first-ready.txt",FileAccess.WRITE)
		if file: file.store_string("ready");file.close()
