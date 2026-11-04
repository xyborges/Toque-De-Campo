extends "res://tests/bugs186_network_fixture.gd"
var pose_relays:=0
func _broadcast(method: String,args: Array) -> void:
	if method=="remote_player_state": pose_relays+=1
	super._broadcast(method,args)
func _network_port() -> int:
	if not get_meta("war_host",false):
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-proxy-port="): return int(arg.trim_prefix("--qa-proxy-port="))
	return 39607
func _server_reload(id: int,weapon: String) -> void:
	var actor:=players.get(id) as WarPlayer
	if actor: print("RELOAD_DIAGNOSTIC ",actor.name," ",weapon," ",{"life":actor.life_id,"weapon":actor.weapon_id,"reload":actor.reload_weapon,"left":actor.reload_left,"ammo":actor.ammo,"reserve":actor.reserves,"vehicle":actor.vehicle_id,"member_vehicle":members[id].vehicle,"gadget":actor.gadget_equipped,"water":actor.in_water(),"hp":actor.hp,"deployed":actor.deployed})
	super._server_reload(id,weapon)
