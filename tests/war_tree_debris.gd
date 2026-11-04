extends Node3D

# Experimental client-only presentation for real indexed trees. Intact trees
# have no processing; 12 pooled rigid bodies exist but remain frozen/disabled.
const MAX_FALLING:=12
const SETTLE_AFTER:=3.0
var index: RefCounted
var game: Node
var reserved: Dictionary={}
var pool: Array[Dictionary]=[]
var stump_mesh: CylinderMesh
var log_mesh: CylinderMesh
var material: StandardMaterial3D

func _ready() -> void:
	set_physics_process(false)
	if DisplayServer.get_name()=="headless": return
	material=StandardMaterial3D.new();material.albedo_color=Color("4b493b");material.roughness=.98
	stump_mesh=CylinderMesh.new();stump_mesh.height=.4;stump_mesh.top_radius=.12;stump_mesh.bottom_radius=.18;stump_mesh.radial_segments=6
	log_mesh=CylinderMesh.new();log_mesh.height=4.;log_mesh.top_radius=.11;log_mesh.bottom_radius=.18;log_mesh.radial_segments=6
	for cell: Vector2i in index.cells:
		var entries: Array=index.cells[cell]
		var stump:=_reserve(stump_mesh,entries);var fallen:=_reserve(log_mesh,entries)
		reserved[cell]={"stump":stump,"fallen":fallen,"stump_node":null,"fallen_node":null}
	for i in MAX_FALLING:
		var body:=RigidBody3D.new();body.name="PooledTreeDebris";body.freeze=true;body.collision_layer=0;body.collision_mask=1;body.can_sleep=true;body.hide();add_child(body)
		var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.17;cylinder.height=4.;shape.shape=cylinder;shape.disabled=true;body.add_child(shape)
		var visual:=MeshInstance3D.new();visual.mesh=log_mesh;visual.material_override=material;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;body.add_child(visual)
		pool.append({"body":body,"shape":shape,"active":false})

func _reserve(mesh: Mesh,entries: Array) -> MultiMesh:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=entries.size()
	for i in entries.size(): mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),entries[i].position))
	return mm

func _node(cell: Vector2i,kind: String) -> MultiMeshInstance3D:
	var state: Dictionary=reserved[cell];var key:=kind+"_node"
	if is_instance_valid(state[key]): return state[key]
	var node:=MultiMeshInstance3D.new();node.name="TreeDebris_"+kind;node.multimesh=state[kind];node.material_override=material
	node.visibility_range_end=240.;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);state[key]=node
	return node

func on_break(event: Dictionary,animate: bool) -> void:
	if DisplayServer.get_name()=="headless": return
	var cell: Vector2i=event.cell;var id:=int(event.index);var point: Vector3=index.cells[cell][id].position
	var direction: Vector3=event.direction
	_node(cell,"stump").multimesh.set_instance_transform(id,Transform3D(Basis.IDENTITY,point+Vector3.UP*.2))
	if not animate: _static_fall(cell,id,point,direction);return
	var slot:=-1
	for i in pool.size():
		if not pool[i].active: slot=i;break
	if slot<0: _static_fall(cell,id,point,direction);return
	var entry: Dictionary=pool[slot];entry.active=true;entry.cell=cell;entry.index=id;entry.age=0.
	var body: RigidBody3D=entry.body
	if is_instance_valid(game) and is_instance_valid(game.vehicle_system):
		for vehicle in game.vehicle_system.vehicles.values():
			if is_instance_valid(vehicle): body.add_collision_exception_with(vehicle)
		for actor in game.players.values():
			if actor is PhysicsBody3D: body.add_collision_exception_with(actor)
	body.global_position=point+Vector3.UP*2.;body.rotation=Vector3.ZERO;body.show();body.freeze=false;body.sleeping=false
	(entry.shape as CollisionShape3D).set_deferred("disabled",false)
	body.linear_velocity=direction*.45;body.angular_velocity=Vector3.UP.cross(direction)*1.35
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var active:=false
	for entry in pool:
		if not entry.active: continue
		entry.age+=delta
		if entry.age<SETTLE_AFTER: active=true;continue
		var body: RigidBody3D=entry.body
		_node(entry.cell,"fallen").multimesh.set_instance_transform(entry.index,body.global_transform)
		body.freeze=true;body.hide();(entry.shape as CollisionShape3D).set_deferred("disabled",true);entry.active=false
	if not active: set_physics_process(false)

func _static_fall(cell: Vector2i,id: int,point: Vector3,direction: Vector3) -> void:
	var yaw:=atan2(direction.x,direction.z)
	_node(cell,"fallen").multimesh.set_instance_transform(id,Transform3D(Basis.from_euler(Vector3(PI*.5,yaw,0)),point+direction*2.+Vector3.UP*.15))
