extends SceneTree
var role:="host"
var game: WarGame
var actor: WarPlayer
var checks:=0
var failures: Array[String]=[]
var samples:=0
var eye_frames:=0
var fpp_frames:=0
var maximum_error:=0.0
var sampling:=false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func wait_for(condition: Callable,label_text: String,seconds:=20.) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call(): return true
		await process_frame
	failures.append("timeout: "+label_text);return false
func record_pose() -> void:
	if not sampling or not is_instance_valid(actor): return
	samples+=1
	if actor.view_root.visible: fpp_frames+=1
	var length_value:=actor.shoulder_arm.get_hit_length()
	if length_value>1 and game.third_person and not actor.iron_sights:
		if actor.camera.position.z<.1: eye_frames+=1
		maximum_error=maxf(maximum_error,absf(actor.camera.position.z-length_value))
func run() -> void:
	Engine.max_fps=144 if role=="host" else 60
	if role=="host":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.frame_pre_draw.connect(record_pose)
	var credentials:=NavalStorage.read_json("res://work/naval-e2e-credentials.json")
	var accounts:=NavalAccounts.new();root.add_child(accounts)
	var response: Dictionary=await accounts.sign_in("login",str(credentials[role].username),str(credentials[role].password))
	check(response.get("ok",false) and accounts.validated_session,"real QA account authenticates over verified TLS")
	if failures.is_empty():
		game=WarGame.new();game.accounts_service=accounts;root.add_child(game)
		if await wait_for(func():return game.join_ready and is_instance_valid(game.local_player) and game.players.size()==2,"central War join",35):
			check(not game.testing and game._central_pvp(),"online camera test uses production Ubuntu authority")
			if role=="guest": await wait_for(func():return game.members.values().any(func(member):return bool(member.get("deployed",false))),"team 1 deployed")
			game.request_deploy(0 if role=="host" else 1,"soldier","fal","rpg","rally")
			if await wait_for(func():return game.local_player.deployed and game._battle_active(),"two opposing players deployed"):
				actor=game.local_player as WarPlayer;game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=true;actor._update_view()
				if role=="host":
					var distance_value:=0.0;var previous:=actor.position
					sampling=true;Input.action_press("move_forward")
					for frame in 420:
						var motion:=InputEventMouseMotion.new();motion.relative=Vector2(12 if frame<210 else -12,sin(frame*.02)*.5);Input.parse_input_event(motion)
						if frame==120: actor.equip_quick_slot(1)
						if frame==250: actor.equip_quick_slot(2)
						await process_frame
						distance_value+=actor.position.distance_to(previous);previous=actor.position
					Input.action_release("move_forward");sampling=false
					check(samples>=400 and distance_value>5,"native online actor walks and looks around for at least400 rendered frames")
					check(eye_frames==0 and fpp_frames==0,"online rendered TPP frames never show a shoulder/eye jump or FPP clone")
					check(maximum_error<.025,"online movement, mouse input and weapon switches preserve the SpringArm solution")
					check(game.third_person and actor.camera.current and actor.camera.get_parent()==actor.shoulder_arm,"online actor keeps the chosen TPP camera")
					NavalStorage.write_json("res://work/central166-camera-stage.json",{"done":true,"distance":distance_value})
				else:
					await wait_for(func():return NavalStorage.read_json("res://work/central166-camera-stage.json").get("done",false),"host movement completed",40)
					var remote: WarPlayer
					for other: WarPlayer in game.players.values():
						if not other.is_local: remote=other
					check(is_instance_valid(remote) and remote.body_root.visible,"observer retains the moving remote avatar")
	var result: Dictionary={"role":role,"checks":checks,"failures":failures,"rendered_samples":samples,"eye_frames":eye_frames,"fpp_frames":fpp_frames,"maximum_arm_error":maximum_error,"authority":"Ubuntu, two authenticated accounts, normal movement/input and equipment packets"}
	NavalStorage.write_json("res://tests/ubuntu-war-camera-"+role+".json",result);print(JSON.stringify(result))
	if is_instance_valid(game): game.show_menu();game.queue_free()
	await create_timer(.4).timeout;accounts.queue_free();quit(0 if failures.is_empty() else 1)
