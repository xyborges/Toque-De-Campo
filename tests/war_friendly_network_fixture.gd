extends "res://tests/war_network_fixture.gd"
var author_peer:=0
var victim_peer:=0
func _network_port() -> int: return 39588
@rpc("authority","call_remote","reliable")
func qa_identities(author_id: int,victim_id: int) -> void:
	author_peer=author_id;victim_peer=victim_id
