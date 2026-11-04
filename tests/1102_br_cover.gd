extends SceneTree
const FIXTURE=preload("res://tests/br_round_clock_fixture.gd")
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label)
 print(("PASS " if ok else "FAIL ")+label)
func run()->void:
 var game:BattleRoyaleGame=FIXTURE.new();game.set_meta("test_mode",true);root.add_child(game)
 await process_frame;game.flat_world()
 var bot:=game._spawn_player(100000,false,false,Vector3.ZERO) as BRPlayer;bot.br_bot=true
 var enemy:=game._spawn_player(2,false,false,Vector3(0,0,-12)) as BRPlayer
 bot.set_physics_process(false);enemy.set_physics_process(false)
 var brain:=BRBotBrain.new()
 await physics_frame;await physics_frame
 check(not brain._find_cover(game,bot,enemy).is_finite(),"no false cover in open field")
 var wall:=StaticBody3D.new();game.world_root.add_child(wall)
 var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.6,1.25,.35);col.shape=box;col.position=Vector3(2.75,.625,-1.);wall.add_child(col)
 await physics_frame;await physics_frame
 var point:=brain._find_cover(game,bot,enemy)
 check(point.is_finite() and point.x>2.,"low wall conceals body with line of sight from eye")
 col.position.y=1.3;box.size.y=2.6
 await physics_frame;await physics_frame
 check(not brain._find_cover(game,bot,enemy).is_finite(),"solid wall blocking eyes rejected")
 var result={"failures":failures,"scope":"headless geometry test; 2 side candidates, body and eye rays, no multiplayer or performance claim"}
 NavalStorage.write_json("res://work/1102-br-cover.json",result);print(JSON.stringify(result))
 game.leave_match();await create_timer(.05).timeout;game.free();await process_frame;quit(0 if failures.is_empty() else 1)
