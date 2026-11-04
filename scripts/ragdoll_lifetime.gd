extends Node3D

var bodies: Dictionary
var materials: Array[StandardMaterial3D]=[]
var persistent:=false
var settled:=false

func begin(body_parts: Dictionary,body_materials: Array[StandardMaterial3D],keep_body:=false) -> void:
	bodies=body_parts;materials=body_materials
	persistent=keep_body
	if persistent:
		var settle:=Timer.new();settle.name="SettleCorpse";settle.one_shot=true;settle.wait_time=6.
		add_child(settle);settle.timeout.connect(freeze_corpse);settle.start()
		return
	# Owned timers disappear with the corpse when a match is left. No scene-tree
	# timer keeps an anonymous capture of a node that may already be freed.
	var fade:=Timer.new();fade.one_shot=true;fade.wait_time=9.0
	add_child(fade);fade.timeout.connect(_fade);fade.start()
	var lifetime:=Timer.new();lifetime.one_shot=true;lifetime.wait_time=11.0
	add_child(lifetime);lifetime.timeout.connect(queue_free);lifetime.start()

func freeze_corpse() -> void:
	if settled:return
	settled=true
	for child in get_children():
		if child is Joint3D:child.queue_free()
	for body: RigidBody3D in bodies.values():
		if not is_instance_valid(body):continue
		body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
		body.collision_layer=0;body.collision_mask=0;body.freeze=true
		body.set_physics_process(false);body.set_process(false)

func _fade() -> void:
	for body in bodies.values():
		if is_instance_valid(body): body.sleeping=true
	for material in materials:
		if not is_instance_valid(material): continue
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		var tween:=create_tween()
		tween.tween_property(material,"albedo_color:a",0.0,2.0)
