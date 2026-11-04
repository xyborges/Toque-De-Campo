extends "res://tests/war_locomotion_network_fixture.gd"

class TimedPlayer extends WarPlayer:
	func _physics_process(delta: float) -> void:
		var at:=GamePerformanceProbe.begin(&"player.local.physics" if is_local else &"player.remote.physics")
		super._physics_process(delta)
		GamePerformanceProbe.end(&"player.local.physics" if is_local else &"player.remote.physics",at)
	func _animate_walk() -> void:
		var at:=GamePerformanceProbe.begin(&"player.pose")
		var deadline:=next_pose_usec
		super._animate_walk();GamePerformanceProbe.end(&"player.pose",at)
		if at>0 and not is_local and next_pose_usec!=deadline:game.pose_count+=1
	func _update_weapon_pose() -> void:
		var at:=GamePerformanceProbe.begin(&"player.weapon_pose")
		super._update_weapon_pose();GamePerformanceProbe.end(&"player.weapon_pose",at)
	func _finish_body_pose() -> void:
		var at:=GamePerformanceProbe.begin(&"player.body_pose")
		super._finish_body_pose();GamePerformanceProbe.end(&"player.body_pose",at)
	func _pose_arm(arm: Node3D,hand: Vector3,group: String) -> void:
		var at:=GamePerformanceProbe.begin(&"player.arm_ik")
		super._pose_arm(arm,hand,group);GamePerformanceProbe.end(&"player.arm_ik",at)

# Observe production authority work without the remote profiler's periodic
# JSON capture, which could itself perturb a one-second hitch investigation.
class TimedBots extends WarBotDirector:
	var measuring:=false
	var ticks: Array=[]
	var thoughts: Array=[]
	func _physics_process(delta: float) -> void:
		var at:=Time.get_ticks_usec()
		super._physics_process(delta)
		if measuring:ticks.append([at*.001,(Time.get_ticks_usec()-at)*.001])
	func _think(id: int) -> void:
		var at:=Time.get_ticks_usec()
		super._think(id)
		if measuring:thoughts.append([at*.001,id,(Time.get_ticks_usec()-at)*.001])

var measuring:=false
var physics_samples: Array=[]
var previous_tick:=0
var pose_count:=0
var pose_frames: Array=[]

func _new_player() -> GamePlayer:return TimedPlayer.new()

func _input(event: InputEvent) -> void:
	# The QA trajectory must not turn when the desktop cursor is captured.
	# Real movement input, collision and server validation remain unchanged.
	if event is InputEventMouseMotion:return
	super._input(event)

func _ready() -> void:
	# QA instrumentation changes a script included in the editor freshness
	# hash. Both peers read this same checkout. Leave authored scenes and
	# prepared artifacts untouched; --map-uncached rebuilds actual navigation.
	preload("res://scripts/maps/definition.gd").checked["ukraine"]=true
	super._ready()

func _prepare_online_bots() -> void:
	if offline_operation or not online or not multiplayer.is_server() or closing or is_instance_valid(bot_director):return
	bot_director=TimedBots.new();bot_director.setup(self,true);world_root.add_child(bot_director)

func _physics_process(delta: float) -> void:
	var at:=Time.get_ticks_usec()
	var health_due:=dedicated_pvp and Time.get_unix_time_from_system()-pvp_health_at>2.
	super._physics_process(delta)
	if measuring:
		physics_samples.append([at*.001,(at-previous_tick)*.001 if previous_tick>0 else 0.,(Time.get_ticks_usec()-at)*.001,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,health_due])
		previous_tick=at

func _process(delta: float) -> void:
	if measuring:pose_frames.append([Time.get_ticks_usec()*.001,pose_count]);pose_count=0
	super._process(delta)
