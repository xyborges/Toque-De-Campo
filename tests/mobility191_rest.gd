extends SceneTree

class World extends Node3D:
	var game: WarGame
	func flood_vehicle(_vehicle: WarVehicle) -> void: pass

class MeasuredVehicle extends WarVehicle:
	var aim_calls:=0
	var gear_calls:=0
	func aim(delta: float,point: Vector3,immediate:=false) -> void:
		aim_calls+=1;super.aim(delta,point,immediate)
	func animate_running_gear(delta: float) -> void:
		gear_calls+=1;super.animate_running_gear(delta)

var checks:=0
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
var world: World
var floor_body: StaticBody3D
var floor_collision: CollisionShape3D
var vehicle: MeasuredVehicle

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func create(kind: String) -> void:
	world=World.new();world.game=WarGame.new();root.add_child(world)
	floor_body=StaticBody3D.new();floor_body.position=Vector3(0,9.5,0);floor_body.collision_layer=1
	floor_collision=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,1,40);floor_collision.shape=box;floor_body.add_child(floor_collision);world.add_child(floor_body)
	vehicle=MeasuredVehicle.new();vehicle.kind=kind;vehicle.vehicle_id="rest_"+kind;vehicle.position=Vector3(0,10.1,0);world.add_child(vehicle)

func tick(count: int,control: Dictionary={}) -> void:
	for frame in count:
		world.game.war_clock+=1./60.;vehicle.simulate(1./60.,control);await physics_frame

func cleanup() -> void:
	var game:=world.game;world.queue_free();await physics_frame;await physics_frame;game.free()

func rest_and_timers(kind: String) -> void:
	create(kind);await tick(120)
	check(vehicle.resting,kind+": empty stable hull enters rest")
	var before:=vehicle.aim_calls;var gears:=vehicle.gear_calls
	vehicle.ammo=0;vehicle.reserve=30;vehicle.reloading=true;vehicle.reload_left=.4
	vehicle.secondary_ammo=0;vehicle.secondary_reserve=3;vehicle.secondary_reload_left=.4;vehicle.fire_wait=.8;vehicle.secondary_fire_wait=.8
	await tick(120)
	var active:=vehicle.aim_calls-before
	measurements.append({"kind":kind,"ticks":120,"active_motion_ticks":active,"skipped_motion_ticks":120-active})
	check(active<=20 and vehicle.gear_calls-gears==active,kind+": rest skips at least 100/120 motion/aim/gear ticks")
	check(not vehicle.reloading and vehicle.ammo==vehicle.capacity() and vehicle.secondary_ammo==mini(3,int(WarRules.SECONDARY[kind].capacity)) and vehicle.fire_wait==0 and vehicle.secondary_fire_wait==0,kind+": rest preserves weapon reload and cooldown timers")
	vehicle.allocate_seat(77);before=vehicle.aim_calls;await tick(90)
	check(not vehicle.resting and vehicle.aim_calls-before==90,kind+": entry immediately wakes and occupied hull never skips simulation")
	vehicle.clear_seats();await tick(120);check(vehicle.resting,kind+": empty hull can rest again after exit")
	await tick(1,{"throttle":.5});check(not vehicle.resting and vehicle.speed>0,kind+": control wakes on the same tick")
	await cleanup()

func changed_support(kind: String,change: String) -> void:
	create(kind);await tick(120);check(vehicle.resting,kind+" / "+change+": starts with stable rest")
	var before_y:=vehicle.position.y
	match change:
		"removed": floor_body.queue_free();await physics_frame
		"moved": floor_body.position.y-=1.;await physics_frame
		"shape_moved": floor_collision.position.y-=1.;await physics_frame
		"disabled": floor_collision.disabled=true;await physics_frame
		"layer": floor_body.collision_layer=0;await physics_frame
		"replaced":
			var box:=BoxShape3D.new();box.size=Vector3(40,.2,40);floor_collision.shape=box;await physics_frame
		"reshaped":
			(floor_collision.shape as BoxShape3D).size.y=.2
			check(not vehicle.resting,kind+": shape changed signal wakes before the next tick")
			await physics_frame
		"teleport": vehicle.position.y+=2;before_y=vehicle.position.y
	await tick(1)
	check(not vehicle.resting and vehicle.position.y<before_y-.001,kind+" / "+change+": wakes and falls on first simulation tick")
	await cleanup()

func changed_state(kind: String,change: String) -> void:
	create(kind);await tick(120);check(vehicle.resting,kind+" / "+change+": starts with stable rest")
	# Leave a complete validation interval available: waking must come from
	# this mutation rather than the ordinary periodic support recheck.
	vehicle.rest_check_left=.15
	var before:=vehicle.aim_calls
	match change:
		"hp": vehicle.hp-=1
		"selected": vehicle.selected="secondary"
		"turret_yaw": vehicle.turret_yaw+=.1
		"gun_pitch": vehicle.gun_pitch+=.1
		"aim_target": vehicle.aim_target+=Vector3(2,1,0)
	await tick(1)
	check(not vehicle.resting and vehicle.aim_calls==before+1,kind+" / "+change+": external state mutation resumes simulation on the first tick")
	await cleanup()

func sequence_order() -> void:
	create("guarani")
	var state:=vehicle.snapshot();state.position=Vector3(1,10,1);vehicle.receive(state)
	check(vehicle.destination==state.position,"legacy snapshot works before first sequenced packet")
	state.sequence=10;state.position=Vector3(10,10,1);vehicle.receive(state)
	var old:=state.duplicate(true);old.sequence=9;old.position=Vector3(9,10,1);old.hp=1;old.destroyed=true;vehicle.receive(old)
	check(vehicle.destination==state.position and vehicle.hp!=1 and not vehicle.destroyed,"older same-seat snapshot cannot rewind pose, health or destruction")
	old.sequence=10;vehicle.receive(old);check(vehicle.destination==state.position,"duplicate sequence cannot overwrite accepted state")
	old.erase("sequence");vehicle.receive(old);check(vehicle.destination==state.position,"unsequenced state cannot overwrite sequenced stream")
	vehicle.receive_seats({},3,3);old=state.duplicate(true);old.sequence=100;old.seats_revision=2;vehicle.receive(old)
	check(vehicle.received_state_sequence==10,"old seat generation does not advance the motion sequence")
	state.sequence=11;state.seats_revision=3;state.position=Vector3(11,10,1);vehicle.receive(state)
	check(vehicle.destination==state.position and vehicle.received_state_sequence==11,"fresh current-seat packet survives late high sequence from previous generation")
	state.sequence=12;state.destroyed=true;vehicle.receive(state);state.sequence=13;state.destroyed=false;vehicle.receive(state);vehicle.receive(old)
	check(vehicle.received_state_sequence==13 and not vehicle.destroyed,"respawn keeps monotonic receive sequence")
	await cleanup()

func run() -> void:
	for kind in ["guarani","bmp2","abrams","t90"]:
		await rest_and_timers(kind)
		for change in ["removed","moved","shape_moved","disabled","layer","replaced","reshaped","teleport"]: await changed_support(kind,change)
		for change in ["hp","selected","turret_yaw","gun_pitch","aim_target"]: await changed_state(kind,change)
	await sequence_order()
	var result: Dictionary={"checks":checks,"failures":failures,"rest_motion":measurements,"fixture":"Real WarVehicle physics, static support mutation, weapon timers, occupied control and out-of-order observer snapshots."}
	NavalStorage.write_json("res://tests/mobility191-rest-results.json",result);print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
