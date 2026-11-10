extends SceneTree
## Real war scene: prove the native separation path is called by the bot
## director with deployed actors, not only exercised by synthetic math QA.
var game: WarGame
var failures: Array[String]=[]
var sampled:=0
var max_delta:=0.0
var native_ready_frames:=0
var inspected_bots:=0
var nonzero_separation_samples:=0

func _initialize() -> void:
	_run.call_deferred()

func _reference(director: WarBotDirector, actor: WarPlayer) -> Vector3:
	var result:=Vector3.ZERO
	for other: WarPlayer in director._near_actors(actor.global_position):
		if not is_instance_valid(other) or not other.is_inside_tree() or other==actor or other.hp<=0 or not other.deployed or not other.vehicle_id.is_empty():continue
		var offset:=actor.global_position-other.global_position
		offset.y=0
		var distance:=offset.length()
		if distance>.01 and distance<1.1: result+=offset/distance*(1.1-distance)
	return result

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--experimental-native-separation"):
		failures.append("missing --experimental-native-separation")
	if not ClassDB.class_exists("WarNativePoseMath"):
		failures.append("GDExtension not loaded")
	if not failures.is_empty():
		_finish();return
	seed(20261110)
	game=WarGame.new()
	game.offline_operation=true
	game.offline_participants=13
	game.set_meta("test_mode",true)
	root.add_child(game)
	var deadline:=Time.get_ticks_msec()+90000
	while not game.join_ready and Time.get_ticks_msec()<deadline:
		await process_frame
	if not game.join_ready:
		failures.append("world did not load")
		_finish();return
	game.request_deploy(0,"soldier","fal","stinger","base")
	var director:=game.bot_director as WarBotDirector
	if not is_instance_valid(director):
		failures.append("director missing")
		_finish();return
	deadline=Time.get_ticks_msec()+40000
	while director.bots.size()<12 and Time.get_ticks_msec()<deadline:
		await process_frame
	if director.bots.size()!=12:failures.append("wrong bot population "+str(director.bots.size()))
	for tick in 60:
		await physics_frame
		# Verify the real director is executing the native branch BEFORE
		# refreshing spatial state for the equivalence snapshot.
		if director.native_separation_ready:native_ready_frames+=1
		# Real WarPlayer bodies, briefly placed as neighbors to exercise
		# repulsion above zero (not just the trivial zero-force case).
		if tick in [15,40] and director.bot_ids.size()>=2:
			var first:=game.players.get(director.bot_ids[0]) as WarPlayer
			var second:=game.players.get(director.bot_ids[1]) as WarPlayer
			if is_instance_valid(first) and is_instance_valid(second):
				second.global_position=first.global_position+Vector3(.75,0,0)
		# Compute both paths on the same world positions and spatial index.
		director._index_actors()
		director._prepare_native_separations()
		for bot_id in director.bot_ids:
			var actor:=game.players.get(bot_id) as WarPlayer
			if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty():continue
			var actual: Vector3=director.native_separation_by_id.get(actor.peer_id,Vector3.ZERO)
			var expected:=_reference(director,actor)
			var error:=actual.distance_to(expected)
			if expected.length_squared()>.000001:nonzero_separation_samples+=1
			max_delta=maxf(max_delta,error)
			inspected_bots+=1
			if error<.0005:sampled+=1
	if native_ready_frames!=60:failures.append("native path not ready for all frames: "+str(native_ready_frames))
	if inspected_bots<100:failures.append("insufficient moving bot samples "+str(inspected_bots))
	if nonzero_separation_samples<2:failures.append("never exercised nonzero separation in live WarPlayer physics")
	if max_delta>.01:failures.append("force mismatch with director spatial steering: "+str(max_delta))
	_finish()

func _finish() -> void:
	print("GDE_SEPARATION_RUNTIME_QA ",JSON.stringify({
		"failures":failures,"native_ready_frames":native_ready_frames,
		"bot_samples":inspected_bots,"matching_samples":sampled,
		"nonzero_separation_samples":nonzero_separation_samples,
		"max_force_error":max_delta,"requested_bots":12}))
	if is_instance_valid(game):game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
