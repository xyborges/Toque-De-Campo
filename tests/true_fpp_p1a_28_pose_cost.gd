extends SceneTree
## P1a microbenchmark: measures only articulated host pose CPU, not full FPS.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const GROUP_COUNT:=28
const SAMPLES:=120
var game: WarGame
func _initialize() -> void:
	run.call_deferred()
func percentile(sorted: Array[float],p: float) -> float:
	var idx: int=clampi(roundi(float(sorted.size()-1)*p),0,sorted.size()-1)
	return sorted[idx]
func run() -> void:
	Engine.max_fps=60
	game=Fixture.new()
	root.add_child(game)
	await process_frame
	var actors: Array[WarPlayer]=[]
	for index in GROUP_COUNT:
		var x: float=5.0+float(index%7)*7.0
		var z: float=-12.0-float(index/7)*8.0
		var actor:=game.make_actor(6100+index,false,1,"soldier",Vector3(x,0,z)) as WarPlayer
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.hp=100;actor.deployed=true
		actor.velocity=Vector3(-2.0,0,-3.0)
		actor.locomotion.reset(actor)
		actor.weapon_id="g3"
		actor.owned=["g3","glock"]
		actor.loadout=actor.owned.duplicate()
		actor._refresh_weapon()
		actors.append(actor)
	var times: Array[float]=[]
	for sample in range(SAMPLES+12):
		# Keep distance-LOD timestamps realistic instead of making all
		# iterations within a single millisecond of wall-clock time.
		await physics_frame
		var start: int=Time.get_ticks_usec()
		for index in actors.size():
			var actor:=actors[index]
			actor.pitch=sin(float(sample+index)*.018)*.5
			actor.lean=sin(float(sample+index)*.022)*.50
			actor.locomotion.phase=float(sample)*.09+float(index)*.08
			actor.locomotion.moving=.8
			if sample%45==0:
				actor.set_posture((sample/45+index)%3,false,true)
			actor.stance.advance(actor,1.0/60.0)
			actor._animate_walk()
		var elapsed: float=float(Time.get_ticks_usec()-start)/1000.0
		if sample>=12:times.append(elapsed)
	times.sort()
	var total:=0.0
	for value: float in times:total+=value
	var report: Dictionary={
		"host_authority":game.multiplayer.is_server(),
		"collision_pilot_enabled":actors[0].p1a_authority_collision_pilot,
		"actors":actors.size(),"samples":times.size(),
		"batch_p50_ms":percentile(times,.50),
		"batch_p95_ms":percentile(times,.95),
		"batch_p99_ms":percentile(times,.99),
		"batch_mean_ms":total/maxi(1,times.size()),
		"warning":"Only synchronous pose solve in 28 remote G3 actors over 120 physics frames; no AI/nav/render/full frame. Compare same fixture with pilot enabled/disabled, but this is NOT a production FPS benchmark."
	}
	report["fixture_ok"]=actors.size()==GROUP_COUNT and report.host_authority
	print("TRUE_FPP_P1A_COST ",JSON.stringify(report))
	var scenario: String="pilot" if actors[0].p1a_authority_collision_pilot else "legacy"
	var file:=FileAccess.open("res://work/fpp-tpp-p1a-20261104/authority-28-pose-cost-"+scenario+".json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report,"\t"));file.close()
	game.queue_free()
	await process_frame
	quit(0 if report.fixture_ok else 1)
