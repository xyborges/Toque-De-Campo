extends "res://tests/favela_network_qa.gd"
## V27 ENet: one authoritative host, two actual clients, real WarPlayer input/camera.
## Reuse tests/run_favela_network.py --script tests/favela_roof_v27_network_trace.gd
const FRAMES := 75
const CASES := 4
var traces: Array[Dictionary] = []
var telemetry: Dictionary = {}

func _server() -> void:
	print("V27_ENET_SERVER_READY online=",game.online," members=",game.members.size()); if not await wait_for(func(): return game.players.size()==2 and game.loading_baselines.is_empty(), "ENet clients", 220.0): return
	var alpha: WarPlayer
	var bravo: WarPlayer
	for actor: WarPlayer in game.players.values():
		if str(actor.name)=="alpha": alpha=actor
		elif str(actor.name)=="bravo": bravo=actor
	if not is_instance_valid(alpha) or not is_instance_valid(bravo):
		failures.append("no joined alpha/bravo")
		return
	check(game._deploy(alpha.peer_id,0,"soldier","fal","","base"),"alpha deploy")
	check(game._deploy(bravo.peer_id,1,"soldier","g3","","base"),"bravo deploy")
	if not await wait_for(func(): return game.reports.has("alpha-ready") and game.reports.has("bravo-ready"),"deployed clients",35.0):return
	var favela := game.world_root.find_child("FavelaWar",true,false) as WarFavelaMap
	check(favela!=null,"favela scene available")
	if favela==null:return
	var paths: Array[PackedVector3Array]=[]
	for path: PackedVector3Array in favela.roof_paths:
		if path.size()==9: paths.append(path)
	check(paths.size()>=30,"roof routes discovered")
	if paths.size()<30:return
	for i in CASES:
		var path: PackedVector3Array=paths[3+i*8]
		# Starting just inside the access landing, facing roof center.
		var starting: Vector3=path[7]+Vector3.UP*.12
		var target: Vector3=path[8]
		var heading:=Vector3(target.x-starting.x,0,target.z-starting.z).normalized()
		var yaw_value:=atan2(-heading.x,-heading.z)
		alpha.yaw=yaw_value
		alpha.rotation.y=yaw_value
		_pose(alpha,starting)
		_pose(bravo,WarRules.BASES[1]+Vector3.UP)
		# _pose broadcasts position and yaw; client waits a physics tick to settle.
		_phase("roof-"+str(i))
		if not await wait_for(func():return game.reports.has("alpha-roof-"+str(i)) and game.reports.has("bravo-roof-"+str(i)),"clients approach roof "+str(i),25.0):return
		_phase("walk-"+str(i))
		if not await wait_for(func():return game.reports.has("alpha-walk-"+str(i)) and game.reports.has("bravo-walk-"+str(i)),"clients trace roof "+str(i),25.0):return
		traces.append({"case":i,"server_final":alpha.global_position,"target":target})
	_phase("done")
	await create_timer(.4).timeout

func _client() -> void:
	print("V27_ENET_CLIENT_BOOT ",role," online=",game.online," prepared=",game.world_prebuilt); if not await wait_for(func(): return game.join_ready and is_instance_valid(game.local_player),"Favela ENet join",220.0):return
	var actor:=game.local_player as WarPlayer
	if not await wait_for(func():return actor.deployed and game.players.size()==2,"deployed state",45.0):return
	game.ui_focus.close_all()
	check(game.gameplay_input_allowed(),"input enabled")
	game.rpc_id(1,"qa_report",role+"-ready")
	for i in CASES:
		if not await wait_for(func():return game.phase=="roof-"+str(i),"roof phase "+str(i),35.0):return
		# Physics holds to allow teleport and camera to settle before tracing.
		for tick in 8:await physics_frame
		game.rpc_id(1,"qa_report",role+"-roof-"+str(i))
		if not await wait_for(func():return game.phase=="walk-"+str(i),"walk phase "+str(i),35.0):return
		var previous: Vector3=actor.global_position
		var previous_cam: Vector3=actor.camera.global_position
		var reversals:=0
		var freezes:=0
		var camera_jumps:=0
		var frames: Array[Dictionary]=[]
		if role=="alpha": Input.action_press("move_forward",1.0)
		for tick in FRAMES:
			await physics_frame
			var current:=actor.global_position
			var cam:=actor.camera.global_position
			var delta_pos:=current-previous
			var horiz:=Vector2(delta_pos.x,delta_pos.z).length()
			var projected:=delta_pos.dot(-actor.global_basis.z)
			if projected<-.012:reversals+=1
			if role=="alpha" and horiz<.004:freezes+=1
			if cam.distance_to(previous_cam)>.30:camera_jumps+=1
			var hits: Array[String]=[]
			for j in mini(actor.get_slide_collision_count(),4):
				var hit:=actor.get_slide_collision(j)
				hits.append(str(hit.get_normal())+":"+str(hit.get_collider().name if hit.get_collider() is Node else "?"))
			frames.append({"tick":tick,"pos":current,"cam":cam,"delta":delta_pos,
				"floor":actor.is_on_floor(),"vel":actor.velocity,
				"colliders":hits,"camera_parent":str(actor.camera.get_parent().name),
				"arm_length":actor.shoulder_arm.spring_length if actor.shoulder_arm else -1.0,
				"step_contact_frame":actor.get_meta("step_contact_frame",-1)})
			previous=current
			previous_cam=cam
		if role=="alpha":Input.action_release("move_forward")
		var record: Dictionary={"role":role,"case":i,"reversals":reversals,
			"freeze_ticks":freezes,"camera_jumps":camera_jumps,"frames":frames,
			"start":frames[0].pos,"end":frames[-1].pos}
		traces.append(record)
		var directory:=OS.get_environment("FAVELA_NET_QA_DIR")
		var file:=FileAccess.open(directory.path_join(role+"-roof-"+str(i)+".json"),FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(record))
			file.close()
		check(role!="alpha" or reversals<=2,"alpha no persistent backward motion case "+str(i))
		game.rpc_id(1,"qa_report",role+"-walk-"+str(i))
	if not await wait_for(func():return game.phase=="done","final phase",20.0):return
	telemetry={"cases":traces.size(),"role":role}
