extends "res://tests/war_optics_fixture.gd"

var fire_requested := false
var test_done := false
var client_receipt: Dictionary = {}

@rpc("authority", "call_remote", "reliable")
func qa_done() -> void:
	test_done = true

@rpc("authority", "call_remote", "reliable")
func qa_fire() -> void:
	fire_requested = true
	vehicle_system.request_command("gadget", {})

@rpc("any_peer", "call_remote", "reliable")
func qa_receipt(data: Dictionary) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() in multiplayer.get_peers() and var_to_bytes(data).size() < 1800:
		client_receipt = data

func prepare_network_shooter(peer_id: int) -> WarPlayer:
	var actor := make_actor(peer_id, false, 1, "antitank", Vector3(0, 400, 0))
	actor.velocity = Vector3.ZERO
	actor.yaw = 0.
	actor.rotation.y = 0.
	actor.pitch = .04
	actor.camera_pivot.rotation.x = actor.pitch
	actor.set_gadget(true, "rpg")
	actor._update_weapon_pose()
	actor.set_physics_process(false)
	members[peer_id].deployed = true
	members[peer_id].team = 1
	members[peer_id].role = "antitank"
	members[peer_id].gadget = "rpg"
	members[peer_id].charges = 4
	members[peer_id].last_gadget = -100.
	members[peer_id].shield = 0.
	return actor
