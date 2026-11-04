extends SceneTree
const CODEC=preload("res://scripts/voice/codec.gd")
const JITTER=preload("res://scripts/voice/jitter.gd")
const CLIENT=preload("res://scripts/voice/client.gd")
var checks:=0
var failures: Array[String]=[]
class Actor extends Node3D:
	var life_id:=1
	var hp:=100.
class Context extends Node:
	var allowed:=true
	var muted: Dictionary={}
	var actors: Dictionary={}
	func voice_local_allowed() -> bool:return allowed
	func voice_speaker(id: int) -> Node3D:return actors.get(id)
	func voice_muted(id: int) -> bool:return bool(muted.get(id,false))
	func voice_listener_position() -> Vector3:return Vector3.ZERO

func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

static func waveform(frame: int) -> PackedFloat32Array:
	var pcm:=PackedFloat32Array();pcm.resize(CODEC.SAMPLES)
	for i in pcm.size():
		var time:=float(frame*CODEC.SAMPLES+i)/CODEC.SAMPLE_RATE
		pcm[i]=.17*sin(TAU*173.*time)+.07*sin(TAU*346.*time)
	return pcm

func run() -> void:
	check(CODEC.available(),"pinned Opus client extension loads in Godot4.7.2")
	if not CODEC.available():finish({});return
	var encoder:=CODEC.encoder();var decoder:=CODEC.decoder()
	# A steady sine is intentionally classified as non-speech by Opus VAD;
	# disable DTX only for bitrate measurement, then verify DTX separately.
	encoder.call("set_dtx",false)
	var packets: Array[PackedByteArray]=[];var byte_count:=0
	for frame in 400:
		var packet: PackedByteArray=encoder.call("encode",waveform(frame));packets.append(packet);byte_count+=packet.size()
		var pcm: PackedFloat32Array=decoder.call("decode",packet)
		check(CODEC.valid_packet(packet) and pcm.size()==CODEC.SAMPLES,"20ms Opus size/decoded frame %d"%frame)
	check(byte_count*8./8./1000.<24. and byte_count*8./8./1000.>16.,"mono payload bitrate within16-24kbps")
	var recovery: PackedFloat32Array=decoder.call("decode_fec",packets[0]);check(recovery.size()==480,"Opus FEC available without DNN")
	var plc: PackedFloat32Array=decoder.call("decode_plc");check(plc.size()==480,"Opus PLC available")
	encoder.call("set_dtx",true)
	var silence:=PackedFloat32Array();silence.resize(480)
	for index in 100:encoder.call("encode",silence)
	check(bool(encoder.call("is_in_dtx")),"Opus silence uses DTX")
	var resampler:=CODEC.resampler(48000)
	var input:=PackedFloat32Array();input.resize(4800)
	for i in input.size():input[i]=sin(i*TAU*233./48000.)*.1
	var resampled: PackedFloat32Array=resampler.call("resample",input)
	check(resampled.size()>2300 and resampled.size()<=2400,"native input resampler48000->24000 uses correct rate")
	CODEC.release(resampler)
	var jitter:=JITTER.new();jitter.configure(decoder);jitter.push(1,packets[0],0.)
	check(jitter.pull(.059).is_empty() and jitter.pull(.060).size()==480,"60ms jitter initial hold")
	check(not jitter.push(999,PackedByteArray([0]),.061),"wrong Opus duration is rejected before native decoding")
	check(not jitter.push(1,packets[0],.061),"late duplicate cannot replay decoded audio")
	jitter.reset()
	var delivery: Array[Dictionary]=[]
	for index in packets.size():
		if index%9==4:continue
		var delay:=.025+float(posmod(index*13,5))*.007+(.044 if index%11==6 else 0.)
		delivery.append({"at":index*.020+delay,"sequence":index+1,"packet":packets[index]})
	delivery.sort_custom(func(a: Dictionary,b: Dictionary):return a.at<b.at)
	var cursor:=0;var produced:=0
	for frame in 1800:
		var now:=frame*.005
		while cursor<delivery.size() and float(delivery[cursor].at)<=now:
			jitter.push(int(delivery[cursor].sequence),delivery[cursor].packet,now);cursor+=1
		if not jitter.pull(now).is_empty():produced+=1
	var jitter_stats:=jitter.stats()
	check(produced>=350,"loss/reordering playout remains continuous")
	check(jitter_stats.fec>0 and jitter_stats.plc>0 and jitter_stats.peak_frames<=JITTER.MAX_FRAMES,"bounded jitter recovers FEC and conceals missing frames")
	jitter.reset()
	for index in 40:jitter.push(index+1000,packets[index],1.+index*.0001)
	check(jitter.stats().queued_frames<=12 and jitter.stats().overflow>0,"burst cannot grow beyond12frames")
	jitter.pull(1.8);check(jitter.stats().queued_frames<=3,"post-hitch playout discards backlog")
	var context:=Context.new();root.add_child(context)
	for id in range(1,9):
		var actor:=Actor.new();actor.position=Vector3(id*3,0,0);context.add_child(actor);context.actors[id]=actor
	var client:=CLIENT.new();client.simulation_only=true;context.add_child(client);client.configure(context)
	check(client.available() and not client.input_active and not client.transmitting,"configuring codec never activates microphone")
	var outgoing: Array=[];client.encoded_frame.connect(func(sequence: int,packet: PackedByteArray):outgoing.append({"sequence":sequence,"bytes":packet.size()}))
	client.set_transmitting(true)
	for index in 5:client.feed_pcm(waveform(index))
	check(outgoing.size()==5 and not client.input_active,"PTT codec emits one packet per20ms without real microphone in synthetic test")
	client.set_transmitting(false);client.feed_pcm(waveform(10));check(outgoing.size()==5 and client.accumulator.is_empty(),"PTT release drops pending audio and blocks transmission")
	for id in range(2,9):client.receive_frame(id,1,1,packets[0])
	check(client.speakers.size()==6 and not client.speakers.has(8),"only six closest voices get decoders")
	client.receive_frame(1,1,1,packets[0]);check(client.speakers.size()==6 and client.speakers.has(1) and not client.speakers.has(7),"near voice replaces furthest decoder")
	context.muted[1]=true;client.receive_frame(1,1,2,packets[1]);check(not client.speakers.has(1),"muting immediately removes buffered speech")
	context.actors[2].hp=0.;client._process(.02);check(not client.speakers.has(2),"dead speaker is removed")
	context.actors[3].life_id=2;client._process(.02);check(not client.speakers.has(3),"old life cannot keep speaking")
	context.allowed=false;client._process(.02);check(client.speakers.is_empty() and not client.transmitting,"local death/spectator clears all speech")
	context.allowed=true;client.set_enabled(false);client.receive_frame(4,1,4,packets[3]);check(client.speakers.is_empty(),"chat disabled rejects all receive")
	var metrics:=client.stats();context.free();CODEC.release(encoder);CODEC.release(decoder)
	finish({"payload_kbps":byte_count*8./8./1000.,"jitter":jitter_stats,"decoded_under_loss":produced,"client":metrics,"microphone_activated":false})

func finish(metrics: Dictionary) -> void:
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"engine":Engine.get_version_info().string,"scope":"Actual native Opus24kmono20ms codec; synthetic packet loss/reorder/backlog, PTT frames,6nearest, mute/death/life cleanup. No microphone recording or subjective audio claim."}
	NavalStorage.write_json("res://work/br-voice-codec-validation.json",report);print("BR_VOICE_CODEC_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
