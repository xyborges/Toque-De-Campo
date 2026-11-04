extends PanelContainer
class_name GameAimSettingsPanel
var focus: GameUIFocus
var group_picker: OptionButton
var item_picker: OptionButton
var normal: HSlider
var aimed: HSlider
var normal_label: Label
var aimed_label: Label
var save_timer: Timer
var catalog: Dictionary={}
var current:=""
func _ready() -> void:
	name="AimSensitivitySettings";theme=GameUI.THEME
	add_theme_stylebox_override("panel",FieldTheme.box())
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",14);scroll.add_child(column)
	GameUI.label(column,"MIRA E SENSIBILIDADE",24,FieldTheme.INK)
	catalog=GameAimSensitivity.groups();group_picker=OptionButton.new();column.add_child(group_picker)
	for key in catalog: group_picker.add_item(key)
	item_picker=OptionButton.new();column.add_child(item_picker)
	normal_label=GameUI.label(column,"",15,FieldTheme.ACCENT)
	normal=_slider(column);aimed_label=GameUI.label(column,"",15,FieldTheme.ACCENT);aimed=_slider(column)
	aimed.tooltip_text="Multiplica a sensibilidade durante o zoom."
	GameUI.button(column,"RESTAURAR ESTE EQUIPAMENTO",func(): GameAimSensitivity.reset(current);GameAimSensitivity.flush();_show_values())
	GameUI.button(column,"VOLTAR",func(): GameAimSensitivity.flush();focus.close_top())
	save_timer=Timer.new();save_timer.one_shot=true;save_timer.wait_time=.3;add_child(save_timer);save_timer.timeout.connect(func(): GameAimSensitivity.flush())
	group_picker.item_selected.connect(func(_index): _group_changed())
	item_picker.item_selected.connect(func(_index): _show_values())
	for slider in [normal,aimed]: slider.value_changed.connect(func(_value): _changed())
	visibility_changed.connect(func():
		if not visible: GameAimSensitivity.flush()
	)
	_group_changed();hide()
func _slider(column: Node) -> HSlider:
	var slider:=HSlider.new();slider.min_value=5;slider.max_value=300;slider.step=1;column.add_child(slider);return slider
func _group_changed() -> void:
	item_picker.clear()
	var group: Dictionary=catalog[group_picker.get_item_text(group_picker.selected)]
	for id in group:
		item_picker.add_item(str(group[id]));item_picker.set_item_metadata(item_picker.item_count-1,id)
	_show_values()
func _show_values() -> void:
	if item_picker.item_count==0: return
	current=str(item_picker.get_item_metadata(item_picker.selected));var values:=GameAimSensitivity.values(current)
	normal.set_value_no_signal(float(values.normal)*100);aimed.set_value_no_signal(float(values.aim)*100);_labels()
func _labels() -> void:
	normal_label.text="Normal · %d%%"%int(normal.value)
	aimed_label.text="Ao mirar · %d%%"%int(aimed.value)
func _changed() -> void:
	GameAimSensitivity.set_values(current,normal.value/100,aimed.value/100);_labels();save_timer.start()
func present(owner_focus: GameUIFocus,context: String="weapon:ak") -> void:
	focus=owner_focus
	var index:=0
	for key in catalog:
		if Dictionary(catalog[key]).has(context):
			group_picker.select(index);_group_changed()
			for item in item_picker.item_count:
				if str(item_picker.get_item_metadata(item))==context: item_picker.select(item);break
			_show_values();break
		index+=1
	focus.open(self)
func _exit_tree() -> void: GameAimSensitivity.flush()
