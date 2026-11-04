extends "res://tests/domination_network_fixture.gd"
var inventory_calls:=0
var equipment_calls:=0
var hud_calls:=0
var supply_microseconds: Array[int]=[]
func _network_port() -> int: return 39582
func update_hud() -> void:
	hud_calls+=1;super.update_hud()
@rpc("authority","call_remote","reliable")
func remote_inventory(id: int,magazines: Dictionary,reserve: Dictionary,ack: int,reload_id: String,reload_seconds: float,total_seconds: float=0.,paused: Dictionary={},inventory_life: int=0,revision: int=-1) -> void:
	inventory_calls+=1;super.remote_inventory(id,magazines,reserve,ack,reload_id,reload_seconds,total_seconds,paused,inventory_life,revision)
@rpc("authority","call_remote","reliable")
func remote_equipment(id: int,choices: Array,enabled: bool,count: int) -> void:
	equipment_calls+=1;super.remote_equipment(id,choices,enabled,count)
@rpc("any_peer","call_remote","reliable")
func server_supply_request(life: int) -> void:
	var started:=Time.get_ticks_usec();super.server_supply_request(life);supply_microseconds.append(Time.get_ticks_usec()-started)
