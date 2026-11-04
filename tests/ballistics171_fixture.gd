extends "res://scripts/main.gd"
var impact_time:=-1.0
var impact_position:=Vector3.ZERO
func _build_desert() -> void: pass
func _present_impact(id: String,point: Vector3,normal: Vector3,blood: bool) -> void:
	impact_time=Time.get_ticks_msec()*.001;impact_position=point
	super._present_impact(id,point,normal,blood)
