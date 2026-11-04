extends SceneTree

var checks:=0
var failures: Array[String]=[]
var metrics: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func run() -> void:
 var game:=load("res://tests/br_terrain_camera_regression_fixture.gd").new() as BattleRoyaleGame
 game.offline_operation=false;game.set_meta("br_host",true);game.set_meta("test_mode",true);game.set_meta("br_direct_connect",true);game.assigned_port=39594
 root.add_child(game);await process_frame;await process_frame
 game.dedicated_pvp=false;game.mode="pvp";game._enter_match_world()
 var world_id:=game.world_root.get_instance_id()
 check(game.map_kind=="afghan" and game.afghan_map.built,"actual full Afghan world prepared before transport")
 game.join_game("pvp")
 check(game.online and game.map_kind=="afghan","online join preserves Afghan map identity before connect callback")
 game._enter_match_world()
 check(game.map_kind=="afghan" and game.world_root.get_instance_id()==world_id,"connect re-entry preserves identity and reuses prepared world")
 var peer:=game.network_api.multiplayer_peer;game.network_api.multiplayer_peer=OfflineMultiplayerPeer.new();peer.close();game.online=false
 game.phase="active";game.br_generation=1;game.pvp_spawn_confirmed=true;game.ui_focus.close_all();root.gui_release_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 var actor:=game._spawn_player(1,true,false,Vector3.ZERO) as BRPlayer;game.local_player=actor
 var p:=game.find_spawn(7919)
 actor.position=p;actor.hp=100.;actor.deployed=true
 var start:=actor.position
 for index in 90:await physics_frame
 metrics.spawn_start=start;metrics.spawn_end=actor.position;metrics.floor=actor.is_on_floor();metrics.afghan_ground=BRAfghanMap.height_at(actor.position.x,actor.position.z)
 var floor_query:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*.15,actor.position-Vector3.UP*.6,1,[actor.get_rid()])
 var floor_hit:=actor.get_world_3d().direct_space_state.intersect_ray(floor_query)
 check(Vector2(actor.position.x-start.x,actor.position.z-start.z).length()<1.,"a distant spawn is not clamped into the small desert square")
 check(actor.is_on_floor() and not floor_hit.is_empty() and absf(actor.position.y-float(floor_hit.position.y))<.3,"character settles on actual full-map collision without sky or limbo")
 game.closing=true;game.free();await process_frame;await physics_frame
 game=load("res://tests/br_motorbike_camera_fixture.gd").new();game.set_meta("br_host",true);game.set_meta("test_mode",true);root.add_child(game);game.flat_world();game.online=false;game.phase="active";game.br_generation=3
 var bikes:=load("res://tests/br_motorbikes_fixture.gd").new() as BRMotorbikes;bikes.game=game;game.motorbikes=bikes;game.world_root.add_child(bikes)
 var bike: WarVehicle=bikes.bikes.br_bike_00
 actor=game._spawn_player(1,true,false,Vector3(1.6,.08,0));game.local_player=actor;actor.hp=100;actor.life_id=7;actor.set_physics_process(false);game.pvp_spawn_confirmed=true
 game.ui_focus.close_all();root.gui_release_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=false;actor._update_view()
 for index in 20:await physics_frame;bike.simulate(1./60.,{})
 bikes._interact(1,bike.vehicle_id,7,3);await physics_frame
 check(bikes.occupied(actor),"real boarding enables motorcycle presentation")
 check(game.gameplay_input_allowed(),"headless fixture exposes active gameplay look input")
 var initial_yaw:=actor.yaw
 var flashed:=0;var snapped:=0;var max_heading_error:=0.
 for third in [false,true]:
  game.third_person=third
  for index in 72:
   Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
   actor.apply_look(Vector2(40.,2. if index<36 else -2.))
   if actor.view_root.visible:flashed+=1
   if actor.camera.global_position.distance_to(actor.camera_pivot.global_position)<2.8:snapped+=1
   max_heading_error=maxf(max_heading_error,absf(angle_difference(actor.rotation.y,bike.heading)))
   # Inspect the rendered state between mouse input and the next physics tick.
   await process_frame
   bikes.pose(actor)
 metrics.mouse_frames=144;metrics.fpp_flashes=flashed;metrics.camera_snaps=snapped;metrics.rider_heading_error=max_heading_error
 check(absf(actor.yaw-initial_yaw)>1.,"144 actual look calls rotate the view")
 check(flashed==0,"mouse look never reveals on-foot first-person hands between physics frames")
 check(snapped==0,"riding camera never jumps to on-foot FPP or shoulder distance while orbiting")
 check(max_heading_error<.001,"looking around never turns the rider away from the bike")
 actor._update_view()
 check(not actor.view_root.visible and actor.camera.global_position.distance_to(actor.camera_pivot.global_position)>2.8,"view refresh remains owned by the vehicle while seated")
 check(bikes.release(1),"clear dismount succeeds")
 await physics_frame;await physics_frame
 actor._update_view()
 check(not actor.view_root.visible and actor.weapon_root.visible,"on-foot selected TPP presentation restored after exit")
 game.closing=true;game.free();await process_frame
 var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Actual production BR join path with prebuilt full Afghan terrain, real capsule settling at distant seeded spawn, and mouse-frame camera state while driving in both selected on-foot perspectives. Local transport setup; authentication covered separately."}
 NavalStorage.write_json("res://work/br-terrain-camera-regression.json",report);print("BR_TERRAIN_CAMERA ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
