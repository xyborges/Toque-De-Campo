extends Resource
class_name GameAttachmentSocket

@export var id:=""
@export var ui_label:=""
@export var categories:=PackedStringArray()
@export var interfaces:=PackedStringArray()
@export var available_space:=Vector3(.2,.3,.4)
@export var transform:=Transform3D.IDENTITY
@export var source_node:=NodePath("")
@export var fitting_tags:=PackedStringArray()
@export var required_tags:=PackedStringArray()
@export var denied_tags:=PackedStringArray()
@export var hide_base_when_occupied:=PackedStringArray()
@export var ui_position:=Vector2(.5,.5)
@export var allow_multiple:=false
@export var rail_length:=0.
@export var rail_axis:=Vector3.FORWARD
