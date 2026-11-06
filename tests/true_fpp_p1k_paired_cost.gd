extends SceneTree
## Fixed 28-actor CPU workload using the same 2/4/8 tick LOD in each arm.
const Fixture=preload("res://tests/war_optics_fixture.gd")
const ACTORS:=28
const LOD_SKIP:=1000000000000
const WEAPONS: Array[String]=["g3","ak","fal","glock","sniper"]

var game: WarGame

func _initialize() -> void:
	run.call_deferred()

func configure(actor: WarPlayer,index: int,pilot: bool) -> void:
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.weapon_id=WEAPONS[index%WEAPONS.size()]
	actor.owned=WEAPONS.duplicate()
	actor.loadout=WEAPONS.duplicate()
	actor.set_meta("weapon_optics",{})
	actor.set_meta("weapon_attachments",{actor.weapon_id:{}})
	actor._refresh_weapon()
	actor.velocity=Vector3.ZERO
	actor.locomotion.reset(actor)
	actor.stance.reset(actor)
	actor.next_pose_usec=0
	actor._animate_walk()
	actor._set_hitboxes_enabled(true)
	actor.p1g_set_collision_pilot(pilot)

func advance(actor: WarPlayer,index: int,tick: int) -> void:
	actor.pitch=sin(float(tick+index)*.031)*.52
	actor.lean=sin(float(tick+index)*.047)*.48
	actor.locomotion.phase=float(tick)*.12+float(index)*.17
	actor.locomotion.moving=.72
	actor.locomotion.sprint=.65 if index%4==0 else 0.
	actor.locomotion.grounded=true
	actor.locomotion.local_direction=Vector3.FORWARD
	if tick%36==0:
		actor.set_posture((int(tick/36)+index)%3,false,true)
	actor.stance.advance(actor,1./60.)

func run() -> void:
	var samples:=600
	var warmup:=120
	var pace_usec:=0
	var args:=OS.get_cmdline_user_args()
	var pilot: bool="--pilot" in args
	for arg: String in args:
		if arg.begins_with("--samples="): samples=int(arg.get_slice("=",1))
		if arg.begins_with("--warmup="): warmup=int(arg.get_slice("=",1))
		if arg.begins_with("--pace-usec="): pace_usec=int(arg.get_slice("=",1))
	game=Fixture.new()
	root.add_child(game)
	await process_frame
	for actor: WarPlayer in game.players.values():
		actor.set_process(false)
		actor.set_physics_process(false)
	var actors: Array[WarPlayer]=[]
	var startup_fallbacks:=0
	for index in ACTORS:
		var point:=Vector3(18.+float(index%7)*26.,0,-30.-float(index/7)*42.)
		var actor:=game.make_actor(7200+index,false,1,"soldier",point) as WarPlayer
		configure(actor,index,pilot)
		actors.append(actor)
		startup_fallbacks+=actor.p1g_legacy_fallback_frames

	var raw: PackedFloat64Array=[]
	var visual_updates:=0
	var schedule_errors:=0
	for tick in range(warmup+samples):
		await physics_frame
		var started:=Time.get_ticks_usec()
		for index in ACTORS:
			var actor:=actors[index]
			advance(actor,index,tick)
			var cadence:=2 if index<7 else (4 if index<21 else 8)
			var due: bool=(tick+index)%cadence==0
			actor.next_pose_usec=0 if due else LOD_SKIP
			actor._animate_walk()
			if pilot: actor._p1g_collision_tick(actor._p1g_visual_pose_updated)
			if (actor.next_pose_usec!=LOD_SKIP)!=due: schedule_errors+=1
			if due: visual_updates+=1
		if tick>=warmup: raw.append(float(Time.get_ticks_usec()-started)/1000.)
		# Optional equal wall-clock pacing avoids running the cheaper arm at
		# a much higher tick rate. Sleep is outside the measured pose interval.
		if pace_usec>0:
			var remaining:=pace_usec-(Time.get_ticks_usec()-started)
			if remaining>0: OS.delay_usec(remaining)

	var authority:=0
	var solved:=0
	var reuse:=0
	var shared:=0
	var fallback: int=-startup_fallbacks
	var states: Array[Dictionary]=[]
	for actor in actors:
		states.append(WarCollisionPoseSolver.state(actor))
		if not pilot: continue
		var rig:=actor.p1g_collision_rig
		if rig.using_authority and rig.regions.size()==16:
			var live:=true
			for key: String in rig.regions:
				var region:=rig.regions[key] as Area3D
				var original:=rig.legacy_regions[key] as Area3D
				live=live and region.collision_layer==2 and original.collision_layer==0
			if live: authority+=1
		solved+=actor.p1g_solver_frames
		reuse+=actor.p1g_visual_reuse_frames
		shared+=actor.p1g_shared_pose_frames
		fallback+=actor.p1g_legacy_fallback_frames
	var valid: bool=schedule_errors==0 and (not pilot or (authority==ACTORS and fallback==0 and shared==reuse and reuse==visual_updates and solved+reuse==ACTORS*(warmup+samples)))
	print("P1K_COST ",JSON.stringify({"pass":valid,"pilot":pilot,"raw_ms":Array(raw),
		"state_sha256":JSON.stringify(states).sha256_text(),"visual_updates":visual_updates,
		"authority":authority,"solved":solved,"reuse":reuse,"shared":shared,"fallback":fallback,
		"schedule_errors":schedule_errors}))
	game.queue_free()
	await process_frame
	quit(0 if valid else 1)
