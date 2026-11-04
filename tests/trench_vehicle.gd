extends SceneTree

class Authority extends WarVehicles:
	var packets:=0
	func _ready() -> void:
		tv.manager=self
		set_process(false);set_physics_process(false);set_process_input(false)
	func _broadcast(_method: String,_args: Array) -> void: packets+=1

var failures: Array[String] = []
var fixed_delta:=1./60.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	Engine.max_fps=0
	if "--ticks40" in OS.get_cmdline_user_args(): Engine.physics_ticks_per_second=40;fixed_delta=1./40.
	else: Engine.physics_ticks_per_second=240
	var stage:=Node3D.new();root.add_child(stage)
	WarTerrain.build(stage,false,[Vector2i(15,16),Vector2i(16,16),Vector2i(17,16),Vector2i(18,16),Vector2i(19,16)])
	await physics_frame
	for mode in ["offline","online_authority"]:
		if mode=="online_authority":
			var peer:=ENetMultiplayerPeer.new()
			if peer.create_server(28992,1)!=OK: failures.append("could not create isolated server");break
			root.multiplayer.multiplayer_peer=peer
		for kind in ["guarani","bmp2","abrams","t90"]:
			for reverse in [false,true]:
				for path in ([Vector3(-135,0,-125)] if "--ticks40" in OS.get_cmdline_user_args() else [Vector3(-135,0,-125),Vector3(170,0,-90)]):
					await scenario(stage,mode,kind,reverse,path)
		if mode=="online_authority": root.multiplayer.multiplayer_peer.close();root.multiplayer.multiplayer_peer=null
	stage.queue_free();await process_frame
	print("TRENCH_FAILURES ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)

func scenario(stage: Node3D,mode: String,kind: String,reverse: bool,path: Vector3) -> void:
			var game:=WarGame.new();game.offline_operation=mode=="offline";game.online=mode=="online_authority"
			var authority:=Authority.new();authority.game=game;stage.add_child(authority)
			var vehicle:=WarVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="trench_"+kind
			vehicle.position=WarTerrain.point(path.x,path.z)+Vector3.UP*.3
			vehicle.heading=0 if path.x<0 else -PI*.5;vehicle.rotation.y=vehicle.heading
			authority.add_child(vehicle);vehicle.driver=77;authority.vehicles[vehicle.vehicle_id]=vehicle
			var mirror:=WarVehicle.new();mirror.kind=kind;mirror.vehicle_id="observer";stage.add_child(mirror);mirror.collision_layer=0;mirror.collision_mask=0
			for i in (40 if fixed_delta>1./60. else 100):
				game.war_clock+=fixed_delta;authority.controls[77]={"throttle":0.,"at":game.war_clock,"aim":Vector3.FORWARD*1000}
				authority._physics_process(fixed_delta);await physics_frame
			var origin:=vehicle.position
			var forward:=Basis(Vector3.UP,vehicle.heading)*Vector3.FORWARD
			var max_step:=0.
			for i in 600:
				var before:=vehicle.position
				game.war_clock+=fixed_delta;authority.controls[77]={"throttle":-1. if reverse else 1.,"steer":0.,"at":game.war_clock,"aim":Vector3.FORWARD*1000}
				authority._physics_process(fixed_delta)
				mirror.receive(vehicle.snapshot());mirror.collision_layer=0;mirror.render(fixed_delta)
				max_step=maxf(max_step,vehicle.position.distance_to(before));await physics_frame
				if absf((vehicle.position-origin).dot(forward))>12.: break
			var moved:=absf((vehicle.position-origin).dot(forward))
			var ok:=moved>12. and max_step<1. and authority.packets>0 and mirror.destination.distance_to(vehicle.position)<.001
			var result:={"mode":mode,"kind":kind,"reverse":reverse,"path":str(path),"origin":str(origin),"end":str(vehicle.position),"travel":moved,"max_step":max_step,"packets":authority.packets,"passed":ok}
			print("TRENCH_VEHICLE ",JSON.stringify(result))
			if not ok: failures.append("%s %s reverse=%s path=%s"%[mode,kind,reverse,path])
			authority.queue_free();mirror.queue_free();await physics_frame;game.free()
