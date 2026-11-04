extends SceneTree
var game: WarGame
var role:="server"
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
 run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label)
 print(("PASS " if ok else "FAIL ")+label)
func wait_for(test:Callable,label:String,seconds:=80.) -> bool:
 var until:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<until:
  if test.call():return true
  await process_frame
 failures.append("timeout "+label);return false
func run() -> void:
 game=load("res://tests/bots195_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true)
 if role=="server":game.set_meta("war_host",true);game.set_meta("online_bots_test",true)
 else:game.set_meta("war_visual_preview",true)
 root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
 if role=="server":await server()
 else:await client()
 var out:Dictionary={"role":role,"checks":checks,"failures":failures}
 NavalStorage.write_json("res://work/1102-bots-"+role+".json",out);print(JSON.stringify(out))
 game.show_menu();game.queue_free();await create_timer(.5).timeout;quit(0 if failures.is_empty() else 1)
func server() -> void:
 if not await wait_for(func():return game.get("reports").has("alpha"),"alpha",120):return
 if not await wait_for(func():return is_instance_valid(game.bot_director) and game.bot_director.bots.size()==28 and game.players.size()==29,"28 bots",120):return
 var director:=game.bot_director
 var deployed:=0;var teams:=[0,0];var objectives:Dictionary={}
 for id in director.bots:
  var actor:=game.players[id] as WarPlayer
  if actor.deployed:deployed+=1
  teams[int(director.bots[id].team)]+=1
  var objective:=str(director.bots[id].objective);objectives[objective]=int(objectives.get(objective,0))+1
 check(deployed==28,"28 bots truly deployed; failures="+str(director.diagnostics.deploy_failures))
 check(teams==[14,14],"14 bots per team "+str(teams))
 director._assign_objectives();objectives={}
 for record:Dictionary in director.bots.values():objectives[record.objective]=int(objectives.get(record.objective,0))+1
 print("OBJECTIVES ",objectives)
 check(objectives.size()==5,"all five objectives assigned "+str(objectives))
 var file:=FileAccess.open("res://work/1102-bravo-go",FileAccess.WRITE);file.store_string("go");file.close()
 if not await wait_for(func():return game.get("reports").has("bravo") and director.bots.size()==28 and game.players.size()==30,"second player and 28 bots",120):return
 check(true,"28 bots remain when a second human joins")
 var before:int=director.diagnostics.moves
 var sides:Array=[null,null]
 for id in director.bots:
  var team:=int(director.bots[id].team)
  if sides[team]==null:sides[team]=game.players[id]
 var point:=Vector3.ZERO
 for x in range(-120,121,20):
  var a:=WarTerrain.point(x,0);var b:=WarTerrain.point(x+10,0)
  if game.npc_line_clear(a+Vector3.UP*1.5,b+Vector3.UP*1.5):point=a;break
 for team in [0,1]:
  var bot:WarPlayer=sides[team]
  bot.global_position=WarTerrain.point(point.x+team*10,point.z)+Vector3.UP*.15
  bot.velocity=Vector3.ZERO
  director.bots[bot.peer_id].next_shot=0.;game.members[bot.peer_id].shield=0.
 await create_timer(10.).timeout
 check(int(director.diagnostics.moves)>before,"bots move through normal physics")
 check(int(director.diagnostics.target_acquisitions)>0 and int(director.diagnostics.shot_attempts)>0,"bots perceive and attempt shots in proximity")
 print("DIAGNOSTICS ",director.diagnostics)
 game._broadcast("qa_phase",["done"]);await create_timer(1.).timeout
func client() -> void:
 if role=="bravo" and not await wait_for(func():return FileAccess.file_exists("res://work/1102-bravo-go"),"go",200):return
 await game.join_game("pvp")
 if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),"join",120):return
 var team:=0 if role=="alpha" else 1
 game.request_deploy(team,"soldier","fal" if team==0 else "ak","stinger" if team==0 else "rpg","base")
 if not await wait_for(func():return game.local_player.deployed,"deploy",60):return
 game.rpc_id(1,"qa_report",role)
 check(await wait_for(func():return game.players.size()>=29,"replicated actors",120),"clients receive 28 bots")
 check(await wait_for(func():return int(game.get("bot_batches"))>=2,"pose packets",30),"clients receive moving bot snapshots")
 await wait_for(func():return game.get("phase")=="done","end",170)
