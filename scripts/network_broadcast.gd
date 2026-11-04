extends RefCounted
class_name GameNetworkBroadcast

# All callers use call_remote RPCs. Serialize one identical broadcast once,
# while retaining the closing-peer guard required during disconnection.
static func send(node: Node,method: String,arguments: Array) -> void:
	var api:=node.multiplayer
	var transport:=api.multiplayer_peer as ENetMultiplayerPeer
	if transport==null or transport.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	var peers:=api.get_peers()
	if peers.is_empty(): return
	var ready:=PackedInt32Array()
	for id in peers:
		var peer:=GameNetworkPeers.connected(transport,id)
		if peer and peer.get_state()==ENetPacketPeer.STATE_CONNECTED and peer.get_channels()>0: ready.append(id)
	if ready.size()==peers.size():
		node.callv("rpc",[method]+arguments)
	else:
		for id in ready: node.callv("rpc_id",[id,method]+arguments)
