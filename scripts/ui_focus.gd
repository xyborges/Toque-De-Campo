extends CanvasLayer
class_name GameUIFocus

signal changed
var stack: Array[Control] = []
var shield: ColorRect
var restore_focus: Dictionary = {}
var feedback: GameUIFeedback

func _ready() -> void:
	layer = 40
	feedback = GameUIFeedback.new()
	add_child(feedback)
	shield = ColorRect.new()
	shield.color = Color(0.025,0.05,0.06,0.86)
	shield.theme = GameUI.THEME
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	shield.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton: shield.accept_event()
	)
	add_child(shield)
	shield.hide()
	get_viewport().size_changed.connect(_resize_panels)

func open(panel: Control) -> void:
	if panel in stack:
		while stack.back()!=panel: close_top()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus: restore_focus[panel.get_instance_id()] = weakref(focus)
	if not stack.is_empty(): stack.back().hide()
	if panel.get_parent() != shield:
		panel.reparent(shield)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if panel.get_meta("fullscreen",false):
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var desired: Vector2=panel.get_meta("preferred_size",Vector2(560,620))
		var extent := Vector2(minf(desired.x, get_viewport().get_visible_rect().size.x - 32), minf(desired.y, get_viewport().get_visible_rect().size.y - 32))
		panel.offset_left = -extent.x / 2
		panel.offset_right = extent.x / 2
		panel.offset_top = -extent.y / 2
		panel.offset_bottom = extent.y / 2
	stack.append(panel)
	shield.show()
	shield.mouse_filter=Control.MOUSE_FILTER_STOP
	if panel.has_meta("ui_process_before"):panel.process_mode=int(panel.get_meta("ui_process_before"))
	panel.modulate.a=1.;panel.scale=Vector2.ONE;panel.show()
	if not panel is GameLoginScreen:
		feedback.watch(panel)
		GameUI.fade(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if panel.has_method("focus_initial"): panel.call_deferred("focus_initial")
	else: _focus_first(panel)
	changed.emit()

func open_root(panel: Control) -> void:
	# Screen navigation must not leave unrelated pages behind the root.
	if stack.size()==1 and stack[0]==panel: return
	close_all()
	open(panel)

func open_route(panel: Control, root_page: Control) -> void:
	# A route has at most a home page and one destination. Modal overlays
	# still use open() and retain the normal LIFO back behavior.
	if panel==root_page:
		open_root(root_page)
		return
	if stack.size()==2 and stack[0]==root_page and stack[1]==panel: return
	if stack.size()==1 and stack[0]==root_page:
		open(panel)
		return
	if stack.size()==2 and stack[0]==root_page:
		close_top()
		open(panel)
		return
	close_all()
	open(root_page)
	open(panel)

func back() -> bool:
	if stack.is_empty(): return false
	var top: Control=stack.back()
	if bool(top.get_meta("ui_back_locked",false)): return true
	var action: Variant=top.get_meta("ui_back_action") if top.has_meta("ui_back_action") else null
	if action is Callable and action.is_valid(): action.call()
	else: close_top()
	return true

func close_top() -> void:
	if stack.is_empty(): return
	var panel: Control = stack.pop_back()
	GameUI.dismiss(panel)
	# When revealing an underlying modal, hide the dismissed overlay now;
	# keeping it drawn during the fade obscures the restored menu.
	# The last modal can retain the original animated dismissal.
	if not stack.is_empty() or bool(panel.get_meta("ui_instant_close",false)): panel.hide()
	if not stack.is_empty():
		stack.back().show()
	else:
		shield.mouse_filter=Control.MOUSE_FILTER_IGNORE
		get_tree().create_timer(.11).timeout.connect(func():if stack.is_empty():shield.hide())
	var prior: WeakRef = restore_focus.get(panel.get_instance_id())
	restore_focus.erase(panel.get_instance_id())
	if prior and is_instance_valid(prior.get_ref()) and prior.get_ref().is_visible_in_tree():
		prior.get_ref().grab_focus()
	changed.emit()

func close_all() -> void:
	while not stack.is_empty(): close_top()

func blocked() -> bool:
	return not stack.is_empty()

func _focus_first(parent: Node) -> bool:
	for child in parent.get_children():
		if child is Button and child.visible:
			child.grab_focus()
			return true
		if _focus_first(child): return true
	return false

func _resize_panels() -> void:
	for panel in stack:
		if panel.get_meta("fullscreen",false):
			panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			continue
		var desired: Vector2=panel.get_meta("preferred_size",Vector2(560,620))
		var extent := Vector2(minf(desired.x,get_viewport().get_visible_rect().size.x - 32),minf(desired.y,get_viewport().get_visible_rect().size.y - 32))
		panel.offset_left = -extent.x / 2
		panel.offset_right = extent.x / 2
		panel.offset_top = -extent.y / 2
		panel.offset_bottom = extent.y / 2
