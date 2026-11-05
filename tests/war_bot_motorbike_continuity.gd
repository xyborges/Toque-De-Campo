extends SceneTree
# Headless integration: collect motorcycle AI throttle/brake/position evidence.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("BOT_MOTO: "+label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game:=WarGame.new()
	game.operation_id=WarOperation.AFGHAN
	game.offline_operation=true
	game.set_meta("war_test",true)
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+40000
	while not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	if not game.join_ready:
		check(false,"WarGame not ready")
		quit(1);return
	var director:=game.bot_director as WarBotDirector
	director.stop()
	var manager:=game.vehicle_system as WarVehicles
	var team:=0 if "--bike-team=0" in OS.get_cmdline_user_args() else 1
	var bike:=manager.vehicles.get("v_bike_"+str(team)+"_0") as WarVehicle
	if not is_instance_valid(bike):
		check(false,"bike missing")
		quit(1);return
	var id:=16088+team
	var actor:=game._spawn_player(id,false,false,bike.global_position) as WarPlayer
	actor.apply_identity(team,"soldier")
	actor.deployed=true;actor.hp=100
	actor.set_physics_process(false)
	game.members[id]={"team":team,"role":"soldier","deployed":true,"bot":true,"vehicle":bike.vehicle_id,"vehicle_seat":0,"vehicle_role":"operator","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
	actor.vehicle_id=bike.vehicle_id
	bike.allocate_seat(id)
	actor.body_collision.set_deferred("disabled",true)
	var record: Dictionary={"team":team,"slot":8,"objective":"D" if team==0 else "B","target":0,"target_vehicle":"","line_clear":false,"vehicle_goal":"","vehicle_path":[],"vehicle_index":0,"vehicle_stuck":0.,"vehicle_check_at":0.,"boarding_until":0.,"last_position":bike.global_position,"terrain_detour":Vector3.INF}
	director.bots[id]=record
	director.bot_ids=[id]
	var initial: Vector3=bike.global_position
	var brake_counts: Dictionary={}
	var grade_ticks:=0
	var stalled_ticks:=0
	var reverse_ticks:=0
	var throttle_ticks:=0
	var active_ticks:=0
	var longest_stall:=0
	var stall_sequence:=0
	var distance_traveled:=0.
	var previous:=initial
	for frame in 600:
		if bike.driver!=id: break
		director._drive(actor,record,1./60.)
		var input: Dictionary=manager.controls.get(id,{})
		if frame%60==0:
			var nodes: Array=record.get("vehicle_path",[])
			var index:=mini(int(record.get("vehicle_index",0)),nodes.size()-1)
			var waypoint: Vector3=nodes[index] if index>=0 else Vector3.INF
			var contact:=bike.get_last_slide_collision()
			var collider: Object=contact.get_collider() if contact else null
			print("BOT_MOTO_FRAME ",JSON.stringify({"f":frame,"pos":bike.global_position,"speed":bike.speed,"heading":bike.heading,"point":waypoint,"index":index,"nodes":nodes.size(),"input":input,"blocked":bike.step_motion.blocked_motion,"collider":str(collider),"normal":contact.get_normal() if contact else Vector3.UP,"collision_at":contact.get_position() if contact else Vector3.INF,"on_floor":bike.is_on_floor()}))
			if frame==240:
				for collision_index in bike.get_slide_collision_count():
					var slide:=bike.get_slide_collision(collision_index)
					for contact_index in slide.get_collision_count():
						print("BOT_MOTO_CONTACT ",JSON.stringify({"normal":slide.get_normal(contact_index),"position":slide.get_position(contact_index),"collider":str(slide.get_collider(contact_index))}))
				var advance:=Basis(Vector3.UP,bike.heading)*Vector3.FORWARD
				var side:=advance.cross(Vector3.UP).normalized()
				for lateral in [-4.,-2.,0.,2.,4.]:
					var samples: Array=[]
					for distance in [0.,2.,4.,8.]:
						var q: Vector3=bike.global_position+advance*float(distance)+side*float(lateral)
						samples.append(snappedf(WarTerrain.height_at(q.x,q.z),.01))
					print("BOT_MOTO_HEIGHT lateral=",lateral," height=",samples)
		if bool(input.get("brake",false)):
			var reason:=str(record.get("traffic",{}).get("reason","unknown"))
			brake_counts[reason]=int(brake_counts.get(reason,0))+1
		if bool(record.get("terrain_blocked",false)):grade_ticks+=1
		if float(input.get("throttle",0.))<-.01:reverse_ticks+=1
		if float(input.get("throttle",0.))>.01:throttle_ticks+=1
		await physics_frame
		var movement:=bike.global_position.distance_to(previous)
		distance_traveled+=movement
		if frame>60:
			active_ticks+=1
			if movement<.007:
				stalled_ticks+=1
				stall_sequence+=1
				longest_stall=maxi(longest_stall,stall_sequence)
			else:stall_sequence=0
		previous=bike.global_position
	var report: Dictionary={"team":team,"distance_total":distance_traveled,"displacement":initial.distance_to(bike.global_position),"grade_ticks":grade_ticks,"brakes":brake_counts,"reverse_ticks":reverse_ticks,"positive_ticks":throttle_ticks,"stalled_ticks":stalled_ticks,"active_ticks":active_ticks,"max_consecutive_stall":longest_stall,"remaining_driver":bike.driver,"last_objective":str(record.get("objective",""))}
	print("BOT_MOTO_CONTINUITY ",JSON.stringify(report))
	check(throttle_ticks>100,"motorcycle throttle does not become permanently idle")
	# Continuity threshold is intentionally tight enough to reproduce stuttering.
	check(longest_stall<120,"no >=2 second freezes after acceleration")
	check(initial.distance_to(bike.global_position)>35.,"motorcycle progresses toward objective")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
