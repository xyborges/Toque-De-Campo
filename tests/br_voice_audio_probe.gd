extends SceneTree
const CODEC=preload("res://scripts/voice/codec.gd")
const CLIENT=preload("res://scripts/voice/client.gd")
class Actor extends Node3D:
	var life_id:=1
	var hp:=100.
class Context extends Node3D:
	var allowed:=true
	var speaker: Node3D
	func voice_local_allowed() -> bool:return allowed
	func voice_speaker(_id: int) -> Node3D:return speaker
	func voice_muted(_id: int) -> bool:return false
	func voice_listener_position() -> Vector3:return Vector3.ZERO
var report: Dictionary={}

func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.max_fps=120
	root.title="Toque de Campo — voz local · verificação"
	var context:=Context.new();root.add_child(context)
	var camera:=Camera3D.new();context.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();camera.add_child(listener);listener.make_current()
	var actor:=Actor.new();actor.position=Vector3(3,0,-3);context.add_child(actor);context.speaker=actor
	var client:=CLIENT.new();context.add_child(client);client.configure(context);client.set_volume(0.)
	var encoder:=CODEC.encoder()
	if not is_instance_valid(encoder):finish({"ok":false,"codec":false});context.free();return
	encoder.call("set_dtx",false)
	# Let native window/renderer and codec startup settle before timing playout.
	# A startup frame over 120 ms deliberately resets the production generator.
	await create_timer(.4).timeout
	var began:=Time.get_ticks_usec()*.000001
	var previous:=began;var max_feed_gap:=0.
	for index in 80:
		while Time.get_ticks_usec()*.000001<began+index*.02:await process_frame
		var now:=Time.get_ticks_usec()*.000001;max_feed_gap=maxf(max_feed_gap,now-previous);previous=now
		var pcm:=PackedFloat32Array();pcm.resize(480)
		for i in pcm.size():pcm[i]=sin(float(index*480+i)*TAU*233./24000.)*.1
		var packet: PackedByteArray=encoder.call("encode",pcm)
		client.receive_frame(2,1,index+1,packet)
		await process_frame
	var speaker: Dictionary=client.speakers.get(2,{})
	var consumed:=0;var queued:=0;var skipped:=0;var attached:=false
	if not speaker.is_empty():
		var player:=speaker.player as AudioStreamPlayer3D
		attached=player.get_parent()==actor
		var playback:=player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback:queued=maxi(0,int(speaker.buffer_capacity)-playback.get_frames_available());skipped=playback.get_skips()
		consumed=int(speaker.queued_samples)-maxi(0,queued)
	var playback_stats:=client.stats()
	client.reset()
	var input:={"requested":false,"active_error":-1,"frames":0,"rate":0.,"resampled_samples":0,"stopped":true,"recorded":false,"transmitted":false}
	if "--probe-microphone" in OS.get_cmdline_user_args():
		input.requested=true
		var error:=AudioServer.set_input_device_active(true);input.active_error=error
		if error==OK:
			input.stopped=false
			await create_timer(.35).timeout
			input.rate=AudioServer.get_input_mix_rate()
			var frames:=AudioServer.get_input_frames_available();input.frames=frames
			var stereo:=AudioServer.get_input_frames(frames) if frames>0 else PackedVector2Array()
			AudioServer.set_input_device_active(false);input.stopped=true
			var mono:=PackedFloat32Array();mono.resize(stereo.size())
			for i in stereo.size():mono[i]=(stereo[i].x+stereo[i].y)*.5
			var resampler:=CODEC.resampler(int(input.rate))
			if resampler:input.resampled_samples=PackedFloat32Array(resampler.call("resample",mono)).size();CODEC.release(resampler)
			elif int(input.rate)==CODEC.SAMPLE_RATE:input.resampled_samples=mono.size()
			# Audio content is immediately discarded; only counts/rate retained.
			stereo=PackedVector2Array();mono=PackedFloat32Array()
	CODEC.release(encoder);context.allowed=false;client.reset();context.free();await process_frame
	finish({"ok":attached and consumed>24000 and int(playback_stats.playback_resets)==0 and bool(input.stopped),"version":ProjectSettings.get_setting("application/config/version"),"max_feed_gap_ms":max_feed_gap*1000.,"driver":AudioServer.get_driver_name(),"decoded_samples_consumed":consumed,"generator_queued_samples":queued,"generator_skips":skipped,"spatial_parent":attached,"stats":playback_stats,"input":input,"scope":"Synthetic silent spatial generator playback through actual audio driver after 400 ms native startup warmup; optional350ms mic buffer counts only, no mic encoding/listening/recording/transmission."})

func finish(value: Dictionary) -> void:
	NavalStorage.write_json("res://work/br-voice-audio-probe.json",value);print("BR_VOICE_AUDIO_PROBE ",JSON.stringify(value));quit(0 if value.get("ok",false) else 1)
