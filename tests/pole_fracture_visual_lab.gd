extends Node3D

# Experimental presentation, not installed in WarPowerGrid. All coordinates
# are local to this test root. Cosmetic falling is animated, not rigid physics.
const Model=preload("res://tests/pole_fracture_model.gd")
const HEIGHT:=8.2
const CELL_SIZE:=90.0
const MAX_FALLING:=12
const FALL_SECONDS:=1.6
const WIRE_PARTS:=8
var cells: Dictionary={}
var entries: Dictionary={}
var wires: Array[Dictionary]=[]
var adjacency: Dictionary={}
var pool: Array[Dictionary]=[]
var max_active:=0
var trunk_mesh: CylinderMesh
var arm_mesh: BoxMesh
var wire_mesh: BoxMesh
var material: StandardMaterial3D

func _ready() -> void:
	set_process(false)
	trunk_mesh=CylinderMesh.new();trunk_mesh.height=1.;trunk_mesh.top_radius=.12;trunk_mesh.bottom_radius=.16;trunk_mesh.radial_segments=7
	arm_mesh=BoxMesh.new();arm_mesh.size=Vector3(1.5,.10,.10)
	wire_mesh=BoxMesh.new();wire_mesh.size=Vector3(.025,1.,.025)
	material=StandardMaterial3D.new();material.albedo_color=Color("737c77");material.roughness=.8
	for i in MAX_FALLING:
		var pivot:=Node3D.new();pivot.name="FallingPole%d"%i;add_child(pivot)
		var shaft:=MeshInstance3D.new();shaft.mesh=trunk_mesh;shaft.material_override=material;shaft.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;pivot.add_child(shaft)
		var arm:=MeshInstance3D.new();arm.mesh=arm_mesh;arm.material_override=material;arm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;pivot.add_child(arm)
		pivot.hide();pool.append({"pivot":pivot,"shaft":shaft,"arm":arm,"active":false})

func _id(cell: Vector2i,index: int) -> String:
	return "%d:%d:%d"%[cell.x,cell.y,index]

func setup(points: Array,connections: Array) -> bool:
	# points order per cell must match the authoritative model on every peer.
	if not cells.is_empty() or not is_inside_tree(): return false
	var grouped: Dictionary={}
	for value in points:
		if typeof(value)!=TYPE_VECTOR3: return false
		var p: Vector3=value
		if not p.is_finite(): return false
		var cell:=Vector2i(floori(p.x/CELL_SIZE),floori(p.z/CELL_SIZE))
		if not grouped.has(cell): grouped[cell]=[]
		grouped[cell].append(p)
	for cell: Vector2i in grouped:
		var positions: Array=grouped[cell];var body:=StaticBody3D.new();body.name="PoleCell_%d_%d"%[cell.x,cell.y];body.collision_layer=1;body.collision_mask=0;add_child(body)
		var shafts:=_batch(trunk_mesh,positions.size(),"IntactShafts");var arms:=_batch(arm_mesh,positions.size(),"IntactArms")
		var stumps:=_batch(trunk_mesh,positions.size(),"BrokenStumps");var fallen:=_batch(trunk_mesh,positions.size(),"FallenShafts");var fallen_arms:=_batch(arm_mesh,positions.size(),"FallenArms")
		cells[cell]={"body":body,"shafts":shafts,"arms":arms,"stumps":stumps,"fallen":fallen,"fallen_arms":fallen_arms}
		for index in positions.size():
			var base: Vector3=positions[index];var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.20;cylinder.height=HEIGHT;shape.shape=cylinder;shape.position=base+Vector3.UP*HEIGHT*.5
			shape.set_meta("surface","metal");shape.set_meta("pole_cell",cell);shape.set_meta("pole_index",index);body.add_child(shape)
			# Reserve the stump shape up front, so breaking does not renumber
			# any shape. Its size and height depend on the authority event.
			var stump_shape:=CollisionShape3D.new();var stump_cylinder:=CylinderShape3D.new();stump_cylinder.radius=.20;stump_cylinder.height=1.;stump_shape.shape=stump_cylinder;stump_shape.disabled=true
			stump_shape.set_meta("surface","metal");stump_shape.set_meta("pole_cell",cell);stump_shape.set_meta("pole_index",index);body.add_child(stump_shape)
			shafts.multimesh.set_instance_transform(index,_shaft(base,Vector3.UP,HEIGHT))
			arms.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,base+Vector3.UP*(HEIGHT-.7)))
			for node in [stumps,fallen,fallen_arms]: node.multimesh.set_instance_transform(index,_hidden())
			entries[_id(cell,index)]={"cell":cell,"index":index,"base":base,"shape":shape,"stump_shape":stump_shape,"broken":false,"height":HEIGHT,"tip":base+Vector3.UP*(HEIGHT-.5)}
	# Each connection is [Vector2i cellA, indexA, Vector2i cellB, indexB].
	var wire_groups: Dictionary={}
	for connection in connections:
		if not connection is Array or connection.size()!=4: return false
		var a:=_id(connection[0],connection[1]);var b:=_id(connection[2],connection[3])
		if not entries.has(a) or not entries.has(b) or a==b: return false
		var source: Vector2i=connection[0]
		if not wire_groups.has(source): wire_groups[source]=[]
		var wire_index:=wires.size();var slot: int=wire_groups[source].size()
		wire_groups[source].append(wire_index);wires.append({"a":a,"b":b,"node":null,"slot":slot,"from":Vector3.ZERO,"to":Vector3.ZERO})
		for id in [a,b]:
			if not adjacency.has(id): adjacency[id]=[]
			adjacency[id].append(wire_index)
	for source: Vector2i in wire_groups:
		var line:=_batch(wire_mesh,WIRE_PARTS*wire_groups[source].size(),"PoleWires_%d_%d"%[source.x,source.y])
		for wire_index: int in wire_groups[source]: wires[wire_index].node=line
	for i in wires.size(): _update_wire(i)
	return true

func _batch(mesh: Mesh,count: int,label: String) -> MultiMeshInstance3D:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=count
	var node:=MultiMeshInstance3D.new();node.name=label;node.multimesh=mm;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=280.;add_child(node)
	return node

func _hidden() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO)

func _shaft(base: Vector3,direction: Vector3,length: float) -> Transform3D:
	var orientation:=Basis(Quaternion(Vector3.UP,direction.normalized()))
	return Transform3D(orientation*Basis.from_scale(Vector3(1.,length,1.)),base+direction*length*.5)

func present(event: Dictionary,animate:=true) -> bool:
	if not event.has_all(["cell","index","direction","height_cm"]): return false
	if typeof(event.cell)!=TYPE_VECTOR2I or typeof(event.index)!=TYPE_INT or typeof(event.direction)!=TYPE_VECTOR3 or typeof(event.height_cm)!=TYPE_INT: return false
	var cell: Vector2i=event.cell;var index: int=event.index;var id:=_id(cell,index)
	if not entries.has(id) or entries[id].broken: return false
	var direction: Vector3=event.direction;direction.y=0.
	if not direction.is_finite() or direction.length_squared()<.000001: return false
	if event.height_cm<70 or event.height_cm>670: return false
	direction=direction.normalized();var h:=float(event.height_cm)*.01
	var entry: Dictionary=entries[id];var group: Dictionary=cells[cell];entry.broken=true;entry.height=h;entry.direction=direction
	group.shafts.multimesh.set_instance_transform(index,_hidden());group.arms.multimesh.set_instance_transform(index,_hidden())
	group.stumps.multimesh.set_instance_transform(index,_shaft(entry.base,Vector3.UP,h))
	(entry.shape as CollisionShape3D).set_deferred("disabled",true)
	var stump_shape: CollisionShape3D=entry.stump_shape
	(stump_shape.shape as CylinderShape3D).height=h
	stump_shape.set_deferred("position",entry.base+Vector3.UP*h*.5)
	stump_shape.set_deferred("disabled",false)
	if animate:
		for slot: Dictionary in pool:
			if slot.active: continue
			slot.active=true;slot.id=id;slot.elapsed=0.;slot.pivot.position=entry.base+Vector3.UP*h
			slot.pivot.rotation=Vector3.ZERO;slot.shaft.scale=Vector3(1.,HEIGHT-h,1.);slot.shaft.position=Vector3.UP*(HEIGHT-h)*.5
			slot.arm.position=Vector3.UP*(HEIGHT-h-.7);slot.pivot.show()
			max_active=maxi(max_active,active_count());set_process(true);return true
	# Pool exhausted or late join: resolve immediately to static debris.
	_settle(id)
	return true

func active_count() -> int:
	var count:=0
	for slot: Dictionary in pool:
		if slot.active: count+=1
	return count

func _process(delta: float) -> void:
	for slot: Dictionary in pool:
		if not slot.active: continue
		var entry: Dictionary=entries[slot.id];slot.elapsed+=maxf(0.,delta)
		var t:=clampf(float(slot.elapsed)/FALL_SECONDS,0.,1.);var ease:=t*t*(3.-2.*t)
		var axis:=Vector3.UP.cross(entry.direction).normalized()
		slot.pivot.basis=Basis(axis,PI*.5*ease)
		# After the upper piece breaks loose, lower it to the ground rather
		# than leaving the fallen shaft floating at the fracture height.
		var ground_progress:=smoothstep(.45,1.,t)
		slot.pivot.position=entry.base+Vector3.UP*lerpf(float(entry.height),.16,ground_progress)
		entry.tip=slot.pivot.position+slot.pivot.basis*Vector3.UP*(HEIGHT-float(entry.height)-.5)
		_update_wires_for(slot.id)
		if t>=1.:
			slot.active=false;slot.pivot.hide();_settle(slot.id)
	if active_count()==0: set_process(false)

func _settle(id: String) -> void:
	var entry: Dictionary=entries[id];var group: Dictionary=cells[entry.cell];var length:=HEIGHT-float(entry.height)
	var base: Vector3=entry.base+Vector3.UP*.16;var direction: Vector3=entry.direction
	group.fallen.multimesh.set_instance_transform(entry.index,_shaft(base,direction,length))
	var orientation:=Basis(Quaternion(Vector3.UP,direction))
	group.fallen_arms.multimesh.set_instance_transform(entry.index,Transform3D(orientation,base+direction*(length-.7)))
	entry.tip=base+direction*(length-.5);_update_wires_for(id)

func _update_wires_for(id: String) -> void:
	for i: int in adjacency.get(id,[]): _update_wire(i)

func _update_wire(index: int) -> void:
	var wire: Dictionary=wires[index];var start: Vector3=entries[wire.a].tip;var end: Vector3=entries[wire.b].tip
	wire.from=start;wire.to=end
	var sag:=3. if entries[wire.a].broken or entries[wire.b].broken else 1.4
	var previous:=start
	wire.min_y=INF
	for part in WIRE_PARTS:
		var t:=float(part+1)/WIRE_PARTS;var next:=start.lerp(end,t)-Vector3.UP*sin(t*PI)*sag
		# The lab uses flat/interpolated support height. The game integration
		# must query the real terrain and quay surfaces instead.
		var floor_y:=lerpf(float(entries[wire.a].base.y),float(entries[wire.b].base.y),t)+.04
		next.y=maxf(next.y,floor_y);wire.min_y=minf(float(wire.min_y),next.y)
		var segment:=next-previous
		var instance:=int(wire.slot)*WIRE_PARTS+part
		if segment.length_squared()>.000001: wire.node.multimesh.set_instance_transform(instance,_shaft(previous,segment.normalized(),segment.length()))
		else: wire.node.multimesh.set_instance_transform(instance,_hidden())
		previous=next
