extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: errors.append(label)
func force_scan(game: WarGame,voice: AudioStreamPlayer3D) -> void:
	var active:=game.get_tree().get_nodes_in_group("war_spatial_audio")
	var index:=active.find(voice)
	if index>=0:
		game.soundscape.acoustic_cursor=(index-1+active.size())%active.size()
		game.soundscape._update_acoustics(GameWeaponAudio.listener_position(root),.12)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var game:WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game);await process_frame
	if not is_instance_valid(game.combat_audio):
		game.combat_audio=WarAudio.new();game.combat_audio.game=game;game.world_root.add_child(game.combat_audio)
	if not is_instance_valid(game.soundscape):
		game.soundscape=WarSoundscape.new();game.soundscape.game=game;game.world_root.add_child(game.soundscape)
	var actor:=game.local_player as WarPlayer
	var manager:=game.vehicle_system as WarVehicles
	var apc:=manager.vehicles.v_guarani as WarVehicle
	apc.allocate_seat(actor.peer_id);actor.vehicle_id=apc.vehicle_id
	game.members[actor.peer_id].vehicle=apc.vehicle_id
	manager.vehicle_view.external=true
	var listener:=GameWeaponAudio.listener_position(root)
	var point:=listener+Vector3(0,23,-44)
	var voice:=game.combat_audio.explosion_audio._start("armor:external:50",point,"destroy")
	check(is_instance_valid(voice) and voice.playing,"50m armored wreck creates a live 3D voice")
	for i in 2: game.soundscape._process(.12)
	force_scan(game,voice)
	check(not game.soundscape.operator_optic,"external armored camera is not a cabin optic")
	check(voice.bus!="WarCabinWeapons","external armored camera does not apply cabin muffling")
	check(voice.volume_db> -6.,"external armored camera retains the explosion near-field gain")
	check(voice.max_db>=3.,"external view retains higher 3D sound ceiling")
	# On-foot with the same acoustic event should not be reclassified as a cabin.
	actor.vehicle_id=""
	game.members[actor.peer_id].vehicle=""
	game.soundscape._process(.12)
	force_scan(game,voice)
	check(not game.soundscape.operator_optic and not game.soundscape.cabin,"on-foot view has no cabin classification")
	check(voice.bus!="WarCabinWeapons","on-foot explosion is not routed through cabin low-pass")
	print("ARMOR_EXTERNAL ",JSON.stringify({"checks":checks,"failures":errors,"bus":voice.bus,"db":voice.volume_db,"max_db":voice.max_db}))
	game.show_menu();game.queue_free();await process_frame
	quit(0 if errors.is_empty() else 1)
