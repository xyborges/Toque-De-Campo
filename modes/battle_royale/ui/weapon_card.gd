extends PanelContainer
class_name BRWeaponCard
signal weapon_pressed(index: int)
signal drop_pressed(index: int)
signal socket_pressed(index: int,path: String,button: Button)
const REGISTRY=preload("res://scripts/attachments/registry.gd")
const STATE=preload("res://scripts/attachments/state.gd")
var index:=0
var weapon:=""
var header: Button
var ammo: Label
var drop: Button
var stage: Control
var silhouette: TextureRect
var slots: Dictionary={}
var slot_signature:=-1
var normal_style: StyleBoxFlat
var current_style: StyleBoxFlat
var configuration: Dictionary={}

func _ready() -> void:
	name="WeaponCard%d"%(index+1);custom_minimum_size=Vector2(260,195)
	normal_style=FieldTheme.box(Color("0d181a"),FieldTheme.BORDER,9)
	current_style=FieldTheme.box(Color("182b24"),FieldTheme.ACCENT,9);current_style.border_width_left=3
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",3);add_child(content)
	var row:=HBoxContainer.new();content.add_child(row)
	header=GameUI.button(row,str(index+1)+"  —",func():weapon_pressed.emit(index));header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.alignment=HORIZONTAL_ALIGNMENT_LEFT;header.custom_minimum_size.y=32;header.add_theme_font_size_override("font_size",14)
	ammo=GameUI.label(row,"",13,FieldTheme.MUTED);ammo.autowrap_mode=TextServer.AUTOWRAP_OFF;ammo.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	drop=GameUI.button(row,"×",func():drop_pressed.emit(index));drop.custom_minimum_size=Vector2(30,30);drop.tooltip_text="Largar arma"
	stage=Control.new();stage.custom_minimum_size.y=140;stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(stage)
	silhouette=TextureRect.new();silhouette.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;silhouette.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	silhouette.mouse_filter=Control.MOUSE_FILTER_IGNORE;silhouette.modulate=Color("c5d0c7");stage.add_child(silhouette)
	silhouette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);silhouette.offset_top=34;silhouette.offset_bottom=-41;silhouette.offset_left=12;silhouette.offset_right=-12
	stage.resized.connect(_place_slots)

func present(id: String,config: Dictionary,mag: int,reserve: int,current: bool,selected: Dictionary={},blocked:=false) -> void:
	weapon=id;configuration=config
	header.text="%d  %s"%[index+1,str(GameWeapons.ITEMS.get(id,{}).get("name","—")).to_upper()]
	header.disabled=id.is_empty();drop.disabled=id.is_empty();ammo.text="%d / %d"%[mag,reserve] if not id.is_empty() else ""
	add_theme_stylebox_override("panel",current_style if current else normal_style)
	silhouette.texture=GameWeaponSilhouette.texture(id)
	var available: Dictionary=STATE.socket_records(id,config) if not id.is_empty() else {}
	var signature:=hash(available)
	if signature!=slot_signature:
		slot_signature=signature
		for button: Button in slots.values():stage.remove_child(button);button.queue_free()
		slots.clear()
		for path in available:
			var button:=Button.new();button.name="Socket_"+str(path).replace("/","_");button.custom_minimum_size=Vector2(46,37);button.size=Vector2(46,37)
			button.expand_icon=true;button.add_theme_constant_override("icon_max_width",28)
			button.pressed.connect(func():socket_pressed.emit(index,str(path),button));stage.add_child(button);slots[path]=button
		_place_slots()
	for path in slots:
		var button: Button=slots[path];var spec: Variant=available[path]
		var installed: Dictionary=config.get(path,{})
		var definition=REGISTRY.definition(str(installed.get("id","")))
		var category:=str(spec.get("category","attachment")) if spec is Dictionary else "attachment"
		if definition:category=str(definition.category)
		button.icon=GameAttachmentIcons.texture(category)
		var match_selected: bool=not selected.is_empty() and bool(STATE.can_install(id,config,str(path),str(selected.get("id",""))).get("ok",false))
		var style:=FieldTheme.box(Color("263f31") if match_selected else Color("101d20"),FieldTheme.ACCENT if match_selected or definition else FieldTheme.BORDER,2)
		button.add_theme_stylebox_override("normal",style)
		button.tooltip_text=str(definition.display_name) if definition else str(spec.get("label",category.capitalize()))
		button.disabled=blocked

func _place_slots() -> void:
	if not is_instance_valid(stage) or weapon.is_empty():return
	var available: Dictionary=STATE.socket_records(weapon,configuration)
	for path in slots:
		var spec: Variant=available.get(path,{})
		var position_value: Variant=spec.get("ui_position",Vector2(.5,.12)) if spec is Dictionary else Vector2(.5,.12)
		var point: Vector2=position_value if position_value is Vector2 else Vector2(float(position_value[0]),float(position_value[1]))
		slots[path].position=(stage.size*point-slots[path].size*.5).clamp(Vector2.ZERO,(stage.size-slots[path].size).max(Vector2.ZERO))
