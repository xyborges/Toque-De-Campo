extends GameItemPreview

signal slot_clicked(slot: String)
var available: Dictionary={}
var hovered:=""
var highlighted: Dictionary={}
var overlay: StandardMaterial3D
var idle_clock:=0.0

func _ready() -> void:
	super._ready();mouse_filter=Control.MOUSE_FILTER_STOP
	for node in stage.get_children():
		if node is WorldEnvironment or node is Light3D:stage.remove_child(node);node.free()
	LoginBackdrop.populate(stage);camera.far=120
	overlay=StandardMaterial3D.new();overlay.albedo_color=Color(FieldTheme.ACCENT,.24)
	overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	gui_input.connect(_pointer);mouse_exited.connect(func():_highlight(""))
	set_process(true)

func show_item(kind: String,values: Dictionary={}) -> void:
	_highlight("");super.show_item(kind,values)
	idle_clock=0.
	_fit_camera()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or subject!="person" or not is_instance_valid(actor) or not is_instance_valid(actor.weapon_root) or not actor.weapon_root.visible:return
	idle_clock+=delta
	actor.pitch=.025+sin(idle_clock*1.4)*.008
	actor.body_root.position.y=sin(idle_clock*1.4)*.003
	actor._update_weapon_pose();actor._pose_weapon_arms()
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func _fit_camera() -> void:
	if not is_instance_valid(camera):return
	if subject!="person":super._fit_camera();return
	var long_tool: bool=is_instance_valid(actor) and actor.weapon_id in ["axe","broom","squeegee"]
	camera.fov=32;camera.position=Vector3(0,1.18 if long_tool else 1.05,-6.0 if long_tool else -5.0)
	camera.look_at(Vector3(0,1.14 if long_tool else 1.02,0))

func _pointer(event: InputEvent) -> void:
	if event is InputEventMouseMotion:_highlight(_pick(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var slot:=_pick(event.position)
		if not slot.is_empty():slot_clicked.emit(slot);accept_event()

func _targets(slot: String) -> Array:
	if not is_instance_valid(actor):return []
	if slot=="optic":
		return [actor.weapon_optics.world_scope] if is_instance_valid(actor.weapon_optics.world_scope) else []
	if slot==held_slot:return [actor.weapon_root] if is_instance_valid(actor.weapon_root) else []
	if slot=="helmet":return [actor.avatar_parts.get("head")]
	if slot=="vest":return [actor.avatar_parts.get("torso")]
	return []

func _meshes(slot: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	for target in _targets(slot):
		if not is_instance_valid(target):continue
		if target is MeshInstance3D and target.is_visible_in_tree():result.append(target)
		for mesh: MeshInstance3D in target.find_children("*","MeshInstance3D",true,false):
			if mesh.is_visible_in_tree():result.append(mesh)
	return result

func _pick(point: Vector2) -> String:
	if not is_instance_valid(camera) or not is_instance_valid(view) or size.x<=0 or size.y<=0:return ""
	var pixel:=point*Vector2(view.size)/size
	# Small mounted optics take precedence over the weapon, which precedes
	# the torso behind it. Mesh bounds follow the actual avatar and pose.
	for slot in ["optic",held_slot,"helmet","vest"]:
		if not available.has(slot):continue
		for mesh in _meshes(slot):
			var bounds:=mesh.get_aabb();var rect:=Rect2();var first:=true
			for index in 8:
				var p: Vector3=mesh.global_transform*(bounds.position+bounds.size*Vector3(index&1,(index>>1)&1,(index>>2)&1))
				if camera.is_position_behind(p):continue
				var screen:=camera.unproject_position(p)
				if first:rect=Rect2(screen,Vector2.ZERO);first=false
				else:rect=rect.expand(screen)
			if not first and rect.grow(4).has_point(pixel):return slot
	return ""

func _highlight(slot: String) -> void:
	if hovered==slot:return
	for ref: WeakRef in highlighted:
		var mesh: MeshInstance3D=ref.get_ref()
		if is_instance_valid(mesh):mesh.material_overlay=highlighted[ref]
	highlighted.clear();hovered=slot
	for mesh in _meshes(slot):
		highlighted[weakref(mesh)]=mesh.material_overlay;mesh.material_overlay=overlay
	tooltip_text=str(GameLoadouts.TITLES.get(slot,""));mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if not slot.is_empty() else Control.CURSOR_ARROW
	if is_instance_valid(view):view.render_target_update_mode=SubViewport.UPDATE_ONCE

func _exit_tree() -> void:
	_highlight("");super._exit_tree()
