extends SceneTree
class Mode extends NavalMode:
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _exit_tree() -> void:pass
class Simulation extends Node3D:
	var ships: Dictionary={}
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var mode:=Mode.new();root.add_child(mode)
	var network:=NavalNetwork.new();mode.network=network;mode.add_child(network)
	network.service=true;network.connection.multiplayer_peer=OfflineMultiplayerPeer.new()
	var one:=Simulation.new();var two:=Simulation.new();mode.add_child(one);mode.add_child(two)
	var listener:=NavalShip.new();listener.peer=1;listener.identity="qa-one";listener.display_name="Listener";listener.hp=100.
	var speaker:=NavalShip.new();speaker.peer=2;speaker.identity="qa-two";speaker.display_name="Speaker";speaker.hp=100.;speaker.position=Vector3(2,0,0)
	one.add_child(listener);two.add_child(speaker);one.ships[1]=listener;two.ships[2]=speaker
	network.rooms={"a":{"match":"a","state":"IN_PROGRESS","simulation":one},"b":{"match":"b","state":"IN_PROGRESS","simulation":two}}
	var context: Node3D=load("res://scripts/voice/naval_adapter.gd").new();context.naval=mode;network.add_child(context)
	await process_frame;context._process(0.)
	var relay: BRVoiceRelay=context.voice
	GameVoiceSettings.set_option("voice_enabled",true)
	check(context.multiplayer==network.connection and relay.multiplayer==network.connection,"naval adapter inherits actual naval MultiplayerAPI")
	check(context.players.size()==2 and context.local_player.peer_id==1,"ship operators become voice proxies")
	check(context.players[2].global_position.is_equal_approx(speaker.global_position+Vector3.UP*1.5),"proxy follows ship position")
	check(not context.voice_can_relay(1,2) and context.voice_generation(1)!=context.voice_generation(2),"naval rooms have independent voice generations")
	relay._set_presence(1,true,24.,[]);relay._set_presence(2,true,24.,[])
	var packet:=PackedByteArray();packet.resize(50);packet.fill(17)
	relay._accept_frame(2,1,context.voice_generation(2),1,packet)
	check(relay.accepted==1 and relay.delivered==0,"nearby ships in separate rooms cannot hear each other")
	two.ships.erase(2);one.ships[2]=speaker;context._process(0.)
	relay._accept_frame(2,1,context.voice_generation(2),2,packet)
	check(relay.delivered==1,"living ships in the same room receive proximity voice")
	speaker.dead=true;context._process(0.);relay._accept_frame(2,1,context.voice_generation(2),3,packet)
	check(relay.delivered==1 and relay.rejected>0,"dead naval operators cannot transmit")
	one.ships.erase(2);context._process(0.)
	check(not context.players.has(2) and not relay.recipient_settings.has(2),"departed ship clears voice identity and preferences")
	relay.shutdown();check(relay.closed and relay.roster.is_empty(),"naval voice closes cleanly")
	mode.free();await process_frame
	var report:={"checks":checks,"failures":failures,"ok":failures.is_empty(),"scope":"Actual naval adapter/API inheritance, ship proxies, room isolation, positional source, death and cleanup. Offline transport fixture; Opus/DTLS routing verified in separate tests."}
	NavalStorage.write_json("res://work/revision-1102-naval-voice.json",report);print("NAVAL_VOICE_1102 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
