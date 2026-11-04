extends Control
class_name BRMinimap

const HALF:=1000.0
var zone: Dictionary={}
var player_position:=Vector3.ZERO
var player_yaw:=0.0
var terrain: Texture2D
var ink: Ink
class Ink extends Control:
	var painter: Callable
	func _draw() -> void:painter.call(self)

func _ready() -> void:
	terrain=load("res://scripts/maps/definition.gd").cartography("afghan")
	custom_minimum_size=Vector2(180,180)
	clip_contents=true
	mouse_filter=MOUSE_FILTER_IGNORE
	ink=Ink.new();ink.painter=_paint;ink.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(ink);ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func present(current: Dictionary,at: Vector3,yaw: float) -> void:
	zone=current;player_position=at;player_yaw=yaw
	if is_instance_valid(ink):ink.queue_redraw()

func _map(p: Vector2) -> Vector2:
	return (p/2000.0+Vector2(.5,.5))*size

func _vector(value: Variant,fallback:=Vector2.ZERO) -> Vector2:
	if value is Vector2: return value
	if value is Vector3: return Vector2(value.x,value.z)
	if value is Array and value.size()>=2: return Vector2(float(value[0]),float(value[1]))
	return fallback

func _paint(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,size),Color(.035,.07,.075,.86))
	if terrain:canvas.draw_texture_rect(terrain,Rect2(Vector2.ZERO,size),false,Color(.8,.85,.8,.95))
	for i in 5:
		var q:=float(i)/4.0
		canvas.draw_line(Vector2(q*size.x,0),Vector2(q*size.x,size.y),Color(.42,.48,.43,.15))
		canvas.draw_line(Vector2(0,q*size.y),Vector2(size.x,q*size.y),Color(.42,.48,.43,.15))
	var center:=_vector(zone.get("center",Vector2.ZERO))
	var target:=_vector(zone.get("target_center",center),center)
	var radius:=maxf(0.,float(zone.get("radius",1000.)))
	var next_radius:=maxf(0.,float(zone.get("target_radius",radius)))
	if radius>0: canvas.draw_arc(_map(center),radius/2000.0*size.x,0,TAU,80,FieldTheme.ACCENT,1.8,true)
	if next_radius>0: canvas.draw_arc(_map(target),next_radius/2000.0*size.x,0,TAU,64,Color(.8,.86,.85,.65),1.,true)
	var p:=_map(Vector2(player_position.x,player_position.z)).clamp(Vector2.ONE*4,size-Vector2.ONE*4)
	var facing:=Vector2(-sin(player_yaw),-cos(player_yaw))
	canvas.draw_colored_polygon(PackedVector2Array([p+facing*7,p+facing.rotated(2.45)*5,p+facing.rotated(-2.45)*5]),Color.WHITE)
	canvas.draw_rect(Rect2(Vector2.ZERO,size),FieldTheme.BORDER,false,1.)
