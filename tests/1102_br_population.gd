extends SceneTree
const FIXTURE=preload("res://tests/br_round_clock_fixture.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
 print(("PASS " if ok else "FAIL ")+label)
func run()->void:
 var game:BattleRoyaleGame=FIXTURE.new();game.offline_operation=false;game.set_meta("test_mode",true);root.add_child(game)
 await process_frame;game.flat_world();game.online=true;game.phase="waiting"
 var human:=game._spawn_player(1,true,false,Vector3(0,0,-18)) as BRPlayer
 game.br_inventory.add_player(1);game._fill_queue_bots()
 var bots:=0
 for actor:BRPlayer in game.players.values():
  if actor.br_bot:bots+=1
 check(bots==28 and game.players.size()==29,"28 authority bots plus one human")
 var extra:=game._spawn_player(2,false,false,Vector3(10,0,-18)) as BRPlayer
 game.br_inventory.add_player(2);game._fill_queue_bots();bots=0
 for actor:BRPlayer in game.players.values():
  if actor.br_bot:bots+=1
 check(bots==28 and game.players.size()==30,"28 bots persist after another human joins")
 check(game._queue_roster(1).size()==30,"roster contains all participants")
 var report={"checks":checks,"failures":failures,"participants":game.players.size(),"bots":bots,"scope":"Authority flat scene fill/roster, not a full round or 28-client performance test"}
 NavalStorage.write_json("res://work/1102-br-population.json",report);print(JSON.stringify(report))
 game.leave_match();await create_timer(.05).timeout;game.free();await process_frame;quit(0 if failures.is_empty() else 1)
