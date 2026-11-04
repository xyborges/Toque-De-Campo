extends Resource
## Cell-local GPU transforms, baked against the final physical map.
@export var source_hash:=""
@export var map_id:=""
@export var cell_size:=20.0
@export var capacity:=100
@export var buffers: Dictionary={}
@export var counts: Dictionary={}
@export var bounds: Dictionary={}
@export var patches:=0
@export var far_buffers: Dictionary={}
@export var far_counts: Dictionary={}
@export var far_bounds: Dictionary={}
