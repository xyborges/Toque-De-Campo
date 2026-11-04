extends SceneTree

var role:="server"
var game: BattleRoyaleGame
var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}
var alpha:=0
var bravo:=0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func wait_for(test: Callable,label: String,seconds:=10.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.02).timeout
	check(false,"timeout "+label);return false
func command(peer: int,label: String,action: String,data: Dictionary) -> void:
	game.rpc_id(peer,"qa_bike_command",label,action,data)
	await wait_for(func():return game.acknowledgements.has(str(peer)+":"+label),label)
	await create_timer(.10).timeout
func verify(label: String,bike_id: String,driver: int,exited:=0) -> void:
	for id in game.multiplayer.get_peers():game.rpc_id(id,"qa_bike_check",label,bike_id,driver,exited)
	for id in game.multiplayer.get_peers():
		await wait_for(func():return game.acknowledgements.has(str(id)+":"+label) or game.acknowledgements.has(str(id)+":FAIL:"+label),label+str(id))
		check(game.acknowledgements.has(str(id)+":"+label),"observer state "+label+" "+str(id))
func control_data(bike: WarVehicle,number: int,life:=7,generation:=3,throttle:=1.,steer:=0.) -> Dictionary:
	return {"bike":bike.vehicle_id,"epoch":bike.control_epoch,"sequence":number,"life":life,"generation":generation,"throttle":throttle,"steer":steer}
func run() -> void:
	game=load("res://tests/br_motorbikes_network_fixture.gd").new();game.set_meta("br_host",true);game.set_meta("test_mode",true);game.offline_operation=false;root.add_child(game)
	game.flat_world();game.add_test_bikes();game.online=true;game.phase="active";game.br_generation=3
	var peer:=ENetMultiplayerPeer.new();var error: Error
	if role=="server":error=peer.create_server(39608,2)
	else:error=peer.create_client("127.0.0.1",39608,4)
	if error==OK:error=GameSecureTransport.server(peer) if role=="server" else GameSecureTransport.client(peer,"localhost")
	if error!=OK:print("TRANSPORT ",error_string(error));quit(1);return
	game.network_api.multiplayer_peer=peer
	if role=="server":game.multiplayer.peer_disconnected.connect(game._peer_disconnected)
	if role!="server":await create_timer(60.).timeout;quit(1);return
	if await wait_for(func():return game.multiplayer.get_peers().size()==2,"two DTLS clients",15.):await scenario()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"scope":"Real ENet/DTLS server and two clients. Entry/exit replicated to both, physical drive, foreign/stale control rejection, bike switch, dead/disconnected seat cleanup. Flat collision fixture; complete Afghan world tested separately."}
	NavalStorage.write_json("res://work/br-motorbikes-network.json",report);print("BR_MOTORBIKES_NETWORK ",JSON.stringify(report))
	for id in game.multiplayer.get_peers():game.rpc_id(id,"qa_bike_finish")
	await create_timer(.8).timeout;game.online=false;game.voice.shutdown();peer.close();game.free();quit(0 if failures.is_empty() else 1)
func scenario() -> void:
	var ids:=game.multiplayer.get_peers();alpha=int(ids[0]);bravo=int(ids[1])
	for index in 2:
		var id: int=ids[index];var point:=Vector3(1.6 if index==0 else -1.6,.08,0)
		var actor:=game._spawn_player(id,false,false,point);actor.hp=100.;actor.life_id=7;actor.set_physics_process(false);actor.set_process(false);actor.set_meta("br_generation",3)
		game.br_inventory.add_player(id);game._broadcast("qa_actor",[id,point])
	game.br_round.begin([alpha,bravo],game._now());await create_timer(.4).timeout
	var system: BRMotorbikes=game.motorbikes;var bike: WarVehicle=system.bikes.br_bike_00;var other: WarVehicle=system.bikes.br_bike_01
	await command(alpha,"client_cannot_mutate","direct_client",{"bike":bike.vehicle_id})
	check(bike.driver==0 and game.acknowledgements.has(str(alpha)+":client_cannot_mutate"),"client helper cannot allocate an authoritative seat")
	await command(alpha,"board","enter",{"bike":bike.vehicle_id,"life":7,"generation":3})
	check(bike.driver==alpha,"real boarding RPC reserves the seat for its sender")
	await verify("boarded",bike.vehicle_id,alpha)
	await command(bravo,"contested","enter",{"bike":bike.vehicle_id,"life":7,"generation":3})
	check(bike.driver==alpha and game.players[bravo].vehicle_id.is_empty(),"another client cannot steal an occupied bike")
	await command(alpha,"drive","control",control_data(bike,1))
	var start: Vector3=bike.position
	for number in range(2,9):await command(alpha,"drive"+str(number),"control",control_data(bike,number))
	measurements.physical_travel_m=bike.position.distance_to(start)
	check(bike.position.distance_to(start)>1.,"client throttle moves the server's real colliding bike")
	await command(bravo,"foreign_control","control",control_data(bike,90))
	check(not system.controls.has(bravo),"foreign peer cannot control someone else's bike")
	var before: int=system.sequences.get(alpha,-1)
	for entry in [["old_life",6,3],["old_round",7,2]]:await command(alpha,str(entry[0]),"control",control_data(bike,100,int(entry[1]),int(entry[2])))
	var wrong:=control_data(other,100);wrong.epoch=bike.control_epoch
	await command(alpha,"wrong_bike","control",wrong)
	check(int(system.sequences.get(alpha,-1))==before,"old life, old round and different bike cannot change accepted control")
	var old_epoch:=bike.control_epoch
	await command(alpha,"exit","enter",{"bike":bike.vehicle_id,"life":7,"generation":3})
	check(bike.driver==0 and not system.controls.has(alpha),"real exit RPC revokes input and releases the seat")
	await verify("exited",bike.vehicle_id,0,alpha)
	game.players[alpha].position=bike.position+Vector3(1.5,.08,0);game.network_guard.clear()
	await command(alpha,"reenter","enter",{"bike":bike.vehicle_id,"life":7,"generation":3})
	var stale:=control_data(bike,200);stale.epoch=old_epoch
	await command(alpha,"old_occupancy","control",stale)
	check(bike.driver==alpha and not system.controls.has(alpha),"delayed packet from an earlier boarding cannot restart movement")
	system.release(alpha,true);game.players[alpha].position=other.position+Vector3(1.5,.08,0);game.network_guard.clear()
	await command(alpha,"other_bike","enter",{"bike":other.vehicle_id,"life":7,"generation":3})
	var previous_bike:=control_data(bike,250);previous_bike.epoch=other.control_epoch
	await command(alpha,"previous_bike_control","control",previous_bike)
	check(other.driver==alpha and not system.controls.has(alpha),"matching epochs on different bikes cannot authorize delayed control")
	await verify("switched",other.vehicle_id,alpha)
	await command(alpha,"valid_second","control",control_data(other,1))
	check(system.controls.has(alpha),"current controls work after a legitimate bike switch")
	game.network_guard.clear()
	await command(alpha,"disconnect_rider","disconnect",{})
	await wait_for(func():return not game.players.has(alpha),"rider disconnect is removed",5.)
	check(other.driver==0 and other.seats.is_empty() and not system.controls.has(alpha),"real disconnect releases seat and controls before actor removal")
