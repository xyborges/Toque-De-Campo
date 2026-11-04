extends RefCounted
class_name GameNetworkPeers

# SceneMultiplayer may briefly list an ID already removed by ENet. Remember
# packet peers while ENet emits CONNECT (when get_peer is valid), then query
# their state without touching the native ID table during disconnects.
const CACHE := "tdc_packet_peers"

static func watch(transport: ENetMultiplayerPeer) -> void:
	if not transport or transport.has_meta(CACHE):return
	var peers: Dictionary={}
	transport.set_meta(CACHE,peers)
	var weak: WeakRef=weakref(transport)
	transport.peer_connected.connect(func(id: int):
		var owner:=weak.get_ref() as ENetMultiplayerPeer
		if owner:peers[id]=owner.get_peer(id)
	)
	transport.peer_disconnected.connect(func(id: int):peers.erase(id))

static func connected(transport: ENetMultiplayerPeer,id: int,minimum_channels: int=1) -> ENetPacketPeer:
	if not transport or transport.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return null
	var peers: Dictionary=transport.get_meta(CACHE,{})
	var packet:=peers.get(id) as ENetPacketPeer
	if not packet or not packet.is_active() or packet.get_state()!=ENetPacketPeer.STATE_CONNECTED:
		peers.erase(id);return null
	return packet if packet.get_channels()>=minimum_channels else null

