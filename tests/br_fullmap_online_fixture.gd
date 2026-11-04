extends BattleRoyaleGame

var qa_results: Dictionary={}
func _ready() -> void:
 set_meta("br_host",true);set_meta("test_mode",true)
 super._ready()
 address_input.text="127.0.0.1"
func host_game(_kind: String) -> void:pass
func open_qa_host() -> void:
 super.host_game("pvp")
 dedicated_pvp=false
func _network_port() -> int:return 39598
func gameplay_input_allowed() -> bool:return phase=="active" and not closing
@rpc("authority","call_remote","reliable")
func qa_walk(label: String) -> void:
 var actor:=local_player
 var before:=actor.position
 Input.action_press("move_right")
 await get_tree().create_timer(2.2).timeout
 Input.action_release("move_right")
 await get_tree().create_timer(.3).timeout
 var query:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*.15,actor.position-Vector3.UP*.6,1,[actor.get_rid()])
 var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
 var good:=map_kind=="afghan" and actor.position.x>151. and actor.position.distance_to(before)>5. and actor.is_on_floor() and not hit.is_empty()
 qa_report.rpc_id(1,label,{"ok":good,"map":map_kind,"before":before,"after":actor.position,"on_floor":actor.is_on_floor(),"floor_y":float(hit.get("position",Vector3.ZERO).y)})
@rpc("authority","call_remote","reliable")
func qa_settled(label: String) -> void:
 await get_tree().create_timer(2.).timeout
 var actor:=local_player
 var query:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*.15,actor.position-Vector3.UP*.6,1,[actor.get_rid()])
 var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
 qa_report.rpc_id(1,label,{"ok":map_kind=="afghan" and actor.is_on_floor() and not hit.is_empty() and absf(actor.position.x)>149.,"map":map_kind,"position":actor.position,"on_floor":actor.is_on_floor(),"floor_y":float(hit.get("position",Vector3.ZERO).y)})
@rpc("any_peer","call_remote","reliable")
func qa_report(label: String,result: Dictionary) -> void:
 if multiplayer.is_server():qa_results[str(multiplayer.get_remote_sender_id())+":"+label]=result
@rpc("authority","call_remote","reliable")
func qa_finish() -> void:
 leave_match()
 await get_tree().create_timer(2.5).timeout
 get_tree().quit()
