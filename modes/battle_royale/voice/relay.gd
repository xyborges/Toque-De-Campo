extends Node
class_name BRVoiceRelay

signal changed
signal frame_received(speaker: int,life: int,sequence: int,packet: PackedByteArray)
const CHANNEL:=3
const MAX_PACKET:=256
const RANGE_MARGIN:=2.
static var managed_bus_users:=0
static var managed_bus_owned:=false
var game: Node3D
var client: Node
var roster: Dictionary={}
var recipient_settings: Dictionary={}
var guards: Dictionary={}
var stopped: Dictionary={}
var talking: Dictionary={}
var roster_delivered: Dictionary={}
var presence_clock:=0.
var roster_signature:=-1
var preferences_signature:=-1
var poll_clock:=0.
var round_seen:=-1
var last_active:=false
var delivered:=0
var rejected:=0
var accepted:=0
var bytes_relayed:=0
var closed:=false
var bus_registered:=false

func configure(context: Node3D) -> void:
	closed=false;set_process(true);game=context;name="ProximityVoice"
	# Headless servers only relay bytes; they never load or instantiate Opus.
	if DisplayServer.get_name()!="headless":
		_acquire_bus()
		if is_instance_valid(client):client.shutdown();client.queue_free();client=null
		var backend=load("res://scripts/voice/client.gd")
		if backend:
			client=backend.new();add_child(client);client.configure(self)
			client.encoded_frame.connect(_encoded)
			if client.has_signal("availability_changed"):client.availability_changed.connect(func(_ready: bool,_status: String):changed.emit())
	apply_preferences()

func _active() -> bool:
	if not is_instance_valid(game):return false
	if game.get("phase")!=null:return game.phase=="active"
	if game is WarGame:return not game.match_ended
	return bool(game.get("match_started")) and game.get("mode")=="pvp"
func _generation(id: int=-1) -> int:
	if game.has_method("voice_generation"):return int(game.voice_generation(id))
	return int(game.get("br_generation")) if game.get("br_generation")!=null else 0
func _alive(id: int) -> bool:
	var actor: Variant=voice_speaker(id)
	return is_instance_valid(actor) and actor.hp>0 and (game.get("br_round")==null or game.br_round.is_alive(id))

func voice_local_allowed() -> bool:
	return not closed and is_instance_valid(game) and game.get("closing")!=true and _active() and is_instance_valid(game.local_player) and game.local_player.hp>0 and GameVoiceSettings.enabled()
func voice_speaker(id: int) -> Variant:
	return game.players.get(id) if is_instance_valid(game) else null
func voice_muted(id: int) -> bool:
	return GameVoiceSettings.is_muted(str(roster.get(id,{}).get("identity","")))
func available() -> bool:return is_instance_valid(client) and client.available()
func status() -> String:return client.status() if is_instance_valid(client) else "Voz indisponível"
func is_transmitting() -> bool:
	return bool(client.get("transmitting")) if is_instance_valid(client) else false

func _process(delta: float) -> void:
	if closed or not is_instance_valid(game):return
	if not _transport_ready():
		if is_instance_valid(client):
			client.set_transmitting(false)
			if last_active:client.reset()
		last_active=false;return
	var active:=voice_local_allowed()
	if is_instance_valid(client):
		var controls: bool=active and game.online and game.gameplay_input_allowed() and game.get_window().has_focus()
		client.set_transmitting(controls and Input.is_physical_key_pressed(KEY_X))
	if round_seen!=_generation():
		reset();round_seen=_generation()
	if not active and last_active and is_instance_valid(client):client.reset()
	last_active=active
	var now:=Time.get_ticks_msec()*.001
	for id in talking.keys():
		if now-float(talking[id])>.3:talking.erase(id);changed.emit()
	presence_clock+=delta
	if presence_clock>=8.:presence_clock=0.;preferences_signature=-1
	poll_clock+=delta
	if poll_clock<.5:return
	poll_clock=0
	if game.multiplayer.is_server():_update_roster()
	apply_preferences()

func apply_preferences() -> void:
	if closed or not is_instance_valid(game):return
	if is_instance_valid(client):
		client.set_enabled(GameVoiceSettings.enabled());client.set_volume(GameVoiceSettings.volume())
		client.set_input_device(GameVoiceSettings.input_device())
	if not GameVoiceSettings.enabled():talking.clear()
	var ids: Array[int]=[]
	for id in roster:
		if voice_muted(int(id)):ids.append(int(id))
	var preferences:={"enabled":GameVoiceSettings.enabled(),"radius":GameVoiceSettings.radius(),"muted":ids}
	var signature:=hash(preferences)
	if signature==preferences_signature:return
	preferences_signature=signature
	if game.online and _transport_ready():
		if game.multiplayer.is_server():
			if is_instance_valid(game.local_player):_set_presence(game.local_player.peer_id,preferences.enabled,preferences.radius,ids)
		elif game.multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
			rpc_id(1,"server_presence",preferences.enabled,preferences.radius,ids)
	changed.emit()

func _identity(actor: Node3D) -> String:
	var account:=str(actor.get_meta("account_id",""))
	if not account.is_empty():return ("tdc-voice:"+account).sha256_text()
	if not actor.has_meta("voice_identity"):
		actor.set_meta("voice_identity",("session:%d:%d:%d"%[actor.peer_id,Time.get_ticks_usec(),randi()]).sha256_text())
	return str(actor.get_meta("voice_identity"))

func _update_roster() -> void:
	var current: Dictionary={}
	for actor in game.players.values():
		if actor.get("br_bot")==true or actor.get_meta("war_bot",false):continue
		current[actor.peer_id]={"identity":_identity(actor),"name":str(actor.name).left(24)}
	var signature:=hash(current)
	if signature!=roster_signature:
		roster_signature=signature;roster=current;preferences_signature=-1;roster_delivered.clear()
	if game.online:
		for id in game.multiplayer.get_peers():
			if game.players.has(id) and _peer_ready(int(id)) and not roster_delivered.has(id):
				var visible:=current.duplicate()
				if game.has_method("voice_can_relay"):
					for speaker in visible.keys():
						if not game.voice_can_relay(int(id),int(speaker)):visible.erase(speaker)
				rpc_id(id,"remote_roster",visible);roster_delivered[id]=true
	changed.emit()

@rpc("authority","call_remote","reliable")
func remote_roster(data: Dictionary) -> void:
	if closed or data.size()>64:return
	var clean: Dictionary={}
	for raw_id in data:
		var row: Variant=data[raw_id]
		if not row is Dictionary:continue
		var identity:=str(row.get("identity",""))
		if identity.length()!=64 or not identity.is_valid_hex_number(false):continue
		clean[int(raw_id)]={"identity":identity,"name":str(row.get("name","")).left(24)}
	roster=clean;preferences_signature=-1;apply_preferences();changed.emit()

@rpc("any_peer","call_remote","reliable")
func server_presence(enabled: bool,radius: float,muted_ids: Array) -> void:
	if closed or not game.multiplayer.is_server():return
	var id:=multiplayer.get_remote_sender_id()
	if not game.players.has(id) or not game.network_guard.allow(id,"voice_presence",3,3):return
	_set_presence(id,enabled,radius,muted_ids)

func _set_presence(id: int,enabled: bool,radius: float,muted_ids: Array) -> void:
	if not is_finite(radius) or muted_ids.size()>64:return
	var muted: Dictionary={}
	for raw in muted_ids:
		if (raw is int or raw is float) and game.players.has(int(raw)):muted[int(raw)]=true
	# Keep the RPC argument for existing peers; clients no longer choose range.
	recipient_settings[id]={"enabled":enabled,"radius":GameVoiceSettings.radius(),"muted":muted}

func _encoded(sequence: int,packet: PackedByteArray) -> void:
	if not voice_local_allowed() or not game.online:return
	var actor: Variant=game.local_player
	if game.multiplayer.is_server():_accept_frame(actor.peer_id,actor.life_id,_generation(actor.peer_id),sequence,packet)
	else:rpc_id(1,"server_frame",actor.life_id,_generation(actor.peer_id),sequence,packet)

@rpc("any_peer","call_remote","unreliable",3)
func server_frame(life: int,generation: int,sequence: int,packet: PackedByteArray) -> void:
	if game.multiplayer.is_server():_accept_frame(multiplayer.get_remote_sender_id(),life,generation,sequence,packet)

func _accept_frame(id: int,life: int,generation: int,sequence: int,packet: PackedByteArray) -> void:
	if closed:rejected+=1;return
	var actor: Variant=voice_speaker(id)
	if not actor or actor.hp<=0 or not _active() or not _alive(id) or actor.life_id!=life or _generation(id)!=generation or sequence<0 or sequence>2147483647 or packet.is_empty() or packet.size()>MAX_PACKET:
		rejected+=1;return
	if not bool(recipient_settings.get(id,{}).get("enabled",false)):rejected+=1;return
	var now:=Time.get_ticks_msec()*.001
	var record: Dictionary=guards.get(id,{})
	if int(record.get("life",-1))!=life or int(record.get("generation",-1))!=generation:
		record={"life":life,"generation":generation,"high":-1,"seen":{},"at":now,"accepted_at":now,"tokens":10.,"bytes":1024.}
	var elapsed:=maxf(0.,now-float(record.at));record.at=now
	record.tokens=minf(10.,float(record.tokens)+elapsed*60.)
	record.bytes=minf(1024.,float(record.bytes)+elapsed*4000.)
	var high:=int(record.high)
	if record.seen.has(sequence) or (high>=0 and (sequence<high-63 or (sequence>high+500 and now-float(record.accepted_at)<2.))) or float(record.tokens)<1. or float(record.bytes)<packet.size():
		guards[id]=record;rejected+=1;return
	record.tokens-=1.;record.bytes-=packet.size();record.high=maxi(high,sequence);record.seen[sequence]=true;record.accepted_at=now
	for old in record.seen.keys():
		if int(old)<int(record.high)-63:record.seen.erase(old)
	guards[id]=record;accepted+=1
	for listener in game.players.values():
		if game.has_method("voice_can_relay") and not game.voice_can_relay(id,listener.peer_id):continue
		if listener.peer_id==id or listener.hp<=0 or not _alive(listener.peer_id) or listener.get("br_bot")==true or listener.get_meta("war_bot",false):continue
		var preference: Dictionary=recipient_settings.get(listener.peer_id,{"enabled":false,"muted":{}})
		if not bool(preference.enabled) or preference.muted.has(id) or listener.global_position.distance_squared_to(actor.global_position)>pow(GameVoiceSettings.radius()+RANGE_MARGIN,2):continue
		if listener.is_local:remote_frame(id,life,generation,sequence,packet)
		elif game.online and _peer_ready(listener.peer_id):rpc_id(listener.peer_id,"remote_frame",id,life,generation,sequence,packet)
		else:continue
		delivered+=1;bytes_relayed+=packet.size()

@rpc("authority","call_remote","unreliable",3)
func remote_frame(id: int,life: int,generation: int,sequence: int,packet: PackedByteArray) -> void:
	var actor: Variant=voice_speaker(id)
	if not voice_local_allowed() or not actor or actor.hp<=0 or actor.life_id!=life or generation!=_generation(id) or packet.is_empty() or packet.size()>MAX_PACKET or voice_muted(id):return
	if stopped.get(id)==Vector2i(life,generation):return
	if game.local_player.global_position.distance_squared_to(actor.global_position)>pow(GameVoiceSettings.radius()+RANGE_MARGIN,2):return
	talking[id]=Time.get_ticks_msec()*.001
	frame_received.emit(id,life,sequence,packet)
	if is_instance_valid(client):client.receive_frame(id,life,sequence,packet)
	changed.emit()

func silence(id: int) -> void:
	var actor: Variant=voice_speaker(id)
	if not actor:return
	remote_stop(id,actor.life_id,_generation(id))
	if game.online and game.multiplayer.is_server():
		for peer in multiplayer.get_peers():
			if game.players.has(peer) and _peer_ready(int(peer)):rpc_id(peer,"remote_stop",id,actor.life_id,_generation(id))

func _peer_ready(id: int) -> bool:
	if not _transport_ready():return false
	return GameNetworkPeers.connected(game.multiplayer.multiplayer_peer as ENetMultiplayerPeer,id,CHANNEL+1)!=null

func _transport_ready() -> bool:
	if not is_instance_valid(game):return false
	var peer:=game.multiplayer.multiplayer_peer
	return peer!=null and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED

@rpc("authority","call_remote","reliable")
func remote_stop(id: int,life: int,generation: int) -> void:
	if closed:return
	stopped[id]=Vector2i(life,generation);talking.erase(id)
	if is_instance_valid(client):
		client.remove_speaker(id)
		if is_instance_valid(game.local_player) and game.local_player.peer_id==id:client.set_transmitting(false);client.reset()
	changed.emit()

func set_muted(id: int,value: bool) -> void:
	GameVoiceSettings.set_muted(str(roster.get(id,{}).get("identity","")),value)
	if value and is_instance_valid(client):client.remove_speaker(id)
	preferences_signature=-1;apply_preferences()

func forget(id: int) -> void:
	roster_delivered.erase(id);roster.erase(id);recipient_settings.erase(id);guards.erase(id);stopped.erase(id);talking.erase(id);roster_signature=-1
	for preference in recipient_settings.values():preference.muted.erase(id)
	if is_instance_valid(client):client.remove_speaker(id)
	changed.emit()

func reset() -> void:
	guards.clear();stopped.clear();talking.clear();preferences_signature=-1
	if is_instance_valid(client):client.reset()
	changed.emit()

func _acquire_bus() -> void:
	if bus_registered:return
	if AudioServer.get_bus_index("Voice")<0:
		AudioServer.add_bus();var bus:=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"Voice");AudioServer.set_bus_send(bus,"Master")
		AudioServer.add_bus_effect(bus,AudioEffectLimiter.new());managed_bus_owned=true
	managed_bus_users+=1;bus_registered=true

func _release_bus() -> void:
	if not bus_registered:return
	bus_registered=false;managed_bus_users=maxi(0,managed_bus_users-1)
	if managed_bus_users==0 and managed_bus_owned:
		var bus:=AudioServer.get_bus_index("Voice")
		if bus>=0:AudioServer.remove_bus(bus)
		managed_bus_owned=false

func shutdown() -> void:
	if closed:return
	closed=true;set_process(false)
	# Unlike a round reset, no roster, mute peer IDs, presence, or speaking
	# state belongs to a future room. Keep persistent account preferences only.
	if is_instance_valid(client):client.shutdown()
	roster_delivered.clear();roster.clear();recipient_settings.clear();guards.clear();stopped.clear();talking.clear()
	roster_signature=-1;preferences_signature=-1;round_seen=-1;last_active=false
	_release_bus();changed.emit()

func _exit_tree() -> void:
	shutdown()
