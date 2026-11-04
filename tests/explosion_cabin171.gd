extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new();root.add_child(game);await process_frame
	if not is_instance_valid(game.combat_audio): game.combat_audio=WarAudio.new();game.world_root.add_child(game.combat_audio)
	if not is_instance_valid(game.soundscape): game.soundscape=WarSoundscape.new();game.soundscape.game=game;game.world_root.add_child(game.soundscape)
	var actor:=game.local_player as WarPlayer;var manager:=game.vehicle_system as WarVehicles
	var apc:=manager.vehicles.v_guarani as WarVehicle;apc.allocate_seat(actor.peer_id);actor.vehicle_id=apc.vehicle_id
	game.members[actor.peer_id].vehicle=apc.vehicle_id;manager.vehicle_view.external=false
	var listener:=GameWeaponAudio.listener_position(root)
	var voice:=game.combat_audio.explosion_audio.play_event("cabin171",listener+Vector3(1,0,0))
	for i in 3: game.soundscape._process(.12)
	if not is_instance_valid(voice) or not game.soundscape.operator_optic or voice.bus!="WarCabinWeapons" or voice.volume_db>-15: failures.append("vehicle FPP failed to muffle the real pooled explosion")
	var result:={"failures":failures,"bus":voice.bus if is_instance_valid(voice) else "none","gain_db":voice.volume_db if is_instance_valid(voice) else 0,"operator_optic":game.soundscape.operator_optic}
	NavalStorage.write_json("res://tests/explosion-cabin171-results.json",result);print(JSON.stringify(result));game.show_menu();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
