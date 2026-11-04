extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func run() -> void:
	var game=load("res://tests/late_join_fixture.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode="training";game.map_kind="sandbox";game._enter_match_world()
	game._static_box(game.world_root,"Floor",Vector3(0,-.25,0),Vector3(100,.4,100),Color.GRAY)
	var actor: GamePlayer=game._spawn_player(1,true,false,Vector3.ZERO)
	game.third_person=false
	actor._update_view()
	await create_timer(.5).timeout
	actor.trigger_held=true
	actor.fire()
	var start:=Time.get_ticks_msec()*.001
	while Time.get_ticks_msec()*.001-start<3.6: await process_frame
	actor.trigger_held=false
	check(game.seen_shots.size()==30 and actor.ammo.fal==0,"held FAL fires exactly 30 rounds with no extra shot")
	check(game.sound_pools["1:fal"].size()>=18 and game.sound_pools["1:fal"].size()<=24,"FAL burst retains overlapping 2.3 second audio tails within a bound")
	check(actor.pending_shots.is_empty(),"offline burst has no stale pending network shots")
	actor.fire()
	await process_frame
	check(game.combat_feedback.empty_at>0,"empty magazine produces feedback")
	game.damage_feedback(80)
	await process_frame
	check(game.combat_feedback.hurt_at>0,"actual health reduction produces feedback")
	var eye: Vector3=actor.camera_pivot.global_position
	check(game.combat_feedback.near_miss(eye+Vector3(1,0,-4),eye+Vector3(1,0,4),actor,99),"near passing enemy bullet produces a whiz")
	check(not game.combat_feedback.near_miss(eye+Vector3(1,0,-4),eye+Vector3(1,0,4),actor,1),"own bullet never produces a near-miss whiz")
	var colors: Array[Color]=[]
	for weapon in ["fal","glock","sniper"]:
		game._spawn_projectile(1,Vector3(5,5,0),Vector3.FORWARD,weapon,false,false,"color:"+weapon)
		colors.append(game.projectiles.back().color)
	check(colors[0]!=colors[1] and colors[1]!=colors[2] and colors[0]!=colors[2],"three firearms have distinct projectile and tracer colors")
	check(is_equal_approx(NavalCatalog.WEAPONS.missile.speed,86.52*1.05) and is_equal_approx(NavalCatalog.WEAPONS.torpedo.speed,42*1.05),"naval missile and torpedo both gain exactly five percent speed")
	var item: Dictionary=CombatRules.weapon("sniper")
	check(float(item.speed)>105.8 and float(item.gravity)/pow(float(item.speed),2)<8.3385/pow(105.8,2),"sniper is faster with less accumulated drop")
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","rendered game expands to its window aspect without black bars")
	game.show_menu()
	await process_frame
	check(game.players.is_empty() and game.projectiles.is_empty() and game.sound_pools.is_empty() and not game.match_started and not game.player_in_vehicle and game.feedback_hp==100,"exit resets simulation, audio and combat feedback")
	game.queue_free()
	await create_timer(.2).timeout
	var report: Dictionary={"checks":checks,"failures":failures}
	NavalStorage.write_json("res://tests/combat-feedback-results.json",report);print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
