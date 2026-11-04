extends RefCounted
class_name GameVoiceCodec

const SAMPLE_RATE:=24000
const FRAME_MS:=20
const SAMPLES:=480
const BITRATE:=20000
const MAX_PACKET:=256
const EXTENSION:="res://native/voice/godotopus.gdextension"
static var load_attempted:=false
static var load_error:=""

static func available() -> bool:
	if ClassDB.class_exists("GodotOpusEncoder") and ClassDB.class_exists("GodotOpusDecoder"):return true
	if load_attempted:return false
	load_attempted=true
	if not OS.has_feature("windows") or not ResourceLoader.exists(EXTENSION):
		load_error="Voz indisponível nesta plataforma";return false
	var status:=GDExtensionManager.load_extension(EXTENSION)
	if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		load_error="Voz indisponível";return false
	return ClassDB.class_exists("GodotOpusEncoder") and ClassDB.class_exists("GodotOpusDecoder")

static func encoder() -> Object:
	if not available():return null
	var result: Object=ClassDB.instantiate("GodotOpusEncoder")
	result.call("initialize",SAMPLE_RATE,1,FRAME_MS)
	result.call("set_bitrate",BITRATE);result.call("set_complexity",5)
	result.call("set_vbr",false,true);result.call("set_signal_voice",true)
	result.call("set_inband_fec",true);result.call("set_expected_packet_loss",10)
	# Push-to-talk already defines speech boundaries. DTX remains enabled for
	# silence, but sequence numbers advance only for transmitted frames.
	result.call("set_dtx",true)
	return result

static func decoder() -> Object:
	if not available():return null
	var result: Object=ClassDB.instantiate("GodotOpusDecoder")
	result.call("initialize",SAMPLE_RATE,1,FRAME_MS)
	return result

static func resampler(from_rate: int) -> Object:
	if from_rate==SAMPLE_RATE:return null
	if from_rate<8000 or from_rate>192000:return null
	if not available() or not ClassDB.class_exists("GodotOpusResampler"):return null
	var result: Object=ClassDB.instantiate("GodotOpusResampler")
	result.call("initialize",from_rate,SAMPLE_RATE,1,5)
	return result

static func release(native: Object) -> void:
	if is_instance_valid(native) and not native is RefCounted:native.free()

static func valid_packet(packet: PackedByteArray) -> bool:
	if packet.is_empty() or packet.size()>MAX_PACKET:return false
	# RFC6716 TOC duration/channels checks are cheap and reject oversized
	# audio durations before the native decoder. Only mono20ms is negotiated.
	var toc:=int(packet[0]);var config:=toc>>3
	if toc&4:return false
	var quarter_ms: int=[40,80,160,240][config&3] if config<12 else ([40,80][config&1] if config<16 else [10,20,40,80][config&3])
	var code:=toc&3;var frames:=1 if code==0 else 2
	if code==3:
		if packet.size()<2:return false
		frames=int(packet[1])&63
	return frames>0 and frames*quarter_ms==80
