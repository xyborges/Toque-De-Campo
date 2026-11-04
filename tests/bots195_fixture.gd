extends "res://tests/bugs187_network_fixture.gd"
var bot_batches:=0
var max_bot_packet:=0
@rpc("authority","call_remote","unreliable")
func war_bot_states(batch: Array) -> void:
	bot_batches+=1;max_bot_packet=maxi(max_bot_packet,var_to_bytes(batch).size())
	super.war_bot_states(batch)
