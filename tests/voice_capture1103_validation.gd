extends SceneTree
class FakeEncoder extends RefCounted:
	func reset() -> void:pass
class Capture extends GameVoiceClient:
	static var hardware_device:="Default"
	static var hardware_active:=false
	var device_list:=PackedStringArray(["Default","Integrated","USB"])
	var activation: Array[bool]=[]
	var queued:=PackedVector2Array()
	func _audio_devices() -> PackedStringArray:return device_list
	func _audio_device() -> String:return hardware_device
	func _audio_set_device(value: String) -> void:hardware_device=value
	func _audio_activate(value: bool) -> Error:hardware_active=value;activation.append(value);return OK
	func _audio_rate() -> int:return 24000
	func _audio_available() -> int:return queued.size()
	func _audio_read(count: int) -> PackedVector2Array:
		var result:=queued.slice(0,count);queued=queued.slice(count);return result
	func _allowed() -> bool:return true
	func available() -> bool:return true
var checks:=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
	print(("PASS " if value else "FAIL ")+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var voice:=Capture.new();root.add_child(voice);voice.encoder=FakeEncoder.new();voice.set_process(false)
	var monitor:=Capture.new();root.add_child(monitor);monitor.set_process(false)
	voice.set_input_device("Integrated");voice.set_transmitting(true)
	check(voice.transmitting and voice.input_active and Capture.hardware_active,"push-to-talk acquires exclusive microphone")
	monitor.set_input_device("USB")
	check(Capture.hardware_device=="Integrated" and voice.input_active,"inactive settings monitor cannot switch live input")
	check(monitor.start_microphone_test(false),"microphone test opens selected device")
	check(not voice.transmitting and not voice.input_active and monitor.input_active and Capture.hardware_device=="USB","test stops voice owner before taking capture")
	var before:=voice.activation.size();voice.set_transmitting(true)
	check(not voice.transmitting and voice.activation.size()==before and Capture.hardware_active,"PTT cannot steal active microphone test")
	var anti:=PackedVector2Array()
	for i in 480:anti.append(Vector2(.2,-.2))
	monitor._consume_stereo(anti)
	check(monitor.test_peak>.19 and bool(monitor.capture_attempt.signal),"opposite polarity retains audible mono signal")
	check(float(monitor.capture_attempt.peak_left)>.19 and float(monitor.capture_attempt.peak_right)>.19 and int(monitor.capture_attempt.channel_fallbacks)==1,"left and right levels plus mono fallback recorded")
	monitor.set_input_device("Integrated")
	check(monitor.microphone_testing and monitor.input_active and monitor.test_frames==0 and int(monitor.capture_attempt.frames)==0,"device change closes and reopens test with fresh attempt counters")
	var silent:=PackedVector2Array();silent.resize(480);monitor._consume_stereo(silent)
	monitor.stop_microphone_test()
	check(bool(monitor.last_capture.opened) and not bool(monitor.last_capture.signal) and int(monitor.last_capture.frames)==480,"open but silent device distinguished from detected signal")
	check(not Capture.hardware_active and GameVoiceClient._owner()==null,"test closes microphone and releases global ownership")
	voice.set_transmitting(true);voice.capture_attempt.frames=70;voice.set_transmitting(false);voice.set_transmitting(true)
	check(int(voice.capture_attempt.frames)==0 and int(voice.capture_attempt.encoded)==0 and int(voice.capture_attempt.bytes)==0,"each PTT attempt resets capture counters")
	voice.device_list=PackedStringArray(["Default","USB"]);voice._check_capture_device(.5)
	check(voice.current_device=="Default" and voice.input_active and int(voice.capture_attempt.restarts)==1,"removed device reopens default input once")
	voice.last_input_at=Time.get_ticks_msec()-2100;voice._check_capture_device(.5)
	check(not voice.input_active and not voice.transmitting and not voice.status().is_empty(),"repeated capture loss stops cleanly without restart loop")
	voice.set_transmitting(true);voice.shutdown();monitor.shutdown()
	check(not Capture.hardware_active and GameVoiceClient._owner()==null,"room shutdown releases microphone")
	voice.free();monitor.free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"physical_microphone_opened":false,"recording":false,"scope":"Mock AudioServer boundary; real ownership/device/capture control, synthetic stereo levels, per-attempt counters and shutdown. Does not establish physical notebook microphone speech capture."}
	NavalStorage.write_json("res://work/voice-capture1103-validation.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
