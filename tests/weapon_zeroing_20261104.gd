extends SceneTree

const ZERO=preload("res://scripts/weapon_zeroing.gd")
const BULLET=preload("res://scripts/bullet_physics.gd")
const RULES=preload("res://scripts/combat_rules.gd")
const PLAYER=preload("res://scripts/player.gd")
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)

func vertical_error_at(item: Dictionary,distance: float) -> float:
	var direction:=ZERO.compensate(Vector3.FORWARD,item,int(distance))
	var position:=Vector3.ZERO
	var velocity:=direction*float(item.speed)
	var previous:=position
	for _i in 24000:
		previous=position
		var state:=BULLET.advance(position,velocity,float(item.gravity),float(item.drag),1.0/240.0)
		position=state.position
		velocity=state.velocity
		if -position.z>=distance:
			var a:=-previous.z
			var b:=-position.z
			var weight:=clampf((distance-a)/maxf(.000001,b-a),0.,1.)
			return lerpf(previous.y,position.y,weight)
	return INF

func run() -> void:
	for id in ["glock","ak","g3","fal","sniper"]:
		var item:=RULES.weapon(id)
		check(ZERO.supported(item),id+" supports projectile zeroing")
		check(ZERO.sanitize(73,item)==50,id+" snaps arbitrary range to 50 m steps")
		check(ZERO.step(0,1,item)==50,id+" scroll up advances one 50 m step")
		check(ZERO.step(50,-1,item)==0,id+" scroll down returns to zero")
		var sample_distances: Array[int]=[50,100]
		if ZERO.maximum(item)>=300:sample_distances.append(300)
		if ZERO.maximum(item)>=600:sample_distances.append(600)
		for distance in sample_distances:
			var error:=vertical_error_at(item,float(distance))
			check(absf(error)<.045,"%s %d m zero crosses LOS within 4.5 cm (%.4f m)"%[id,distance,error])
		var zero_direction:=ZERO.compensate(Vector3.FORWARD,item,0)
		check(zero_direction.distance_to(Vector3.FORWARD)<.000001,id+" 0 m leaves bore direction unchanged")
	var glock:=RULES.weapon("glock")
	check(ZERO.maximum(glock)==150,"Glock maximum zero respects its 160 m weapon range")
	check(ZERO.maximum(RULES.weapon("ak"))==900,"AK maximum zero respects its 900 m weapon range")
	check(ZERO.maximum(RULES.weapon("sniper"))==1200,"sniper zero is defensively capped at 1200 m")
	check(not ZERO.supported(RULES.weapon("stinger")),"zeroing is disabled for gravity-free guided launcher")
	var g3:=RULES.weapon("g3")
	var sniper:=RULES.weapon("sniper")
	check(absf(ZERO.elevation_angle(g3,300)-ZERO.elevation_angle(sniper,300))>.00005,"same 300 m zero produces weapon-specific elevation")
	check(ZERO.elevation_angle(g3,300)>ZERO.elevation_angle(g3,100),"G3 elevation increases with zero distance")
	var actor:=PLAYER.new()
	actor.weapon_id="g3"
	actor.zeroing_ranges={"g3":200,"sniper":500}
	# weapon_spec needs no live game when no attachment metadata is present.
	check(actor.zeroing_distance("g3")==200 and actor.zeroing_distance("sniper")==500,"zeroing state is retained independently per equipped weapon")
	actor.free()
	var game=load("res://tests/ballistics171_fixture.gd").new()
	game.set_meta("test_mode",true)
	root.add_child(game)
	game.mode="training";game.map_kind="desert";game._enter_match_world();game.set_physics_process(false)
	var live:=game._spawn_player(1,true,false,Vector3(4,12,-1000)) as GamePlayer
	live.set_physics_process(false)
	game.ui_focus.close_all();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.third_person=false;live._update_view()
	live.weapon_id="ak";live._refresh_weapon();live.zeroing_ranges["ak"]=100
	game.infantry_hud.refresh()
	check(is_instance_valid(game.infantry_hud.zeroing) and game.infantry_hud.zeroing.visible,"HUD exposes zeroing for projectile firearm")
	check("100 m" in game.infantry_hud.zeroing.text,"HUD shows current per-weapon zero distance")
	live.aiming=true;live.iron_sights=true
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	check(live._handle_zeroing_scroll(wheel),"mouse-wheel event is recognized while aiming")
	check(live.zeroing_distance("ak")==150,"mouse wheel while aiming advances zero by 50 m")
	game.infantry_hud.refresh()
	check("150 m" in game.infantry_hud.zeroing.text,"HUD refresh follows wheel-selected zero")
	live.pitch=0.;live.recoil=0.;live.camera_pivot.rotation.x=0.;live._update_weapon_pose()
	var camera_origin:=live.camera.global_position
	var sight_direction:=-live.camera.global_basis.z.normalized()
	game.shot_clocks[1]=-100.
	game._server_accept_shot(1,1,live.life_id,camera_origin,sight_direction,"ak",2,99999)
	check(live.zeroing_distance("ak")==ZERO.maximum(live.weapon_spec("ak")),"server clamps forged zero range to weapon maximum")
	check(not game.projectiles.is_empty(),"authoritative shot creates projectile after zero validation")
	if not game.projectiles.is_empty():
		var live_velocity: Vector3=game.projectiles.back().vel
		check(live_velocity.normalized().y>sight_direction.y,"authoritative projectile receives server-calculated elevation")
	game.queue_free();await process_frame
	var result:={"checks":checks,"failures":failures}
	print("WEAPON_ZEROING_QA ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
