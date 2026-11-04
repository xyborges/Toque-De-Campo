extends "res://tests/art188_network.gd"
var lean_extents: Dictionary={}
var remote_head_pitch:=0.
func _process(delta: float) -> bool:
	super._process(delta)
	if is_instance_valid(game) and (game.join_ready or game.multiplayer.is_server()):
		for actor: WarPlayer in game.players.values():
			if actor.is_local: continue
			var extent: Vector2=lean_extents.get(actor.peer_id,Vector2.ZERO)
			lean_extents[actor.peer_id]=Vector2(minf(extent.x,actor.lean),maxf(extent.y,actor.lean))
			remote_head_pitch=maxf(remote_head_pitch,absf(actor.avatar_parts.head.rotation.x))
	return false
func cycle(actor: WarPlayer,weapon: String,label: String) -> void:
	if label.begins_with("initial"):
		actor.pitch=-.8;actor.camera_pivot.rotation.x=-.8
		for entry in [["lean_left",-1.],["lean_right",1.]]:
			Input.action_press(entry[0]);await create_timer(.5).timeout
			check(actor.lean*float(entry[1])>.95,label+" Q/E drives held lean "+str(entry[0]))
			Input.action_release(entry[0]);await create_timer(.35).timeout
		check(absf(actor.lean)<.02,"release recenters the local stance")
	await super.cycle(actor,weapon,label)
func client() -> void:
	await super.client()
	var observed:=false
	for extent: Vector2 in lean_extents.values():
		if extent.x<-.8 and extent.y>.8: observed=true
	check(observed,"observer receives both left and right lean through validated movement snapshots")
	check(remote_head_pitch>.5,"observer sees vertical head tracking")
func server() -> void:
	await super.server()
	check(lean_extents.size()==2,"authority evaluated both players' stance")
	for extent: Vector2 in lean_extents.values(): check(extent.x<-.8 and extent.y>.8,"authority validates and relays both lean directions")
