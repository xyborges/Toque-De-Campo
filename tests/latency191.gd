extends SceneTree
const Diagnostics = preload("res://scripts/network_diagnostics.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func run() -> void:
	var diagnostics = Diagnostics.new()
	diagnostics.enabled=true
	check(diagnostics.next_pose_sequence(7,1)==1 and diagnostics.next_pose_sequence(7,1)==2,"outgoing poses increment within one life")
	check(diagnostics.next_pose_sequence(8,1)==1 and diagnostics.next_pose_sequence(7,2)==1,"actors and lives have independent sequences")
	check(diagnostics.accept_pose(7,1,1,1000000),"first sequenced pose is accepted")
	check(diagnostics.accept_pose(7,1,3,1100000),"missing unreliable pose does not block later movement")
	check(not diagnostics.accept_pose(7,1,2,1120000) and not diagnostics.accept_pose(7,1,3,1130000),"reordered and duplicate poses are rejected")
	check(diagnostics.accept_pose(8,1,1,1140000),"one actor's sequence never suppresses another actor")
	check(diagnostics.accept_pose(7,2,1,1150000) and not diagnostics.accept_pose(7,1,99,1160000),"a new life resets its sequence and rejects the previous life")
	check(not diagnostics.accept_pose(7,2,0,1170000),"legacy unsequenced updates cannot overwrite an established sequence")
	diagnostics.observe_input(21,1,1,2000000)
	diagnostics.observe_input(21,1,3,2100000)
	diagnostics.observe_input(21,1,2,2110000)
	var report: Dictionary = diagnostics.report("test",2200000)
	var input_row: Dictionary = {}
	for row: Dictionary in report.streams:
		if row.route=="input" and int(row.id)==21: input_row=row
	check(int(input_row.sequence_skips)==1 and int(input_row.stale_or_duplicate)==1,"input diagnostics distinguish skipped sequences and stale arrivals")
	check(int(input_row.arrival_interval_ms.n)==1 and is_equal_approx(float(input_row.silence_ms),100.),"arrival intervals and local silence use the monotonic receipt clock")
	for i in 700: diagnostics.observe_input(21,1,4+i,2200000+i*50000)
	report=diagnostics.report("test",40000000)
	for row: Dictionary in report.streams:
		if row.route=="input" and int(row.id)==21: input_row=row
	check(int(input_row.arrival_interval_ms.n)==Diagnostics.SAMPLE_LIMIT,"diagnostic sample storage stays bounded")
	diagnostics.forget(7)
	check(diagnostics.accept_pose(7,1,1,3000000),"disconnect clears ordering before peer identity reuse")
	diagnostics.clear()
	check(diagnostics.streams.is_empty() and diagnostics.received.is_empty() and diagnostics.sent.is_empty(),"session reset clears diagnostics and ordering")
	var quiet = Diagnostics.new()
	quiet.enabled=false
	quiet.accept_pose(4,1,1)
	quiet.observe_input(4,1,1)
	quiet.observe_broadcast("test",[Vector3.ZERO],1)
	check(quiet.streams.is_empty() and quiet.broadcasts.is_empty() and not quiet.accept_pose(4,1,1),"disabled metrics allocate no samples while ordering remains active")
	var game = load("res://tests/latency191_fixture.gd").new()
	root.add_child(game)
	diagnostics.tick(game.multiplayer,"test",1./60.,1000000)
	diagnostics.tick(game.multiplayer,"test",1./60.,1016667)
	diagnostics.tick(game.multiplayer,"test",1./60.,1050000)
	report=diagnostics.report("test",1050000)
	check(int(report.ticks)==3 and int(report.late_ticks)==1 and is_equal_approx(float(report.tick_gap_ms.max),33.333),"tick diagnostics detect a real receipt-clock stall independently of fixed simulation delta")
	diagnostics.observe_broadcast("pose",[Vector3.ZERO,1],2)
	report=diagnostics.report("test",1050000)
	check(int(report.broadcasts.pose.calls)==1 and int(report.broadcasts.pose.recipient_copies)==2 and int(report.broadcasts.pose.variant_payload_bytes)>0,"broadcast telemetry counts intended copies and payload estimates without storing packet contents")
	var actor = load("res://tests/latency191_pose_actor.gd").new()
	actor.peer_id=402;actor.life_id=1;actor.hp=100.;game.players[402]=actor
	game.remote_player_state(402,Vector3(3,0,0),.3,.2,"fal",90.,false,1,2,1,2,.4,3)
	game.remote_player_state(402,Vector3(2,0,0),.1,.1,"fal",95.,false,1,1,0,0,.1,2)
	check(actor.network_target==Vector3(3,0,0) and is_equal_approx(actor.network_yaw,.3) and actor.kills==2 and actor.iron_sights and is_equal_approx(actor.network_lean,.4),"the real receiver rejects the complete stale pose before position, aim, lean, or stats can regress")
	game.remote_player_state(402,Vector3(9,0,0),0.,0.,"fal",100.,false,2,0,0,0,0.,100)
	check(actor.network_target==Vector3(3,0,0),"a snapshot from an unannounced life cannot mutate the avatar")
	actor.life_id=2
	game.remote_player_state(402,Vector3(4,0,0),0.,0.,"fal",100.,false,2,0,0,0,0.,1)
	check(actor.network_target==Vector3(4,0,0),"an announced respawn accepts its first pose without the prior life's sequence")
	actor.free();game.players.clear();game.queue_free()
	var result := {"checks":checks,"failures":failures,"dtls_unchanged":true,"network_clients_started":false}
	NavalStorage.write_json("res://tests/latency191-results.json",result)
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
