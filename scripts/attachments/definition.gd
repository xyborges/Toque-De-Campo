extends Resource
class_name GameAttachmentDefinition

@export var id:=""
@export var display_name:=""
@export var category:=""
@export var required_interfaces:=PackedStringArray()
@export var required_weapon_tags:=PackedStringArray()
@export var tags:=PackedStringArray()
@export var conflict_tags:=PackedStringArray()
@export var required_space:=Vector3(.05,.05,.10)
@export var weight:=4.
@export var scene_reference: PackedScene
@export var mount_reference:=NodePath("MountReference")
@export var eye_reference:=NodePath("Eye")
@export var reticle_reference:=NodePath("Lens")
@export var modifiers_flat: Dictionary={}
@export var modifiers_percent: Dictionary={}
@export var modifiers_override: Dictionary={}
@export var behavior_type:=""
@export var behavior_parameters: Dictionary={}
@export var state_schema: Dictionary={}
@export var provided_sockets: Array[Resource]=[]
@export var fittings: Dictionary={}
@export var production:=true
