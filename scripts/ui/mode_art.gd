extends TextureRect
class_name GameModeArt
var kind := "office"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path:="res://assets/ui/modes/%s.jpg" % kind
	texture = load(path if ResourceLoader.exists(path) else "res://assets/ui/modes/desert.jpg")
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.05,0.06,0.16)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
