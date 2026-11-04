extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func state(actor: WarPlayer,sequence: int,point: Vector3) -> Array:
	return [actor.peer_id,point,0.,0.,actor.weapon_id,actor.hp,actor.crouched,actor.life_id,actor.kills,actor.deaths,0,0.,sequence]
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var a:=game.players[2] as WarPlayer
	var b:=game.make_actor(3,false,1,"soldier",Vector3(5,0,0)) as WarPlayer
	var payload:=var_to_bytes([state(a,1,Vector3.ZERO),state(b,1,Vector3.ZERO),state(a,2,Vector3.ZERO),state(b,2,Vector3.ZERO)]).size()
	check(payload<1000,"four sequenced bot states remain below the conservative payload budget: "+str(payload))
	game.war_bot_states([state(a,20,Vector3(20,0,0))])
	game.war_bot_states([state(b,2,Vector3(3,0,0))])
	check(a.network_target==Vector3(20,0,0) and b.network_target==Vector3(3,0,0),"each actor accepts its own fresh sequence independently")
	game.war_bot_states([state(a,19,Vector3(19,0,0)),state(b,3,Vector3(4,0,0))])
	check(a.network_target==Vector3(20,0,0) and b.network_target==Vector3(4,0,0),"reordering one actor does not discard a fresh pose for another actor")
	game.war_bot_states([state(a,20,Vector3(15,0,0))])
	check(a.network_target==Vector3(20,0,0),"duplicate poses cannot rewind an actor")
	game.war_bot_states([state(a,0,Vector3(0,0,0))])
	check(a.network_target==Vector3(20,0,0),"bot poses require a positive sequence")
	var old_life:=state(a,999,Vector3(99,0,0));a.life_id+=1
	game.war_bot_states([state(a,1,Vector3(21,0,0)),old_life])
	check(a.network_target==Vector3(21,0,0),"new life accepts reset sequence and rejects late previous-life poses")
	var legacy:=state(a,5,Vector3(5,0,0));legacy.pop_back();game.war_bot_states([legacy])
	check(a.network_target==Vector3(21,0,0),"old unsequenced packet format cannot overwrite the current protocol")
	var objectives:=WarRules.fresh_objectives()
	game.war_snapshot(200.,900.,[200,200],objectives,false,-1,0,60.,1)
	game.war_snapshot(199.,901.,[201,201],objectives,false,-1,0,60.,1)
	check(game.war_clock==200. and game.match_left==900.,"late operation snapshot cannot rewind clock or tickets")
	game.war_snapshot(200.,500.,[10,10],objectives,false,-1,0,60.,1)
	check(game.match_left==900.,"duplicate operation snapshot is ignored")
	game.war_snapshot(2.,1200.,[300,300],objectives,false,-1,0,60.,2)
	game.war_snapshot(999.,5.,[1,1],objectives,false,-1,0,60.,1)
	check(game.war_clock==2. and game.match_left==1200.,"new generation accepts its first snapshot and rejects previous generation")
	game.war_snapshot(NAN,1.,[1,1],objectives,false,-1,0,60.,2)
	check(game.war_clock==2.,"invalid snapshot timestamp is ignored")
	var next:=game.network_diagnostics.next_pose_sequence(a.peer_id,a.life_id)
	var second:=game.network_diagnostics.next_pose_sequence(a.peer_id,a.life_id)
	check(next==1 and second==2,"authority bot sequences advance in the same per-life stream as human poses")
	game.show_menu();game.queue_free();await create_timer(.3).timeout
	NavalStorage.write_json("res://work/war-state-ordering.json",{"checks":checks,"failures":failures})
	print("WAR_STATE_ORDERING ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
