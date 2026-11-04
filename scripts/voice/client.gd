extends Node
class_name GameVoiceClient

signal encoded_frame(sequence: int,packet: PackedByteArray)
signal transmitting_changed(value: bool)
signal availability_changed(value: bool,message: String)
const MAX_SPEAKERS:=6
# AudioServer owns one process-wide input buffer. A settings monitor and a
# match client must never drain or deactivate each other's microphone.
static var capture_owner: WeakRef
var capture_attempt: Dictionary={}
var last_capture: Dictionary={}
var attempt_serial:=0
var device_poll:=0.
var capture_restarts:=0
var last_input_at:=0

var context: Node
var enabled:=true
var volume:=1.
var microphone_testing:=false
var test_frames:=0
var test_peak:=0.
var transmitting:=false
var sequence:=0
var speakers: Dictionary={}
var encoder: Object
var input_resampler: Object
var input_rate:=0
var accumulator:=PackedFloat32Array()
var current_device:="Default"
var requested_device:="Default"
var input_active:=false
var failed_until_release:=false
var microphone_error:=""
var meter:=0.
var simulation_only:=false
var closed:=false
var diagnostic:={"input_frames":0,"input_peak":0.,"encoded":0,"sent_bytes":0,"capture_discarded":0,"capture_peak_ms":0.,"playback_resets":0,"decode_rejected":0,"speaker_evictions":0}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name()=="headless" and not simulation_only:set_process(false)

func configure(value: Node) -> void:
	closed=false;enabled=true;set_process(true)
	context=value
	if DisplayServer.get_name()=="headless" and not simulation_only:set_process(false);return
	encoder=GameVoiceCodec.encoder()
	availability_changed.emit(is_instance_valid(encoder),status())

func available() -> bool:
	return is_instance_valid(encoder)

func status() -> String:
	return microphone_error if not microphone_error.is_empty() else ("" if available() else "Voz indisponível")

func set_enabled(value: bool) -> void:
	if enabled==value:return
	enabled=value
	if not value:reset()

func set_volume(value: float) -> void:
	volume=clampf(value,0.,1.)

func _audio_devices() -> PackedStringArray:return AudioServer.get_input_device_list()
func _audio_device() -> String:return AudioServer.input_device
func _audio_set_device(value: String) -> void:AudioServer.input_device=value
func _audio_activate(value: bool) -> Error:return AudioServer.set_input_device_active(value)
func _audio_rate() -> int:return int(AudioServer.get_input_mix_rate())
func _audio_available() -> int:return AudioServer.get_input_frames_available()
func _audio_read(count: int) -> PackedVector2Array:return AudioServer.get_input_frames(count)

static func _owner() -> GameVoiceClient:
	return capture_owner.get_ref() as GameVoiceClient if capture_owner!=null else null

func set_input_device(value: String) -> void:
	if value==requested_device:return
	var active:=transmitting;var testing_now:=microphone_testing
	set_transmitting(false);stop_microphone_test()
	requested_device=value;current_device=value if value in _audio_devices() else "Default"
	# A non-owner changing preferences must not switch another active capture.
	if _owner()==null:_audio_set_device(current_device)
	if testing_now:start_microphone_test(false)
	elif active:set_transmitting(true)

func input_devices() -> PackedStringArray:return _audio_devices()

func _acquire_capture(testing_now: bool) -> bool:
	var previous:=_owner()
	if is_instance_valid(previous) and previous!=self:
		if previous.microphone_testing and not testing_now:return false
		previous.set_transmitting(false);previous.stop_microphone_test()
	capture_owner=weakref(self);return true

func _begin_capture(kind: String) -> bool:
	attempt_serial+=1;capture_restarts=0;device_poll=0.
	capture_attempt={"attempt":attempt_serial,"kind":kind,"requested_device":requested_device,"device":current_device,"rate":0,"frames":0,"peak_left":0.,"peak_right":0.,"peak_mono":0.,"encoded":0,"bytes":0,"discarded":0,"channel_fallbacks":0,"opened":false,"signal":false,"restarts":0}
	return _open_capture()

func _open_capture() -> bool:
	current_device=requested_device if requested_device in _audio_devices() else "Default"
	_audio_set_device(current_device)
	var error:=_audio_activate(true)
	input_active=error==OK
	capture_attempt.device=_audio_device();capture_attempt.result=error_string(error);capture_attempt.opened=input_active
	if not input_active:
		microphone_error="Microfone indisponível. Verifique as permissões."
		_release_capture();GameDiagnostics.record("microphone_capture_failed",capture_attempt);return false
	input_rate=maxi(1,_audio_rate());capture_attempt.rate=input_rate
	microphone_error="";last_input_at=Time.get_ticks_msec();_flush_input()
	GameVoiceCodec.release(input_resampler);input_resampler=null
	if str(capture_attempt.kind)=="voice":
		input_resampler=GameVoiceCodec.resampler(input_rate)
		if input_rate!=GameVoiceCodec.SAMPLE_RATE and not is_instance_valid(input_resampler):
			microphone_error="Microfone indisponível";_release_capture();return false
	return true

func _release_capture() -> void:
	if _owner()==self:
		if input_active:_flush_input();_audio_activate(false)
		capture_owner=null
	input_active=false
	GameVoiceCodec.release(input_resampler);input_resampler=null

func _finish_capture(event: String) -> void:
	if not capture_attempt.is_empty():
		last_capture=capture_attempt.duplicate(true);last_capture.elapsed_ms=Time.get_ticks_msec()-int(capture_attempt.get("started_ms",Time.get_ticks_msec()))
		GameDiagnostics.record(event,last_capture)
	_release_capture()

func _check_capture_device(delta: float) -> void:
	if not input_active or _owner()!=self:return
	device_poll+=delta
	if device_poll<.5:return
	device_poll=0.
	var missing:=current_device!="Default" and current_device not in _audio_devices()
	var changed:=_audio_device()!=current_device or _audio_rate()!=input_rate
	var stalled:=Time.get_ticks_msec()-last_input_at>2000
	if not missing and not changed and not stalled:return
	GameDiagnostics.record("microphone_device_changed",{"device":current_device,"missing":missing,"changed":changed,"stalled":stalled,"attempt":attempt_serial})
	if capture_restarts>=1:
		microphone_error="Microfone desconectado. Selecione o dispositivo novamente."
		set_transmitting(false);stop_microphone_test();return
	capture_restarts+=1;capture_attempt.restarts=capture_restarts
	# Keep the lease while reopening. Never forward samples from the old input.
	_flush_input();_audio_activate(false);input_active=false;accumulator=PackedFloat32Array()
	if not _open_capture():
		transmitting=false;microphone_testing=false;transmitting_changed.emit(false)


func _allowed() -> bool:
	return not closed and enabled and is_instance_valid(context) and context.has_method("voice_local_allowed") and bool(context.call("voice_local_allowed"))

func set_transmitting(value: bool) -> void:
	if not value:failed_until_release=false
	elif failed_until_release:return
	value=value and not microphone_testing and _allowed() and available()
	if value==transmitting:return
	accumulator=PackedFloat32Array();meter=0.
	if value:
		if simulation_only:transmitting=true;transmitting_changed.emit(true);return
		if not _acquire_capture(false):return
		if not _begin_capture("voice"):
			failed_until_release=true;availability_changed.emit(false,microphone_error);return
		capture_attempt.started_ms=Time.get_ticks_msec()
		encoder.call("reset")
		GameDiagnostics.record("voice_capture_started",capture_attempt)
	elif input_active:_finish_capture("voice_capture_stopped")
	transmitting=value;transmitting_changed.emit(value)

func start_microphone_test(use_preferences:=true) -> bool:
	if closed:return false
	set_transmitting(false);stop_microphone_test()
	if use_preferences:requested_device=GameVoiceSettings.input_device()
	if not _acquire_capture(true) or not _begin_capture("test"):return false
	capture_attempt.started_ms=Time.get_ticks_msec()
	microphone_testing=true;test_frames=0;test_peak=0.;meter=0.
	GameDiagnostics.record("microphone_test",capture_attempt);return true

func stop_microphone_test() -> void:
	if not microphone_testing:return
	microphone_testing=false;_finish_capture("microphone_test_result")

func _flush_input() -> void:
	var count:=_audio_available()
	if count>0:_audio_read(count)

func _capture() -> void:
	if not input_active or _owner()!=self:return
	var count:=_audio_available()
	if count<=0:return
	last_input_at=Time.get_ticks_msec()
	var limit:=maxi(1,input_rate/10)
	if count>limit:
		_audio_read(count-limit);diagnostic.capture_discarded+=count-limit;capture_attempt.discarded+=count-limit;count=limit;accumulator=PackedFloat32Array()
	_consume_stereo(_audio_read(count))

func _consume_stereo(stereo: PackedVector2Array) -> void:
	if stereo.is_empty():return
	var left:=0.;var right:=0.;var sum:=0.
	for sample in stereo:
		left+=sample.x*sample.x;right+=sample.y*sample.y;sum+=pow((sample.x+sample.y)*.5,2)
	# Some microphone drivers expose one live channel or opposite polarity.
	# Preserve that signal instead of cancelling it during the mono downmix.
	var stronger:=maxf(left,right)
	var fallback:=stronger>.000001 and (minf(left,right)<stronger*.02 or sum<stronger*.05)
	var mono:=PackedFloat32Array();mono.resize(stereo.size())
	var energy:=0.
	for i in stereo.size():
		var sample:=stereo[i]
		mono[i]=clampf((sample.x if left>=right else sample.y) if fallback else (sample.x+sample.y)*.5,-1.,1.)
		energy+=mono[i]*mono[i]
		capture_attempt.peak_left=maxf(float(capture_attempt.peak_left),absf(sample.x));capture_attempt.peak_right=maxf(float(capture_attempt.peak_right),absf(sample.y));capture_attempt.peak_mono=maxf(float(capture_attempt.peak_mono),absf(mono[i]))
	capture_attempt.frames+=mono.size();capture_attempt.signal=bool(capture_attempt.signal) or sqrt(energy/mono.size())>.002
	if fallback:capture_attempt.channel_fallbacks+=1
	if microphone_testing:
		meter=sqrt(energy/mono.size());test_peak=maxf(test_peak,meter);test_frames+=mono.size();return
	diagnostic.input_frames+=mono.size()
	for sample in mono:diagnostic.input_peak=maxf(float(diagnostic.input_peak),absf(sample))
	if is_instance_valid(input_resampler):mono=input_resampler.call("resample",mono)
	feed_pcm(mono)

func feed_pcm(pcm: PackedFloat32Array) -> void:
	# Also used by deterministic tests; never writes or stores recordings.
	if not transmitting or not _allowed() or not available():return
	accumulator.append_array(pcm)
	diagnostic.capture_peak_ms=maxf(float(diagnostic.capture_peak_ms),accumulator.size()*1000./GameVoiceCodec.SAMPLE_RATE)
	if accumulator.size()>GameVoiceCodec.SAMPLES*5:
		diagnostic.capture_discarded+=accumulator.size()-GameVoiceCodec.SAMPLES*2
		accumulator=accumulator.slice(accumulator.size()-GameVoiceCodec.SAMPLES*2)
	var budget:=3
	while accumulator.size()>=GameVoiceCodec.SAMPLES and budget>0:
		var frame:=accumulator.slice(0,GameVoiceCodec.SAMPLES);accumulator=accumulator.slice(GameVoiceCodec.SAMPLES)
		var energy:=0.
		for sample in frame:energy+=sample*sample
		meter=sqrt(energy/GameVoiceCodec.SAMPLES)
		var packet: PackedByteArray=encoder.call("encode",frame)
		if not packet.is_empty() and packet.size()<=GameVoiceCodec.MAX_PACKET and not bool(encoder.call("is_in_dtx")):
			sequence+=1;diagnostic.encoded+=1;diagnostic.sent_bytes+=packet.size()
			if not capture_attempt.is_empty():capture_attempt.encoded+=1;capture_attempt.bytes+=packet.size()
			encoded_frame.emit(sequence,packet)
		budget-=1

func _local_position() -> Vector3:
	if is_instance_valid(context) and context.has_method("voice_listener_position"):return context.call("voice_listener_position")
	var game: Variant=context.get("game") if is_instance_valid(context) else null
	if is_instance_valid(game) and is_instance_valid(game.local_player):return game.local_player.global_position
	return Vector3.INF

func _speaker(id: int) -> Node3D:
	return context.call("voice_speaker",id) as Node3D if is_instance_valid(context) and context.has_method("voice_speaker") else null

func receive_frame(id: int,life: int,packet_sequence: int,packet: PackedByteArray) -> void:
	if not enabled or not available() or not _allowed() or packet.size()>GameVoiceCodec.MAX_PACKET or packet.is_empty():return
	if not GameVoiceCodec.valid_packet(packet):diagnostic.decode_rejected+=1;return
	if context.has_method("voice_muted") and bool(context.call("voice_muted",id)):remove_speaker(id);return
	var actor:=_speaker(id)
	if not actor or int(actor.get("life_id"))!=life or float(actor.get("hp"))<=0:return
	var distance:=_local_position().distance_to(actor.global_position)
	if distance>GameVoiceSettings.radius():remove_speaker(id);return
	if speakers.has(id) and int(speakers[id].life)!=life:remove_speaker(id)
	if not speakers.has(id):
		if speakers.size()>=MAX_SPEAKERS:
			var farthest:=-1;var farthest_distance:=distance
			for other in speakers:
				var source:=_speaker(int(other))
				var d:=_local_position().distance_to(source.global_position) if source else INF
				if d>farthest_distance:farthest=int(other);farthest_distance=d
			if farthest<0:return
			remove_speaker(farthest);diagnostic.speaker_evictions+=1
		var decoder:=GameVoiceCodec.decoder()
		if not is_instance_valid(decoder):return
		var jitter:=GameVoiceJitter.new();jitter.configure(decoder)
		var player:=AudioStreamPlayer3D.new();player.name="ProximityVoice"
		var stream:=AudioStreamGenerator.new();stream.mix_rate=GameVoiceCodec.SAMPLE_RATE;stream.buffer_length=.12;player.stream=stream
		player.bus="Voice" if AudioServer.get_bus_index("Voice")>=0 else "Master"
		GameCombatAudioCatalog.apply_player_voice_profile(player)
		player.panning_strength=1.1
		player.volume_db+=linear_to_db(volume) if volume>0. else -INF
		player.attenuation_filter_cutoff_hz=20000
		var head_anchor:=actor.get("camera_pivot") as Node3D
		if is_instance_valid(head_anchor):head_anchor.add_child(player);player.position=Vector3.ZERO
		else:actor.add_child(player);player.position=Vector3(0,1.55,0)
		speakers[id]={"life":life,"decoder":decoder,"jitter":jitter,"player":player,"last_at":Time.get_ticks_usec()*.000001,"queued_samples":0,"playback_skips":0,"buffer_capacity":0,"pending":[]}
	var speaker: Dictionary=speakers[id]
	speaker.last_at=Time.get_ticks_usec()*.000001
	if not speaker.jitter.push(packet_sequence,packet,speaker.last_at):diagnostic.decode_rejected+=1

func _process(delta: float) -> void:
	_check_capture_device(delta)
	if microphone_testing:_capture();return
	if not _allowed():
		if transmitting:set_transmitting(false)
		for id in speakers.keys():remove_speaker(int(id))
		return
	if transmitting:_capture()
	var now:=Time.get_ticks_usec()*.000001
	for id in speakers.keys():
		var actor:=_speaker(int(id));var speaker: Dictionary=speakers[id]
		if not actor or float(actor.get("hp"))<=0 or int(actor.get("life_id"))!=int(speaker.life) or now-float(speaker.last_at)>.45 or (context.has_method("voice_muted") and context.call("voice_muted",id)):
			remove_speaker(int(id));continue
		var distance:=_local_position().distance_to(actor.global_position)
		if distance>GameVoiceSettings.radius():remove_speaker(int(id));continue
		var player: AudioStreamPlayer3D=speaker.player
		if not is_instance_valid(player):remove_speaker(int(id));continue
		if delta>.12:
			player.stop();speaker.pending.clear();diagnostic.playback_resets+=1
		player.volume_db=GameCombatAudioCatalog.PLAYER_VOICE_VOLUME_DB+(linear_to_db(volume) if volume>0. else -INF)
		var jitter: GameVoiceJitter=speaker.jitter
		if not jitter.started and jitter.expected<0 and player.playing and speaker.pending.is_empty():
			var idle_playback:=player.get_stream_playback() as AudioStreamGeneratorPlayback
			if idle_playback and idle_playback.get_frames_available()>=int(speaker.buffer_capacity)-1:player.stop()
		for step in 3:
			var pcm:=jitter.pull(now)
			if pcm.is_empty():break
			if simulation_only:continue
			speaker.pending.append(pcm)
			# Keep the network jitter target60ms. Prime the generator separately
			# with three decoded frames so its first audio mix cannot underrun.
			if not player.playing and speaker.pending.size()<3:continue
			if not player.playing:player.play()
			var playback:=player.get_stream_playback() as AudioStreamGeneratorPlayback
			if not playback:break
			speaker.buffer_capacity=maxi(int(speaker.buffer_capacity),playback.get_frames_available())
			for queued: PackedFloat32Array in speaker.pending:
				if playback.get_frames_available()<queued.size():
					player.stop();player.play();playback=player.get_stream_playback();diagnostic.playback_resets+=1
				var stereo:=PackedVector2Array();stereo.resize(queued.size())
				for i in queued.size():stereo[i]=Vector2(queued[i],queued[i])
				playback.push_buffer(stereo);speaker.queued_samples+=queued.size();speaker.playback_skips=playback.get_skips()
			speaker.pending.clear()

func remove_speaker(id: int) -> void:
	if not speakers.has(id):return
	var speaker: Dictionary=speakers[id]
	if is_instance_valid(speaker.player):speaker.player.stop();speaker.player.queue_free()
	GameVoiceCodec.release(speaker.decoder);speakers.erase(id)

func reset() -> void:
	set_transmitting(false);accumulator=PackedFloat32Array()
	for id in speakers.keys():remove_speaker(int(id))

func shutdown() -> void:
	# Round reset can reuse the encoder; leaving a room releases every native
	# audio object immediately and blocks late frames until a new configure.
	if closed:return
	stop_microphone_test()
	closed=true;reset();enabled=false;set_process(false);context=null
	GameVoiceCodec.release(encoder);GameVoiceCodec.release(input_resampler);encoder=null;input_resampler=null

func stats() -> Dictionary:
	var result:=diagnostic.duplicate();result.capture_attempt=capture_attempt.duplicate(true);result.last_capture=last_capture.duplicate(true);result.active_speakers=speakers.size();result.capture_queued_ms=accumulator.size()*1000./GameVoiceCodec.SAMPLE_RATE;result.speakers={}
	for id in speakers:
		var row: Dictionary=speakers[id];var peer_stats: Dictionary=row.jitter.stats()
		var player:=row.player as AudioStreamPlayer3D
		var playback:=player.get_stream_playback() as AudioStreamGeneratorPlayback if is_instance_valid(player) and player.playing else null
		peer_stats.output_queued_ms=maxi(0,int(row.buffer_capacity)-playback.get_frames_available())*1000./GameVoiceCodec.SAMPLE_RATE if playback else 0.
		peer_stats.playback_skips=row.playback_skips;result.speakers[id]=peer_stats
	return result

func _exit_tree() -> void:
	shutdown()
