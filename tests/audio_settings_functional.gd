extends SceneTree

class Infantry extends "res://scripts/main.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _exit_tree() -> void:pass
class War extends WarGame:
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _exit_tree() -> void:pass
class Actor extends Node3D:
	var hp:=100.
	var life_id:=1
class Context extends Node3D:
	var actor: Actor
	var online:=false
	func voice_local_allowed() -> bool:return true
	func voice_speaker(_id: int) -> Node3D:return actor
	func voice_muted(_id: int) -> bool:return false
	func voice_listener_position() -> Vector3:return Vector3.ZERO

var checks:=0
var failures: Array[String]=[]
var measurements: Dictionary={}
var capture: AudioEffectCapture
var panel: GameAudioSettingsPanel
var probe: AudioStreamPlayer

func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func tone() -> AudioStreamWAV:
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=24000
	var bytes:=PackedByteArray();bytes.resize(4800)
	for i in 2400:bytes.encode_s16(i*2,int(sin(TAU*440*i/24000.)*3000))
	stream.data=bytes;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=2400
	return stream

func rms() -> float:
	var frames:=capture.get_buffer(capture.get_frames_available());var energy:=0.
	for frame in frames:energy+=frame.length_squared()
	return sqrt(energy/maxi(1,frames.size()))

func sample() -> float:
	await create_timer(.12).timeout;capture.clear_buffer()
	await create_timer(.16).timeout
	return rms()

func run() -> void:
	Engine.max_fps=120
	if DisplayServer.get_name()=="headless":
		check(false,"run with a native display to exercise production audio initialization");finish();return
	# Isolated profile only; never change the player's saved settings.
	NavalStorage.preference_account="audio-functional"
	NavalStorage.write_json(NavalStorage.settings_folder().path_join("audio-settings.json"),{"_schema":2})
	GameAudioSettings.loaded_path="";GameAudioSettings.ensure()
	panel=GameAudioSettingsPanel.new();root.add_child(panel)
	check(panel.sliders.size()==8,"all eight audio controls are present")
	capture=AudioEffectCapture.new();capture.buffer_length=2.;AudioServer.add_bus_effect(0,capture)
	probe=AudioStreamPlayer.new();probe.stream=tone();root.add_child(probe);probe.play()
	for category: String in GameAudioSettings.LABELS:
		if category=="Master":continue
		probe.bus="Armas" if category=="Efeitos" else category
		panel.sliders[category].value=100.;var full: float=await sample()
		panel.sliders[category].value=50.;var half: float=await sample()
		panel.sliders[category].value=0.;var muted: float=await sample()
		check(full>.0001,category+" reaches the output mixer")
		check(half/full>.46 and half/full<.54,category+" slider halves PCM amplitude at 50%")
		check(muted<.000001,category+" slider silences output at 0%")
		measurements[category]={"full_rms":full,"half_rms":half,"muted_rms":muted}
		panel.sliders[category].value=100.
	probe.bus="Interface"
	for percent in [100.,50.,0.]:
		panel.sliders.Master.value=percent;await create_timer(.15).timeout
		check(AudioServer.is_bus_mute(0)==(percent==0.),"master native mute at %d%%"%int(percent))
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),maxf(.001,percent/100.)),"master native gain at %d%%"%int(percent))
	panel.sliders.Master.value=100.;probe.stop()
	await preferences()
	await routes()
	await voice()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	panel.free();probe.free();finish()

func preferences() -> void:
	panel.sliders.Armas.value=37.;panel.sliders.Music.value=23.
	await create_timer(.45).timeout
	var stored:=NavalStorage.read_json(GameAudioSettings.loaded_path)
	check(is_equal_approx(float(stored.Armas),.37) and is_equal_approx(float(stored.Music),.23),"slider debounce persists category values")
	GameAudioSettings.loaded_path="";panel.refresh_values()
	check(is_equal_approx(panel.sliders.Armas.value,37.) and is_equal_approx(panel.sliders.Music.value,23.),"reopening restores saved sliders and mixer")
	NavalStorage.preference_account="audio-functional-other"
	NavalStorage.write_json(NavalStorage.settings_folder().path_join("audio-settings.json"),{"_schema":2,"Armas":.71})
	panel.refresh_values();check(is_equal_approx(panel.sliders.Armas.value,71.),"account change reapplies its own mixer preferences")
	NavalStorage.preference_account="audio-functional";panel.refresh_values()
	check(is_equal_approx(panel.sliders.Armas.value,37.),"return to previous account restores its audio")
	for category in panel.sliders:panel.sliders[category].value=100.
	GameAudioSettings.flush()

func routes() -> void:
	var game:=Infantry.new();root.add_child(game);game.world_root=Node3D.new();game.add_child(game.world_root)
	var camera:=Camera3D.new();camera.position=Vector3.UP;game.world_root.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();camera.add_child(listener);listener.make_current()
	game._play_death_sound(0,Vector3(0,0,-4))
	var death:=game.world_root.get_children().back() as AudioStreamPlayer3D
	check(death!=null and death.bus=="Efeitos","production player death routes through Efeitos")
	check(death.max_distance==55. and death.unit_size==4. and death.volume_db==-6.,"death profile remains 55 m / 4 m / -6 dB")
	var audible: float=await sample()
	check(audible>.00001,"supplied death WAV reaches the output mixer")
	GameAudioSettings.set_volume("Efeitos",0.);var silent: float=await sample()
	check(silent<.000001,"Efeitos=0 silences a playing death WAV")
	GameAudioSettings.set_volume("Efeitos",1.)
	if is_instance_valid(death):death.stop()
	var atmosphere:=EnvironmentAtmosphere.new();atmosphere.kind="qa";game.world_root.add_child(atmosphere)
	var ambient:=atmosphere.get_child(0) as AudioStreamPlayer
	check(ambient!=null and ambient.bus=="Ambiente","production atmosphere uses Ambiente")
	check(await sample()>.000001,"production ambient sound reaches mixer")
	GameAudioSettings.set_volume("Ambiente",0.);check(await sample()<.000001,"Ambiente=0 silences atmosphere")
	GameAudioSettings.set_volume("Ambiente",1.);atmosphere.free()
	var service:=NavalAccounts.new();var login:=GameLoginScreen.new();login.service=service;login.hide();root.add_child(login);login.set_process(false)
	check(login.ui_audio.bus=="Interface","production login sound uses Interface")
	login.ui_audio.stream=probe.stream;login.ui_audio.play()
	check(await sample()>.000001,"login feedback reaches mixer")
	GameAudioSettings.set_volume("Interface",0.);check(await sample()<.000001,"Interface=0 silences login feedback")
	GameAudioSettings.set_volume("Interface",1.);login.free();service.free()
	var war:=War.new();root.add_child(war);war._build_audio()
	check(war.music_player.bus=="Music" and war.sound_player.bus=="Efeitos","War shared players use their audio categories")
	war.free();game.free();await process_frame

func voice() -> void:
	GameOptions.set_value("voice_distance",8.);GameOptions.set_value("voice_clear_distance",1.);GameOptions.flush();GameOptions.path="";GameOptions.ensure()
	check(GameVoiceSettings.radius()==55. and not GameOptions.values.has("voice_distance") and not GameOptions.values.has("voice_clear_distance"),"legacy distance preferences cannot change voice range")
	GameVoiceSettings.set_option("voice_distance",8.);check(not GameOptions.values.has("voice_distance"),"removed voice option cannot be saved again")
	var voice_panel:=GameVoiceSettingsPanel.new();root.add_child(voice_panel)
	check(voice_panel.sliders.keys()==["voice_volume"],"voice panel exposes only the volume slider")
	var context:=Context.new();root.add_child(context)
	var camera:=Camera3D.new();context.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();context.add_child(listener);listener.make_current()
	context.actor=Actor.new();context.add_child(context.actor);context.actor.position=Vector3(0,0,-4)
	var client:=GameVoiceClient.new();context.add_child(client);client.configure(context);client.set_process(false)
	var relay:=BRVoiceRelay.new();context.add_child(relay);relay._acquire_bus();relay.set_process(false)
	relay.game=context;relay.client=client;voice_panel.relay=relay
	var encoder:=GameVoiceCodec.encoder();check(client.available() and encoder!=null,"native Opus codec is available without opening microphone")
	if encoder==null:voice_panel.free();context.free();return
	encoder.call("set_dtx",false)
	var pcm:=PackedFloat32Array();pcm.resize(GameVoiceCodec.SAMPLES)
	for i in pcm.size():pcm[i]=sin(float(i)*TAU*233./24000.)*.12
	var packet: PackedByteArray=encoder.call("encode",pcm)
	client.set_volume(1.);client.receive_frame(2,1,1,packet)
	var player:=client.speakers[2].player as AudioStreamPlayer3D
	check(player.max_distance==55. and player.unit_size==4. and player.volume_db==-6. and player.attenuation_model==AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,"VOIP uses the actual death sound spatial profile")
	# A steady synthetic source isolates profile, gain and distance in the real
	# production speaker. Codec jitter/lifecycle have separate regression tests.
	player.stream=probe.stream;player.play()
	var levels: Array[float]=[]
	for distance in [4.,28.,56.]:
		context.actor.position=Vector3(0,0,-distance);levels.append(await sample())
	check(levels[0]>.0001 and levels[1]>0. and levels[1]<levels[0]*.3 and levels[2]<.000001,"voice attenuates near / transition / beyond 55 m")
	context.actor.position=Vector3(0,0,-4);player.stop()
	# Keep actual per-frame volume code, without feeding a playback generator.
	client.simulation_only=true;client.speakers[2].last_at=Time.get_ticks_usec()*.000001
	voice_panel.sliders.voice_volume.value=50.;client._process(.01);player.play()
	var half: float=await sample()
	check(half/levels[0]>.46 and half/levels[0]<.54,"VOIP volume control halves PCM at 50%")
	client.speakers[2].last_at=Time.get_ticks_usec()*.000001;voice_panel.sliders.voice_volume.value=0.;client._process(.01)
	check(await sample()<.000001,"VOIP volume 0% is silent")
	GameAudioSettings.set_volume("Master",0.);check(AudioServer.is_bus_mute(0) and AudioServer.get_bus_send(AudioServer.get_bus_index(player.bus))=="Master","VOIP is governed by the master bus")
	GameAudioSettings.set_volume("Master",1.)
	context.actor.position=Vector3(0,0,-56.);client.receive_frame(2,1,2,packet)
	check(client.speakers.is_empty(),"client removes a speaker beyond the fixed range")
	measurements.voice={"near_rms":levels[0],"transition_rms":levels[1],"far_rms":levels[2],"half_rms":half}
	GameVoiceSettings.set_option("voice_volume",.33);voice_panel._refresh()
	check(is_equal_approx(voice_panel.sliders.voice_volume.value,33.),"voice volume preference restores into panel")
	voice_panel.toggle.button_pressed=false;check(not client.enabled and client.speakers.is_empty(),"voice toggle disables the actual client and clears playback")
	voice_panel.toggle.button_pressed=true;check(client.enabled,"voice toggle enables the actual client")
	check(not client.input_active,"audio validation never activated microphone")
	GameVoiceCodec.release(encoder);voice_panel.free();context.free();await process_frame

func finish() -> void:
	var sources: Dictionary={}
	for path in ["scripts/audio_settings.gd","scripts/main.gd","scripts/voice/client.gd","scripts/voice/settings_panel.gd","modes/battle_royale/voice/relay.gd","modes/war/scripts/game.gd","modes/war/scripts/rules.gd"]:sources[path]=FileAccess.get_file_as_string("res://"+path).sha256_text()
	var report:={"ok":failures.is_empty(),"version":ProjectSettings.get_setting("application/config/version"),"source_sha256":sources,"checks":checks,"failures":failures,"driver":AudioServer.get_driver_name(),"measurements":measurements,"scope":"Native output mixer captures for seven category sliders (100/50/0%), native master gain/mute, saved/reloaded/account-isolated preferences, production death/ambient/login routes and fixed VOIP profile at near/transition/far distances; voice volume/toggle through the actual UI and relay; native Opus initialization without microphone capture. Master capture occurs before its gain; master checked through native gain/mute API."}
	NavalStorage.write_json("res://work/audio-settings-functional.json",report);print("AUDIO_SETTINGS_FUNCTIONAL ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
