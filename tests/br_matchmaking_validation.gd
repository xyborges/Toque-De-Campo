extends SceneTree
const POOL=preload("res://modes/battle_royale/matchmaking/room_pool.gd")
const REGISTRY=preload("res://modes/battle_royale/matchmaking/room_registry.gd")
const BROKER=preload("res://modes/battle_royale/matchmaking/broker.gd")
var checks:=0
var failures: Array[String]=[]
var pid:=4000
var live: Dictionary={}
var killed: Array[int]=[]
var folder: String
var clock:=1000.
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func launch(_port: int,_id: String,_folder: String) -> int:pid+=1;live[pid]=true;return pid
func alive(id: int) -> bool:return bool(live.get(id,false))
func kill(id: int) -> void:killed.append(id);live[id]=false
func status(record: Dictionary,phase: String="waiting",accounts: Array=[],deadline: float=0.,ready: bool=true) -> void:
	REGISTRY.atomic_json(str(record.folder).path_join("status.json"),{"room_id":record.id,"pid":record.pid,"phase":phase,"accounts":accounts,"humans":accounts.size(),"ready":ready,"join_deadline":deadline,"heartbeat":clock})
func run() -> void:
	folder=ProjectSettings.globalize_path("res://work/br-matchmaking-test-"+str(Time.get_ticks_usec()))
	var pool:=POOL.new();pool.configure(folder,2,launch,alive,kill)
	var first: String="a".repeat(32);var second: String="b".repeat(32);var third: String="c".repeat(32)
	check(bool(pool.request(first,clock).ok),"authenticated account starts bounded room")
	check(pool.rooms.size()==1 and live.size()==1,"one request launches one child")
	var record: Dictionary=pool.rooms.values()[0]
	check(bool(pool.result(first,clock).pending),"route waits for physical map readiness")
	check(bool(pool.request(second,clock).ok) and pool.rooms.size()==1,"waiting participants share existing room")
	status(record);pool.pump(clock)
	var route: Dictionary=pool.result(first,clock)
	check(bool(route.ok) and int(route.port)==3020 and REGISTRY.is_hex(str(route.reservation),64),"ready room returns bounded port and opaque reservation")
	check(not REGISTRY.claim_at(record.folder,record.id,second,route.reservation,clock),"reservation belongs to authenticated account")
	check(not REGISTRY.claim_at(record.folder,record.id,first,"../"+route.reservation,clock),"path traversal token rejected")
	check(REGISTRY.claim_at(record.folder,record.id,first,route.reservation,clock),"reserved account admitted once")
	check(not REGISTRY.claim_at(record.folder,record.id,first,route.reservation,clock),"replayed admission rejected")
	status(record,"waiting",[first],clock+30.);pool.pump(clock)
	check(not pool.assignments.has(first),"admitted human replaces pending reservation")
	var second_route: Dictionary=pool.result(second,clock)
	status(record,"active",[first],clock-1.);pool.pump(clock)
	check(not REGISTRY.claim_at(record.folder,record.id,second,second_route.reservation,clock),"no admission after a match starts")
	check(bool(pool.request(third,clock).ok) and pool.rooms.size()==2,"active match creates independent next room")
	var other: Dictionary=pool.rooms[pool.assignments[third]]
	check(int(other.port)==3021 and other.id!=record.id,"rooms have independent identifiers and ports")
	var reroute: Dictionary=pool.result(second,clock)
	check(bool(reroute.pending) and pool.assignments[second]==other.id,"late reservation reroutes to waiting room")
	status(other,"waiting",[],clock+2.);pool.pump(clock)
	check(not bool(pool.request("d".repeat(32),clock).ok),"closing queue and process cap prevent unbounded child launch")
	clock+=3.;status(other,"waiting",[],clock-1.);pool.pump(clock)
	check(not bool(pool.result(third,clock).ok),"expired waiting window cannot receive participants")
	clock+=1.;status(other,"cancelled");pool.pump(clock)
	check(pool.rooms.size()==1 and int(other.pid) in killed,"cancelled empty child reclaimed")
	check(not bool(pool.request(first,clock).ok),"account already in active match cannot open duplicate session")
	var expiry_token:=REGISTRY.create_admission(record.folder,record.id,second,clock-1.)
	status(record,"waiting",[],0.);pool.pump(clock)
	check(not REGISTRY.claim_at(record.folder,record.id,second,expiry_token,clock),"expired token rejected")
	var deadline_token:=REGISTRY.create_admission(record.folder,record.id,second,clock+45.)
	status(record,"waiting",[],clock)
	check(not REGISTRY.claim_at(record.folder,record.id,second,deadline_token,clock),"deadline enforced before physics start transition")
	status(record,"waiting",[],0.,false)
	check(not REGISTRY.claim_at(record.folder,record.id,second,deadline_token,clock),"unready map rejects admission")
	clock+=100.;pool.pump(clock)
	check(pool.rooms.is_empty(),"stalled startup is bounded and stopped")
	pool.shutdown();check(pool.closed,"shutdown disables future allocations")
	check(not bool(pool.request(first,clock).ok),"closed broker cannot spawn children")
	var full:=POOL.new();full.configure(folder.path_join("capacity"),1,launch,alive,kill)
	for i in 12:check(bool(full.request(("%032x"%(i+1)),clock).ok),"capacity reservation %d"%i)
	check(not bool(full.request("f".repeat(32),clock).ok) and full.rooms.size()==1,"thirteenth request cannot oversubscribe room or launch beyond cap")
	full.shutdown()
	var broker:=BROKER.new();root.add_child(broker);await process_frame;broker.queue_free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Production bounded allocation, queue cutoff, one-use account-bound disk admissions, rerouting, expiration, child cleanup and router parse; fake child launcher, no VPN/server mutation."}
	var file:=FileAccess.open("res://work/br-matchmaking-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BR_MATCHMAKING_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
