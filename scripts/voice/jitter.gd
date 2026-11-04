extends RefCounted
class_name GameVoiceJitter

# Time-driven playout rather than decoding on arrival. Three 20 ms packets
# absorb short bursts/reordering without allowing an unbounded latency queue.
const START_DELAY:=.060
const FRAME_SECONDS:=.020
const MAX_FRAMES:=12
const SILENCE_RESET:=.28
var decoder: Object
var packets: Dictionary={}
var expected:=-1
var high_sequence:=-1
var started:=false
var first_at:=0.
var last_at:=-100.
var due:=0.
var concealments:=0
var counters:={"received":0,"decoded":0,"plc":0,"fec":0,"duplicates":0,"late":0,"overflow":0,"underflow":0,"invalid":0,"peak_frames":0,"resets":0}

func configure(value: Object) -> void:
	decoder=value

func reset(preserve_sequence:=false) -> void:
	packets.clear();expected=-1;started=false;first_at=0.;last_at=-100.;due=0.;concealments=0
	if not preserve_sequence:high_sequence=-1
	if is_instance_valid(decoder):decoder.call("reset")
	counters.resets+=1

func push(sequence: int,packet: PackedByteArray,now: float) -> bool:
	if sequence<0 or not GameVoiceCodec.valid_packet(packet) or not is_finite(now):counters.invalid+=1;return false
	if sequence<=high_sequence-MAX_FRAMES or (started and sequence<expected):counters.late+=1;return false
	if packets.has(sequence):counters.duplicates+=1;return false
	if now-last_at>SILENCE_RESET:
		var prior:=high_sequence
		reset(true)
		# A packet older than the previous utterance cannot resurrect it.
		if sequence<=prior:counters.late+=1;return false
		first_at=now
	if expected<0:expected=sequence;first_at=now
	elif not started:expected=mini(expected,sequence)
	packets[sequence]=packet;last_at=now;high_sequence=maxi(high_sequence,sequence);counters.received+=1
	while packets.size()>MAX_FRAMES:
		var keys:=packets.keys();keys.sort();packets.erase(keys[0]);expected=maxi(expected,int(keys[0])+1);counters.overflow+=1
	counters.peak_frames=maxi(int(counters.peak_frames),packets.size())
	return true

func pull(now: float) -> PackedFloat32Array:
	if not is_instance_valid(decoder) or expected<0:return PackedFloat32Array()
	if not started:
		if now-first_at<START_DELAY:return PackedFloat32Array()
		if now-first_at>.12:
			var keys:=packets.keys();keys.sort()
			while keys.size()>3:packets.erase(keys.pop_front());counters.overflow+=1
			if not keys.is_empty():expected=int(keys[0])
		started=true;due=now
	if now+0.00001<due:return PackedFloat32Array()
	# A stalled main thread must not replay all audio accumulated behind it.
	if now-due>.12:
		var keys:=packets.keys();keys.sort()
		if not keys.is_empty():
			while keys.size()>3:packets.erase(keys.pop_front());counters.overflow+=1
			expected=int(keys[0]);due=now
		else:reset(true);return PackedFloat32Array()
	var pcm:=PackedFloat32Array()
	if packets.has(expected):
		pcm=decoder.call("decode",packets[expected]);packets.erase(expected);concealments=0;counters.decoded+=1
	elif packets.has(expected+1):
		pcm=decoder.call("decode_fec",packets[expected+1]);concealments+=1;counters.fec+=1
	elif now-last_at<.10 and concealments<3:
		pcm=decoder.call("decode_plc");concealments+=1;counters.plc+=1
	else:
		counters.underflow+=1;reset(true);return PackedFloat32Array()
	expected+=1;due+=FRAME_SECONDS
	if pcm.size()!=GameVoiceCodec.SAMPLES:counters.invalid+=1;return PackedFloat32Array()
	for sample in pcm:
		if not is_finite(sample):counters.invalid+=1;return PackedFloat32Array()
	return pcm

func stats() -> Dictionary:
	var result:=counters.duplicate();result.queued_frames=packets.size();result.queued_ms=packets.size()*20;result.started=started
	return result
