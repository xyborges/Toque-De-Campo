extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var game=load("res://tests/war_optics_fixture.gd").new();root.add_child(game)
	var ground:=StaticBody3D.new();ground.collision_layer=1;ground.position=Vector3(150,49.5,0)
	var ground_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(800,1,100);ground_shape.shape=floor_box;ground.add_child(ground_shape);game.world_root.add_child(ground)
	game.local_player.position=Vector3(0,50.1,0);(game.players[2] as WarPlayer).position=Vector3(0,50.1,15)
	var bot:=game.make_actor(99,false,1,"soldier",Vector3(300,50.1,0)) as WarPlayer
	bot.set_meta("war_bot",true);bot.set_physics_process(false);bot.deployed=true
	var director:=load("res://tests/perf200_bot_lod_prototype.gd").new() as WarBotDirector
	director.game=game;game.world_root.add_child(director);director.set_physics_process(false)
	var record: Dictionary={"direction":Vector3.RIGHT,"slot":5,"target":0,"line_clear":false,"last_position":bot.position,"stuck":0.,"boarded_once":true}
	await physics_frame
	bot.body_collision.set_deferred("disabled",false);bot._set_hitboxes_enabled(true)
	await physics_frame
	for tick in 180:
		director._move(bot,record,1./60.);await physics_frame
	print("BOT_LOD_DIAGNOSTIC ",JSON.stringify({"position":str(bot.position),"floor":bot.is_on_floor(),"deferred":director.deferred_ticks,"reduced":director.reduced_steps,"full":director.full_rate_ticks,"velocity":str(bot.velocity),"deployed":bot.deployed}))
	check(director.reduced_steps>10 and director.deferred_ticks>10,"distant grounded bot takes staggered reduced movement steps")
	check(bot.position.x>303. and bot.position.y>49.85,"distant bot keeps moving and remains above the floor")
	var deferred_before: int=director.deferred_ticks;var full_before: int=director.full_rate_ticks
	bot.position=Vector3(4,50.1,0);bot.velocity=Vector3.ZERO;record.last_position=bot.position
	for tick in 15: director._move(bot,record,1./60.);await physics_frame
	check(director.deferred_ticks==deferred_before and director.full_rate_ticks-full_before==15,"near a human, movement stays at full physics rate")
	bot.position=Vector3(300,50.1,0);bot.velocity=Vector3.ZERO;record.last_position=bot.position;record.target=1
	deferred_before=director.deferred_ticks;full_before=director.full_rate_ticks
	for tick in 15: director._move(bot,record,1./60.);await physics_frame
	check(director.deferred_ticks==deferred_before and director.full_rate_ticks-full_before==15,"bot with acquired target keeps full physics rate")
	game.show_menu();game.queue_free();await process_frame
	print("BOT_LOD_GUARD ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
