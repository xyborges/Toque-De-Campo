extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var panel:=GameVoiceSettingsPanel.new();root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel._toggle_test()
	await create_timer(8.5).timeout
	var monitor:=panel.monitor
	var report:={"capture_started":is_instance_valid(monitor) and monitor.test_frames>0,"frames":monitor.test_frames if monitor else 0,"peak":monitor.test_peak if monitor else 0.,"devices":Array(AudioServer.get_input_device_list()),"selected":GameVoiceSettings.input_device(),"status":monitor.status() if monitor else "No monitor","scope":"Actual Windows settings microphone-test button and AudioServer capture. Only frame count and level retained; no recording, speech recognition or transmission. A silent room cannot confirm intelligibility."}
	if monitor:report.no_network_encoder=monitor.encoder==null
	panel._stop_test()
	if monitor:report.capture_closed=not monitor.input_active and not monitor.microphone_testing
	NavalStorage.write_json("res://work/revision-1102-microphone.json",report);print("MICROPHONE_1102 ",JSON.stringify(report))
	panel.free();await process_frame;quit()
