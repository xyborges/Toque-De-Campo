extends SceneTree
const PROBE=preload("res://scripts/pose_cost_probe.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func nested(actor: Node) -> void:
	var _outer=PROBE.scope(actor,"outer")
	_outer.section("phase")
	inner(actor)
	return
func inner(actor: Node) -> void:
	var _inner=PROBE.scope(actor,"inner")
	var total:=0
	for i in 500:total+=i
func run() -> void:
	var game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game)
	PROBE.stride=1;PROBE.collecting=true;PROBE.reset()
	nested(game.local_player)
	if not PROBE.stack.is_empty():failures.append("scope lifetime did not close on return")
	var r=PROBE.report(1,1)
	var rows: Dictionary=r.scopes
	if rows.size()!=3:failures.append("missing scopes")
	if rows.get("authority_local/outer",{}).get("sampled_calls",0)!=1:failures.append("wrong nesting count")
	var original: Dictionary={"test":1};var alias: Dictionary=original
	if not is_same(original,alias) or is_same(original,original.duplicate()):failures.append("dictionary identity unavailable")
	PROBE.collecting=false
	var actor=game.players[2]
	var before=actor.global_transform
	actor._physics_process(1./60.)
	if not PROBE.stack.is_empty():failures.append("disabled scope")
	print("POSE_PROBE_CHECK ",JSON.stringify({"failures":failures,"report":r,"finite":actor.global_position.is_finite(),"before":str(before)}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
