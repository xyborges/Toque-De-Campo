extends WarGame

# Small acoustic arena only. Production WarAudio, WarSoundscape, WarPlayer,
# server shot validation and remote_shot_packet remain the systems under test.
var acoustic_mode:="war"
var desert_audio: GameWeaponAudio
var observer_peer:=0
var received:=0
var emitted:=0
var event_sequence:=0
var latest_packet: Dictionary={}
var qa_done:=false
var wall: StaticBody3D

func _ready() -> void:
	set_meta("war_test",true);set_meta("war_visual_preview",true);set_meta("test_mode",true)
	super._ready()
	set_physics_process(false);set_process(false)
	mode="pvp";map_kind="war";online=true
	world_root=Node3D.new();world_root.name="AcousticArena";add_child(world_root)
	var lamp:=DirectionalLight3D.new();lamp.rotation_degrees=Vector3(-50,-30,0);world_root.add_child(lamp)
	var plane:=MeshInstance3D.new();var shape:=PlaneMesh.new();shape.size=Vector2(1000,1000);plane.mesh=shape
	world_root.add_child(plane)
	combat_audio=WarAudio.new();world_root.add_child(combat_audio)
	desert_audio=GameWeaponAudio.new();world_root.add_child(desert_audio)
	soundscape=WarSoundscape.new();soundscape.game=self;world_root.add_child(soundscape)
	for voice: AudioStreamPlayer3D in soundscape.loops.values(): voice.stop()
	soundscape.ambient_at=1e9
	add_acoustic_actor(1,false,Vector3(0,0,-50))
	var port:=39574
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-port="): port=int(arg.trim_prefix("--audio-port="))
	var transport:=ENetMultiplayerPeer.new()
	# Match production transport initialization. Without this watcher the
	# GameNetworkBroadcast ready-peer guard drops every remote_shot_packet.
	GameNetworkPeers.watch(transport)
	if "--role=server" in OS.get_cmdline_user_args():
		dedicated_pvp=true
		transport.create_server(port,1,4)
		multiplayer.peer_connected.connect(func(id: int):
			observer_peer=id;add_acoustic_actor(id,false,Vector3.ZERO)
		)
	else:
		dedicated_pvp=false
		transport.create_client("127.0.0.1",port,4)
		multiplayer.connected_to_server.connect(func():
			observer_peer=multiplayer.get_unique_id()
			local_player=add_acoustic_actor(observer_peer,true,Vector3.ZERO)
			local_player.audio_listener.make_current();local_player.camera.make_current()
			join_ready=true;ui_focus.close_all();loading_screen.hide();menu_layer.hide();hud_layer.show()
		)
	multiplayer.multiplayer_peer=transport

func add_acoustic_actor(id: int,local: bool,point: Vector3) -> WarPlayer:
	var actor:=_spawn_player(id,local,false,point) as WarPlayer
	actor.hp=100;actor.deployed=true;actor.apply_identity(1 if id==1 else 0,"soldier")
	actor.owned=["glock","fal","sniper"];actor.loadout=actor.owned.duplicate();actor.set_physics_process(false)
	actor.collision_layer=0;actor.body_collision.disabled=true;actor._set_hitboxes_enabled(false)
	members[id]={"team":actor.war_team,"role":"soldier","deployed":true,"vehicle":"","shield":0.,"charges":3,"ready_at":0.,"last_gadget":-100.}
	actor._update_view()
	return actor

func play_weapon_sound(id: String,point: Vector3,emitter:=0,elapsed:=0.0) -> void:
	if acoustic_mode=="desert": desert_audio.play(emitter,id,point,elapsed)
	else: super.play_weapon_sound(id,point,emitter,elapsed)

func _spawn_projectile(_owner: int,_point: Vector3,_direction: Vector3,_weapon: String,_melee: bool,_authority: bool,_key: String="") -> void:
	pass # This fixture measures audio transport; projectile physics has other tests.

func _present_shot(packet: Dictionary) -> bool:
	var accepted:=super._present_shot(packet)
	if accepted:
		latest_packet=packet.duplicate();received+=1
	return accepted

@rpc("any_peer","call_remote","reliable")
func qa_fire(weapon: String,point: Vector3) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id()!=observer_peer or weapon not in ["glock","fal","sniper"] or not point.is_finite() or point.length()>1000: return
	var actor:=players[1] as WarPlayer
	if actor.weapon_id!=weapon: actor.weapon_id=weapon;actor._refresh_weapon()
	actor.recoil=0;actor.attack_anim=0;actor.pitch=0;actor.yaw=0;actor.rotation=Vector3.ZERO
	actor.ammo[weapon]=int(GameWeapons.ITEMS[weapon].mag)
	actor._update_weapon_pose()
	actor.global_position+=point-actor.get_muzzle_position()
	event_sequence+=1
	var before:=int(actor.ammo[weapon])
	_server_accept_shot(1,event_sequence,actor.life_id,actor.camera_pivot.global_position,Vector3.FORWARD,weapon,0)
	if int(actor.ammo[weapon])<before: emitted+=1

@rpc("any_peer","call_remote","reliable")
func qa_finish() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id()==observer_peer: qa_done=true

@rpc("any_peer","call_remote","reliable")
func qa_duplicate_last() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id()==observer_peer and not latest_packet.is_empty():
		rpc_id(observer_peer,"remote_shot_packet",latest_packet)

func configure_wall(enabled: bool) -> void:
	if is_instance_valid(wall): wall.queue_free();wall=null
	if not enabled: return
	wall=StaticBody3D.new();wall.collision_layer=1
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12,6,.5);collision.shape=box
	wall.add_child(collision);world_root.add_child(wall);wall.position=Vector3(0,2,-25)
	var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;visual.mesh=mesh;wall.add_child(visual)
