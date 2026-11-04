extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(700,220)
	var label:=Label.new();label.text="Prepare-se: teste de microfone em 3 segundos";label.position=Vector2(30,65);label.add_theme_font_size_override("font_size",23);root.add_child(label)
	await create_timer(3.).timeout
	label.text="FALE AGORA · teste de 8 segundos"
	var monitor:=GameVoiceClient.new();root.add_child(monitor);monitor.set_process(false)
	var opened:=monitor.start_microphone_test()
	if opened:
		var began:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-began<8000:
			monitor._check_capture_device(.02);monitor._capture()
			label.text="FALE AGORA · %d segundos · nível %.4f"%[8-(Time.get_ticks_msec()-began)/1000,monitor.test_peak]
			await create_timer(.02).timeout
		monitor.stop_microphone_test()
	var report:={"device_opened":opened,"capture":monitor.last_capture,"error":monitor.microphone_error,"signal_detected":bool(monitor.last_capture.get("signal",false)),"recording":false,"transmission":false,"scope":"Eight seconds of physical microphone capture; stores scalar levels/counts only. Signal detection does not prove speech intelligibility or network voice delivery."}
	NavalStorage.write_json("res://work/voice-capture1103-physical.json",report);print(JSON.stringify(report));monitor.shutdown();monitor.free();await process_frame;quit(0 if opened else 1)
