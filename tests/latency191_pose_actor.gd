extends "res://scripts/player.gd"

func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
func receive_network_state(pos: Vector3, new_yaw: float, new_pitch: float) -> void:
	network_target=pos;network_yaw=new_yaw;network_pitch=new_pitch
