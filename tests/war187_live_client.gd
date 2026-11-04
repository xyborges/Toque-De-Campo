extends WarGame
# The baseline uses protocol 18 against build 57. No authentication, gameplay,
# authority or transport checks are bypassed by this diagnostic client.
func _appearance_payload() -> Dictionary:
	var payload:=super._appearance_payload()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-protocol="): payload.war_protocol=int(arg.trim_prefix("--probe-protocol="))
	return payload
func gameplay_input_allowed() -> bool:
	if DisplayServer.get_name()=="headless": return join_ready and is_instance_valid(local_player) and local_player.hp>0 and local_player.deployed and not ui_focus.blocked()
	return super.gameplay_input_allowed()
