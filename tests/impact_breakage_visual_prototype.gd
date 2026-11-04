extends Node3D

# Temporary proof of the grouped presentation only; do not attach to live
# WarGame until authoritative replication, navigation and all tests are done.
const Model=preload("res://tests/impact_breakage_model.gd")
const MAX_FALLING:=12
var model=Model.new()
var cells: Dictionary={}
var pool: Array[Dictionary]=[]
var material: StandardMaterial3D
var fallen_mesh: CylinderMesh

func _ready() -> void:
	set_process(false)
	material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	fallen_mesh=CylinderMesh.new();fallen_mesh.height=4.;fallen_mesh.top_radius=.11;fallen_mesh.bottom_radius=.18;fallen_mesh.radial_segments=6
	for i in MAX_FALLING:
		var visual:=MeshInstance3D.new();visual.mesh=fallen_mesh;visual.material_override=material;visual.hide();visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
		pool.append({"visual":visual,"active":false})

func add_cell(cell: Vector2i,items: Array) -> void:
	model.register(cell,items)
	var body:=StaticBody3D.new();body.name="GroupedCollision";body.collision_layer=1;body.collision_mask=0;add_child(body)
	var mm_by_kind: Dictionary={};var grouped: Dictionary={};var records: Array=[]
	for kind in ["pole","thin","thick","burnt"]: grouped[kind]=[]
	for item: Dictionary in items: grouped[item.kind].append(item)
	for kind in grouped:
		var entries: Array=grouped[kind]
		if entries.is_empty(): continue
		var mesh: Mesh=fallen_mesh if kind=="pole" else WarVegetation.tree_mesh(kind!="burnt",0,true)
		var mm:=_batch(mesh,entries.size());mm_by_kind[kind]=mm
		for i in entries.size(): mm.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,entries[i].position))
	var stump_mesh:=CylinderMesh.new();stump_mesh.height=.4;stump_mesh.top_radius=.12;stump_mesh.bottom_radius=.18;stump_mesh.radial_segments=6
	var stumps:=_batch(stump_mesh,items.size());var fallen:=_batch(fallen_mesh,items.size())
	var indices: Dictionary={"pole":0,"thin":0,"thick":0,"burnt":0}
	for i in items.size():
		var item: Dictionary=items[i];var kind: String=item.kind
		var shape:=CylinderShape3D.new();shape.radius=.18 if kind!="thick" else .32;shape.height=4.
		var collider:=CollisionShape3D.new();collider.shape=shape;collider.position=item.position+Vector3.UP*2.;body.add_child(collider)
		records.append({"collider":collider,"visual":mm_by_kind[kind],"visual_index":indices[kind],"position":item.position})
		indices[kind]+=1
		stumps.multimesh.set_instance_transform(i,_hidden(item.position));fallen.multimesh.set_instance_transform(i,_hidden(item.position))
	cells[cell]={"body":body,"records":records,"stumps":stumps,"fallen":fallen}

func _batch(mesh: Mesh,count: int) -> MultiMeshInstance3D:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=count
	var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node

func _hidden(point: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO),point)

func vehicle_contact(vehicle: CharacterBody3D,mass: float,pre_collision_velocity: Vector3) -> Array[Dictionary]:
	# Caller is the authority and supplies velocity from before move_and_slide;
	# afterward that method may already have clipped velocity to zero.
	var events: Array[Dictionary]=[]
	for slide in vehicle.get_slide_collision_count():
		var contact:=vehicle.get_slide_collision(slide)
		for hit in contact.get_collision_count():
			var body:=contact.get_collider(hit) as StaticBody3D
			if not is_instance_valid(body): continue
			for cell in cells:
				var group: Dictionary=cells[cell]
				if group.body!=body: continue
				var shape_node:=contact.get_collider_shape(hit)
				for index in group.records.size():
					if group.records[index].collider!=shape_node: continue
					var event: Dictionary=model.impact(cell,index,mass,pre_collision_velocity.length(),pre_collision_velocity)
					if event.is_empty(): continue
					accept(event);events.append(event)
					vehicle.velocity*=.68
					if vehicle is WarVehicle: vehicle.speed*=.68
	return events

func accept(event: Dictionary) -> void:
	var cell: Vector2i=event.cell;var index:=int(event.index)
	var group: Dictionary=cells[cell];var record: Dictionary=group.records[index]
	var visual: MultiMeshInstance3D=record.visual
	visual.multimesh.set_instance_transform(record.visual_index,_hidden(record.position))
	var stump: MultiMeshInstance3D=group.stumps
	stump.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,record.position+Vector3.UP*.2))
	# Do not remove or reorder CollisionShape3D children: stable shape indices.
	(record.collider as CollisionShape3D).set_deferred("disabled",true)
	var slot:=-1
	for i in pool.size():
		if not pool[i].active: slot=i;break
	if slot<0:
		_settle(cell,index,event.direction);return
	var entry: Dictionary=pool[slot];entry.active=true;entry.cell=cell;entry.index=index;entry.direction=event.direction;entry.elapsed=0.
	entry.visual.global_position=record.position+Vector3.UP*2.;entry.visual.rotation=Vector3.ZERO;entry.visual.show()
	set_process(true)

func _process(delta: float) -> void:
	var any_active:=false
	for entry in pool:
		if not entry.active: continue
		entry.elapsed+=delta
		var progress:=clampf(float(entry.elapsed)/1.4,0.,1.)
		var direction: Vector3=entry.direction
		var yaw:=atan2(direction.x,direction.z)
		var angle:=PI*.5*progress*progress
		var point: Vector3=cells[entry.cell].records[entry.index].position
		entry.visual.global_position=point+Vector3.UP*(2.*cos(angle))+direction*(2.*sin(angle))
		entry.visual.rotation=Vector3(angle,yaw,0)
		if progress>=1.:
			_settle(entry.cell,entry.index,direction);entry.visual.hide();entry.active=false
		else: any_active=true
	if not any_active: set_process(false)

func _settle(cell: Vector2i,index: int,direction: Vector3) -> void:
	var group: Dictionary=cells[cell];var point: Vector3=group.records[index].position
	var yaw:=atan2(direction.x,direction.z)
	var basis:=Basis.from_euler(Vector3(PI*.5,yaw,0))
	var fallen: MultiMeshInstance3D=group.fallen
	fallen.multimesh.set_instance_transform(index,Transform3D(basis,point+direction*2.+Vector3.UP*.15))
