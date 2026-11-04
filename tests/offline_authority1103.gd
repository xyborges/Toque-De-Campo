extends SceneTree
class Accounts extends NavalAccounts:
 var calls:=0
 func call_api(_action: String,_payload: Dictionary={}) -> Dictionary:
  calls+=1;return {"ok":false}
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label)
 print(("PASS " if ok else "FAIL ")+label)
func wait_for(test:Callable) -> bool:
 var end:=Time.get_ticks_msec()+60000
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await process_frame
 return false
func run() -> void:
 var accounts:=Accounts.new();root.add_child(accounts)
 var game:=WarGame.new();game.offline_operation=true;game.accounts_service=accounts;game.set_meta("war_test",true);root.add_child(game)
 check(await wait_for(func():return game.join_ready and is_instance_valid(game.local_player)),"offline deployment loads locally")
 check(not game.online and game.network_api.multiplayer_peer is OfflineMultiplayerPeer and game.multiplayer.get_peers().is_empty(),"offline uses no network transport")
 game.request_deploy(0,"soldier","fal","stinger","base")
 check(await wait_for(func():return game.players.size()==18),"18participants are simulated on client")
 var teams:=[0,0]
 for member: Dictionary in game.members.values():
  if int(member.team) in [0,1]:teams[int(member.team)]+=1
 check(teams==[9,9] and game.bot_director.enabled and not game.bot_director.online_fill,"offline authority creates balanced9vs9 locally")
 await create_timer(2.).timeout
 check(int(game.bot_director.diagnostics.moves)>0,"offline bots move through local simulation")
 check(accounts.calls==0,"offline never contacts account/server services")
 game.show_menu();check(game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not game.online,"leaving offline retains no connection")
 game.free();accounts.free();await process_frame
 var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual full War offline world and local18participant9vs9 AI; fake account boundary rejects all external calls, no network transport."}
 NavalStorage.write_json("res://work/offline-authority1103.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
