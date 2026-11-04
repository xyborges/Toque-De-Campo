extends WarVehicle

# Keep the production snapshot/receive implementations and omit map/models.
func _ready() -> void:
	turret=Node3D.new();add_child(turret)
	elevation=Node3D.new();turret.add_child(elevation)
func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
func update_wreck(_delta: float) -> void: pass
