extends "res://tests/bots195_fixture.gd"

var baseline_started_usec:=0
var baseline_finished_usec:=0
var connected_started_usec:=0
var legacy:=false
var adds:=0
var add_peak_ms:=0.
var preview: Camera3D
func _network_port() -> int:return 39618
func host_game(kind: String) -> void:
 weather_seed=8377;WarWeather.seed=weather_seed
 super.host_game(kind)
func _connected_to_server() -> void:
 connected_started_usec=Time.get_ticks_usec()
 super._connected_to_server()
func _send_baseline_chunk(id: int,transfer: WarJoinTransfer,count: int,total: int) -> bool:
 if not legacy:return await super._send_baseline_chunk(id,transfer,count,total)
 var nonce:=transfer.begin_chunk()
 rpc_id(id,"war_baseline_chunk",transfer.token,nonce,count,total)
 await get_tree().process_frame
 return _baseline_current(id,transfer)
@rpc("authority","call_remote","reliable")
func war_baseline_begin(transfer: String,total: int) -> void:
 baseline_started_usec=Time.get_ticks_usec()
 super.war_baseline_begin(transfer,total)
@rpc("authority","call_remote","reliable")
func war_baseline_complete(transfer: String) -> void:
 super.war_baseline_complete(transfer)
 baseline_finished_usec=Time.get_ticks_usec()
@rpc("authority","call_remote","reliable")
func remote_add_player(id: int,nickname: String,appearance: Dictionary,pos: Vector3) -> void:
 var began:=Time.get_ticks_usec();var existed:=players.has(id)
 super.remote_add_player(id,nickname,appearance,pos)
 add_peak_ms=maxf(add_peak_ms,(Time.get_ticks_usec()-began)*.001)
 if not existed:adds+=1
func prepare_preview() -> void:
 preview=Camera3D.new();world_root.add_child(preview)
 preview.global_position=WarTerrain.point(-300,230)+Vector3(0,75,0)
 preview.look_at(WarTerrain.point(-80,0),Vector3.UP);preview.current=true
 for node in world_root.find_children("*","Node",true,false):
  if node is GameDayNight:node.set_process(false);node.apply_time(0,true)
func _process(delta: float) -> void:
 super._process(delta)
 if is_instance_valid(preview):preview.current=true
