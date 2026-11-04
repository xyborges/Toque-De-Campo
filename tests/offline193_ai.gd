extends SceneTree
var game: WarGame
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	game=WarGame.new();game.offline_operation=true;game.set_meta("test_mode",true);root.add_child(game)
	while not game.join_ready: await process_frame
	game.request_deploy(0,"soldier","fal","stinger","base");game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	while game.players.size()<18: await process_frame
	check(game.players.size()==18 and game.bot_director.bots.size()==17,"18 offline participants use ordinary player actors")
	var teams:=[0,0]
	for member: Dictionary in game.members.values(): teams[int(member.team)]+=1
	check(teams==[9,9],"offline teams are balanced nine against nine")
	var start:=game.war_clock;var progress:=0;var boarded: Dictionary={};var driven: Dictionary={};var starts: Dictionary={};var invalid:=0;var owners: Dictionary={}
	for id in game.vehicle_system.vehicles: starts[id]=game.vehicle_system.vehicles[id].position
	while game.war_clock-start<160:
		await physics_frame
		for actor: WarPlayer in game.players.values():
			if not actor.position.is_finite(): invalid+=1
			if not actor.vehicle_id.is_empty(): boarded[actor.peer_id]=actor.vehicle_id
		for id: String in game.vehicle_system.vehicles:
			var vehicle: WarVehicle=game.vehicle_system.vehicles[id]
			if vehicle.position.distance_to(starts[id])>40: driven[id]=true
		for id: String in game.objective_states:
			if int(game.objective_states[id].owner)>=0: owners[id]=game.objective_states[id].owner
		if int((game.war_clock-start)/20)>progress:
			progress+=1;print("AI_PROGRESS ",progress*20," ",game.bot_director.diagnostics," vehicles=",driven.keys()," captured=",owners.keys())
	check(invalid==0,"all participant transforms stay finite")
	check(int(game.bot_director.diagnostics.shots)>15,"bots fire authoritative projectiles in a spontaneous full-map battle")
	check(int(game.bot_director.diagnostics.shot_rejections)<maxi(5,int(game.bot_director.diagnostics.shots)/10),"bot bursts respect authority cadence and inventory")
	check(boarded.size()>=3 and driven.size()>=1,"AI uses real vehicle seats and drives on the road graph")
	check(not owners.is_empty(),"squads capture previously neutral objectives")
	var damaged:=0;var deaths:=0
	for row: Dictionary in game.match_stats.rows.values(): damaged+=int(row.damage);deaths+=int(row.deaths)
	check(damaged>100 and deaths>0,"normal damage, deaths and match statistics work in the offline battle")
	var report:={"checks":checks,"failures":failures,"diagnostics":game.bot_director.diagnostics.duplicate(),"simulation_seconds":game.war_clock-start,"boarded":boarded,"driven":driven.keys(),"captured":owners,"damage":damaged,"deaths":deaths,"note":"Headless functional simulation, not an FPS benchmark."}
	game.show_menu();check(not game.bot_director.enabled,"leaving stops the AI director")
	report.checks=checks
	NavalStorage.write_json("res://work/offline193-ai.json",report);print(JSON.stringify(report));game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
