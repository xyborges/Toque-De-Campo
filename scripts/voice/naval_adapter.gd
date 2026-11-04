extends Node3D

# Reuses the same secure unreliable relay. Each authoritative ship supplies
# its operator's position/life; packets never cross naval room boundaries.
class Operator extends Node3D:
	var peer_id:=0
	var life_id:=1
	var hp:=0.
	var is_local:=false

var mode:="pvp"
var match_started:=false
var online:=false
var closing:=false
var players: Dictionary={}
var local_player: Operator
var network_guard: GameNetworkGuard
var naval: NavalMode
var voice: BRVoiceRelay

func _ready() -> void:
	name="VoiceContext";network_guard=naval.network.network_guard
	voice=BRVoiceRelay.new();add_child(voice);voice.configure(self);naval.voice=voice

func gameplay_input_allowed() -> bool:
	return not naval.closing and is_instance_valid(naval.focus) and not naval.focus.blocked()

func voice_generation(id: int=-1) -> int:
	var actor: Operator=players.get(id,local_player)
	return int(actor.get_meta("voice_generation",0)) if actor else 0

func voice_can_relay(a: int,b: int) -> bool:
	return players.has(a) and players.has(b) and players[a].get_meta("voice_room","")==players[b].get_meta("voice_room","")

func _process(_delta: float) -> void:
	if not is_instance_valid(naval.network):return
	closing=naval.closing
	online=naval.network.connection.multiplayer_peer!=null and naval.network.connection.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED
	var sources: Dictionary={}
	if naval.network.service:
		for room: Dictionary in naval.network.rooms.values():
			var simulation: Node=room.get("simulation")
			if is_instance_valid(simulation) and str(room.get("state",""))=="IN_PROGRESS":
				for ship: NavalShip in simulation.ships.values():sources[ship.peer]={"ship":ship,"room":str(room.get("match",""))}
	else:
		for ship: NavalShip in naval.ships.values():sources[ship.peer]={"ship":ship,"room":naval.current_match}
	for id in players.keys():
		if not sources.has(id):voice.forget(id);players[id].queue_free();players.erase(id)
	local_player=null
	for id in sources:
		var row: Dictionary=sources[id];var ship: NavalShip=row.ship
		if not players.has(id):
			var actor:=Operator.new();actor.peer_id=id;add_child(actor);players[id]=actor
		var actor: Operator=players[id]
		actor.name=ship.display_name;actor.life_id=ship.life;actor.hp=0. if ship.dead else ship.hp;actor.is_local=id==naval.network.local_id()
		actor.global_position=ship.global_position+Vector3.UP*1.5
		# Player identities can stay unchanged while their naval rooms change.
		# Invalidate per-recipient rosters too, so names/mute targets from the old
		# room cannot remain visible just because the global identity hash matches.
		if str(actor.get_meta("voice_room",""))!=str(row.room):
			voice.roster_signature=-1;voice.roster_delivered.clear()
		actor.set_meta("account_id",ship.identity);actor.set_meta("voice_room",row.room);actor.set_meta("voice_generation",int(str(row.room).sha256_text().substr(0,7).hex_to_int()))
		if actor.is_local:local_player=actor
	match_started=not sources.is_empty()
	if not online:voice.reset()

func _exit_tree() -> void:
	if is_instance_valid(voice):voice.shutdown()
