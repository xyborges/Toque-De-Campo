extends SceneTree
class Authority extends WarVehicles:
	func _ready() -> void:
		tv.manager=self;set_process(false);set_physics_process(false);set_process_input(false)
	func _broadcast(_method: String,_args: Array) -> void: pass

var failures: Array[String]=[]
func _initialize() -> void:
	Engine.physics_ticks_per_second=40
	run.call_deferred()
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var ground:=StaticBody3D.new();ground.collision_layer=1;ground.position=Vector3(500,9.5,500)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(120,1,120);shape.shape=box;ground.add_child(shape);stage.add_child(ground)
	await physics_frame
	for mode in ["offline","online"]:
		if mode=="online":
			var peer:=ENetMultiplayerPeer.new()
			if peer.create_server(28993,1)!=OK: failures.append("test server did not start");break
			root.multiplayer.multiplayer_peer=peer
		for kind in ["guarani","bmp2","abrams","t90"]:
			var game:=WarGame.new();game.offline_operation=mode=="offline";game.online=mode=="online"
			var manager:=Authority.new();manager.game=game;stage.add_child(manager)
			var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id=kind;vehicle.position=Vector3(500,10.2,500);manager.add_child(vehicle)
			vehicle.driver=77;manager.vehicles[kind]=vehicle
			var start:=vehicle.position;var lowest_up:=1.;var maximum_step:=0.
			for tick in 120:
				game.war_clock+=.025;manager.controls[77]={"throttle":.5,"steer":.65,"at":game.war_clock,"aim":Vector3(500,12,0)}
				var before:=vehicle.position;manager._physics_process(.025)
				maximum_step=maxf(maximum_step,vehicle.position.distance_to(before));lowest_up=minf(lowest_up,vehicle.basis.y.y)
				await physics_frame
			var ok:=absf(vehicle.heading)>.3 and vehicle.position.distance_to(start)>3 and lowest_up>.8 and vehicle.position.y>=9.85 and maximum_step<.6
			print("STEERING40 ",JSON.stringify({"mode":mode,"vehicle":kind,"turn_radians":vehicle.heading,"distance":vehicle.position.distance_to(start),"min_up":lowest_up,"max_step":maximum_step,"passed":ok}))
			if not ok: failures.append(mode+" "+kind)
			manager.queue_free();await physics_frame;game.free()
		if mode=="online": root.multiplayer.multiplayer_peer.close();root.multiplayer.multiplayer_peer=null
	stage.queue_free();await process_frame
	print("STEERING40_FAILURES ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
