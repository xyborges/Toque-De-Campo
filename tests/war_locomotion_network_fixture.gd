extends "res://tests/war_network_fixture.gd"

var corrections:=0

func _network_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--war-port="): return int(arg.trim_prefix("--war-port="))
	return 39572

@rpc("authority","call_remote","unreliable")
func remote_position_correction(point: Vector3) -> void:
	corrections+=1
	super.remote_position_correction(point)
