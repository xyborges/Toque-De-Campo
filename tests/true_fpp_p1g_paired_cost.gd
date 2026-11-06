extends SceneTree
## Deterministic CPU/physics comparison, not a rendered full-match gate.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const COUNT:=28
const WEAPONS: Array[String]=["g3","ak","fal","glock","sniper"]
var actors: Array[WarPlayer]=[]
var game: WarGame
var samples:=600
var warmup:=120
var pilot:=false
var profile:=false
var errors: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	var ordered:=values.duplicate();ordered.sort()
	var total:=0.
	for value in ordered:total+=value
	return {"p50":ordered[int((ordered.size()-1)*.50)],"p95":ordered[int((ordered.size()-1)*.95)],"p99":ordered[int((ordered.size()-1)*.99)],"mean":total/ordered.size()}

func configure(actor: WarPlayer,index: int) -> void:
	actor.set_process(false);actor.set_physics_process(false)
	actor.hp=100.;actor.deployed=true;actor.vehicle_id="";actor.utility_mode="";actor.gadget_equipped=false
	actor.weapon_id=WEAPONS[index%5];actor.owned=WEAPONS.duplicate();actor.loadout=WEAPONS.duplicate()
	actor.set_meta("weapon_optics",{});actor.set_meta("weapon_attachments",{actor.weapon_id:{}});actor._refresh_weapon()
	actor.velocity=Vector3.ZERO;actor.locomotion.reset(actor);actor.stance.reset(actor)
	actor.set_posture(0,false,true);actor.stance.advance(actor,1.)
	actor.pitch=0.;actor.lean=0.;actor.recoil=0.;actor.attack_anim=0.;actor.reload_left=0.;actor.reload_total=0.;actor.reload_weapon=""
	actor.fire_cooldown=0.;actor.aiming=false;actor.iron_sights=false;actor.next_pose_usec=0;actor._animate_walk()
	actor.p1g_set_collision_pilot(pilot)
	actor.p1g_profile_collision=profile

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--pilot":pilot=true
		if arg=="--profile":profile=true
		if arg.begins_with("--samples="):samples=int(arg.get_slice("=",1))
		if arg.begins_with("--warmup="):warmup=int(arg.get_slice("=",1))
	Engine.max_fps=60
	game=Fixture.new();root.add_child(game);await process_frame
	for actor in game.players.values():actor.set_process(false);actor.set_physics_process(false)
	for index in COUNT:
		var actor:=game.make_actor(7200+index,false,1,"soldier",Vector3(18.+float(index%7)*26.,0,-30.-float(index/7)*42.)) as WarPlayer
		configure(actor,index);actors.append(actor)
	var times: Array[float]=[];var visual: Array[float]=[];var collision: Array[float]=[];var physics: Array[float]=[]
	var visual_updates:=0
	for tick in range(warmup+samples):
		await physics_frame
		var start:=Time.get_ticks_usec();var visual_us:=0;var collision_us:=0
		for index in COUNT:
			var actor:=actors[index]
			actor.pitch=sin(float(tick+index)*.031)*.52;actor.lean=sin(float(tick+index)*.047)*.48
			actor.locomotion.phase=float(tick)*.12+float(index)*.17;actor.locomotion.moving=.72;actor.locomotion.sprint=.65 if index%4==0 else 0.
			actor.locomotion.grounded=true;actor.locomotion.local_direction=Vector3(0,0,-1)
			# Preserve the original cost fixture's frequent posture transitions.
			if tick==0 or tick%36==0:actor.set_posture((int(tick/36)+index)%3,false,true)
			actor.stance.advance(actor,1./60.)
			# Same 30/15/7.5 Hz presentation work in each arm. Wall-clock LOD
			# would otherwise reward a slower candidate with a different work mix.
			var cadence:=2 if index<7 else (4 if index<21 else 8)
			var due: bool=(tick+index)%cadence==0
			actor.next_pose_usec=0 if due else Time.get_ticks_usec()+10000000
			var phase:=Time.get_ticks_usec();actor._animate_walk();visual_us+=Time.get_ticks_usec()-phase
			if due and tick>=warmup:visual_updates+=1
			phase=Time.get_ticks_usec()
			if pilot:actor._p1g_collision_tick()
			collision_us+=Time.get_ticks_usec()-phase
		if tick>=warmup:
			times.append(float(Time.get_ticks_usec()-start)/1000.);visual.append(float(visual_us)/1000.);collision.append(float(collision_us)/1000.)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
	var solver:=0;var fallback:=0;var authority:=0;var legacy_live:=0;var regions:=0;var reasons: Dictionary={};var costs: Dictionary={}
	var states: Array=[]
	for actor in actors:
		states.append(WarCollisionPoseSolver.state(actor))
		solver+=actor.p1g_solver_frames;fallback+=actor.p1g_legacy_fallback_frames
		for key in actor.p1g_fallback_reasons:reasons[key]=int(reasons.get(key,0))+int(actor.p1g_fallback_reasons[key])
		for key in actor.p1g_profile_usec:costs[key]=int(costs.get(key,0))+int(actor.p1g_profile_usec[key])
		if pilot:
			if actor.p1g_collision_rig.using_authority:authority+=1
			regions+=actor.p1g_collision_rig.regions.size()
			for area in actor.p1g_collision_rig.legacy_regions.values():
				if area.collision_layer!=0:legacy_live+=1
	if pilot and (authority!=COUNT or regions!=COUNT*16 or legacy_live!=0):errors.append("Invalid collision authority")
	if pilot and solver+fallback!=COUNT*(warmup+samples+1):errors.append("Not all actor physics ticks were solved or mirrored")
	var report: Dictionary={"pilot":pilot,"profile":profile,"samples":samples,"warmup":warmup,
		"loop_ms":stats(times),"visual_ms":stats(visual),"collision_ms":stats(collision),"physics_ms":stats(physics),
		"raw_loop_ms":times,"raw_physics_ms":physics,"visual_updates":visual_updates,
		"state_sha256":JSON.stringify(states).sha256_text(),"solver_frames":solver,"fallback_frames":fallback,
		"fallback_reasons":reasons,"profile_usec":costs,"authority":authority,"regions":regions,"legacy_live":legacy_live,
		"errors":errors,"scope":"Synthetic deterministic CPU/physics; no AI, full map, rendering or network"}
	print("P1G_PAIRED ",JSON.stringify(report))
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
