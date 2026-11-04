extends SceneTree
var checks:=0
var failures: Array[String]=[]
var game: WarGame
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label_text: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label_text)
	if not ok: failures.append(label_text)
func run() -> void:
	game=WarGame.new();game.offline_operation=true;game.set_meta("war_test",true);game.set_meta("test_mode",true);root.add_child(game)
	var deadline:=Time.get_ticks_msec()+65000
	while not game.join_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not game.join_ready: print("FAIL game not ready");quit(1);return
	game.set_physics_process(false);game.vehicle_system.set_physics_process(false)
	for id in [701,702]:
		var actor:=game._spawn_player(id,false,false,WarTerrain.point(-200 if id==701 else 200,50)) as WarPlayer
		actor.set_physics_process(false)
		game.members[id]={"team":-1,"role":"soldier","deployed":false,"vehicle":"","charges":3,"ready_at":0.,"shield":0.,"gadget":"rpg","pending":{},"last_gadget":-100.}
		game._deploy(id,0 if id==701 else 1,"soldier","fal","rpg","base")
	await physics_frame
	var manager:=game.vehicle_system as WarVehicles
	check(WarRules.VEHICLE_RESPAWN_SECONDS==15,"15-second authoritative armored respawn policy")
	for vehicle: WarVehicle in manager.vehicles.values():
		if vehicle is WarShip: continue
		var instance_id:=vehicle.get_instance_id();var original:=vehicle.spawn_position
		check(original.distance_to(WarRules.BASES[vehicle.team])<60,"vehicle belongs to its team's base: "+vehicle.kind)
		vehicle.global_position=WarTerrain.point(80,220);vehicle.ammo=0;vehicle.reserve=0;vehicle.secondary_ammo=0;vehicle.selected="secondary";vehicle.reloading=true;vehicle.reload_left=5
		var attacker:=702 if vehicle.team==0 else 701
		manager.damage_from_hit(attacker,vehicle,100000,"tank",Vector3.FORWARD)
		check(vehicle.destroyed and vehicle.hp==0 and vehicle.visible and vehicle.collision_layer==0,"destroyed wreck remains visible and noncollidable: "+vehicle.kind)
		check(vehicle.respawn_left==15 and vehicle.snapshot().respawn==15,"destruction starts a replicated 15-second countdown: "+vehicle.kind)
		manager.damage_from_hit(attacker,vehicle,100000,"tank",Vector3.FORWARD)
		manager._step_vehicle_respawns(14.9)
		check(vehicle.destroyed and vehicle.respawn_left>0 and vehicle.snapshot().respawn==1,"vehicle cannot return before 15 seconds: "+vehicle.kind)
		var remote:=WarVehicle.new();remote.kind=vehicle.kind;remote.vehicle_id="mirror";game.world_root.add_child(remote);remote.receive(vehicle.snapshot())
		check(remote.destroyed and remote.respawn_left==1 and remote.visible,"remote vehicle receives the same remaining second: "+vehicle.kind)
		manager._step_vehicle_respawns(.1)
		check(not vehicle.destroyed and vehicle.visible and vehicle.respawn_left==0 and vehicle.collision_layer==(1|16),"15 seconds restores visibility and collisions: "+vehicle.kind)
		check(vehicle.get_instance_id()==instance_id and vehicle.global_position.is_equal_approx(original) and vehicle.team==int(vehicle.spec.team),"same vehicle returns to its own original base: "+vehicle.kind)
		check(vehicle.hp==float(vehicle.spec.hp) and vehicle.ammo==vehicle.capacity() and vehicle.reserve==int(vehicle.spec.ammo)-vehicle.ammo and vehicle.secondary_ammo==int(WarRules.SECONDARY[vehicle.kind].capacity),"respawn refills integrity and finite ammunition: "+vehicle.kind)
		check(vehicle.driver==0 and vehicle.speed==0 and vehicle.velocity==Vector3.ZERO and not vehicle.reloading and vehicle.reload_left==0 and vehicle.selected=="primary" and vehicle.turret_yaw==0 and vehicle.gun_pitch==0,"respawn clears occupancy, controls, reload and turret state: "+vehicle.kind)
		remote.receive(vehicle.snapshot())
		check(not remote.destroyed and remote.visible and remote.global_position.is_equal_approx(original),"remote respawn snaps directly to base without interpolating across the map: "+vehicle.kind)
		remote.queue_free()
	game.queue_free();await process_frame;await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"note":"Uses real authority damage and respawn methods; countdown is advanced deterministically."}
	NavalStorage.write_json("res://tests/war-vehicle-respawn-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
