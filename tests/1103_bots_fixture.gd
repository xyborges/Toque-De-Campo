extends "res://tests/bots195_fixture.gd"

var first_baseline_held:=false
@rpc("authority","call_remote","reliable")
func war_baseline_chunk(transfer: String,nonce: String,count: int,total: int) -> void:
 if "--qa-hold-first-baseline" in OS.get_cmdline_user_args() and not first_baseline_held:
  first_baseline_held=true
  var initial_count:=players.size();var before:=Engine.get_process_frames()
  rpc_id(1,"server_war_baseline_ack","old-transfer",nonce)
  rpc_id(1,"server_war_baseline_ack",transfer,"wrong-chunk")
  request_deploy(1,"soldier","ak","rpg","base")
  await get_tree().create_timer(.8).timeout
  var local_count:=1 if is_instance_valid(local_player) else 0
  NavalStorage.write_json("res://work/war-baseline-throttle1103.json",{"ok":players.size()==initial_count and initial_count-local_count==count and not join_ready and not local_player.deployed,"received_before_ack":initial_count,"remote_actors":initial_count-local_count,"received_after_wait":players.size(),"presented_frames":Engine.get_process_frames()-before,"total":total})
 await super.war_baseline_chunk(transfer,nonce,count,total)
