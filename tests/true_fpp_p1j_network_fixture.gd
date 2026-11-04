extends "res://tests/war_network_fixture.gd"
## P1j real-ENet fixture. Production shot/damage code is untouched; this only
## records which collider reached _apply_hit and keeps QA actors at server poses.
var qa_payloads: Dictionary={}
var qa_hits: Array[Dictionary]=[]

func _network_port() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--p1j-port="): return int(arg.trim_prefix("--p1j-port="))
	return 39627

func _build_desert() -> void:
	var floor_body:=StaticBody3D.new()
	var floor_shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(60,1,60)
	floor_shape.shape=box
	floor_body.add_child(floor_shape)
	floor_body.position=Vector3(0,79.5,0)
	world_root.add_child(floor_body)

# Transport setup is intentionally inherited from WarGame/MainGame. The
# runner supplies a localhost QA certificate through the existing test-only
# --game-tls-* overrides, so this fixture exercises the production ENet/DTLS
# setup and only changes the port plus QA observation hooks.

@rpc("any_peer","call_remote","reliable")
func qa_payload(key: String,payload: Dictionary) -> void:
	if multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()):
		qa_payloads[key]=payload.duplicate(true)

@rpc("any_peer","call_remote","unreliable")
func server_player_state(pos: Vector3,new_yaw: float,new_pitch: float,weapon: String,crouched: bool,aim_level:=0,life:=1,sequence:=0,lean_value:=0.0) -> void:
	var actor:=players.get(multiplayer.get_remote_sender_id()) as WarPlayer
	if is_instance_valid(actor) and actor.get_meta("p1j_freeze",false):
		# Keep the server-authored QA position fixed but allow the legitimate
		# look state to follow the client for shot validation.
		actor.yaw=wrapf(new_yaw,-PI,PI)
		actor.rotation.y=actor.yaw
		actor.pitch=actor.clamp_aim_pitch(new_pitch)
		actor.camera_pivot.rotation.x=actor.pitch
		return
	super.server_player_state(pos,new_yaw,new_pitch,weapon,crouched,aim_level,life,sequence,lean_value)

func _apply_hit(owner_id: int,hit: Dictionary,damage: float,fallback_region:="chest",weapon:="ak",direction:=Vector3.ZERO) -> void:
	var collider: Object=hit.get("collider")
	var node:=collider as Node
	var proxy:=false
	while is_instance_valid(node) and not node is GamePlayer:
		if node is WarCollisionRigProxy:
			proxy=true
			break
		node=node.get_parent()
	if is_instance_valid(collider):
		qa_hits.append({
			"owner":owner_id,
			"proxy":proxy,
			"region":str(collider.get_meta("hit_region",fallback_region)) if collider.has_meta("hit_region") else fallback_region,
			"weapon":weapon,
			"collider":str((collider as Node).name) if collider is Node else ""
		})
	super._apply_hit(owner_id,hit,damage,fallback_region,weapon,direction)
