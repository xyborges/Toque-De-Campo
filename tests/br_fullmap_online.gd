extends SceneTree

var role:="server"
var game: BattleRoyaleGame
var checks:=0
var failures: Array[String]=[]
var metrics: Dictionary={}
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
 run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1;print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func wait_for(test: Callable,label: String,seconds:=35.) -> bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
 while Time.get_ticks_msec()<deadline:
  if test.call():return true
  await create_timer(.03).timeout
 check(false,"timeout "+label);return false
func run() -> void:
 game=load("res://tests/br_fullmap_online_fixture.gd").new();game.offline_operation=false;game.set_meta("br_direct_connect",true);root.add_child(game)
 await process_frame;await process_frame
 if role!="server":
  game.join_game("pvp")
  await create_timer(100.).timeout;quit(1);return
 game.open_qa_host()
 check(game.map_kind=="afghan" and game.afghan_map.built and game.navigation.ready,"server builds full Afghan world and prepared navigation")
 if await wait_for(func():return game._human_ids().size()==2 and game._cohort_ready(),"two clients prepare actual maps and join over DTLS",55.):
  check(game.players.size()==30,"two humans plus28 authority bots on full map")
  game.round_start_clock=game._now()-.1;game.start_br_round()
  check(game.phase=="active","authority starts prepared cohort")
  await create_timer(.4).timeout
  for id in game._human_ids():game.rpc_id(id,"qa_settled","seeded_spawn")
  if await wait_for(func():return game.qa_results.size()==2,"clients settle on distant seeded spawns",12.):
   for value: Dictionary in game.qa_results.values():check(value.ok,"online full-map spawn settles without desert clamp")
   metrics.seeded_spawns=game.qa_results.duplicate(true)
  var route_z:=NAN
  for z in range(-120,121,12):
   var good:=true;var previous_y:=BRAfghanMap.height_at(145.,z)
   for x in range(145,159):
    var p:=BRAfghanMap.point(x,z)
    if absf(p.y-previous_y)>.25 or BRAfghanMap.is_water(p) or not game._spawn_capsule_clear(p+Vector3.UP*.12):good=false;break
    previous_y=p.y
   if good:route_z=float(z);break
  check(is_finite(route_z),"clear gentle physical route crosses the former149m boundary")
  if is_finite(route_z):
   var id: int=game._human_ids()[0];var actor: GamePlayer=game.players[id]
   actor.position=BRAfghanMap.point(145.,route_z)+Vector3.UP*.12;actor.velocity=Vector3.ZERO;actor.yaw=0.;actor.rotation.y=0.
   game.network_guard.clear();game.rpc_id(id,"br_spawn",id,actor.position,actor.life_id,game.br_generation)
   await create_timer(.3).timeout
   game.rpc_id(id,"qa_walk","cross_boundary")
   var key:=str(id)+":cross_boundary"
   if await wait_for(func():return game.qa_results.has(key),"real client input across old boundary",12.):
    var result: Dictionary=game.qa_results[key];metrics.walk=result
    check(result.ok,"walking input crosses former invisible wall and stays grounded")
    await create_timer(.3).timeout
    metrics.authority_walk_position=actor.position
    check(actor.position.x>151.,"server accepts and replicates movement beyond former149m square")
  for id in game._human_ids():game.rpc_id(id,"qa_finish")
  await wait_for(func():return game._human_ids().is_empty(),"two client disconnects",12.)
  check(game.phase=="cancelled","last human exit cleans full-map room")
 metrics.results=game.qa_results
 var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Three independent local Godot processes: full Afghan authority with28bots and two full-map clients using production prebuild/join/connect/spawn and actual on-foot movement over ENet/DTLS. QA bypasses account matchmaking and shortens queue; no production restart or publish."}
 NavalStorage.write_json("res://work/br-fullmap-online.json",report);print("BR_FULLMAP_ONLINE ",JSON.stringify(report));game.online=false;game.free();await process_frame;quit(0 if failures.is_empty() else 1)
