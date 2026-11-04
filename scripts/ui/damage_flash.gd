extends ColorRect
class_name GameDamageFlash
var animation: Tween
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	color=Color(.12,.012,.008,0)
func pulse(amount: float,health_percent: float) -> void:
	if animation and animation.is_valid(): animation.kill()
	var intensity:=clampf(.20+amount*.004+(1-health_percent/100)*.15,.22,.65)
	color=Color(.12,.012,.008,maxf(color.a,intensity))
	animation=create_tween()
	animation.tween_property(self,"color:a",0.0,.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
func reset() -> void:
	if animation and animation.is_valid(): animation.kill()
	color.a=0
