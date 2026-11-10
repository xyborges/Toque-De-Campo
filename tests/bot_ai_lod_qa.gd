extends SceneTree
## Safe, deterministic logic and cadence invariants; no full map or GPU needed.
const AI_LOD:=preload("res://scripts/bot_ai_lod.gd")
class ProbePlayer extends WarPlayer:
	func _ready() -> void:pass
	func _physics_process(_delta: float) -> void:pass
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)

func _simulate(enemy_sq: float,urgent: bool,objective: bool,ids_count: int,duration: float) -> Dictionary:
	var due: Array[float]=[]
	var counts: Array[int]=[]
	for id in ids_count:
		due.append(0.)
		counts.append(0)
	var cursor:=0
	var ticks:=0
	var empty:=0
	for frame in int(duration*40.):
		var clock:=float(frame)*.025
		var picked:=-1
		for slot in ids_count:
			var id:=cursor%ids_count
			cursor+=1
			if clock+0.00001<due[id]:continue
			picked=id
			due[id]=clock+AI_LOD.interval(enemy_sq,urgent,objective)
			counts[id]+=1
			ticks+=1
			break
		if picked<0:empty+=1
	var low: int=int(counts.min())
	var high: int=int(counts.max())
	return {"ticks":ticks,"empty":empty,"min":low,"max":high,"counts":counts}

func _run() -> void:
	check(AI_LOD.interval(INF,false,false)==1.,"unengaged distant bots use 1 s")
	check(AI_LOD.interval(300.*300.,false,false)==.55,"middle range follows moderate cadence")
	check(AI_LOD.interval(199.*199.,false,false)==.25,"nearby hostile restores combat cadence")
	check(AI_LOD.interval(INF,true,false)==.25,"current target or urgent bot stays responsive")
	check(AI_LOD.interval(INF,false,true)==.25,"objective defense stays responsive")
	check(AI_LOD.interval(200.*200.,false,false)==.25,"combat range boundary inclusive")
	check(AI_LOD.interval(350.*350.,false,false)==.55,"middle range boundary inclusive")
	check(AI_LOD.interval(351.*351.,false,false)==1.,"distant boundary works")
	var far:=_simulate(INF,false,false,28,10.)
	var near:=_simulate(90.*90.,false,false,28,10.)
	var medium:=_simulate(280.*280.,false,false,28,10.)
	var near12:=_simulate(90.*90.,false,false,12,10.)
	var medium12:=_simulate(280.*280.,false,false,12,10.)
	var far12:=_simulate(INF,false,false,12,10.)
	check(int(near12.ticks)>int(medium12.ticks) and int(medium12.ticks)>int(far12.ticks),"12-bot tiers separate decision budgets")
	check(int(far12.min)>=9 and int(far12.max)<=11,"12 distant bots keep per-bot minimum progress")
	check(int(far.ticks)<=280,"28 distant bots do not execute more than once per second each")
	check(int(far.min)>=9 and int(far.max)<=11,"28 distant bots each progress about once per second")
	check(int(near.ticks)<=400,"40 decisions/s global limit retained")
	check(int(near.max)-int(near.min)<=1,"combat round-robin fairness retained")
	check(int(medium.max)-int(medium.min)<=1,"middle tier round-robin fairness retained")
	check(int(near.ticks)>int(far.ticks),"near combat gets more decisions than distant idle squad")
	# Exercise the actual director selector with real WarPlayer/WarGame objects,
	# without starting gameplay physics or building the 3.5 km map.
	var game:=WarGame.new()
	var actor:=ProbePlayer.new()
	actor.peer_id=10001;actor.hp=100.;actor.deployed=true;actor.war_team=0
	actor.position=Vector3.ZERO
	var enemy:=ProbePlayer.new()
	enemy.peer_id=10002;enemy.hp=100.;enemy.deployed=true;enemy.war_team=1
	enemy.position=Vector3(600,0,0)
	root.add_child(actor);root.add_child(enemy)
	game.players={10001:actor,10002:enemy}
	game.war_clock=0.
	var director:=WarBotDirector.new()
	check(not director.pilot_ai_lod_enabled,"real director defaults to unchanged scheduler")
	director.game=game
	director.bots={10001:{"target":0,"objective":""}}
	var ids: Array=[10001]
	check(director._pilot_next_think_id(ids)==10001,"real director schedules initial distant bot")
	check(is_equal_approx(float(director.bots[10001].ai_lod_next),1.),"real director schedules distant interval 1s")
	game.war_clock=.2
	check(director._pilot_next_think_id(ids)==-1,"real director skips expensive distant re-think")
	director.bots[10001].target=10002
	game.war_clock=.5
	check(director._pilot_next_think_id(ids)==10001,"engaged target wakes previously distant bot early")
	check(is_equal_approx(float(director.bots[10001].ai_lod_next),.75),"combat target uses .25s")
	director.bots[10001].target=0
	enemy.position=Vector3(100,0,0)
	game.war_clock=.76
	check(director._pilot_next_think_id(ids)==10001,"real director detects nearby enemy")
	check(is_equal_approx(float(director.bots[10001].ai_lod_next),1.01),"near enemy uses .25s")
	director.free();actor.free();enemy.free();game.free()
	var result={"checks":checks,"failures":failures,"simulated_10s_28_bots":{"near":near,"middle":medium,"far":far},"simulated_10s_12_bots":{"near":near12,"middle":medium12,"far":far12}}
	print("BOT_AI_LOD_QA ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
