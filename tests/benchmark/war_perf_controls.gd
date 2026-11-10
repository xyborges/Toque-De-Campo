extends "res://tests/benchmark/war_1080p_benchmark.gd"
# Destructive QA ablations only. Never use these controls in a playable build.
const CONTROLS=["baseline","no-monitoring","no-hitbox-space","no-presentation","no-bot-contact","steps-2","steps-3"]
var control:="baseline"
var applied: Dictionary={}
var simulation_start:=0.
var wall_start:=0
var tick_start:=0
var controlled_areas:=0
var contact_pairs:=0
var control_failures: Array[String]=[]

class ProbePlayer extends WarPlayer:
	var skip_pose:=false
	func _animate_walk() -> void:
		if skip_pose and bool(get_meta("war_bot",false)):return
		super._animate_walk()

class ProbeGame extends WarGame:
	var skip_pose:=false
	func _new_player() -> GamePlayer:
		var actor:=ProbePlayer.new();actor.skip_pose=skip_pose
		return actor

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--control="):control=arg.trim_prefix("--control=")
	super._initialize()

func run() -> void:
	if control not in CONTROLS:fail("unknown control");return
	if control.begins_with("steps-"):Engine.max_physics_steps_per_frame=int(control.trim_prefix("steps-"))
	if Engine.physics_ticks_per_second!=60:fail("requires 60 Hz");return
	await super.run()

func _make_game() -> WarGame:
	var probe:=ProbeGame.new();probe.skip_pose=control=="no-presentation"
	return probe

func _apply_controls() -> void:
	for id in game.bot_director.bots:
		var actor:=game.players.get(id) as WarPlayer
		if not is_instance_valid(actor) or applied.has(actor.get_instance_id()):continue
		applied[actor.get_instance_id()]=true
		if control=="no-bot-contact":
			for other_id in game.bot_director.bots:
				var other:=game.players.get(other_id) as WarPlayer
				if is_instance_valid(other) and other!=actor:
					actor.add_collision_exception_with(other)
					other.add_collision_exception_with(actor)
		if control in ["no-monitoring","no-hitbox-space"]:
			for area: Area3D in actor.hit_regions.values():
				if control=="no-monitoring":area.monitoring=false;area.monitorable=false
				else:PhysicsServer3D.area_set_space(area.get_rid(),RID())
				controlled_areas+=1

func _after_deploy() -> void:
	_apply_controls()
	# Request focus before warmup only; every measured frame is still validated.
	DisplayServer.window_move_to_foreground()

func _sample_extra() -> void:
	_apply_controls()
	# Sample the actual measurement interval (after warmup), not loading time.
	if wall_start==0:
		wall_start=Time.get_ticks_usec();simulation_start=game.war_clock;tick_start=Engine.get_physics_frames()

func _result_extra() -> Dictionary:
	if control in ["no-monitoring","no-hitbox-space"]:
		for id in game.bot_director.bots:
			var actor:=game.players.get(id) as WarPlayer
			for area: Area3D in actor.hit_regions.values():
				if control=="no-monitoring" and area.monitorable:control_failures.append("monitorable restored")
				if control=="no-hitbox-space" and PhysicsServer3D.area_get_space(area.get_rid()).is_valid():control_failures.append("hitbox reentered space")
	if control=="no-bot-contact":
		for id in game.bot_director.bots:
			var actor:=game.players.get(id) as WarPlayer
			for other_id in game.bot_director.bots:
				if id==other_id:continue
				if game.players[other_id] in actor.get_collision_exceptions():contact_pairs+=1
				else:control_failures.append("missing exception")
	var wall:=float(Time.get_ticks_usec()-wall_start)*.000001
	var sim:=game.war_clock-simulation_start
	return {"control":control,"control_failures":control_failures,"controlled_areas":controlled_areas,"directed_contact_exceptions":contact_pairs,"simulation_seconds":sim,"simulation_wall_ratio":sim/wall if wall>0 else 0.,"measurement_wall_seconds":wall,"physics_ticks":Engine.get_physics_frames()-tick_start,"physics_hz":Engine.physics_ticks_per_second,"max_physics_steps_per_frame":Engine.max_physics_steps_per_frame,"diagnostics":game.bot_director.diagnostics.duplicate(true),"qa_only":true,"valid":control_failures.is_empty(),"control_scope":"Offline fixed-camera diagnostic ablation, not gameplay or multiplayer approval; removed hitboxes/presentation invalidate combat parity"}
