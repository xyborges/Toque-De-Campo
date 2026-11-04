extends BattleRoyaleGame
var acknowledgements: Dictionary={}
var test_phase:=""
func host_game(_kind: String) -> void: pass
func join_game(_kind: String) -> void: pass
func _physics_process(_delta: float) -> void: pass
func _process(_delta: float) -> void: pass
func _input(_event: InputEvent) -> void: pass
func _unhandled_input(_event: InputEvent) -> void: pass

@rpc("authority","call_remote","reliable")
func qa_actor(id: int,pos: Vector3) -> void:
	if players.has(id): return
	var actor:=_spawn_player(id,id==multiplayer.get_unique_id(),false,pos)
	actor.set_physics_process(false);actor.set_process(false);actor.hp=100;actor.life_id=7
	br_generation=3;phase="active";pvp_spawn_confirmed=true;ui_focus.close_all()
	actor.set_meta("br_generation",3)

@rpc("authority","call_remote","reliable")
func qa_operation(label: String,action: String,data: Dictionary) -> void:
	_request_br(action,data)
	qa_ack.rpc_id(1,label)

@rpc("authority","call_remote","reliable")
func qa_check_gear(label: String,owner: int,vest: int,helmet: int,backpack: int) -> void:
	var actor:=players.get(owner) as GamePlayer
	var okay: bool=is_instance_valid(actor) and int(actor.get_meta("br_vest",0))==vest and int(actor.get_meta("br_helmet",0))==helmet and int(actor.get_meta("br_backpack",0))==backpack
	if owner==multiplayer.get_unique_id():okay=okay and int(own_inventory.get("backpack",0))==backpack and int(own_inventory.get("protection",{}).get("vest",{}).get("level",0))==vest
	else:okay=okay and actor.ammo.is_empty() and actor.reserves.is_empty()
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)

@rpc("authority","call_remote","reliable")
func qa_check_round(label: String,expected_phase: String,generation: int,living: int,unarmed: bool) -> void:
	var okay: bool=phase==expected_phase and br_generation==generation and int(snapshot.get("generation",-1))==generation and int(snapshot.get("alive",-1))==living
	if unarmed:
		okay=okay and local_player.hp==100. and local_player.weapon_id=="fists" and local_player.loadout.is_empty() and own_inventory.get("weapons",[]).is_empty() and own_inventory.get("ammo",{}).is_empty() and own_inventory.get("optics",{}).is_empty() and own_inventory.get("attachments",{}).is_empty() and local_player.get_meta("weapon_optics",{}).is_empty()
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)

@rpc("authority","call_remote","reliable")
func qa_check_optic(label: String,owner: int,weapon: String,optic: String) -> void:
	var actor:=players.get(owner) as GamePlayer
	var okay: bool=is_instance_valid(actor) and actor.get_meta("weapon_optics",{}).get(weapon,"")==optic
	if owner==multiplayer.get_unique_id():okay=okay and own_inventory.get("attachments",{}).get(weapon,"")==optic and own_inventory.get("optics",{}).is_empty()
	else:okay=okay and actor.ammo.is_empty() and actor.reserves.is_empty()
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)

@rpc("authority","call_remote","reliable")
func qa_try(label: String,item: int,pos: Vector3,health: float,life: int=7,generation: int=3) -> void:
	local_player.position=pos;local_player.hp=health;local_player.life_id=life;br_generation=generation
	# The ordinary input request, inventory RPC and server action are unchanged.
	br_interact(item)
	qa_ack.rpc_id(1,label)

@rpc("any_peer","call_remote","reliable")
func qa_ack(label: String) -> void:
	if multiplayer.is_server(): acknowledgements[str(multiplayer.get_remote_sender_id())+":"+label]=true

@rpc("authority","call_remote","reliable")
func qa_check(label: String,item: int,owns: bool,weapon: String) -> void:
	var present:=false
	for record in visible_loot:
		if int(record.id)==item: present=true
	var okay: bool=not present and (weapon in own_inventory.get("weapons",[]))==owns
	NavalStorage.write_json("res://work/br-loot-client-"+str(multiplayer.get_unique_id())+".json",{"ok":okay,"label":label,"owns":own_inventory.get("weapons",[]),"item_removed":not present,"dtls":true})
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)

@rpc("authority","call_remote","reliable")
func qa_finish() -> void:
	get_tree().quit()
