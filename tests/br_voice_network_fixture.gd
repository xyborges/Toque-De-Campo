extends Node3D

class Actor extends BRPlayer:
	func _ready() -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _process(_delta: float) -> void:pass
	func _unhandled_input(_event: InputEvent) -> void:pass
var players: Dictionary={}
var local_player: GamePlayer
var br_round:=BRRound.new()
var br_generation:=4
var phase:="active"
var online:=true
var network_guard:=GameNetworkGuard.new()
var voice: BRVoiceRelay
var network_api:=SceneMultiplayer.new()
var acknowledgements: Dictionary={}
var received: Array=[]
var reports: Dictionary={}

func gameplay_input_allowed() -> bool:return false
func _ready() -> void:
	name="VoiceQA";network_api.server_relay=false;network_api.allow_object_decoding=false
	get_tree().set_multiplayer(network_api,get_path())
	voice=BRVoiceRelay.new();add_child(voice);voice.configure(self)
	voice.frame_received.connect(func(id: int,life: int,sequence: int,_packet: PackedByteArray):received.append([id,life,sequence]))

@rpc("authority","call_remote","reliable")
func qa_setup(ids: Array,positions: Array) -> void:
	for index in ids.size():
		var id:=int(ids[index])
		if not players.has(id):
			var actor:=Actor.new();actor.peer_id=id;actor.hp=100.;actor.life_id=1;actor.position=positions[index];actor.is_local=id==multiplayer.get_unique_id();add_child(actor);players[id]=actor
			if actor.is_local:local_player=actor
	br_round.begin(ids,0.)
	GameVoiceSettings.set_option("voice_enabled",true)
	voice.preferences_signature=-1;voice.apply_preferences()
	if not multiplayer.is_server():qa_ack.rpc_id(1,"setup")

@rpc("authority","call_remote","reliable")
func qa_send(sequence: int,life: int=1,generation: int=4,length: int=50) -> void:
	var packet:=PackedByteArray();packet.resize(length);packet.fill(17)
	voice.rpc_id(1,"server_frame",life,generation,sequence,packet)
	qa_ack.rpc_id(1,"sent:%d"%sequence)

@rpc("authority","call_remote","reliable")
func qa_presence(label: String,enabled: bool,radius: float,mutes: Array) -> void:
	voice.rpc_id(1,"server_presence",enabled,radius,mutes)
	qa_ack.rpc_id(1,label)

@rpc("authority","call_remote","reliable")
func qa_health(id: int,hp: float) -> void:
	players[id].hp=hp
	if hp<=0 and local_player.peer_id==id:voice.reset()

@rpc("authority","call_remote","reliable")
func qa_report(label: String) -> void:
	qa_results.rpc_id(1,label,received)

@rpc("any_peer","call_remote","reliable")
func qa_results(label: String,frames: Array) -> void:
	if multiplayer.is_server():reports[str(multiplayer.get_remote_sender_id())+":"+label]=frames

@rpc("any_peer","call_remote","reliable")
func qa_ack(label: String) -> void:
	if multiplayer.is_server():acknowledgements[str(multiplayer.get_remote_sender_id())+":"+label]=true

@rpc("authority","call_remote","reliable")
func qa_finish() -> void:get_tree().quit()
