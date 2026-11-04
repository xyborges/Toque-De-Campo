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
	check(game._state_recovery_payload(1,"current",2,[2]).is_empty(),"per-peer response rate capped at two per second")
	game.network_guard.clear();actor.hp=0
	check(game._state_recovery_payload(1,"current",2,[2])[1].is_empty(),"dead actors excluded")
	actor.hp=100;game.network_guard.clear();actor.deployed=false
	check(game._state_recovery_payload(1,"current",3,[2])[1].is_empty(),"undeployed actors excluded")
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
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	var result:={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://work/war-state-recovery-validation.json",result)
	print("WAR_STATE_RECOVERY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
