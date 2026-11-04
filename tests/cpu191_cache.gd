extends SceneTree

class WaterActor extends WarPlayer:
	func _ready() -> void:
		set_process(false);set_physics_process(false)

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func reference_water(actor: WarPlayer) -> bool:
	return actor.hp>0 and actor.deployed and actor.vehicle_id.is_empty() and WarTerrain.height_at(actor.global_position.x,actor.global_position.z)<-.6 and actor.global_position.y<WarCoast.wave(actor.global_position,float(actor.game.war_clock))+.18

func water_time(actor: WarPlayer,cached: bool,count: int) -> int:
	var started:=Time.get_ticks_usec()
	for index in count:
		if cached: actor.in_water()
		else: reference_water(actor)
	return Time.get_ticks_usec()-started

func run() -> void:
	var profile:=NavalStorage.folder()
	check(not profile.is_empty() and DirAccess.dir_exists_absolute(profile),"profile directory resolves and exists")
	var options_file:=profile.path_join("game-options.json")
	NavalStorage.write_json(options_file,{"fov":81.0,"hud_opacity":.85})
	GameOptions.path=""
	check(is_equal_approx(GameOptions.number("fov",70),81.),"cached folder retains the selected options file")
	GameOptions.set_value("fov",84.0);GameOptions.flush()
	check(is_equal_approx(float(NavalStorage.read_json(options_file).get("fov",0)),84.),"changed preferences still persist through the normal writer")
	var option_started:=Time.get_ticks_usec()
	for index in 10000: GameOptions.number("fov",70.)
	var option_usec:=Time.get_ticks_usec()-option_started
	check(NavalStorage.folder()==profile and GameOptions.path==options_file,"warm options preserve the resolved process profile")

	# No full world, renderer, networking, or production account is needed.
	WarTerrainEdits.configure([])
	var game:=WarGame.new();game.war_clock=100.
	var actor:=WaterActor.new();actor.game=game;root.add_child(actor)
	actor.hp=100.;actor.deployed=true;actor.vehicle_id=""
	actor.position=Vector3(0,-2,0)
	check(not actor.in_water() and actor.in_water()==reference_water(actor),"dry terrain agrees with the original water predicate")
	var before_tick:=Engine.get_physics_frames()
	actor.position=Vector3(-1600,-2,-1000)
	check(actor.in_water() and actor.in_water()==reference_water(actor),"same-tick snapshot/teleport invalidates a dry result")
	actor.position.y=5.
	check(not actor.in_water(),"same-tick vertical movement exits the water")
	actor.position.y=-2.
	check(actor.in_water(),"same-tick vertical movement enters the water")
	actor.vehicle_id="v_guarani";check(not actor.in_water(),"vehicle occupancy disables swimming immediately")
	actor.vehicle_id="";actor.hp=0.;check(not actor.in_water(),"death disables swimming immediately")
	actor.hp=100.;actor.deployed=false;check(not actor.in_water(),"undeployed actor cannot swim")
	actor.deployed=true
	var first_level:=WarCoast.wave(actor.position,game.war_clock)+.18
	var second_clock:=game.war_clock+1.
	var second_level:=WarCoast.wave(actor.position,second_clock)+.18
	actor.position.y=(first_level+second_level)*.5
	var before_clock:=actor.in_water()
	game.war_clock=second_clock
	check(actor.in_water()==reference_water(actor) and (before_clock!=actor.in_water() or is_equal_approx(first_level,second_level)),"same-tick clock change updates the wave crossing")
	game.war_clock=600.;WarWeather.seed=0
	first_level=WarCoast.wave(actor.position,game.war_clock)+.18
	WarWeather.seed=1;second_level=WarCoast.wave(actor.position,game.war_clock)+.18
	actor.position.y=(first_level+second_level)*.5
	WarWeather.seed=0;before_clock=actor.in_water()
	WarWeather.seed=1
	check(actor.in_water()==reference_water(actor) and (before_clock!=actor.in_water() or is_equal_approx(first_level,second_level)),"same-tick weather seed change updates wave amplitude")
	actor.position=Vector3(0,-2,0)
	check(not actor.in_water(),"land is dry before a terrain edit")
	var cut:=WarTerrainEdits.descriptor(Transform3D.IDENTITY,Vector2(12,12),10.,1.,1.,"cut")
	WarTerrainEdits.configure([cut])
	check(actor.in_water() and actor.in_water()==reference_water(actor),"same-tick terrain revision invalidates water contact")
	WarTerrainEdits.configure([])
	check(not actor.in_water(),"restored terrain invalidates the cached excavation")
	check(Engine.get_physics_frames()==before_tick,"movement, clock and terrain invalidations were exercised within one physics tick")
	await physics_frame
	check(actor.in_water()==reference_water(actor) and actor._water_tick==Engine.get_physics_frames(),"the next physics tick refreshes water contact")

	var timings: Array[Dictionary]=[]
	for point in [Vector3(0,-2,0),Vector3(-1600,-2,-1000)]:
		actor.position=point;actor.in_water();reference_water(actor)
		var raw_usec:=water_time(actor,false,10000)
		var cached_usec:=water_time(actor,true,10000)
		timings.append({"position":str(point),"calls":10000,"reference_usec":raw_usec,"cached_usec":cached_usec})
	var result: Dictionary={"checks":checks,"failures":failures,"scope":"isolated headless predicate/settings microcheck; not full combat FPS","options_10000_usec":option_usec,"water":timings}
	NavalStorage.write_json("res://work/perf181/cpu191-cache-results.json",result)
	print("CPU191_CACHE ",JSON.stringify(result))
	actor.queue_free();game.free();await process_frame
	quit(0 if failures.is_empty() else 1)
