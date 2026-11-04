extends "res://tests/br_completion_fixture.gd"
var stopping:=false

@rpc("authority","call_remote","reliable")
func qa_modular_command(label: String,action: String,data: Dictionary,life: int=7,generation: int=3) -> void:
	if action=="attachment":request_br_attachment(str(data.weapon),str(data.socket),str(data.attachment),int(data.get("uid",-1)),float(data.get("position",0.)))
	elif action=="drop_attachment":request_br_drop_attachment(str(data.attachment),int(data.get("uid",-1)))
	elif action=="raw_attachment":rpc_id(1,"server_br_action","attachment",data,life,generation)
	elif action=="equip":request_equip(local_player,str(data.weapon))
	else:_request_br(action,data)
	qa_ack.rpc_id(1,label)

func private_key_found(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if str(key) in ["uid","accessory_items","bag_items","ammo","magazines","reserves"] or private_key_found(value[key]):return true
	elif value is Array:
		for entry in value:
			if private_key_found(entry):return true
	return false

@rpc("authority","call_remote","reliable")
func qa_modular_check(label: String,owner: int,expected: Dictionary,bag_count: int=-1) -> void:
	var actor:=players.get(owner) as GamePlayer
	var config: Dictionary=actor.get_meta("weapon_attachments",{}) if actor else {}
	var okay: bool=actor!=null and config==expected and not private_key_found(config)
	if owner==multiplayer.get_unique_id():
		okay=okay and own_inventory.get("weapon_attachments",{})==expected
		if bag_count>=0:okay=okay and own_inventory.get("accessory_items",[]).size()==bag_count
	else:okay=okay and actor.ammo.is_empty() and actor.reserves.is_empty()
	var current: Dictionary=expected.get(str(actor.weapon_id),{}) if actor else {}
	if actor:
		okay=okay and actor.weapon_optics.mounting.instances.size()==current.size()
		for socket in current:
			var module:=actor.weapon_optics.mounting.instances.get(socket) as Node3D
			okay=okay and module!=null and module.get_meta("attachment_id","")==current[socket].id
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)

@rpc("authority","call_remote","reliable")
func qa_rebuild_attachment_actor(label: String,owner: int,pos: Vector3) -> void:
	if players.has(owner):
		var previous: GamePlayer=players[owner];players.erase(owner);previous.get_parent().remove_child(previous);previous.queue_free()
	qa_actor(owner,pos)
	qa_ack.rpc_id(1,label)

@rpc("authority","call_remote","reliable")
func qa_modular_finish() -> void:
	if stopping:return
	stopping=true
	if is_instance_valid(voice):voice.shutdown()
	qa_ack.rpc_id(1,"finishing")
	await get_tree().create_timer(3.).timeout
	leave_match();await get_tree().create_timer(2.2).timeout
	get_tree().quit()
