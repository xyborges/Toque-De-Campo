extends Node
class_name BRMatchRouter
signal completed(result: Dictionary)
const PROTOCOL:=9
const PORT:=3016
var network_api: SceneMultiplayer
var transport: ENetMultiplayerPeer
var server_mode:=false
var protocol:=PROTOCOL
var challenges: Dictionary={}
var requests: Dictionary={}
var ip_limits: Dictionary={}
var closing_peers: Dictionary={}
var accounts: NavalAccounts
var ticket: Dictionary={}
var pending:=false
var terminal:=false
var request_started:=0
var response: Dictionary={}
var router_generation:=0

func _ready() -> void:
	name="MatchRouter"
	network_api=SceneMultiplayer.new();network_api.server_relay=false;network_api.allow_object_decoding=false
	get_tree().set_multiplayer(network_api,get_path())
	network_api.peer_connected.connect(_peer_connected);network_api.peer_disconnected.connect(_peer_disconnected)
	network_api.connection_failed.connect(_connection_failed);network_api.server_disconnected.connect(_connection_failed)

func request_match(service: NavalAccounts,hostname: String,version: int=PROTOCOL,port: int=PORT) -> Dictionary:
	if pending or server_mode:return {"ok":false,"error":"Busca já iniciada."}
	if hostname.is_empty() or hostname.length()>128 or hostname.contains("/") or hostname.contains("\\") or port<1 or port>65535:return {"ok":false,"error":"Endereço inválido."}
	accounts=service;protocol=version;ticket=service.ticket.duplicate(true) if is_instance_valid(service) else {}
	if ticket.is_empty() or not service.device_key():return {"ok":false,"error":"Entre na sua conta novamente."}
	terminal=false;response={};pending=true;router_generation+=1;request_started=Time.get_ticks_msec()
	transport=ENetMultiplayerPeer.new()
	var error:=transport.create_client(hostname,port,1)
	if error==OK:error=GameSecureTransport.client(transport,hostname)
	if error!=OK:_finish({"ok":false,"error":"Não foi possível buscar uma partida."})
	else:network_api.multiplayer_peer=transport
	while pending and not terminal:
		await get_tree().process_frame
	return response.duplicate(true)

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_msec()
	if server_mode:
		for id in closing_peers.keys():
			if now>=int(closing_peers[id]):_disconnect(int(id));closing_peers.erase(id)
		for id in challenges.keys():
			if now>int(challenges[id].expires):_disconnect(int(id));challenges.erase(id)
		for id in requests.keys():
			if now-int(requests[id].started)>120000:_respond(int(id),{"ok":false,"error":"A busca demorou demais. Tente novamente."})
	elif pending and now-request_started>120000:_finish({"ok":false,"error":"A busca demorou demais. Tente novamente."})

func _peer_connected(id: int) -> void:
	if not server_mode:return
	if challenges.size()+requests.size()>=64:_disconnect(id);return
	var address:="unknown"
	var enet_peer:=GameNetworkPeers.connected(transport,id)
	if enet_peer:address=enet_peer.get_remote_address()
	var now:=Time.get_ticks_msec();var bucket: Dictionary=ip_limits.get(address,{"since":now,"count":0})
	if now-int(bucket.since)>10000:bucket={"since":now,"count":0}
	bucket.count=int(bucket.count)+1;ip_limits[address]=bucket
	if int(bucket.count)>12:_disconnect(id);return
	if ip_limits.size()>128:
		for key in ip_limits.keys():
			if now-int(ip_limits[key].since)>10000:ip_limits.erase(key)
		if ip_limits.size()>128:ip_limits.erase(ip_limits.keys()[0])
	var nonce:=Crypto.new().generate_random_bytes(24).hex_encode()
	challenges[id]={"nonce":nonce,"expires":now+15000}
	rpc_id(id,"route_challenge",nonce,protocol)

func _peer_disconnected(id: int) -> void:
	challenges.erase(id)
	closing_peers.erase(id)
	if requests.has(id):
		_on_cancel(str(requests[id].account),true);requests.erase(id)

func _connection_failed() -> void:
	if pending:_finish({"ok":false,"error":"Sem conexão com a busca de partidas."})

@rpc("authority","call_remote","reliable")
func route_challenge(nonce: String,version: int) -> void:
	if server_mode or not pending or nonce.length()!=48:return
	if version!=protocol:_finish({"ok":false,"error":"Atualize o jogo para entrar."});return
	var key:=accounts.device_key()
	var message:="tdc-br-route-v1:"+nonce+":"+str(protocol)+":"+str(ticket.get("payload",""))
	var proof:=Crypto.new().sign(HashingContext.HASH_SHA256,message.sha256_buffer(),key)
	rpc_id(1,"route_auth",ticket,key.save_to_string(true),proof,protocol)

@rpc("any_peer","call_remote","reliable")
func route_auth(envelope: Dictionary,public_pem: String,proof: PackedByteArray,version: int) -> void:
	if not server_mode:return
	var id:=network_api.get_remote_sender_id()
	if not challenges.has(id) or requests.has(id):return
	var challenge: Dictionary=challenges[id];challenges.erase(id)
	if Time.get_ticks_msec()>int(challenge.expires) or version!=protocol:_respond(id,{"ok":false,"error":"Atualize o jogo para entrar."});return
	if public_pem.length()>6000 or proof.size()>1024 or proof.is_empty() or var_to_bytes(envelope).size()>18000:_disconnect(id);return
	var profile:=_verify_profile(envelope,public_pem.sha256_text());var key:=CryptoKey.new()
	if profile.is_empty() or key.load_from_string(public_pem,true)!=OK:_respond(id,{"ok":false,"error":"Entre na sua conta novamente."});return
	var message:="tdc-br-route-v1:"+str(challenge.nonce)+":"+str(protocol)+":"+str(envelope.get("payload",""))
	if not Crypto.new().verify(HashingContext.HASH_SHA256,message.sha256_buffer(),proof,key):_disconnect(id);return
	var account:=str(profile.get("id",""))
	if not BRRoomRegistry.is_hex(account,32):_disconnect(id);return
	for other in requests.keys():
		if str(requests[other].account)==account:_respond(id,{"ok":false,"error":"Busca já iniciada."});return
	GameDiagnostics.record("br_broker_authenticated",{"peer":id,"account":account.sha256_text().left(16)})
	requests[id]={"account":account,"name":str(profile.get("username","Jogador")).left(24),"started":Time.get_ticks_msec()}
	_on_authenticated(id,account)

@rpc("any_peer","call_remote","reliable")
func route_cancel() -> void:
	if not server_mode:return
	var id:=network_api.get_remote_sender_id()
	if requests.has(id):_on_cancel(str(requests[id].account),false);requests.erase(id)
	_disconnect(id)

@rpc("authority","call_remote","reliable")
func route_answer(result: Dictionary) -> void:
	if server_mode or not pending or var_to_bytes(result).size()>4096:return
	if bool(result.get("ok",false)):
		if int(result.get("protocol",0))!=protocol or int(result.get("port",0))<3020 or int(result.get("port",0))>3035 or not BRRoomRegistry.is_hex(str(result.get("room_id","")),32) or not BRRoomRegistry.is_hex(str(result.get("reservation","")),64):_finish({"ok":false,"error":"Resposta de partida inválida."});return
	_finish(result)

func _respond(id: int,result: Dictionary) -> void:
	GameDiagnostics.record("br_route_result",{"peer":id,"ok":result.get("ok",false),"port":result.get("port",0),"error":result.get("error","")})
	if id in network_api.get_peers():rpc_id(id,"route_answer",result)
	requests.erase(id);challenges.erase(id)
	# Let the reliable answer flush, then reclaim even a malicious client
	# that deliberately keeps an already answered connection open.
	closing_peers[id]=Time.get_ticks_msec()+1500

func _on_authenticated(_id: int,_account: String) -> void:pass
func _on_cancel(_account: String,_undelivered_only: bool) -> void:pass
func _verify_profile(envelope: Dictionary,device: String) -> Dictionary:return NavalAccounts.verify_ticket(envelope,device)

func _disconnect(id: int) -> void:
	if transport and id in network_api.get_peers():transport.disconnect_peer(id)

func _finish(result: Dictionary) -> void:
	if terminal:return
	response=result.duplicate(true);pending=false;terminal=true
	completed.emit(response)
	_close_transport.call_deferred()

func cancel() -> void:
	if pending and transport and transport.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:rpc_id(1,"route_cancel")
	_finish({"ok":false,"error":"Busca cancelada."})

func close() -> void:
	if pending:cancel()
	_close_transport()

func _close_transport() -> void:
	if transport:transport.close();transport=null
	if network_api:network_api.multiplayer_peer=OfflineMultiplayerPeer.new()

func _exit_tree() -> void:
	_close_transport()
	if network_api:get_tree().set_multiplayer(null,get_path())
