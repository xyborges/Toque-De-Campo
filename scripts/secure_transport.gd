extends RefCounted
class_name GameSecureTransport

const GAME_CA := "res://assets/accounts/game-ca.crt"
const SERVER_CERT := "/etc/toque-de-campo/game-tls/server.crt"
const SERVER_KEY := "/etc/toque-de-campo/game-tls/server.key"

static func _path(option: String,fallback: String) -> String:
	# Test certificates may only be selected in editor/QA builds. Production
	# clients cannot replace their trust anchor using command-line arguments.
	if OS.has_feature("editor") or OS.has_feature("qa"):
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with(option+"="): return arg.trim_prefix(option+"=")
	return fallback

static func server(peer: ENetMultiplayerPeer) -> Error:
	var certificate:=X509Certificate.new()
	var key:=CryptoKey.new()
	var error:=certificate.load(_path("--game-tls-cert",SERVER_CERT))
	if error==OK: error=key.load(_path("--game-tls-key",SERVER_KEY))
	if error==OK: error=peer.get_host().dtls_server_setup(TLSOptions.server(key,certificate))
	if error!=OK: peer.close()
	else: GameNetworkPeers.watch(peer)
	return error

static func client(peer: ENetMultiplayerPeer,hostname: String) -> Error:
	var certificate:=X509Certificate.new()
	var error:=certificate.load(_path("--game-tls-ca",GAME_CA))
	if error==OK:
		# create_client only queues the ENet connection. Upgrade its socket
		# synchronously before assigning it to MultiplayerAPI, polling or flushing.
		error=peer.get_host().dtls_client_setup(_path("--game-tls-host",hostname),TLSOptions.client(certificate))
	if error!=OK: peer.close()
	else: GameNetworkPeers.watch(peer)
	return error
