extends SceneTree
class FakeIndex extends RefCounted:
	var cells: Dictionary={}
class FakeSystems extends Node:
	var vehicles: Dictionary={}
class FakeGame extends Node3D:
	var vehicle_system: Node
	var players: Dictionary={}
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game:=FakeGame.new();root.add_child(game);var systems:=FakeSystems.new();game.add_child(systems);game.vehicle_system=systems
	var floor:=StaticBody3D.new();floor.collision_layer=1;game.add_child(floor)
	var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(180,1,40)
	var floor_node:=CollisionShape3D.new();floor_node.shape=floor_shape;floor_node.position=Vector3(45,-.5,0);floor.add_child(floor_node)
	var vehicle:=StaticBody3D.new();vehicle.collision_layer=1;game.add_child(vehicle);systems.vehicles["mock"]=vehicle
	var vehicle_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,2,4);vehicle_shape.shape=box;vehicle_shape.position=Vector3(3,1,0);vehicle.add_child(vehicle_shape)
	var index:=FakeIndex.new();var cell:=Vector2i.ZERO;var entries: Array=[]
	for i in 18: entries.append({"position":Vector3(i*4.,0,0)})
	index.cells[cell]=entries
	var presenter=load("res://tests/war_tree_debris.gd").new();presenter.index=index;presenter.game=game;game.add_child(presenter)
	check(not presenter.is_physics_processing(),"idle pool is processing")
	for i in 16: presenter.on_break({"cell":cell,"index":i,"direction":Vector3.RIGHT},true)
	var first_body: RigidBody3D=presenter.pool[0].body
	first_body.contact_monitor=true;first_body.max_contacts_reported=8;first_body.global_position=Vector3(3,2.5,0)
	await process_frame;await physics_frame
	var active:=0
	for entry in presenter.pool:
		if entry.active:
			active+=1;check(not entry.body.freeze,"active rigid body is frozen")
			check(vehicle in entry.body.get_collision_exceptions(),"vehicle exception missing")
	check(active==12,"pool limit incorrect")
	for i in range(12,16): check(presenter.reserved[cell].fallen.get_instance_transform(i).basis.determinant()!=0.,"overflow debris absent")
	await create_timer(.4).timeout
	check(vehicle not in first_body.get_colliding_bodies(),"falling debris collided with vehicle")
	await create_timer(3.1).timeout
	for entry in presenter.pool: check(not entry.active and entry.body.freeze,"pool did not settle")
	check(not presenter.is_physics_processing(),"idle pool still processing")
	for i in 16:
		check(presenter.reserved[cell].stump.get_instance_transform(i).basis.determinant()!=0.,"stump absent")
		check(presenter.reserved[cell].fallen.get_instance_transform(i).basis.determinant()!=0.,"settled debris absent")
	presenter.on_break({"cell":cell,"index":16,"direction":Vector3.RIGHT},false)
	check(presenter.reserved[cell].fallen.get_instance_transform(16).basis.determinant()!=0.,"late snapshot did not settle immediately")
	print(JSON.stringify({"ok":failures.is_empty(),"failures":failures,"pool_limit":presenter.MAX_FALLING,"static_debris":17}))
	quit(0 if failures.is_empty() else 1)
