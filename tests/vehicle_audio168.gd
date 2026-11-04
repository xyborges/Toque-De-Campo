extends SceneTree
var game: WarGame
var checks:=0
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func signal_metrics(frames: PackedVector2Array) -> Dictionary:
	var energy:=0.;var peak:=0.;var difference:=0.;var previous:=Vector2.ZERO
	for sample in frames:
		energy+=sample.length_squared();difference+=(sample-previous).length_squared();previous=sample;peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	return {"rms":sqrt(energy/maxi(1,frames.size())),"peak":peak,"brightness":sqrt(difference/maxf(.0000001,energy)),"frames":frames.size()}
func run() -> void:
	game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	var manager:=game.vehicle_system as WarVehicles;manager.set_process(false)
	game.combat_audio=WarAudio.new();game.world_root.add_child(game.combat_audio)
	game.soundscape=WarSoundscape.new();game.soundscape.game=game;game.world_root.add_child(game.soundscape);game.soundscape.set_process(false);game.soundscape.ambient_at=1e9
	var sound:=game.soundscape as WarSoundscape
	for voice: AudioStreamPlayer3D in sound.loops.values(): voice.stop()
	var actor:=game.local_player as WarPlayer
	var bus:=AudioServer.get_bus_index("Veiculos");var capture:=AudioEffectCapture.new();capture.buffer_length=2.;AudioServer.add_bus_effect(bus,capture)
	var fingerprints: Dictionary={}
	for kind in WarRules.VEHICLES:
		var vehicle:=manager.vehicles["v_"+str(kind)] as WarVehicle;vehicle.position=Vector3(0,10,0);vehicle.allocate_seat(1)
		actor.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id;actor.apply_identity(vehicle.team,"soldier");game.members[1].team=vehicle.team
		manager.last_controlled="";manager._process(.1);manager.vehicle_view.external=true;manager._process(.1)
		manager.tv_listener.make_current();manager.camera.position=vehicle.position+Vector3(5,3,3)
		var listener:=GameWeaponAudio.listener_position(root)
		vehicle.speed=0;sound._process(.11)
		var engine:=sound.loops[vehicle.vehicle_id+":engine"] as AudioStreamPlayer3D
		var servo:=sound.loops[vehicle.vehicle_id+":servo"] as AudioStreamPlayer3D
		var rolling:=sound.loops[vehicle.vehicle_id+":rolling"] as AudioStreamPlayer3D
		check(float(rolling.get_meta("base_db"))==-60,"rolling is silent when stationary: "+str(kind))
		vehicle.speed=10;vehicle.gun_pitch+=.08;sound._process(.11)
		check(float(servo.get_meta("base_db"))>-50,"vertical gun elevation drives servo sound: "+str(kind))
		check(float(rolling.get_meta("base_db"))>-40 and engine.pitch_scale>.85 and engine.pitch_scale<1.20,"speed drives rolling gain and engine pitch: "+str(kind))
		for item in [engine,rolling,servo]:
			var stream:=item.stream as AudioStreamWAV
			check(stream!=null and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.get_length()>1.9,"seamless original loop loaded: "+item.stream.resource_path)
			var hash_value:=hash(stream.data);check(not fingerprints.has(hash_value),"vehicle sound has unique PCM data: "+str(kind));fingerprints[hash_value]=true
		await create_timer(.6).timeout;capture.clear_buffer();await create_timer(.35).timeout
		var metric:=signal_metrics(capture.get_buffer(capture.get_frames_available()));metric.kind=kind;measurements.append(metric)
		check(float(metric.rms)>.0001 and float(metric.peak)<1,"actual vehicle loop is audible and below clipping: "+str(kind))
		vehicle.clear_seats();vehicle.speed=0;actor.vehicle_id="";game.members[1].vehicle=""
		for voice: AudioStreamPlayer3D in sound.loops.values(): voice.stop()
	var vehicle:=manager.vehicles.v_abrams as WarVehicle;vehicle.allocate_seat(1);actor.vehicle_id=vehicle.vehicle_id;game.members[1].vehicle=vehicle.vehicle_id
	actor.apply_identity(0,"soldier");game.members[1].team=0;manager.last_controlled="";manager._process(.1)
	var listener:=GameWeaponAudio.listener_position(root)
	var voice:=game.combat_audio.play(4,"fal",listener+Vector3(0,0,-10))
	sound._process(.11);sound._update_acoustics(listener,1.)
	check(sound.operator_optic and voice.bus=="WarCabinWeapons","operator FPP uses a dedicated muffled shot route")
	var filter:=AudioServer.get_bus_effect(AudioServer.get_bus_index("WarCabinWeapons"),0) as AudioEffectLowPassFilter
	check(filter.cutoff_hz==1800 and AudioServer.get_bus_send(AudioServer.get_bus_index("WarCabinWeapons"))=="WeaponShots","cabin filter feeds existing shared shot limiter once")
	manager.vehicle_view.external=true;sound._process(.11);sound._update_acoustics(listener,1.)
	check(not sound.operator_optic and voice.bus!="WarCabinWeapons","external operator camera removes extra cabin filtering")
	vehicle.vacate_seat(1,false);vehicle.allocate_seat(2);vehicle.allocate_seat(1);sound._process(.11);sound._update_acoustics(listener,1.)
	check(not sound.operator_optic and sound.cabin and voice.bus=="WeaponInterior","passenger retains its previous interior audio behavior")
	check(sound.loops.size()<=16,"fixed three-loop budget per vehicle, plus existing ambience")
	print("AUDIO_METRICS ",JSON.stringify(measurements))
	NavalStorage.write_json("res://tests/vehicle-audio168-results.json",{"checks":checks,"failures":failures,"measurements":measurements})
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
