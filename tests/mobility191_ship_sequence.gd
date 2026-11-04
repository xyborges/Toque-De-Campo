extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func capture(ship: WarShip) -> Dictionary:
	return {"sequence":ship.received_state_sequence,"pose":ship.destination,"hp":ship.hp,"destroyed":ship.destroyed,"team":ship.team,"ammo":ship.naval_ammo.duplicate(true),"reserve":ship.naval_reserve.duplicate(true),"waits":ship.naval_waits.duplicate(true),"weapon":ship.naval_weapon,"velocity":ship.velocity,"clock":ship.server_clock,"sample_clock":ship.sample_clock,"motion":ship.motion.samples.duplicate(true),"gun_state":ship.get_meta("gun_state",{}).duplicate(true)}
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	for kind in ["naval_assault_0","naval_frigate_0","naval_assault_1","naval_frigate_1"]:
		var ship:=WarShip.new();ship.kind=kind;ship.vehicle_id="sequence191_"+kind;stage.add_child(ship)
		var state:=ship.snapshot();state.position=Vector3(1,0,0);state.time=1.;ship.receive(state)
		check(ship.destination==state.position and ship.motion.samples.size()==1,kind+": legacy packet accepted before sequenced stream")
		state.sequence=10;state.position=Vector3(10,0,0);state.time=10.;state.velocity=Vector3(2,0,3);state.slot=1
		var packed: PackedFloat32Array=state.naval.duplicate();packed[0]=17;packed[1]=18;packed[2]=.75;packed[3]=.2;packed[4]=.1;state.naval=packed
		ship.receive(state);var accepted:=capture(ship)
		check(ship.received_state_sequence==10 and ship.velocity==state.velocity and ship.naval_weapon==str(ship.hull.spec.weapons[1]),kind+": fresh packet updates full naval state")
		var old:=state.duplicate(true);old.sequence=9;old.position=Vector3(999,0,0);old.hp=1;old.destroyed=true;old.time=11.;old.velocity=Vector3(-5,0,0);old.team=1-ship.team;old.slot=0
		packed=old.naval.duplicate();packed[0]=1;packed[1]=2;packed[2]=3;packed[3]=-.7;old.naval=packed
		ship.receive(old);check(capture(ship)==accepted,kind+": older packet cannot partially update naval state or interpolation")
		old.sequence=10;ship.receive(old);check(capture(ship)==accepted,kind+": duplicate sequence rejected before naval fields")
		old.erase("sequence");ship.receive(old);check(capture(ship)==accepted,kind+": legacy packet cannot overwrite sequenced naval stream")
		old.sequence=100;old.seats_revision=-1;ship.receive(old);check(capture(ship)==accepted,kind+": old seat generation cannot advance sequence or naval state")
		state.sequence=11;state.time=11.;state.position=Vector3(11,0,0);ship.receive(state)
		check(ship.received_state_sequence==11 and ship.destination==state.position,kind+": current generation survives late high sequence from previous seats")
		state.sequence=12;state.time=12.;state.destroyed=true;ship.receive(state)
		state.sequence=13;state.time=13.;state.destroyed=false;state.position=Vector3(13,0,0);ship.receive(state);accepted=capture(ship)
		old.seats_revision=ship.seats_revision;old.sequence=12;old.time=14.;ship.receive(old)
		check(ship.received_state_sequence==13 and not ship.destroyed and ship.motion.samples.size()==1 and capture(ship)==accepted,kind+": respawn retains sequence and rejects stale naval destruction state")
		ship.queue_free();await process_frame
	stage.queue_free();await process_frame
	var result: Dictionary={"checks":checks,"failures":failures,"fixture":"All four actual WarShip receivers, complete naval state and interpolation samples across out-of-order/duplicate/legacy packets and respawn."}
	NavalStorage.write_json("res://tests/mobility191-ship-sequence-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
