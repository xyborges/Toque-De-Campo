extends SceneTree
const CODEC=preload("res://scripts/voice/codec.gd")
const CLIENT=preload("res://scripts/voice/client.gd")
const RELAY=preload("res://modes/battle_royale/voice/relay.gd")
class Actor extends BRPlayer:
	func _ready() -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _process(_delta: float) -> void:pass
class Context extends Node3D:
	var closing:=false
	var phase:="active"
	var online:=false
	var br_generation:=4
	var local_player: GamePlayer
	var players: Dictionary={}
	var br_round:=BRRound.new()
	var network_guard:=GameNetworkGuard.new()
	func gameplay_input_allowed() -> bool:return false
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func run() -> void:
	var context:=Context.new();root.add_child(context)
	for id in [1,2]:
		var actor:=Actor.new();actor.peer_id=id;actor.life_id=1;actor.hp=100.;actor.position=Vector3(id,0,0);actor.is_local=id==1
		context.add_child(actor);context.players[id]=actor
		if id==1:context.local_player=actor
	context.br_round.begin([1,2],0.)
	var relay:=RELAY.new();context.add_child(relay);relay.configure(context);relay.set_process(false)
	check(relay.client==null if DisplayServer.get_name()=="headless" else relay.client!=null,"headless relay does not construct an audio client")
	# Exercise the same ownership path with the dummy audio driver. No actual
	# microphone is opened: native codec input below is a synthetic20ms tone.
	var bus_existed:=AudioServer.get_bus_index("Voice")>=0
	relay._acquire_bus()
	var client:=CLIENT.new();client.simulation_only=true;relay.add_child(client);client.configure(relay);relay.client=client
	check(client.available() and not client.input_active,"configure leaves physical microphone inactive")
	var encoder_ref: WeakRef=weakref(client.encoder)
	var encoder:=CODEC.encoder();encoder.call("set_dtx",false)
	var samples:=PackedFloat32Array();samples.resize(480)
	for i in samples.size():samples[i]=sin(float(i)*TAU*233./24000.)*.15
	var packet: PackedByteArray=encoder.call("encode",samples)
	var emitted: Array[int]=[];client.encoded_frame.connect(func(sequence: int,_packet: PackedByteArray):emitted.append(sequence))
	client.set_transmitting(true);client.feed_pcm(samples);client.receive_frame(2,1,1,packet)
	check(client.transmitting and not client.input_active and not emitted.is_empty(),"synthetic push-to-talk active without capturing microphone")
	check(client.speakers.size()==1,"room creates decoder and bounded speech buffer")
	var decoder_ref: WeakRef=weakref(client.speakers[2].decoder)
	client.accumulator.append_array(samples.slice(0,100))
	relay.roster={1:{"identity":"a".repeat(64)},2:{"identity":"b".repeat(64)}}
	relay.recipient_settings={1:{"enabled":true,"radius":40.,"muted":{2:true}}}
	relay.guards={2:{"seen":{1:true}}};relay.stopped={3:Vector2i(1,4)};relay.talking={2:1.}
	context.closing=true;relay.shutdown()
	check(relay.closed and client.closed and not client.is_processing() and not relay.is_processing(),"leaving room permanently stops capture and playout processing")
	check(not client.transmitting and not client.input_active and client.accumulator.is_empty() and client.speakers.is_empty(),"leave clears capture, PCM and every speaker jitter buffer")
	check(not is_instance_valid(encoder_ref.get_ref()) and not is_instance_valid(decoder_ref.get_ref()),"leave frees native encoder and decoder immediately")
	check(relay.roster.is_empty() and relay.recipient_settings.is_empty() and relay.guards.is_empty() and relay.stopped.is_empty() and relay.talking.is_empty(),"leave clears room presence, roster, sequence, mute peer IDs and speaking state")
	check(bus_existed or AudioServer.get_bus_index("Voice")==-1,"last owning relay releases temporary audio bus")
	var count:=emitted.size();client.set_enabled(true);client.set_transmitting(true);client.feed_pcm(samples)
	client.receive_frame(2,1,2,packet);relay.remote_frame(2,1,4,2,packet);relay.remote_roster({2:{"identity":"b".repeat(64),"name":"Old room"}})
	check(emitted.size()==count and client.speakers.is_empty() and relay.roster.is_empty(),"late frames, settings and roster cannot reactivate departed room")
	relay.shutdown();client.shutdown();check(not client.input_active,"repeated cleanup is idempotent")
	# A distinct room/generation must explicitly configure a fresh relay.
	context.closing=false;context.br_generation=5
	var next:=RELAY.new();context.add_child(next);next.configure(context);next.set_process(false)
	var next_client:=CLIENT.new();next_client.simulation_only=true;next.add_child(next_client);next_client.configure(next);next.client=next_client
	check(next.guards.is_empty() and next.recipient_settings.is_empty() and next.stopped.is_empty() and next.talking.is_empty() and not next_client.input_active,"new room starts without prior presence, queued speech or microphone capture")
	next_client.receive_frame(2,1,1,packet)
	check(next_client.speakers.size()==1 and next_client.available(),"new room creates its own functioning codec and playback state")
	next.shutdown();CODEC.release(encoder);context.free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"microphone_activated":false,"scope":"Synthetic native Opus room lifecycle: configure/PTT, receive, leave, duplicate shutdown, stale packets, fresh room; native object disposal, buffers, roster/presence and temporary bus cleanup."}
	NavalStorage.write_json("res://work/br-voice-lifecycle-validation.json",report);print("BR_VOICE_LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
