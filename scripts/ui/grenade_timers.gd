extends Control
class_name GameGrenadeTimers

const LIMIT:=8
const DISTANCE:=24.0
var game: Node
var widgets: Array[Dictionary]=[]
var clock:=0.0

func _ready() -> void:
	name="GrenadeTimers";mouse_filter=MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in LIMIT:
		var widget:=VBoxContainer.new();widget.mouse_filter=MOUSE_FILTER_IGNORE;widget.custom_minimum_size=Vector2(66,24);widget.add_theme_constant_override("separation",2);add_child(widget)
		var label:=GameUI.label(widget,"",13,FieldTheme.ACCENT);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size=Vector2(66,3);bar.max_value=GameGrenades.FUSE;bar.mouse_filter=MOUSE_FILTER_IGNORE;widget.add_child(bar)
		widgets.append({"node":widget,"text":label,"bar":bar});widget.hide()

func _process(delta: float) -> void:
	clock+=delta
	if clock<.1: return
	clock=0;refresh()

func refresh() -> void:
	for widget in widgets: widget.node.hide()
	if not is_instance_valid(game.grenades_system) or not is_instance_valid(game.local_player) or game.mode=="menu": return
	var actor: GamePlayer=game.local_player
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	var candidates: Array=[]
	for round: Dictionary in game.grenades_system.rounds.values():
		if round.held or float(round.left)<=0 or not is_instance_valid(round.node): continue
		var point: Vector3=round.position
		if point.distance_to(actor.camera_pivot.global_position)>DISTANCE or camera.is_position_behind(point): continue
		var screen:=camera.unproject_position(point)
		if not get_viewport_rect().grow(-24).has_point(screen): continue
		var query:=PhysicsRayQueryParameters3D.create(camera.global_position,point,1)
		var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and Vector3(hit.position).distance_to(point)>.16: continue
		candidates.append({"round":round,"screen":screen,"distance":point.distance_squared_to(actor.global_position)})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	for i in mini(LIMIT,candidates.size()):
		var widget: Dictionary=widgets[i];var round: Dictionary=candidates[i].round
		widget.node.position=Vector2(candidates[i].screen)+Vector2(-33,-38)
		var text: String=("%.1f s"%maxf(0,float(round.left))).replace(".",",")
		if widget.text.text!=text: widget.text.text=text
		var color:=FieldTheme.BAD if float(round.left)<1.2 else FieldTheme.ACCENT
		if widget.text.get_meta("color",Color.TRANSPARENT)!=color:
			widget.text.add_theme_color_override("font_color",color);widget.text.set_meta("color",color)
		widget.bar.value=float(round.left);widget.node.show()
