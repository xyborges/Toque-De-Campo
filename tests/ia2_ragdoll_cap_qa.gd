extends SceneTree

# Regression: 12 deaths in one frame must never leave more than ten corpses
# after the frame, even when queue_free() has not yet been flushed.
var fails: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func _check(ok: bool, name: String) -> void:
	print(("PASS " if ok else "FAIL ")+name)
	if not ok:fails.append(name)
func run() -> void:
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_meta("war_mode",true)
	game.ia2_remote_ragdoll_queue_enabled=false
	var actors: Array[WarPlayer]=[]
	actors.append(game.players[2] as WarPlayer)
	for i in 11:
		var actor: WarPlayer=game.make_actor(3+i,false,1,"soldier",Vector3(5.+i*4.,0,-25.))
		actor.set_physics_process(false)
		actors.append(actor)
	for strict in [false,true]:
		game.ia2_ragdoll_strict_cap=strict
		var before:=Time.get_ticks_usec()
		for actor in actors:
			actor.death_presented=actor.life_id-1
			game.spawn_ragdoll(actor.global_position,1,actor)
		var callback_ms: float=(Time.get_ticks_usec()-before)*.001
		await process_frame
		var created: Array[Node]=get_nodes_in_group("death_ragdolls")
		print("IA2_CAP_CHECK ",JSON.stringify({"strict":strict,"count":created.size(),"callback_ms":callback_ms}))
		if strict:
			_check(created.size()==10,"strict cap keeps 10 after 12 same-frame deaths")
		else:
			_check(created.size()>10,"previous cap overflows during same-frame burst")
		for corpse in created: corpse.queue_free()
		await process_frame
		_check(get_nodes_in_group("death_ragdolls").is_empty(),"corpses released after each test")
	print("IA2_CAP_QA ",JSON.stringify({"errors":fails,"ok":fails.is_empty()}))
	game.queue_free()
	await process_frame
	quit(0 if fails.is_empty() else 1)
