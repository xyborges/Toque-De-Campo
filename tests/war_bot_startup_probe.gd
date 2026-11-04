extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var game:=load("res://tests/bots195_fixture.gd").new() as WarGame
 game.set_meta("war_test",true);game.set_meta("war_visual_preview",true);game.set_meta("online_bots_test",true);root.add_child(game)
 game.mode="pvp";game.map_kind="desert";game.online=true;var start:=Time.get_ticks_usec();game._enter_match_world();var built:=Time.get_ticks_usec()
 game.online=true
 var actor:=game._spawn_player(1,false,false,WarTerrain.point(-560,0));game.members[1]={"team":0,"role":"soldier","deployed":true,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
 var setup_start:=Time.get_ticks_usec();game._start_online_bots();var setup_end:=Time.get_ticks_usec()
 game.bot_director.set_physics_process(false)
 var samples: Array=[]
 for index in 6:
  var before:=Time.get_ticks_usec();game.bot_director._reconcile_online();var dt:=(Time.get_ticks_usec()-before)*.001
  var teams:=[0,0]
  for record: Dictionary in game.bot_director.bots.values():teams[int(record.team)]+=1
  samples.append({"bot":index+1,"ms":dt,"teams":teams});await process_frame
 var data:={"world_ms":(built-start)*.001,"first_deploy_setup_ms":(setup_end-setup_start)*.001,"spawns":samples}
 NavalStorage.write_json("res://work/war-bot-startup-probe.json",data);print("WAR_BOT_STARTUP ",JSON.stringify(data));game.closing=true;game.online=false;game.free();await process_frame;quit()
