extends "res://tests/br_loot_network_fixture.gd"
var clock_offset:=0.
var corpse_acks: Dictionary={}

func _now() -> float:return Time.get_ticks_msec()*.001+clock_offset

func flat_world() -> void:
	world_root=Node3D.new();add_child(world_root);map_kind="afghan";mode="pvp";phase="active";pvp_spawn_confirmed=true
	var floor_body:=StaticBody3D.new();world_root.add_child(floor_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,1,80);shape.shape=box;shape.position.y=-.5;floor_body.add_child(shape)
	spectator=Camera3D.new();world_root.add_child(spectator)
	loot_visuals=BRLootVisuals.new();loot_visuals.game=self;world_root.add_child(loot_visuals)
	grenades_system=GameGrenades.new();grenades_system.game=self;world_root.add_child(grenades_system)
	ui_focus.close_all();br_zone.configure(712907,[Vector3.ZERO]);br_zone.begin(_now())

@rpc("authority","call_remote","reliable")
func qa_corpse_actor(id: int,pos: Vector3,bot: bool) -> void:
	if players.has(id):return
	var actor:=_spawn_player(id,id==multiplayer.get_unique_id(),false,pos) as BRPlayer
	actor.set_physics_process(false);actor.set_process(false);actor.life_id=9;actor.hp=100.;actor.br_bot=bot
	br_generation=4;phase="active";actor.set_meta("br_generation",4);pvp_spawn_confirmed=true;ui_focus.close_all()

@rpc("authority","call_remote","reliable")
func qa_corpse_operation(label: String,action: String,data: Dictionary) -> void:
	_request_br(action,data)
	qa_corpse_ack.rpc_id(1,label,true,"")

@rpc("authority","call_remote","reliable")
func qa_corpse_check(label: String,key: String,helmet: bool,vest: bool,pack: bool,settled: bool) -> void:
	var body:=corpse_roots.get(key) as Node3D;var okay:=is_instance_valid(body);var detail:=""
	if okay:
		for entry in [["helmet",helmet],["vest",vest],["pack",pack]]:
			var pieces:=BRCorpseAppearance.equipment_pieces(body,str(entry[0]))
			var visible:=not pieces.is_empty()
			for piece in pieces:visible=visible and piece.visible
			if visible!=bool(entry[1]):okay=false;detail+=" gear:"+str(entry[0])
		if settled:
			okay=okay and body.settled
			for node_name in corpses.get(key,{}).get("transforms",{}):
				var part:=body.get_node_or_null(str(node_name)) as RigidBody3D
				if not part or not part.freeze or not part.global_transform.is_equal_approx(corpses[key].transforms[node_name]):okay=false;detail+=" transform:"+str(node_name)
	qa_corpse_ack.rpc_id(1,label,okay,detail)

@rpc("authority","call_remote","reliable")
func qa_corpse_cleanup(label: String) -> void:
	_clear_br_round()
	await get_tree().process_frame
	await get_tree().process_frame
	qa_corpse_ack.rpc_id(1,label,corpses.is_empty() and corpse_roots.is_empty() and get_tree().get_nodes_in_group("death_ragdolls").is_empty(),"records=%d roots=%d bodies=%d"%[corpses.size(),corpse_roots.size(),get_tree().get_nodes_in_group("death_ragdolls").size()])

@rpc("authority","call_remote","reliable")
func qa_corpse_disconnect() -> void:
	if multiplayer.multiplayer_peer:multiplayer.multiplayer_peer.close()
	get_tree().quit()

@rpc("any_peer","call_remote","reliable")
func qa_corpse_ack(label: String,ok: bool,detail: String) -> void:
	if multiplayer.is_server():corpse_acks[str(multiplayer.get_remote_sender_id())+":"+label]={"ok":ok,"detail":detail}
