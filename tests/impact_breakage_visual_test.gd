extends SceneTree
const Prototype=preload("res://tests/impact_breakage_visual_prototype.gd")
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: errors.append(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var prototype=Prototype.new();stage.add_child(prototype);await process_frame
	check(not prototype.is_processing(),"intact objects should not run a per-frame loop")
	var cell:=Vector2i.ZERO;var items: Array=[]
	for i in 16: items.append({"kind":"pole" if i%2==0 else "thin","position":Vector3(2.+i*2.,0,2.)})
	prototype.add_cell(cell,items);await physics_frame
	var group: Dictionary=prototype.cells[cell];var body: StaticBody3D=group.body
	var initial:=body.get_shape_owners().size()
	var owner_ids:=body.get_shape_owners()
	for i in items.size():
		var event: Dictionary=prototype.model.impact(cell,i,30000.,4.,Vector3.RIGHT)
		check(not event.is_empty(),"expected break")
		if not event.is_empty(): prototype.accept(event)
	await process_frame;await physics_frame
	check(body.get_shape_owners().size()==initial,"shape count changed")
	check(body.get_shape_owners()==owner_ids,"shape owners changed")
	for record: Dictionary in group.records:
		check(record.collider.disabled,"collider was not disabled")
		var instance: Transform3D=record.visual.multimesh.get_instance_transform(record.visual_index)
		check(instance.basis.determinant()==0.,"original instance must be hidden: %s"%instance.basis)
	var active:=0
	for slot in prototype.pool:
		if slot.active: active+=1
	check(active<=prototype.MAX_FALLING,"pool limit exceeded")
	await create_timer(2.).timeout
	for slot in prototype.pool: check(not slot.active,"falling slot was not released")
	check(not prototype.is_processing(),"idle falling manager should stop processing")
	for i in items.size(): check(group.fallen.multimesh.get_instance_transform(i).basis.determinant()!=0.,"static debris missing")
	print(JSON.stringify({"ok":errors.is_empty(),"errors":errors,"shape_owners":initial,"pool_max":prototype.MAX_FALLING,"broken":prototype.model.broken.size()}))
	quit(0 if errors.is_empty() else 1)
