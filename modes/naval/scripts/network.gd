extends Node
class_name NavalNetwork

signal event_received(kind: String, payload: Dictionary)
signal disconnected
var service := false
var require_accounts := true
var account_ticket: Dictionary = {}
var port := NavalCatalog.PORT
var rooms: Dictionary = {}
var users: Dictionary = {}
var pending: Dictionary = {}
var accounts: Dictionary = {}
var requests: Dictionary = {}
var key: CryptoKey
var nickname := "Jogador"
var authenticated := false
var account: Dictionary = {}
var room: Dictionary = {}
var room_list: Array = []
var input_sequence := 0
var connection: SceneMultiplayer
var state_parts: Dictionary = {}
var newest_state_tick := -1
var server_host := ""
var network_guard:=GameNetworkGuard.new()

func _ready() -> void:
	require_accounts = not NavalAccounts.testing()
	connection = SceneMultiplayer.new()
	connection.server_relay = false
	connection.allow_object_decoding = false
	get_tree().set_multiplayer(connection,get_path())
	connection.peer_connected.connect(_peer_connected)
	connection.peer_disconnected.connect(_peer_left)
	connection.connected_to_server.connect(_connected)
	connection.server_disconnected.connect(_lost)
	connection.connection_failed.connect(_lost)

func serve() -> Error:
	service = true
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port,48)
	if error==OK: error=GameSecureTransport.server(peer)
	if error == OK:
		port = peer.get_host().get_local_port()
		connection.multiplayer_peer = peer
	return error

func connect_server(address: String, display_name: String) -> Error:
	close_connection()
	service = false
	key = NavalStorage.client_key()
	if key == null: return ERR_CANT_CREATE
	nickname = display_name.strip_edges().left(24)
	if nickname.is_empty(): nickname = "Jogador"
	var peer := ENetMultiplayerPeer.new()
	var endpoint := parse_endpoint(address,port)
	if endpoint.is_empty(): return ERR_INVALID_PARAMETER
	server_host = str(endpoint.host)
	port = int(endpoint.port)
	var error := peer.create_client(server_host,port,4)
	if error==OK: error=GameSecureTransport.client(peer,server_host)
	if error == OK: connection.multiplayer_peer = peer
	return error

func close_connection(graceful:=true) -> void:
	if connection != null and connection.multiplayer_peer != null:
		var previous:=connection.multiplayer_peer
		connection.multiplayer_peer = null
		if graceful and is_inside_tree(): GameNetworkShutdown.retire(get_tree().root,previous)
		else: previous.close()
	authenticated = false
	room_list.clear()
	state_parts.clear()
	newest_state_tick = -1
	room.clear()

func _exit_tree() -> void:
	close_connection(false)
	get_tree().set_multiplayer(null,get_path())

func _connected() -> void:
	GameDiagnostics.record("client_connected",{"peer":local_id(),"mode":"naval","port":port})
	hello.rpc_id(1,NavalCatalog.PROTOCOL,key.save_to_string(true),nickname,account_ticket,load("res://scripts/maps/definition.gd").identity("naval"))

func _lost() -> void:
	GameDiagnostics.record("server_disconnected",{"mode":"naval","port":port})
	authenticated = false
	state_parts.clear()
	newest_state_tick = -1
	room.clear()
	disconnected.emit()

func _peer_connected(id: int) -> void:
	GameDiagnostics.record("peer_connected",{"peer":id,"mode":"naval","port":port})
	if service: pending[id] = {"expires":Time.get_ticks_msec()+10000}

func _process(_delta: float) -> void:
	if not service or connection.multiplayer_peer == null: return
	for id in pending.keys():
		if Time.get_ticks_msec() > int(pending[id].expires):
			(connection.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(int(id))
			pending.erase(id)

func _peer_left(id: int) -> void:
	GameDiagnostics.record("peer_disconnected",{"peer":id,"mode":"naval","port":port})
	if not service: return
	network_guard.forget(id)
	_leave(id)
	users.erase(id)
	pending.erase(id)
	requests.erase(id)

func peer_ready(id: int) -> bool:
	if connection == null or id not in connection.get_peers(): return false
	var transport := connection.multiplayer_peer as ENetMultiplayerPeer
	if transport == null or transport.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return false
	var remote := GameNetworkPeers.connected(transport,id)
	return remote != null and remote.get_state() == ENetPacketPeer.STATE_CONNECTED and remote.get_channels() > 0

func local_id() -> int:
	if connection==null or connection.multiplayer_peer==null or connection.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return 0
	return connection.get_unique_id()

func _send(id: int, kind: String, payload: Dictionary) -> void:
	if not peer_ready(id): return
	message.rpc_id(id,kind,payload)

func _broadcast_room(data: Dictionary, kind: String, payload: Dictionary) -> void:
	for peer in data.members: _send(int(peer),kind,payload)

func _error(id: int, text: String) -> void:
	_send(id,"error",{"text":text})

@rpc("any_peer","call_remote","reliable")
func hello(protocol: int, public_pem: String, display_name: String, ticket: Dictionary, map_content: Dictionary={}) -> void:
	if not service: return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"hello",.25,2): return
	if users.has(id) or not pending.has(id): return
	if not load("res://scripts/maps/definition.gd").compatible("naval",map_content):
		_error(id,"Atualize o mapa pelo launcher.");return
	if protocol != NavalCatalog.PROTOCOL or public_pem.length() > 6000 or var_to_bytes(ticket).size()>18000:
		_error(id,"Versão incompatível. Atualize o jogo.")
		return
	var public_key := CryptoKey.new()
	if public_key.load_from_string(public_pem,true) != OK: return
	var identity := public_pem.sha256_text()
	for other in users.values():
		if other.identity == identity:
			_error(id,"Este perfil já está conectado. Use outra identidade local para testar duas instâncias.")
			return
	var central := NavalAccounts.verify_ticket(ticket,identity) if require_accounts else {}
	if require_accounts and central.is_empty():
		_error(id,"Entre na sua conta novamente para conectar à partida.")
		return
	for other in users.values():
		if not central.is_empty() and other.get("account_id","") == central.id:
			_error(id,"Esta conta já está na partida.")
			return
	var nonce := NavalCatalog.uid()+identity+str(NavalCatalog.PROTOCOL)
	pending[id] = {"identity":identity,"key":public_key,"profile":central,"nonce":nonce,"name":display_name.strip_edges().left(24),"expires":Time.get_ticks_msec()+10000}
	_send(id,"challenge",{"nonce":nonce})

@rpc("any_peer","call_remote","reliable")
func prove(signature: PackedByteArray) -> void:
	if not service: return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"proof",.25,2): return
	var challenge: Dictionary = pending.get(id,{})
	if challenge.is_empty() or not challenge.has("nonce") or Time.get_ticks_msec() > int(challenge.expires) or signature.size() > 1024: return
	if not Crypto.new().verify(HashingContext.HASH_SHA256,str(challenge.nonce).sha256_buffer(),signature,challenge.key): return
	var identity := str(challenge.identity)
	# Re-check at proof time so simultaneous logins cannot share an account.
	for other in users.values():
		if other.identity == identity or (require_accounts and other.get("account_id","") == challenge.profile.id):
			_error(id,"Este perfil já está conectado.")
			return
	var data: Dictionary = challenge.profile if require_accounts else NavalStorage.load_account(identity)
	if not require_accounts and not NavalStorage.save_account(data):
		_error(id,"O servidor não conseguiu salvar o perfil.")
		return
	accounts[identity] = data
	users[id] = {"identity":identity,"account_id":data.id,"name":str(data.get("username",challenge.name)),"room":"","ship":data.selected,"last_sequence":0,"last_input":0,"joined":Time.get_ticks_msec(),"ready":false}
	pending.erase(id)
	_send(id,"authenticated",{"account":_public_account(data),"protocol":NavalCatalog.PROTOCOL})
	_list(id)

func _public_account(data: Dictionary) -> Dictionary:
	return {"id":data.id,"coins":int(data.coins),"owned":data.owned.duplicate(),"selected":data.selected}

@rpc("any_peer","call_remote","reliable")
func command(action: String, payload: Dictionary) -> void:
	if not service: return
	var id := multiplayer.get_remote_sender_id()
	if not users.has(id) or var_to_bytes(payload).size() > 12000: return
	var now := Time.get_ticks_msec()
	var budget: Dictionary = requests.get(id,{"time":now,"tokens":12.0})
	budget.tokens = minf(12.0,float(budget.tokens)+float(now-int(budget.time))*0.02)
	budget.time = now
	requests[id] = budget
	if float(budget.tokens) < 1.0:
		return
	budget.tokens = float(budget.tokens)-1.0
	match action:
		"list": _list(id)
		"create": _create(id,payload)
		"join": _join(id,str(payload.get("id","")),str(payload.get("password","")))
		"leave": _leave(id)
		"start": _start(id)
		"ready": _ready_to_spawn(id)
		"finish": _finish(id)
		"select": _select(id,str(payload.get("ship","light")))
		"buy": _buy(id,str(payload.get("ship","")),str(payload.get("transaction","")))
		"reload": _reload(id)
		"profile": _sync_profile(id,payload)

func request(action: String, payload: Dictionary = {}) -> void:
	if authenticated: command.rpc_id(1,action,payload)

func _list(id: int) -> void:
	var result: Array = []
	for data in rooms.values():
		if not data.private and data.state != "CLOSING":
			result.append({"id":data.id,"name":data.name,"players":data.members.size(),"limit":data.limit,"state":data.state,"late":data.late})
	_send(id,"rooms",{"rooms":result})

func _create(id: int, payload: Dictionary) -> void:
	if not str(users[id].room).is_empty():
		_error(id,"Saia da sala atual antes de criar outra.")
		return
	if rooms.size() >= 8:
		_error(id,"O servidor atingiu o limite de salas.")
		return
	var limit := clampi(int(payload.get("limit",6)),2,6)
	var room_id := NavalCatalog.uid()
	var password := str(payload.get("password","")).left(64)
	var private_room := bool(payload.get("private",false))
	if private_room and password.length() < 3:
		_error(id,"Use uma senha com pelo menos três caracteres.")
		return
	rooms[room_id] = {"id":room_id,"match":NavalCatalog.uid(),"name":str(payload.get("name","Sala naval")).strip_edges().left(32),"private":private_room,"password":(room_id+password).sha256_text(),"limit":limit,"late":bool(payload.get("late",true)),"owner":id,"members":[],"state":"WAITING","map_seed":randi(),"simulation":null,"stats":{}}
	_join(id,room_id,password)

func _join(id: int, room_id: String, password: String) -> void:
	if not str(users[id].room).is_empty():
		_error(id,"Você já está em uma sala.")
		return
	if not rooms.has(room_id):
		_error(id,"Sala não encontrada.")
		return
	var data: Dictionary = rooms[room_id]
	if data.members.size() >= int(data.limit) or data.state in ["STARTING","FINISHED","CLOSING"]:
		_error(id,"Sala indisponível ou cheia.")
		return
	if data.private and (room_id+password).sha256_text() != data.password:
		_error(id,"Senha incorreta.")
		return
	if data.state == "IN_PROGRESS" and not data.late:
		_error(id,"A sala não aceita entrada durante a partida.")
		return
	users[id].room = room_id
	users[id].ready=false
	users[id].last_sequence = 0
	data.members.append(id)
	# Joining a running room opens deployment; a ship is not created yet.
	_room_changed(data)
	if data.simulation != null: _send(id,"snapshot",data.simulation.snapshot())

func _leave(id: int) -> void:
	if not users.has(id): return
	var room_id := str(users[id].room)
	users[id].room = ""
	users[id].ready=false
	if not rooms.has(room_id): return
	var data: Dictionary = rooms[room_id]
	data.members.erase(id)
	if data.simulation != null: data.simulation.remove_player(id)
	_send(id,"left",{"id":room_id})
	if data.members.is_empty():
		data.state = "CLOSING"
		if is_instance_valid(data.simulation): data.simulation.queue_free()
		rooms.erase(room_id)
		return
	if int(data.owner) == id: data.owner = data.members[0]
	_room_changed(data)

func _start(id: int) -> void:
	var data := _user_room(id)
	if data.is_empty() or data.owner != id or data.state != "WAITING": return
	if data.members.size() < 2:
		_error(id,"Aguardando outro jogador: são necessários pelo menos dois participantes.")
		return
	for peer in data.members:
		if not bool(users[peer].get("ready",false)): _error(id,"Aguardando jogadores.");return
	data.state = "STARTING"
	data.match = NavalCatalog.uid()
	_room_changed(data)
	var simulation: Node = get_parent().create_match(data)
	if simulation == null:
		data.state = "WAITING"
		_room_changed(data)
		_error(id,"Não foi possível criar a partida.")
		return
	data.simulation = simulation
	for peer in data.members: simulation.add_player(int(peer),users[peer])
	data.state = "IN_PROGRESS"
	_room_changed(data)
	_broadcast_room(data,"snapshot",simulation.snapshot())

func _finish(id: int) -> void:
	var data := _user_room(id)
	if data.is_empty() or data.owner != id or data.state != "IN_PROGRESS": return
	data.state = "FINISHED"
	_room_changed(data)
	if is_instance_valid(data.simulation): data.simulation.queue_free()
	data.simulation = null
	data.state = "WAITING"
	data.stats.clear()
	_room_changed(data)

func _room_changed(data: Dictionary) -> void:
	var members: Array = []
	for peer in data.members:
		if users.has(peer): members.append({"peer":peer,"name":users[peer].name,"ship":users[peer].ship,"ready":bool(users[peer].get("ready",false))})
	_broadcast_room(data,"room",{"id":data.id,"match":data.match,"name":data.name,"private":data.private,"limit":data.limit,"late":data.late,"owner":data.owner,"members":members,"state":data.state,"map_seed":data.get("map_seed",0)})

func _user_room(id: int) -> Dictionary:
	if not users.has(id): return {}
	return rooms.get(str(users[id].room),{})

func _sync_profile(id: int, ticket: Dictionary) -> void:
	if not require_accounts: return
	var profile := NavalAccounts.verify_ticket(ticket,str(users[id].identity))
	if profile.is_empty() or profile.id != users[id].account_id:
		_error(id,"Perfil de conta inválido. Entre novamente.")
		return
	var old: Dictionary = accounts[users[id].identity]
	if int(profile.revision)<int(old.get("revision",0)): return
	accounts[users[id].identity] = profile
	_send(id,"wallet",{"account":_public_account(profile)})

func _select(id: int, ship: String) -> void:
	var data: Dictionary = accounts[users[id].identity].duplicate(true)
	if not NavalCatalog.SHIPS.has(ship) or ship not in data.owned:
		_error(id,"Você ainda não possui esse navio.")
		return
	var room_data := _user_room(id)
	if not room_data.is_empty() and room_data.state == "IN_PROGRESS":
		var current: NavalShip=room_data.simulation.ships.get(id)
		if is_instance_valid(current) and not current.dead:
			var reason: String=room_data.simulation.can_change_ship(id,ship)
			if not reason.is_empty(): _error(id,reason);return
			room_data.simulation.change_ship(id,ship)
		else: users[id].ready=false
	elif not room_data.is_empty() and room_data.state != "WAITING":
		_error(id,"Aguarde a partida ou volte ao lobby.")
		return
	if not room_data.is_empty() and room_data.state=="WAITING": users[id].ready=false
	data.selected = ship
	if not require_accounts and not NavalStorage.save_account(data):
		_error(id,"Não foi possível salvar a seleção.")
		return
	accounts[users[id].identity] = data
	users[id].ship = ship
	_send(id,"wallet",{"account":_public_account(data),"selection":ship})
	if not room_data.is_empty(): _room_changed(room_data)

func _buy(id: int, ship: String, transaction: String) -> void:
	if require_accounts:
		_error(id,"Use a loja conectada ao servidor de contas.")
		return
	if not NavalCatalog.SHIPS.has(ship) or transaction.length() < 12 or transaction.length() > 80: return
	var data: Dictionary = accounts[users[id].identity]
	if data.transactions.has(transaction):
		_send(id,"wallet",{"account":_public_account(data),"transaction":transaction})
		return
	var candidate := data.duplicate(true)
	var price := int(NavalCatalog.SHIPS[ship].price)
	if ship in candidate.owned:
		_send(id,"wallet",{"account":_public_account(data),"transaction":transaction})
		return
	if int(candidate.coins) < price:
		_error(id,"Saldo insuficiente.")
		return
	candidate.coins = int(candidate.coins)-price
	candidate.owned.append(ship)
	candidate.transactions[transaction] = ship
	if candidate.transactions.size() > 256: candidate.transactions.erase(candidate.transactions.keys()[0])
	if not NavalStorage.save_account(candidate):
		_error(id,"Compra não concluída: falha de gravação no servidor.")
		return
	accounts[users[id].identity] = candidate
	_send(id,"wallet",{"account":_public_account(candidate),"transaction":transaction})

func _reload(id: int) -> void:
	var data := _user_room(id)
	if not data.is_empty() and data.state == "IN_PROGRESS": data.simulation.reload(id)

@rpc("any_peer","call_remote","unreliable_ordered",2)
func control(room_id: String, match_id: String, sequence: int, throttle: float, steering: float, aim: Vector3, weapon: String, firing: bool) -> void:
	if not service: return
	var id := multiplayer.get_remote_sender_id()
	if not network_guard.allow(id,"naval_control",45,12): return
	var data := _user_room(id)
	if data.is_empty() or data.id != room_id or data.match != match_id or data.state != "IN_PROGRESS": return
	if sequence <= int(users[id].last_sequence) or not NavalCatalog.finite(aim) or aim.length() > 5000 or not is_finite(throttle) or not is_finite(steering): return
	users[id].last_sequence = sequence
	users[id].last_input = Time.get_ticks_msec()
	data.simulation.set_control(id,clampf(throttle,-1,1),clampf(steering,-1,1),aim,weapon,firing)

@rpc("any_peer","call_remote","reliable")
func cease_fire(room_id: String, match_id: String, sequence: int) -> void:
	if not service: return
	var data := _user_room(multiplayer.get_remote_sender_id())
	if data.is_empty() or data.id != room_id or data.match != match_id or data.simulation == null: return
	var id := multiplayer.get_remote_sender_id()
	# Reliable release messages can arrive after a newer control packet on
	# another channel. Apply the same ordering rule to both input paths.
	if sequence <= int(users[id].last_sequence): return
	users[id].last_sequence = sequence
	data.simulation.cease_fire(id)

func send_control(throttle: float, steering: float, aim: Vector3, weapon: String, firing: bool) -> void:
	if not authenticated or room.is_empty() or room.state != "IN_PROGRESS": return
	input_sequence += 1
	control.rpc_id(1,str(room.id),str(room.match),input_sequence,throttle,steering,aim,weapon,firing)

func stop_fire() -> void:
	if authenticated and not room.is_empty():
		input_sequence += 1
		cease_fire.rpc_id(1,str(room.id),str(room.match),input_sequence)

# Compression and bounded chunks keep ENet datagrams below the MTU. Losing a
# chunk discards only that snapshot; the next tick supplies a fresh complete state.
func send_state(members: Array, snapshot: Dictionary) -> void:
	var raw := var_to_bytes(snapshot)
	if raw.size() > 524288: return
	var compressed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var count := ceili(float(compressed.size())/900.0)
	if count < 1 or count > 64: return
	for peer in members:
		if not peer_ready(int(peer)): continue
		for index in range(count):
			state_part.rpc_id(int(peer),str(snapshot.room),str(snapshot.match),int(snapshot.tick),index,count,raw.size(),compressed.slice(index*900,mini((index+1)*900,compressed.size())))

@rpc("authority","call_remote","unreliable",1)
func state_part(room_id: String, match_id: String, tick: int, index: int, count: int, size: int, data: PackedByteArray) -> void:
	if service or room.is_empty() or room_id != room.id or match_id != room.match or tick <= newest_state_tick: return
	if count < 1 or count > 64 or index < 0 or index >= count or size < 1 or size > 524288 or data.size() > 900: return
	for old in state_parts.keys():
		if int(old) < tick-9: state_parts.erase(old)
	if not state_parts.has(tick):
		if state_parts.size() >= 4: state_parts.erase(state_parts.keys().min())
		state_parts[tick] = {"count":count,"size":size,"parts":{}}
	var assembly: Dictionary = state_parts[tick]
	if assembly.count != count or assembly.size != size: return
	assembly.parts[index] = data
	if assembly.parts.size() != count: return
	var compressed := PackedByteArray()
	for part in range(count): compressed.append_array(assembly.parts[part])
	state_parts.erase(tick)
	var raw := compressed.decompress(size,FileAccess.COMPRESSION_ZSTD)
	if raw.size() != size: return
	var decoded: Variant = bytes_to_var(raw)
	if not decoded is Dictionary or decoded.get("room") != room_id or decoded.get("match") != match_id or int(decoded.get("tick",-1)) != tick: return
	newest_state_tick = tick
	event_received.emit("snapshot",decoded)

@rpc("authority","call_remote","reliable")
func message(kind: String, payload: Dictionary) -> void:
	if service: return
	if kind == "challenge":
		prove.rpc_id(1,Crypto.new().sign(HashingContext.HASH_SHA256,str(payload.nonce).sha256_buffer(),key))
		return
	if kind == "authenticated":
		authenticated = true
		account = payload.account
	elif kind == "wallet": account = payload.account
	elif kind == "rooms": room_list = payload.rooms
	elif kind == "room":
		if room.get("match","") != payload.get("match",""):
			state_parts.clear()
			newest_state_tick = -1
		room = payload
	elif kind == "left": room = {}
	elif kind in ["shot","impact","destroyed","respawn","damage"]:
		if room.is_empty() or payload.get("room") != room.id or payload.get("match") != room.match: return
	event_received.emit(kind,payload)

static func parse_endpoint(value: String, default_port: int = NavalCatalog.PORT) -> Dictionary:
	var address := value.strip_edges()
	var selected_port := default_port
	if address.is_empty() or address.contains("/") or address.contains(" "): return {}
	if address.begins_with("["):
		var end := address.find("]")
		if end<0: return {}
		var suffix := address.substr(end+1)
		if not suffix.is_empty():
			if not suffix.begins_with(":") or not suffix.substr(1).is_valid_int(): return {}
			selected_port = int(suffix.substr(1))
		address = address.substr(1,end-1)
	elif address.count(":") == 1:
		var pieces := address.split(":")
		if not pieces[1].is_valid_int(): return {}
		address = pieces[0]
		selected_port = int(pieces[1])
	if address.is_empty() or selected_port<1 or selected_port>65535: return {}
	return {"host":address,"port":selected_port}

static func format_endpoint(host: String, selected_port: int) -> String:
	return ("["+host+"]" if host.contains(":") else host)+":"+str(selected_port)


func _ready_to_spawn(id: int) -> void:
	var room_data:=_user_room(id)
	if room_data.is_empty() or room_data.state not in ["WAITING","IN_PROGRESS"]: return
	var chosen:=str(users[id].ship)
	var owned: Array=accounts[users[id].identity].owned
	if chosen not in owned or not NavalCatalog.SHIPS.has(chosen): _error(id,"Embarcação indisponível.");return
	if room_data.state=="IN_PROGRESS":
		if not room_data.simulation.deploy_player(id,chosen): return
	users[id].ready=true
	_room_changed(room_data)
	if room_data.simulation!=null: _send(id,"snapshot",room_data.simulation.snapshot())
