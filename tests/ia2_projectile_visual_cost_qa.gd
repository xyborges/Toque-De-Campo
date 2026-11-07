extends SceneTree

# Isolated client-side visual raycast hot path. No AI, ENet, GPU or damage.
var mode:=false
var run_id:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--optimized="):mode=arg.trim_prefix("--optimized=")=="1"
		if arg.begins_with("--run="):run_id=int(arg.trim_prefix("--run="))
	Engine.max_fps=0
	run.call_deferred()

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	var total:=0.0
	for v in values:total+=v
	return {"mean_ms":total/values.size(),"p95_ms":values[ceili(values.size()*.95)-1],
		"p99_ms":values[ceili(values.size()*.99)-1],"max_ms":values.back(),
		"count":values.size()}

func run() -> void:
	var game: WarGame=load("res://tests/war_optics_fixture.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var projectiles: WarProjectiles=game.war_fx
	projectiles.set_physics_process(false)
	projectiles.ia2_visual_sweep_30hz=mode
	var wall:=StaticBody3D.new()
	wall.collision_layer=1
	wall.collision_mask=0
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(100,50,1)
	collision.shape=box
	wall.add_child(collision)
	game.world_root.add_child(wall)
	wall.position=Vector3(55,10,-76)
	await physics_frame
	var ids: Array[String]=[]
	var starts: Dictionary={}
	for i in 120:
		var position:=Vector3(40.0+(i%20)*1.4,5.0+float(i/20)*.25,0)
		var key:="visual-benchmark-"+str(i)
		if not projectiles.spawn(2,position,Vector3.FORWARD,"glock",false,key,
				{"gravity":0.0,"speed":45.0,"life":7.0,"range":220.0}):
			push_error("SPAWN FAILED "+str(i));quit(2);return
		ids.append(key);starts[key]=position
	await physics_frame
	var done: Dictionary={}
	var per_tick: Array[float]=[]
	var frame_ms: Array[float]=[]
	var failed: Array[String]=[]
	var prev:=Time.get_ticks_usec()
	for tick in 175:
		await physics_frame
		var now:=Time.get_ticks_usec()
		frame_ms.append((now-prev)*.001)
		prev=now
		var begin:=Time.get_ticks_usec()
		projectiles._physics_process(1.0/60.0)
		per_tick.append((Time.get_ticks_usec()-begin)*.001)
		for key in ids:
			if done.has(key):continue
			var shot:=projectiles.find_round(key)
			if not shot.is_empty() and not bool(shot.active):
				done[key]=shot.position
		if done.size()==ids.size():break
	for key in ids:
		if not done.has(key):
			failed.append("did not hit "+key)
		elif absf(Vector3(done[key]).z+75.5)>.2:
			failed.append("wrong wall z "+key+" "+str(done[key]))
	var positions: Array[String]=[]
	for key in ids:
		if done.has(key):positions.append(str(done[key]))
	var digest:=JSON.stringify(positions).sha256_text()
	var result={"mode":"visual_30hz" if mode else "original_60hz","run":run_id,"shots":ids.size(),
		"hits":done.size(),"errors":failed,"tick_cpu":_stats(per_tick),
		"frame_intervals":_stats(frame_ms),
		"simulated_ticks":per_tick.size(),
		"visual_queries":projectiles.ia2_visual_ray_queries,
		"skipped_queries":projectiles.ia2_visual_ray_skipped,
		"authority_queries":projectiles.ia2_authority_ray_queries,
		"hit_positions_sha256":digest}
	print("IA2_VISUAL_PROJECTILE_BENCH ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
