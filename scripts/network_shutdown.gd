extends Node
class_name GameNetworkShutdown

# Keep the old transport alive briefly after detaching it from SceneMultiplayer.
# ENet.close() sends a single immediate disconnect; graceful disconnect retries
# over packet loss while the menu is already usable and old RPCs are detached.
var transport: ENetMultiplayerPeer
var deadline:=0

static func retire(parent: Node, peer: MultiplayerPeer) -> void:
	var enet:=peer as ENetMultiplayerPeer
	if not enet or enet.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED or enet.get_unique_id()==1:
		peer.close()
		return
	var server:=GameNetworkPeers.connected(enet,1)
	if not server or server.get_state()!=ENetPacketPeer.STATE_CONNECTED:
		enet.close()
		return
	var shutdown:=GameNetworkShutdown.new()
	shutdown.transport=enet
	shutdown.deadline=Time.get_ticks_msec()+2000
	shutdown.process_mode=Node.PROCESS_MODE_ALWAYS
	parent.add_child(shutdown)
	enet.disconnect_peer(1)

func _process(_delta: float) -> void:
	if transport.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED: transport.poll()
	if transport.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED or Time.get_ticks_msec()>=deadline:
		transport.close()
		queue_free()

func _exit_tree() -> void:
	if transport: transport.close()
