extends SceneTree
var game: WarGame
var role:="server"
var label:="a1"
var legacy:=false
var frames: Array[float]=[]
var connection_frames: Array[float]=[]
var fixed_window_frames: Array[float]=[]
var previous_usec:=0
var failures: Array[String]=[]
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
  if arg=="--legacy":legacy=true
 run.call_deferred()
func _process(_delta: float) -> bool:
 var now:=Time.get_ticks_usec()
 if previous_usec>0 and is_instance_valid(game) and role=="bravo":
  if int(game.get("connected_started_usec"))>0 and int(game.get("baseline_finished_usec"))==0:connection_frames.append((now-previous_usec)*.001)
  if int(game.get("baseline_started_usec"))>0 and int(game.get("baseline_finished_usec"))==0:frames.append((now-previous_usec)*.001)
  if int(game.get("baseline_started_usec"))>0 and now-int(game.get("baseline_started_usec"))<=4000000:fixed_window_frames.append((now-previous_usec)*.001)
 previous_usec=now
 return false
func wait_for(test: Callable,seconds:=120.) -> bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000.)
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await process_frame
 failures.append("wait timeout");return false
func run() -> void:
 seed(8377)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 if role=="bravo":
  root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
  root.content_scale_size=Vector2i(1920,1080)
  root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
  root.size=Vector2i(1280,720)
 if "--qa-resolution-probe" in OS.get_cmdline_user_args():
  await process_frame
  print("RESOLUTION_PROBE ",root.size," ",root.get_texture().get_size());quit();return
 game=load("res://tests/join1103_render_fixture.gd").new();game.set_meta("test_mode",true);game.set_meta("war_test",true);game.set("legacy",legacy)
 if role=="server":game.set_meta("war_host",true);game.set_meta("online_bots_test",true)
 else:game.set_meta("war_visual_preview",true)
 root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
 if role=="server":
  if await wait_for(func():return game.get("reports").has("alpha") and is_instance_valid(game.bot_director) and game.bot_director.bots.size()==28):
   game.bot_director.set_physics_process(false)
   for id in game.bot_director.bots:game.players[id].set_physics_process(false)
   var f:=FileAccess.open("res://work/join1103-render-"+label+"-go",FileAccess.WRITE);f.store_string("go");f.close()
   if await wait_for(func():return game.get("reports").has("bravo")):game._broadcast("qa_phase",["done"]);await create_timer(1.).timeout
 elif role=="alpha":
  await game.join_game("pvp")
  if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player)):
   game.request_deploy(0,"soldier","fal","stinger","base")
   if await wait_for(func():return game.local_player.deployed):game.rpc_id(1,"qa_report","alpha")
   await wait_for(func():return game.get("phase")=="done",180.)
 else:
  if not await wait_for(func():return FileAccess.file_exists("res://work/join1103-render-"+label+"-go"),180.):finish({});return
  game.mode="pvp";game.map_kind="desert";game._enter_match_world();game.world_prebuilt=true
  game.call("prepare_preview")
  await create_timer(3.).timeout
  await game.join_game("pvp")
  if await wait_for(func():return game.join_ready and int(game.get("baseline_finished_usec"))>0):
   while Time.get_ticks_usec()-int(game.get("baseline_started_usec"))<4100000:await process_frame
   var out:={"frames":metrics(frames),"fixed_4s_window":metrics(fixed_window_frames),"connection_frames":metrics(connection_frames),"resolution":str(root.size),"render_resolution":str(root.get_texture().get_size()),"baseline_ms":(int(game.get("baseline_finished_usec"))-int(game.get("baseline_started_usec")))*.001,"connect_ms":(int(game.get("baseline_finished_usec"))-int(game.get("connected_started_usec")))*.001,"remote_creations":game.get("adds"),"peak_remote_add_ms":game.get("add_peak_ms"),"participants":game.players.size(),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"camera":str((game.get("preview") as Camera3D).global_transform),"world_build_ms":game.world_build_ms,"fixed_seed":8377,"bots_frozen_after_28":true}
   if game.players.size()!=30:failures.append("expected30participants")
   if Vector2i(root.get_texture().get_size())!=Vector2i(1920,1080):failures.append("resolution mismatch")
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://work/join1103-render-"+label+".png")
   game.rpc_id(1,"qa_report","bravo")
   finish(out);return
 finish({})
func metrics(values: Array) -> Dictionary:
 if values.is_empty():return {"samples":0}
 var sorted:=values.duplicate();sorted.sort();var sum:=0.;var slow_sum:=0.;var low_count:=maxi(1,ceili(values.size()*.01))
 for x in values:sum+=x
 for i in range(sorted.size()-low_count,sorted.size()):slow_sum+=sorted[i]
 return {"samples":values.size(),"fps_mean":1000.*values.size()/sum,"one_percent_low":1000.*low_count/slow_sum,"worst_ms":sorted[-1],"p95_ms":sorted[maxi(0,ceili(sorted.size()*.95)-1)],"wall_ms":sum}
func finish(out: Dictionary) -> void:
 out.merge({"role":role,"label":label,"legacy":legacy,"ok":failures.is_empty(),"failures":failures})
 NavalStorage.write_json("res://work/join1103-render-"+label+"-"+role+".json",out);print("JOIN1103_RENDER ",JSON.stringify(out))
 if is_instance_valid(game):game.show_menu();game.queue_free()
 await create_timer(.5).timeout;quit(0 if failures.is_empty() else 1)
