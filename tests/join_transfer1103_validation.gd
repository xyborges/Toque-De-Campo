extends SceneTree
# Pure transfer-state cases plus the production identity/deployment entrypoints.
# No map is built and no socket or production account is opened.
class ProbeGame extends WarGame:
	var validation_calls:=0
	func _physics_process(_delta: float) -> void:pass
	func _process(_delta: float) -> void:pass
	func _deployment_team_allowed(_id: int,_team: int) -> bool:
		validation_calls+=1
		return false

var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
	print(("PASS " if ok else "FAIL ")+label)
func run() -> void:
	var transfer:=WarJoinTransfer.new();var other:=WarJoinTransfer.new()
	check(not transfer.token.is_empty() and transfer.token!=other.token,"each admission has a distinct nonempty transfer identity")
	check(not transfer.accept(transfer.token,""),"ACK before any sent chunk is rejected")
	var first:=transfer.begin_chunk()
	check(not transfer.accept(other.token,first),"another transfer token cannot acknowledge this chunk")
	check(not transfer.accept(transfer.token,"incorrect"),"invalid chunk nonce cannot advance transfer")
	check(not transfer.acknowledged,"invalid acknowledgements leave progress unchanged")
	check(transfer.accept(transfer.token,first),"matching transfer and current nonce acknowledge once")
	check(not transfer.accept(transfer.token,first),"duplicate ACK is ignored")
	var second:=transfer.begin_chunk()
	check(second!=first and not transfer.acknowledged,"next chunk receives a new nonce and awaits a fresh ACK")
	check(not transfer.accept(transfer.token,first),"stale ACK from the previous chunk cannot advance next chunk")
	check(transfer.accept(transfer.token,second),"current chunk still accepts its valid ACK")
	transfer.failed=true;var failed_nonce:=transfer.begin_chunk()
	check(not transfer.accept(transfer.token,failed_nonce),"a failed transfer cannot be revived with a valid ACK")

	var timer:=WarJoinTransfer.new();timer.started=1000;timer.waiting_since=2000
	check(timer.expired(31999).is_empty(),"stall budget remains open just before30seconds")
	check(timer.expired(32000)=="progress","stall expires at30seconds without progress")
	timer.waiting_since=100000
	check(timer.expired(120999).is_empty(),"recent progress does not prematurely exhaust total budget")
	check(timer.expired(121000)=="total","total transfer budget expires at120seconds despite recent progress")
	timer.waiting_since=0
	check(timer.expired(121000)=="total","total limit also covers work outside ACK wait")

	var pending:=WarJoinTransfer.new()
	for id in [10,10,11,12,12,13,14]:pending.queue(id)
	check(pending.dirty.size()==5,"repeated mutations coalesce by actor rather than accumulating RPCs")
	var pair:=pending.take_pair()
	check(pair.size()==2 and pending.dirty.size()==3,"first drain removes at most two actors")
	# A removal followed by recreation of the same actor remains one dirty ID.
	# The sender resolves live actor state when it drains, not at event time.
	pending.queue(12);pending.queue(12)
	pending.queue(int(pair[0]));pending.queue(int(pair[0]))
	check(pending.dirty.size()==4,"remove/recreate and changes during outstanding batch keep one latest-state marker")
	var drained: Dictionary={};var largest:=0
	while not pending.dirty.is_empty():
		var chunk:=pending.take_pair();largest=maxi(largest,chunk.size())
		for id in chunk:drained[id]=true
	check(largest<=2 and drained.size()==4 and drained.has(pair[0]),"all deferred mutations drain through bounded pairs without losing a requeued actor")

	var game:=ProbeGame.new();game.set_meta("war_test",true);game.set_meta("war_visual_preview",true)
	root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.world_root=Node3D.new();game.add_child(game.world_root)
	var actor:=game._spawn_player(1,true,false,Vector3.ZERO) as WarPlayer
	actor.set_process(false);actor.set_physics_process(false)
	var state:={"team":0,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"stinger","pending":{},"last_gadget":-100.}
	game.baseline_loading=true;game.join_ready=false
	game.war_identity(1,state)
	check(game.members.has(1) and actor.war_team==0 and not game.join_ready,"production identity applies team while leaving a synchronizing local player unready")
	game.baseline_loading=false
	game.war_identity(1,state)
	check(game.join_ready,"normal identity behavior remains available after synchronization")
	var blocking:=WarJoinTransfer.new();game.loading_baselines[1]=blocking
	check(not game._deploy(1,0,"soldier","fal","stinger","base") and game.validation_calls==0,"production deployment rejects syncing actor before team/loadout validation")
	blocking.failed=true
	check(not game._deploy(1,0,"soldier","fal","stinger","base") and game.validation_calls==0,"failed transfer continues blocking deployment until removal/disconnect")
	game.loading_baselines.erase(1)
	game._deploy(1,0,"soldier","fal","stinger","base")
	check(game.validation_calls==1,"removing transfer reaches ordinary deployment validation again")
	game.baseline_loading=true;game.baseline_transfer="current";game.join_ready=false
	game.war_baseline_complete("previous")
	check(not game.join_ready and game.baseline_loading,"completion from a prior transfer cannot release the loading screen")
	game.war_baseline_complete("current")
	check(game.join_ready and not game.baseline_loading,"only completion matching current transfer releases readiness")
	game.closing=true;game.free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure transfer identity/chunk ACK validation, exact stall/total deadlines, coalescing and bounded drain; actual War identity/deployment/completion methods on one local avatar without map or sockets. Does not replace two-client DTLS, disconnect/reconnect, graphical pacing or server integration tests."}
	NavalStorage.write_json("res://work/join-transfer1103-validation.json",report);print("JOIN_TRANSFER1103 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
