extends SceneTree
## Long-ish live Favela bot simulation. Diagnoses idle pressure around objectives.
var game: WarGame
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func _active_bot(id: int) -> WarPlayer:
	var actor:=game.players.get(id) as WarPlayer
	return actor if is_instance_valid(actor) and actor.deployed and actor.hp>0 else null

func _run() -> void:
	game=WarGame.new()
	game.operation_id=WarOperation.FAVELA
	game.offline_operation=true
	game.offline_participants=29
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+45000
	while (not game.join_ready or not is_instance_valid(game.bot_director)) and Time.get_ticks_msec()<deadline:
		await process_frame
	if not game.join_ready or not is_instance_valid(game.bot_director):
		push_error("FAVELA_BOT_PRESSURE_FAIL setup join_ready="+str(game.join_ready)+" build_ms="+str(game.world_build_ms))
		quit(1);return
	var director:=game.bot_director as WarBotDirector
	# The war_test harness deliberately does not fill offline bots from UI state.
	# Invoke the same authoritative population path used by a local match.
	director.populate(0)
	deadline=Time.get_ticks_msec()+25000
	while director.bots.size()<28 and Time.get_ticks_msec()<deadline: await process_frame
	if director.bots.size()<28:
		push_error("FAVELA_BOT_PRESSURE_FAIL population="+str(director.bots.size()))
		quit(1);return
	var previous: Dictionary={}
	var no_enemy_run: Dictionary={}
	var enemy_run: Dictionary={}
	var max_no_enemy: Dictionary={}
	var max_enemy: Dictionary={}
	var targetless_far_ticks:=0
	var targetless_far_zero:=0
	var enemy_far_ticks:=0
	var enemy_far_zero:=0
	var start_distance: Dictionary={}
	for id in director.bot_ids:
		var actor:=_active_bot(id)
		if not actor:continue
		previous[id]=actor.global_position
		var record: Dictionary=director.bots[id]
		var objective: Vector3=WarRules.OBJECTIVES[str(record.objective)].position
		start_distance[id]=actor.global_position.distance_to(objective)
	# 15 seconds of a real 28-bot Favela round.
	for frame in 900:
		await physics_frame
		for id in director.bot_ids:
			var actor:=_active_bot(id)
			if not actor or not actor.vehicle_id.is_empty():continue
			var record: Dictionary=director.bots[id]
			var objective: Vector3=WarRules.OBJECTIVES[str(record.objective)].position
			var gap:=actor.global_position.distance_to(objective)
			var moved:=actor.global_position.distance_to(previous.get(id,actor.global_position))
			previous[id]=actor.global_position
			var stalled:=moved<.008
			var target:=int(record.get("target",0))>0 and bool(record.get("line_clear",false))
			if gap>WarRules.CAPTURE_RADIUS:
				if target:
					enemy_far_ticks+=1
					if stalled:
						enemy_far_zero+=1
						enemy_run[id]=float(enemy_run.get(id,0.))+1./60.
						max_enemy[id]=maxf(float(max_enemy.get(id,0.)),float(enemy_run[id]))
					else: enemy_run[id]=0.
				else:
					targetless_far_ticks+=1
					if stalled:
						targetless_far_zero+=1
						no_enemy_run[id]=float(no_enemy_run.get(id,0.))+1./60.
						max_no_enemy[id]=maxf(float(max_no_enemy.get(id,0.)),float(no_enemy_run[id]))
					else:no_enemy_run[id]=0.
	var worst_no: Array=[]
	var worst_enemy: Array=[]
	var progress: Array=[]
	for id in director.bot_ids:
		var actor:=_active_bot(id)
		if not actor:continue
		var record: Dictionary=director.bots[id]
		var objective: Vector3=WarRules.OBJECTIVES[str(record.objective)].position
		var end_gap:=actor.global_position.distance_to(objective)
		if float(max_no_enemy.get(id,0.))>.8:worst_no.append([id,snappedf(float(max_no_enemy[id]),.01),str(record.objective),snappedf(end_gap,.1)])
		if float(max_enemy.get(id,0.))>.8:worst_enemy.append([id,snappedf(float(max_enemy[id]),.01),str(record.objective),snappedf(end_gap,.1)])
		if start_distance.has(id):progress.append([id,snappedf(float(start_distance[id]),.1),snappedf(end_gap,.1),str(record.objective)])
	var objective_summary: Dictionary={}
	for key in game.objective_states:
		var state: Dictionary=game.objective_states[key]
		objective_summary[key]={"owner":int(state.owner),"count":state.count,"progress":snappedf(float(state.progress),.01)}
	var report={
		"bots":director.bots.size(),
		"targetless_far_ticks":targetless_far_ticks,
		"targetless_far_stopped_ratio":float(targetless_far_zero)/maxi(1,targetless_far_ticks),
		"enemy_far_ticks":enemy_far_ticks,
		"enemy_far_stopped_ratio":float(enemy_far_zero)/maxi(1,enemy_far_ticks),
		"worst_no_enemy":worst_no,
		"worst_enemy":worst_enemy,
		"objectives":objective_summary,
		"progress":progress
	}
	print("FAVELA_BOT_PRESSURE_BASELINE ",JSON.stringify(report))

	# Controlled last-mile phase: no enemies exist, one police bot per objective
	# starts on a walkable cell roughly 55 m out. This isolates path/decision
	# stalls from combat and from the long trip across the map.
	var selected: Array[int]=[]
	var used_squads: Dictionary={}
	for id in director.bot_ids:
		var record: Dictionary=director.bots[id]
		if int(record.team)!=0 or used_squads.has(str(record.squad)): continue
		var actor:=_active_bot(id)
		if not actor: continue
		if not actor.vehicle_id.is_empty(): game.vehicle_system.release(id,true)
		selected.append(id);used_squads[str(record.squad)]=true
		if selected.size()>=5: break
	for id in director.bot_ids:
		if id in selected: continue
		var actor:=game.players.get(id) as WarPlayer
		if is_instance_valid(actor) and int(director.bots[id].team)==1:
			actor.hp=0.;actor.deployed=false
			game.members[id].deployed=false;game.members[id].ready_at=game.war_clock+9999.
	var keys:=["A","B","C","D","E"]
	var controlled_start: Dictionary={}
	for index in selected.size():
		var id:=selected[index]
		var actor:=game.players[id] as WarPlayer
		var record: Dictionary=director.bots[id]
		var key: String=keys[index]
		var centre: Vector3=WarRules.OBJECTIVES[key].position
		var angle:=float(index)*TAU/5.+.37
		var desired:=centre+Vector3(cos(angle)*55.,0,sin(angle)*55.)
		var cell:=director.navigation.nearest(desired)
		actor.global_position=director.navigation.world_point(cell)
		actor.velocity=Vector3.ZERO
		record.objective=key;record.target=0;record.line_clear=false;record.direction=Vector3.ZERO
		record.foot_path=[];record.transit_goal=Vector3.INF;record.roof_path=PackedVector3Array();record.roof_follow=false
		controlled_start[id]=actor.global_position.distance_to(centre)
	director.bot_ids=selected
	director.strategy_at=game.war_clock+9999.
	var controlled_stall: Dictionary={}
	var controlled_max: Dictionary={}
	var controlled_prev: Dictionary={}
	for id in selected: controlled_prev[id]=(game.players[id] as WarPlayer).global_position
	for frame in 600:
		await physics_frame
		for id in selected:
			var actor:=_active_bot(id)
			if not actor: continue
			var record: Dictionary=director.bots[id]
			var gap:=actor.global_position.distance_to(Vector3(WarRules.OBJECTIVES[str(record.objective)].position))
			var moved:=actor.global_position.distance_to(controlled_prev[id]);controlled_prev[id]=actor.global_position
			if int(record.target)==0 and gap>WarRules.CAPTURE_RADIUS and moved<.008:
				controlled_stall[id]=float(controlled_stall.get(id,0.))+1./60.
				controlled_max[id]=maxf(float(controlled_max.get(id,0.)),float(controlled_stall[id]))
			else: controlled_stall[id]=0.
	var controlled_result: Array=[]
	for id in selected:
		var actor:=_active_bot(id)
		var record: Dictionary=director.bots[id]
		var end_gap:=actor.global_position.distance_to(Vector3(WarRules.OBJECTIVES[str(record.objective)].position)) if actor else INF
		controlled_result.append({"id":id,"objective":record.objective,"start":snappedf(float(controlled_start[id]),.1),"end":snappedf(end_gap,.1),"stall":snappedf(float(controlled_max.get(id,0.)),.01),"direction":Vector3(record.direction).length()})
	print("FAVELA_BOT_LAST_MILE ",JSON.stringify(controlled_result))

	# Visible-enemy assault: a bot 40-55 m from C must keep pressure on an
	# enemy-owned objective rather than freeze forever on a firing line.
	var attacker_id:=selected[mini(2,selected.size()-1)]
	var enemy_id:=-1
	for id in director.bots:
		if int(director.bots[id].team)==1:enemy_id=int(id);break
	var attacker:=game.players[attacker_id] as WarPlayer
	var enemy:=game.players[enemy_id] as WarPlayer
	if not enemy.vehicle_id.is_empty():game.vehicle_system.release(enemy_id,true)
	enemy.hp=5000.;enemy.deployed=true;game.members[enemy_id].deployed=true;game.members[enemy_id].ready_at=game.war_clock+9999.
	var c_point: Vector3=WarRules.OBJECTIVES["C"].position
	enemy.global_position=director.navigation.world_point(director.navigation.nearest(c_point))
	enemy.velocity=Vector3.ZERO
	var visible_start:=Vector3.INF
	for sample in 16:
		var angle:=float(sample)*TAU/16.
		var candidate:=director.navigation.world_point(director.navigation.nearest(c_point+Vector3(cos(angle)*48.,0,sin(angle)*48.)))
		attacker.global_position=candidate;attacker.velocity=Vector3.ZERO
		var aim:=enemy.global_position-attacker.global_position;aim.y=0
		attacker.yaw=atan2(-aim.x,-aim.z);attacker.rotation.y=attacker.yaw
		var attack_record: Dictionary=director.bots[attacker_id]
		attack_record.target=enemy_id
		if director._has_clear_shot(attacker,enemy):
			visible_start=candidate;break
	var assault_record: Dictionary=director.bots[attacker_id]
	assault_record.objective="C";assault_record.target=enemy_id;assault_record.line_clear=true;assault_record.defend_all=false
	assault_record.foot_path=[];assault_record.transit_goal=Vector3.INF;assault_record.roof_path=PackedVector3Array();assault_record.roof_follow=false
	game.objective_states["C"].owner=1;game.objective_states["C"].side=-1;game.objective_states["C"].progress=0.
	director.bot_ids=[attacker_id];director.strategy_at=game.war_clock+9999.
	var assault_start_gap:=attacker.global_position.distance_to(c_point)
	var assault_origin:=attacker.global_position
	var visible_ticks:=0
	for frame in 300:
		await physics_frame
		if int(assault_record.get("target",0))==enemy_id and bool(assault_record.get("line_clear",false)):visible_ticks+=1
	var assault_result={"los_start_found":visible_start.is_finite(),"visible_ticks":visible_ticks,"start_gap":snappedf(assault_start_gap,.1),"end_gap":snappedf(attacker.global_position.distance_to(c_point),.1),"displacement":snappedf(attacker.global_position.distance_to(assault_origin),.1)}
	print("FAVELA_BOT_VISIBLE_ASSAULT ",JSON.stringify(assault_result))

	# Full-map-control policy: every active point must receive a squad. Once a
	# defender is inside its sector it may fight, but must not chase outwards.
	for key in keys:
		game.objective_states[key].owner=0
		game.objective_states[key].side=-1
		game.objective_states[key].progress=0.
		game.objective_states[key].count=[0,0]
	for id in director.bots:
		if int(director.bots[id].team)!=0:continue
		var actor:=game.players.get(id) as WarPlayer
		if not is_instance_valid(actor):continue
		actor.hp=maxf(actor.hp,100.);actor.deployed=true;game.members[id].deployed=true
	director._assign_objectives()
	var defense_assignments: Dictionary={}
	var defended_points: Dictionary={}
	for squad_id in director.squads:
		var squad: Dictionary=director.squads[squad_id]
		if int(squad.team)==0:
			defense_assignments[squad_id]=squad.objective
			defended_points[str(squad.objective)]=true
	print("FAVELA_BOT_FULL_CONTROL ",JSON.stringify(defense_assignments))

	# Physical hold check using the same LOS pair in reverse.
	assault_record.objective="C";assault_record.defend_all=true;assault_record.target=enemy_id;assault_record.line_clear=true
	attacker.global_position=enemy.global_position;attacker.velocity=Vector3.ZERO
	enemy.global_position=visible_start if visible_start.is_finite() else director.navigation.world_point(director.navigation.nearest(c_point+Vector3(48,0,0)))
	enemy.hp=5000.;enemy.deployed=true
	var defense_origin:=attacker.global_position
	var defense_max_gap:=attacker.global_position.distance_to(c_point)
	director.bot_ids=[attacker_id];director.strategy_at=game.war_clock+9999.
	for frame in 180:
		await physics_frame
		defense_max_gap=maxf(defense_max_gap,attacker.global_position.distance_to(c_point))
	var defense_result={"displacement":snappedf(attacker.global_position.distance_to(defense_origin),.1),"max_gap":snappedf(defense_max_gap,.1),"target":int(assault_record.get("target",0))}
	print("FAVELA_BOT_DEFENSE_HOLD ",JSON.stringify(defense_result))

	var strong_progress:=0
	for result: Dictionary in controlled_result:
		if float(result.start)-float(result.end)>=10.:strong_progress+=1
		if float(result.stall)>1.5:failures.append("last-mile stall "+str(result.objective))
	if strong_progress<4:failures.append("fewer than four last-mile objectives made strong progress")
	if not visible_start.is_finite() or visible_ticks<30:failures.append("visible assault LOS was not sustained")
	if float(assault_result.end_gap)>=float(assault_result.start_gap)-2.:failures.append("visible assault did not pressure objective")
	if defended_points.size()!=5:failures.append("full control does not cover all five objectives")
	if defense_max_gap>WarRules.CAPTURE_RADIUS:failures.append("full-control defender chased outside sector")
	print("FAVELA_BOT_PRESSURE_RESULT ",JSON.stringify({"ok":failures.is_empty(),"failures":failures,"strong_progress":strong_progress}))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
