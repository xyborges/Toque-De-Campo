extends SceneTree
var role:="server"
var game: WarGame
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
 run.call_deferred()
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label)
 print(("PASS " if value else "FAIL ")+label)
func wait_for(test: Callable,seconds:=20.) -> bool:
 var until:=Time.get_ticks_msec()+int(seconds*1000.)
 while Time.get_ticks_msec()<until:
  if test.call():return true
  await process_frame
 return false
func make_game(fault:="") -> void:
 game=load("res://tests/join1103_faults_fixture.gd").new()
 game.set_meta("war_test",true);game.set_meta("war_visual_preview",role!="server");game.set_meta("war_host",role=="server")
 game.set("fault",fault);root.add_child(game);game.address_input.text="127.0.0.1";game.nickname_input.text=role
func drop_game() -> void:
 game.closing=true;game.online=false;game.multiplayer.multiplayer_peer.close();game.free();await process_frame
func run() -> void:
 if role=="server":
  make_game()
  check(await wait_for(func():return game.get("qa").has("alpha")),"first client remains connected")
  check(await wait_for(func():return game.get("qa").has("complete"),80),"client reconnects after intentional leave and both timeout types")
  var results: Dictionary=game.get("qa")
  check(results.get("stall_blocked",false),"stall failure blocks deployment during delayed disconnect")
  check(results.get("total_blocked",false),"total timeout blocks deployment during delayed disconnect")
  check(game.players.size()==2 and game.loading_baselines.is_empty(),"disconnected transfers cleaned and two live clients remain")
  game._broadcast("qa_done",[]);await create_timer(1.).timeout
 elif role=="alpha":
  make_game();await game.join_game("pvp")
  check(await wait_for(func():return game.join_ready),"initial client ready")
  game.rpc_id(1,"qa_report","alpha")
  check(await wait_for(func():return game.get_meta("done",false),85),"other clients timeout without dropping healthy client")
 else:
  await create_timer(2.).timeout
  for fault in ["disconnect","stall","total"]:
   if fault=="stall":await wait_for(func():return Time.get_ticks_msec()>31000,35.)
   make_game(fault);await game.join_game("pvp")
   check(await wait_for(func():return game.get("held")),"failure path reached "+fault)
   check(await wait_for(func():return not game.online or game.multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED),"connection ends cleanly "+fault)
   check(not game.join_ready,"failed transfer never becomes ready "+fault)
   await drop_game();await create_timer(.4).timeout
  make_game();await game.join_game("pvp")
  check(await wait_for(func():return game.join_ready),"fresh transfer succeeds after reconnect")
  game.rpc_id(1,"qa_report","complete")
  await wait_for(func():return game.get_meta("done",false))
 var report:={"role":role,"checks":checks,"failures":failures}
 NavalStorage.write_json("res://work/join1103-faults-"+role+".json",report);print(JSON.stringify(report));await drop_game();quit(0 if failures.is_empty() else 1)
