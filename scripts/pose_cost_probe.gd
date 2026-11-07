extends RefCounted
## Phase 2 source-only benchmark probe. Disabled outside --p2-setter-probe.
static var enabled := "--p2-setter-probe" in OS.get_cmdline_user_args()
static var ik_enabled := "--p2-ik-probe" in OS.get_cmdline_user_args()
static var setters: Dictionary={}
static var ik_deltas: Dictionary={}

static func _bot(actor: Node) -> bool:
	return actor.get_meta("war_bot",false) and actor.game != null and actor.game.bot_director != null and actor.game.bot_director.bots.size()==28

static func write(actor: Node,target: Node3D,property: String,proposed: Variant,scope: String) -> void:
	if not enabled or not _bot(actor) or not is_instance_valid(target):return
	var old: Variant=target.get(property)
	var row: Array=setters.get(scope+"/"+property,[0,0,0])
	row[0]+=1
	if old==proposed:row[1]+=1
	elif old is Vector3 and proposed is Vector3 and old.is_equal_approx(proposed):row[2]+=1
	elif old is Basis and proposed is Basis and old.is_equal_approx(proposed):row[2]+=1
	elif old is Transform3D and proposed is Transform3D and old.is_equal_approx(proposed):row[2]+=1
	setters[scope+"/"+property]=row

static func before(arm: Node3D) -> Dictionary:
	return arm.get_meta("human_pose_cache",{}).duplicate() if ik_enabled else {}

static func after(actor: Node,arm: Node3D,previous: Dictionary,scope: String) -> void:
	if not ik_enabled or not _bot(actor) or previous.is_empty():return
	var current: Dictionary=arm.get_meta("human_pose_cache",{})
	if current.is_empty() or is_same(previous,current):return
	var row: Array=ik_deltas.get(scope,[0,0,0,0,0,0])
	row[0]+=1
	var diff: float=Vector3(previous.get("grip",Vector3.ZERO)).distance_to(Vector3(current.get("grip",Vector3.ZERO)))
	if diff<.0001:row[1]+=1
	elif diff<.001:row[2]+=1
	elif diff<.01:row[3]+=1
	else:row[4]+=1
	if Basis(previous.get("basis",Basis.IDENTITY)).is_equal_approx(Basis(current.get("basis",Basis.IDENTITY))):row[5]+=1
	ik_deltas[scope]=row

static func snapshot() -> Dictionary:
	return {"setters":setters.duplicate(true),"ik_deltas":ik_deltas.duplicate(true),"header":["writes","identical","approx_only"],"ik_header":["invalidated","grip_lt_0_1mm","grip_lt_1mm","grip_lt_1cm","grip_ge_1cm","basis_equal_approx"]}
