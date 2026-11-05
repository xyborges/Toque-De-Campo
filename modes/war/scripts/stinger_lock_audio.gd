extends Node
class_name WarStingerLockAudio

# Local-only seeker feedback. No RPC or combat bus contention.
const RATE := 22050
var speaker: AudioStreamPlayer
var tones: Dictionary = {}
var target_id := ""
var phase := 0
var next_pulse := 0.0

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	speaker=AudioStreamPlayer.new()
	speaker.name="StingerSeekerIndicator"
	speaker.volume_db=-13.0
	add_child(speaker)
	tones={
		"acquire":_tone(480.0,690.0,.15),
		"tracking":_tone(700.0,900.0,.11),
		"confirmed":_tone(1110.0,1360.0,.29,true),
		"locked":_tone(1120.0,1120.0,.15)
	}

func sync(current_target: String,progress: float,delta: float,enabled: bool) -> void:
	if not enabled or current_target.is_empty():
		target_id="";phase=0;next_pulse=0.0
		if is_instance_valid(speaker) and speaker.playing: speaker.stop()
		return
	if not is_instance_valid(speaker): return
	if current_target!=target_id:
		target_id=current_target
		phase=0
		next_pulse=0.0
	var wanted:=2 if progress>=1.0 else 1
	if wanted!=phase:
		phase=wanted
		speaker.stream=tones["confirmed" if phase==2 else "acquire"]
		speaker.play()
		next_pulse=.9 if phase==2 else .32
		return
	next_pulse-=delta
	if next_pulse<=0.0:
		speaker.stream=tones["locked" if phase==2 else "tracking"]
		speaker.play()
		next_pulse=.90 if phase==2 else lerpf(.34,.19,clampf(progress,0.,1.))

static func _tone(start_hz: float,end_hz: float,duration: float,double_chirp:=false) -> AudioStreamWAV:
	var count:=maxi(1,roundi(float(RATE)*duration))
	var pcm:=PackedByteArray()
	pcm.resize(count*2)
	var wave_phase:=0.0
	for index in count:
		var t:=float(index)/float(RATE)
		var unit:=t/duration
		var envelope:=minf(1.0,t/.012)*minf(1.0,(duration-t)/.022)
		if double_chirp and unit>.38 and unit<.52: envelope=0.0
		var hz:=lerpf(start_hz,end_hz,unit)
		wave_phase+=TAU*hz/float(RATE)
		var value:=roundi(sin(wave_phase)*clampf(envelope,0.0,1.0)*9600.0)
		pcm.encode_s16(index*2,value)
	var sound:=AudioStreamWAV.new()
	sound.format=AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate=RATE
	sound.stereo=false
	sound.data=pcm
	return sound
