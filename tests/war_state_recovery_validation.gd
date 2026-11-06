extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var actor:=game.players[2] as WarPlayer
	game.state_recovery_sessions[1]={"token":"current","sequence":0}
	check(game._state_recovery_payload(1,"old",1,[2]).is_empty(),"previous connection token rejected")
	check(game._state_recovery_payload(99,"current",1,[2]).is_empty(),"unadmitted peer rejected")
	game.loading_baselines[1]=WarJoinTransfer.new()
	check(game._state_recovery_payload(1,"current",1,[2]).is_empty(),"loading peer cannot request second baseline")
	game.loading_baselines.clear()
	var too_many: Array=[];too_many.resize(WarRules.CAPACITY+1)
	check(game._state_recovery_payload(1,"current",1,too_many).is_empty(),"oversized requests rejected before allocation")
	var payload:=game._state_recovery_payload(1,"current",1,[2,2,1,999,"2"])
	check(payload.size()==2 and payload[1].size()==1,"deduplicate IDs and ignore self unknown and malformed IDs")
	check(payload[1][0][1]==actor.global_position and payload[1][0][7]==actor.life_id,"recovery uses authority position and life")
	check(game._state_recovery_payload(1,"current",1,[2]).is_empty(),"replayed request sequence rejected")
	check(not game._state_recovery_payload(1,"current",2,[2]).is_empty(),"bounded second token tolerates compressed request arrivals")
	check(game._state_recovery_payload(1,"current",3,[2]).is_empty(),"infantry cannot exceed bounded recovery burst")
	game.network_guard.clear();actor.hp=0
	check(game._state_recovery_payload(1,"current",3,[2])[1].is_empty(),"dead actors excluded")
	actor.hp=100;game.network_guard.clear();actor.deployed=false
	check(game._state_recovery_payload(1,"current",4,[2])[1].is_empty(),"undeployed actors excluded")
	actor.deployed=true
	game.baseline_transfer="current";game.authority_round_generation=1
	game.war_snapshot(200.,900.,[200,200],WarRules.fresh_objectives(),false,-1,0,60.,1)
	game.war_bot_states([[2,Vector3(20,0,0),0.,0.,"fal",100.,false,actor.life_id,0,0,0,0.,20]])
	var operation: Array=[199.,901.,[201,201],WarRules.fresh_objectives(),false,-1,0,60.,1]
	var old_pose: Array=[2,Vector3(19,0,0),0.,0.,"fal",100.,false,actor.life_id,0,0,0,0.,19]
	game.state_recovery_pending=4;game.war_state_recovery("old",4,operation,[old_pose])
	check(game.state_recovery_pending==4,"old token cannot consume pending request")
	game.war_state_recovery("current",3,operation,[old_pose])
	check(game.state_recovery_pending==4,"unmatched response cannot consume pending request")
	game.war_state_recovery("current",4,operation,[old_pose])
	check(game.state_recovery_pending==0 and actor.network_target==Vector3(20,0,0) and game.match_left==900.,"late recovery releases wait without rewinding newer operation or pose")
	game.state_recovery_pending=5;operation[0]=201.;old_pose[1]=Vector3(21,0,0);old_pose[12]=21
	game.war_state_recovery("current",5,operation,[old_pose])
	check(actor.network_target==Vector3(21,0,0) and game.war_clock==201.,"current recovery passes ordinary application path")
	actor.life_id+=1;game.state_recovery_pending=6;operation[0]=202.;old_pose[12]=999
	game.war_state_recovery("current",6,operation,[old_pose])
	check(actor.network_target==Vector3(21,0,0),"late prior-life recovery cannot resurrect or move respawn")
	game.state_recovery_pending=7;operation[8]=0;operation[0]=999.
	game.war_state_recovery("current",7,operation,[])
	check(game.war_clock==202. and game.state_recovery_pending==0,"previous round response ignored without deadlocking recovery")
	game.state_recovery_pending=8;game.baseline_loading=true;operation[8]=1
	game.war_state_recovery("current",8,operation,[])
	check(game.state_recovery_pending==8,"baseline remains exclusive")
	game.baseline_loading=false
	var manager:=game.vehicle_system as WarVehicles
	var vehicle:=manager.vehicles.values()[0] as WarVehicle
	var driver:=game.local_player as WarPlayer
	driver.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id
	vehicle.receive_seats({0:1},1,1)
	vehicle.speed=8.
	var first:=manager._vehicle_snapshot_for_send(vehicle,-1,true)
	manager.vehicle_state(first)
	check(not manager.local_state_stale(vehicle.received_state_usec+149999),"moving vehicle tolerates ordinary snapshot spacing")
	check(manager.local_state_stale(vehicle.received_state_usec+150000),"moving vehicle requests repair before a quarter-second freeze")
	vehicle.speed=0.
	check(not manager.local_state_stale(vehicle.received_state_usec+600000),"parked heartbeat does not provoke recovery traffic")
	check(manager.local_state_stale(vehicle.received_state_usec+650000),"lost final parked pose is eventually repaired")
	var repair:=manager._occupied_recovery_state(1)
	check(not repair.is_empty() and repair.sequence>first.sequence,"occupied repair forces a fresh sequenced snapshot even at rest")
	vehicle.position=Vector3(22,0,0)
	var newer:=manager._vehicle_snapshot_for_send(vehicle,-1,true)
	manager.vehicle_state(newer)
	var received_at:=vehicle.received_state_usec
	manager.baseline_vehicles([repair])
	check(vehicle.destination==Vector3(22,0,0) and vehicle.received_state_usec==received_at,"late reliable vehicle response neither rewinds nor refreshes stale timer")
	vehicle.position=Vector3(23,0,0);repair=manager._occupied_recovery_state(1)
	manager.baseline_vehicles([repair]);manager.vehicle_state(newer)
	check(vehicle.destination==Vector3(23,0,0),"late unreliable vehicle packet cannot undo repair")
	check(manager._occupied_recovery_state(99).is_empty(),"unknown actor cannot get vehicle repair")
	game.members[1].vehicle="other"
	check(manager._occupied_recovery_state(1).is_empty(),"mismatched membership cannot get vehicle repair")
	game.members[1].vehicle=vehicle.vehicle_id;vehicle.receive_seats({},2,2)
	check(manager._occupied_recovery_state(1).is_empty(),"exited vehicle is not returned to former occupant")
	vehicle.receive_seats({1:1},3,3)
	check(not manager._occupied_recovery_state(1).is_empty(),"passenger can repair their own occupied vehicle")
	manager._vehicle_snapshot_for_send(vehicle,1000000)
	var broadcast_bytes: PackedByteArray=manager.last_sent[vehicle.vehicle_id]
	vehicle.position+=Vector3.RIGHT
	manager._vehicle_snapshot_for_send(vehicle,1400000,true)
	check(manager.vehicle_sent_usec[vehicle.vehicle_id]==1000000 and manager.last_sent[vehicle.vehicle_id]==broadcast_bytes,"unicast repair cannot postpone other observers heartbeat or consume their changed pose")
	check(not manager._vehicle_snapshot_for_send(vehicle,1450000).is_empty(),"other observers still receive changed pose after unicast repair")
	game.network_guard.clear()
	check(not game._state_recovery_payload(1,"current",20,[]).is_empty(),"occupied peer may request repair")
	check(not game._state_recovery_payload(1,"current",21,[]).is_empty(),"occupied repair tolerates two compressed arrivals")
	check(game._state_recovery_payload(1,"current",22,[]).is_empty(),"occupied peer cannot exceed bounded recovery burst")
	game.network_guard.rates["1:state_recovery"].at-=.26
	check(not game._state_recovery_payload(1,"current",22,[]).is_empty(),"occupied repair quota replenishes at bounded four per second")
	driver.hp=0
	check(manager._occupied_recovery_state(1).is_empty() and not manager.local_state_stale(Time.get_ticks_usec()+1000000),"dead occupant neither requests nor receives vehicle repair")
	driver.hp=100
	var drone:=WarDrone.new();drone.drone_id="qa_recovery_drone";drone.driver=1;drone.owner_id=1
	manager.add_child(drone);manager.drones[drone.drone_id]=drone
	driver.vehicle_id=drone.drone_id;game.members[1].vehicle=drone.drone_id
	var old_drone:=manager._occupied_recovery_state(1)
	drone.position=Vector3(30,10,0);var new_drone:=drone.snapshot()
	manager.drone_state(new_drone);received_at=drone.received_state_usec
	manager.baseline_drone(old_drone)
	check(drone.destination==Vector3(30,10,0) and drone.received_state_usec==received_at,"late drone repair cannot rewind pose or refresh silence timer")
	drone.position=Vector3(31,10,0);manager.baseline_drone(manager._occupied_recovery_state(1))
	manager.drone_state(new_drone)
	check(drone.destination==Vector3(31,10,0),"unreliable drone update cannot undo newer repair")
	check(manager.local_state_stale(drone.received_state_usec+150000),"drone freshness uses its own stream")
	drone.driver=2
	check(manager._occupied_recovery_state(1).is_empty(),"drone of another operator is never repaired for caller")
	manager.drone_removed(drone.drone_id);manager.baseline_drone(new_drone)
	check(not manager.drones.has("qa_recovery_drone"),"late repair cannot resurrect retired drone")
	driver.vehicle_id="";game.members[1].vehicle=""
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	var result:={"checks":checks,"failures":failures}
	var output:=OS.get_environment("CAMPO_RECOVERY_UNIT_REPORT")
	if not output.is_empty():NavalStorage.write_json(output,result)
	print("WAR_STATE_RECOVERY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
