@tool
extends Node3D
class_name WarTrenchModule
@export_range(.8,2.8,.05) var depth:=1.5:
	set(value):
		depth=clampf(value,.8,2.8);refresh()
@export var excavate:=true:
	set(value): excavate=value;refresh()

func _ready() -> void:
	refresh()
	set_notify_transform(true)

func refresh() -> void:
	var lining:=get_node_or_null("Revestimento") as Node3D
	if lining: lining.position.y=-depth;lining.scale.y=depth/1.5
	if Engine.is_editor_hint() and is_inside_tree(): get_tree().call_group("war_map_authoring","terrain_edit_changed")

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_inside_tree(): get_tree().call_group("war_map_authoring","terrain_edit_changed")

func _exit_tree() -> void:
	if Engine.is_editor_hint(): get_tree().call_group("war_map_authoring","terrain_edit_changed")
