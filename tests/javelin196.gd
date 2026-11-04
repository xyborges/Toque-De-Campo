extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func point_at(actor: WarPlayer,point: Vector3) -> void:
	var direction: Vector3=(point-actor.camera_pivot.global_position).normalized()
	actor.yaw=atan2(-direction.x,-direction.z);actor.rotation.y=actor.yaw;actor.pitch=asin(direction.y);actor.camera_pivot.rotation.x=actor.pitch
func run() -> void:
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game)
	var actor:=game.local_player as WarPlayer;actor.apply_identity(0,"antitank");game.members[1].role="antitank";actor.set_gadget(true,"stinger")
	var manager:=game.vehicle_system as WarVehicles
	for vehicle: WarVehicle in manager.vehicles.values(): vehicle.global_position=Vector3(500,100,500)
	var enemy:=manager.vehicles.v_t90 as WarVehicle;enemy.global_position=Vector3(0,0,-50);enemy.show()
	await physics_frame;await physics_frame
	point_at(actor,enemy.global_position+Vector3.UP*1.2)
	check(manager.acquire(actor).get("id","")==enemy.vehicle_id,"Javelin acquires enemy tank")
	for i in 90: manager._update_gadgets(1./60.)
	check(float(manager.locks.get(1,{}).get("progress",0.))>=1.,"server completes tank lock")
	actor._update_weapon_pose();game.members[1].last_gadget=-100.
	var count: int=game.war_fx.active_slots.size();manager.use_gadget(1)
	check(game.war_fx.active_slots.size()==count+1 and int(game.members[1].charges)==3,"locked missile is fired and consumes one charge")
	var shot: Dictionary=game.war_fx.rounds[game.war_fx.active_slots.back()]
	check(str(shot.get("target",""))==enemy.vehicle_id,"authoritative projectile tracks tank")
	var initial_hp:=enemy.hp
	for i in 180:
		game.war_clock+=1./120.;game.war_fx._step(shot,1./120.)
		if not shot.active: break
	check(enemy.hp<initial_hp,"homing projectile physically hits and damages enemy tank")
	enemy.team=0;check(manager.acquire(actor).is_empty(),"friendly tank is not lockable")
	enemy.team=1
	var wall:=StaticBody3D.new();var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12,8,1);col.shape=box;wall.add_child(col);wall.position=Vector3(0,2,-25);game.world_root.add_child(wall)
	await physics_frame;await physics_frame
	check(manager.acquire(actor).is_empty(),"cover prevents tank lock")
	var before:=int(game.members[1].charges);game.members[1].last_gadget=-100.;manager.use_gadget(1)
	check(int(game.members[1].charges)==before,"stale lock cannot fire through cover")
	check(GameWeapons.ITEMS.stinger.name=="Javelin","player-facing weapon name is Javelin")
	game.show_menu();game.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
