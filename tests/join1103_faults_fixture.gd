extends WarGame
var fault:=""
var held:=false
var qa: Dictionary={}
func _network_port() -> int:return 39619
func _enter_match_world() -> void:
 if is_instance_valid(world_root):return
 world_root=Node3D.new();add_child(world_root);map_kind="war"
 var floor_body:=StaticBody3D.new();world_root.add_child(floor_body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1400,1,1000);shape.shape=box;shape.position.y=-.5;floor_body.add_child(shape)
func _physics_process(_delta: float) -> void:pass
func _process(_delta: float) -> void:pass
@rpc("authority","call_remote","reliable")
func war_baseline_chunk(transfer: String,nonce: String,count: int,total: int) -> void:
 if not held and not fault.is_empty():
  held=true
  rpc_id(1,"server_war_baseline_ack","previous-transfer",nonce)
  request_deploy(1,"soldier","ak","rpg","base")
  if fault=="disconnect":
   await get_tree().create_timer(.15).timeout
   multiplayer.multiplayer_peer.close();online=false;return
  rpc_id(1,"qa_expire",fault)
  return
 await super.war_baseline_chunk(transfer,nonce,count,total)
@rpc("any_peer","call_remote","reliable")
func qa_expire(kind: String) -> void:
 var id:=multiplayer.get_remote_sender_id()
 if not multiplayer.is_server() or not loading_baselines.has(id):return
 var transfer: WarJoinTransfer=loading_baselines[id]
 if kind=="total":transfer.started=Time.get_ticks_msec()-120001
 else:transfer.waiting_since=Time.get_ticks_msec()-30001
 await get_tree().create_timer(.1).timeout
 qa[kind+"_blocked"]=loading_baselines.get(id)==transfer and transfer.failed and not _deploy(id,1,"soldier","ak","rpg","base")
@rpc("any_peer","call_remote","reliable")
func qa_report(label: String) -> void:
 if multiplayer.is_server():qa[label]=true

@rpc("authority","call_remote","reliable")
func qa_done() -> void:set_meta("done",true)
