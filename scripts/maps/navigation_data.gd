extends Resource
@export var source_hash:=""
@export var map_id:=""
@export var region:=Rect2i()
@export var cell_size:=Vector2.ONE
@export var offset:=Vector2.ZERO
@export var blocked:=PackedByteArray()
@export var weights:=PackedFloat32Array()
@export var heights:=PackedFloat32Array()
