extends "res://tests/combat_153_network_fixture.gd"
func _network_port() -> int: return 39583
@rpc("any_peer","call_remote","reliable")
func qa_prepare_death() -> void:
	if not multiplayer.is_server(): return
	var actor:=players.get(multiplayer.get_remote_sender_id()) as GamePlayer
	if not is_instance_valid(actor) or str(actor.name)!="shooter": return
	actor.ammo.fal=11;actor.ammo.glock=3;sync_inventory(actor)
