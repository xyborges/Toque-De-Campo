extends HBoxContainer
class_name WarVehicleSlots
var manager: WarVehicles
var entries: Dictionary={}
var clock:=0.0
func _ready() -> void:
	for number in [1,2,3,4]:
		var button:=GameUI.button(self,"",func():
			if manager._local_is_operator(): manager.clear_trigger();manager.request_command("weapon",{"slot":number})
		)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y=44;button.add_theme_font_size_override("font_size",12)
		entries[number]=button
func _process(delta: float) -> void:
	clock+=delta
	if clock<.1: return
	clock=0
	var own:=manager.find_target(manager._own_id()) as WarVehicle
	visible=is_instance_valid(own) and not manager._transport(own) and manager._local_is_operator() and not manager.tv.viewing()
	if not visible: return
	for number in entries:
		var button: Button=entries[number]
		if own is WarShip:
			var allowed: Array=own.hull.spec.weapons
			button.visible=number<=allowed.size()
			if not button.visible: continue
			var weapon:=str(allowed[number-1])
			var text:="%d · %s\n%d / %d"%[number,NavalCatalog.WEAPONS[weapon].name,int(own.naval_ammo[weapon]),int(own.naval_reserve[weapon])]
			if button.text!=text: button.text=text
			var selected: bool=own.naval_weapon==weapon
			if selected!=bool(button.get_meta("selected",false)): button.set_meta("selected",selected);GameUI.accent(button,selected)
			continue
		button.visible=number<=2
		if not button.visible: continue
		var secondary: bool=number==2
		var title:=str(WarRules.SECONDARY[own.kind].name) if secondary else ("CANHÃO" if own.spec.gun=="tank" else "30 mm")
		var text:="%d · %s\n%d / %d"%[number,title,own.secondary_ammo if secondary else own.ammo,own.secondary_reserve if secondary else own.reserve]
		if button.text!=text: button.text=text
		var selected:=own.selected==("secondary" if secondary else "primary")
		if selected!=bool(button.get_meta("selected",false)): button.set_meta("selected",selected);GameUI.accent(button,selected)
