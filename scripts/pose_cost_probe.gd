extends RefCounted
## Diagnostic only. A nested scope closes on every return, without wrapping
## gameplay calls or changing their order. No actor references are retained.
static var enabled := "--pose-cost-probe" in OS.get_cmdline_user_args()
static var collecting := false
static var stride := 17
static var stack: Array = []
static var totals: Dictionary = {}
static var events: Dictionary = {}
static var observer_usec := 0
static var setter_probe := "--pose-setters" in OS.get_cmdline_user_args()
static var setters: Dictionary = {}
static var ik_deltas: Dictionary = {}
static func record_setter(actor: Node,node: Node3D,field: String,proposed: Variant,scope_name: String) -> void:
	if not collecting or not setter_probe or not is_instance_valid(node) or not actor.get_meta("war_bot",false):return
	var old: Variant=node.get(field)
	var key:=role_for(actor)+"/"+scope_name+"/"+field
	var counts: Array=setters.get(key,[0,0,0])
	counts[0]+=1
	if old==proposed:counts[1]+=1
	elif old is Vector3 and proposed is Vector3 and old.is_equal_approx(proposed):counts[2]+=1
	elif old is Basis and proposed is Basis and old.is_equal_approx(proposed):counts[2]+=1
	elif old is Transform3D and proposed is Transform3D and old.is_equal_approx(proposed):counts[2]+=1
	setters[key]=counts

static func record_ik_delta(actor: Node,old: Dictionary,new: Dictionary) -> void:
	if not collecting or not setter_probe or not sampled(actor) or old.is_empty() or new.is_empty():return
	var key:=role_for(actor)
	var counts: Array=ik_deltas.get(key,[0,0,0,0,0,0,0])
	counts[0]+=1
	var gap: float=Vector3(old.get("grip",Vector3.ZERO)).distance_to(Vector3(new.get("grip",Vector3.ZERO)))
	if gap<.0001:counts[1]+=1
	if gap<.001:counts[2]+=1
	if gap<.01:counts[3]+=1
	if gap>=.01:counts[4]+=1
	if Basis(old.get("basis",Basis.IDENTITY)).is_equal_approx(Basis(new.get("basis",Basis.IDENTITY))):counts[5]+=1
	if Transform3D(old.get("arm",Transform3D.IDENTITY)).is_equal_approx(Transform3D(new.get("arm",Transform3D.IDENTITY))):counts[6]+=1
	ik_deltas[key]=counts

class Scope extends RefCounted:
	var probe: GDScript
	var role: String
	var section_open := false
	func section(label: String) -> void:
		if section_open: probe.close_scope()
		probe.open_scope(role+"/"+label)
		section_open=true
	func _notification(what: int) -> void:
		if what==NOTIFICATION_PREDELETE and probe:
			if section_open: probe.close_scope()
			probe.close_scope()

static func role_for(actor: Node) -> String:
	var authority: bool=is_instance_valid(actor.game) and actor.game.multiplayer.is_server()
	return ("authority" if authority else "replica")+("_local" if actor.is_local else ("_bot" if actor.get_meta("war_bot",false) else "_remote"))

static func scope(actor: Node,label: String) -> Scope:
	if not sampled(actor):return null
	var began:=Time.get_ticks_usec()
	var value:=Scope.new()
	value.probe=load("res://scripts/pose_cost_probe.gd")
	value.role=role_for(actor)
	open_scope(value.role+"/"+label)
	observer_usec+=Time.get_ticks_usec()-began
	return value

static func open_scope(label: String) -> void:
	stack.append([label,Time.get_ticks_usec(),0])

static func close_scope() -> void:
	var now:=Time.get_ticks_usec()
	var value: Array=stack.pop_back()
	var elapsed: int=now-int(value[1])
	var exclusive: int=elapsed-int(value[2])
	var state: Array=totals.get(value[0],[0,0,0,0])
	state[0]+=1;state[1]+=elapsed;state[2]+=exclusive;state[3]=maxi(state[3],elapsed)
	totals[value[0]]=state
	if not stack.is_empty():stack[-1][2]+=elapsed
	observer_usec+=Time.get_ticks_usec()-now

static func count(actor: Node,label: String) -> void:
	if not sampled(actor):return
	var now:=Time.get_ticks_usec()
	var key:=role_for(actor)+"/"+label
	events[key]=int(events.get(key,0))+1
	observer_usec+=Time.get_ticks_usec()-now

static func sampled(actor: Node) -> bool:
	return collecting and posmod(Engine.get_physics_frames()+int(actor.peer_id),stride)==0

static func cache_before(arm: Node3D) -> Dictionary:
	return arm.get_meta("human_pose_cache",{})

static func cache_after(actor: Node,arm: Node3D,before: Dictionary) -> void:
	# HumanRig replaces the dictionary on a solve, leaves it untouched on
	# cache return. A degenerate solve with no write is reported separately.
	var after: Dictionary=arm.get_meta("human_pose_cache",{})
	record_ik_delta(actor,before,after)
	if after.is_empty():count(actor,"ik.no_cache_or_degenerate")
	elif before.is_empty():count(actor,"ik.cold")
	elif is_same(before,after):count(actor,"ik.reused_or_degenerate")
	else:
		count(actor,"ik.invalidated")
		for key in ["weapon","grip","basis","proportion","firearm","grabbing","arm"]:
			if before.get(key)!=after.get(key):count(actor,"ik.changed_"+key)

static func reset() -> void:
	assert(stack.is_empty())
	totals.clear();events.clear();observer_usec=0;setters.clear();ik_deltas.clear()

static func report(ticks: int,frames: int) -> Dictionary:
	var rows: Dictionary={}
	for key in totals:
		var v: Array=totals[key]
		rows[key]={"sampled_calls":v[0],"estimated_calls":v[0]*stride,"sampled_inclusive_ms":v[1]*.001,"sampled_exclusive_ms":v[2]*.001,"inclusive_ms_per_tick":v[1]*stride*.001/maxi(1,ticks),"exclusive_ms_per_tick":v[2]*stride*.001/maxi(1,ticks),"inclusive_ms_per_frame":v[1]*stride*.001/maxi(1,frames),"exclusive_ms_per_frame":v[2]*stride*.001/maxi(1,frames),"max_sampled_call_ms":v[3]*.001}
	return {"scopes":rows,"setter_counts":setters.duplicate(true),"ik_delta_buckets":ik_deltas.duplicate(true),"sampled_events":events.duplicate(),"stride":stride,"observer_accounted_ms":observer_usec*.001,"open_scopes":stack.size(),"ticks":ticks,"frames":frames,"units":"sampled wall-clock, estimates expanded by stride; nested observer cost included; calibrate with off/on pairs"}
