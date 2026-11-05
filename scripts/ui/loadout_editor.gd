extends VBoxContainer
class_name GameLoadoutEditor
signal changed
var game: Node
var mode:="desert"
var role:="soldier"
var team:=0
var slots: Dictionary={}
var rows: Dictionary={}
var choices: Dictionary={}
var listing: VBoxContainer
var detail: Label
var add_option: OptionButton
var preview: GameItemPreview
var preview_signature:=""
var equipment_changed:=false
var optic_primary:=""
var preview_slot:="primary"

func _ready() -> void:
	add_theme_constant_override("separation",7)
	listing=VBoxContainer.new();listing.add_theme_constant_override("separation",7);add_child(listing)
	detail=GameUI.label(self,"",13,FieldTheme.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.hide()
	add_option=OptionButton.new();add_option.custom_minimum_size.y=30;add_child(add_option)
	add_option.item_selected.connect(func(index: int):
		if index<=0: return
		var slot:=str(add_option.get_item_metadata(index));slots[slot]=choices[slot][0];_rebuild();_changed()
	)
	visibility_changed.connect(func():
		if is_visible_in_tree(): _preview_once.call_deferred()
	)

func configure(owner_game: Node,kind: String,chosen_role:="soldier",chosen_team:=0) -> void:
	game=owner_game;mode=kind;role=chosen_role;team=chosen_team
	preview_slot="primary"
	choices=GameLoadouts.allowed(mode,game.profile.owned,role,team)
	var restored:=GameLoadouts.saved(game,mode,role,team)
	slots=Dictionary(restored.get("slots",{})).duplicate();equipment_changed=bool(restored.get("adjusted",false))
	optic_primary=str(slots.get("primary",""))
	_rebuild();_update_preview()

func _rebuild() -> void:
	_sync_optic_choice()
	for child in listing.get_children(): listing.remove_child(child);child.queue_free()
	rows.clear()
	for slot in GameLoadouts.ORDER:
		if not slots.has(slot) or not choices.has(slot): continue
		var row:=HBoxContainer.new();listing.add_child(row)
		var button:=GameUI.button(row,GameLoadouts.title(str(slots[slot])),_select.bind(slot))
		button.icon=null if slot=="optic" else GameUI.icon(str(slots[slot]));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",34);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y=44
		button.tooltip_text=GameLoadouts.TITLES[slot]
		var amount:=GameUI.label(row,_amount(str(slots[slot])),14,FieldTheme.MUTED);amount.custom_minimum_size.x=82;amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		GameUI.button(row,"×",func(): slots.erase(slot);_rebuild();_changed()).custom_minimum_size=Vector2(32,32)
		var picker:=OptionButton.new();picker.hide();listing.add_child(picker)
		for id in choices[slot]: picker.add_item(GameLoadouts.title(id));picker.set_item_metadata(picker.item_count-1,id)
		picker.select(choices[slot].find(slots[slot]))
		picker.item_selected.connect(func(index: int): slots[slot]=str(picker.get_item_metadata(index));_rebuild();_changed();_show_detail(str(slots[slot])))
		rows[slot]={"button":button,"picker":picker,"amount":amount}
		if slot=="grenade" and choices[slot].size()>1:
			# Both grenade types stay visible; the equipped type is accented.
			# The main slot selector still works just like the other weapons.
			var grenade_choices:=HBoxContainer.new()
			grenade_choices.add_theme_constant_override("separation",6)
			listing.add_child(grenade_choices)
			for kind: String in choices[slot]:
				var title: String="FUMAÇA M18" if kind=="smoke" else "EXPLOSIVA"
				var option:=GameUI.button(grenade_choices,title,_choose_grenade.bind(kind))
				option.name="GrenadeChoice_"+kind
				option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				option.custom_minimum_size.y=34
				option.add_theme_font_size_override("font_size",12)
				GameUI.accent(option,str(slots[slot])==kind)
	add_option.clear();add_option.add_item("Adicionar")
	for slot in GameLoadouts.ORDER:
		if choices.has(slot) and not slots.has(slot): add_option.add_item(GameLoadouts.TITLES[slot]);add_option.set_item_metadata(add_option.item_count-1,slot)
	add_option.visible=add_option.item_count>1

func _sync_optic_choice() -> void:
	var primary:=str(slots.get("primary",""))
	if primary in GameLoadouts.OPTIC_WEAPONS and primary in choices.get("primary",[]):
		choices.optic=GameOpticCatalog.ids_for_weapon(primary)
		if primary!=optic_primary:
			var preference:=GameLoadouts.optic_choice(primary)
			if not preference.is_empty() and GameOpticCatalog.compatible(preference,primary):slots.optic=GameOpticCatalog.resolve(preference,primary)
			else:slots.erase("optic")
		elif str(slots.get("optic",""))=="scope4x":
			slots.optic=GameOpticCatalog.resolve("scope4x",primary)
	else:
		choices.erase("optic")
		if slots.has("optic"): slots.erase("optic");equipment_changed=true
	optic_primary=primary

func _choose_grenade(kind: String) -> void:
	if kind not in choices.get("grenade",[]): return
	if str(slots.get("grenade",""))==kind: return
	slots.grenade=kind
	_rebuild()
	_changed()
	_show_detail(kind)

func _select(slot: String) -> void:
	if slot in ["primary","sidearm","melee","optic"]:
		preview_slot="primary" if slot=="optic" else slot
		_update_preview()
	for other in rows: rows[other].picker.visible=other==slot and not rows[other].picker.visible
	_show_detail(str(slots[slot]))

func _show_detail(id: String) -> void:
	if id=="smoke":
		detail.text="M18 · cortina de fumaça para ocultação, sem dano explosivo"
		detail.show();return
	if id=="grenade":
		detail.text="Fragmentação · explosão com dano em área"
		detail.show();return
	if id.begins_with("vest_") or id.begins_with("helmet_"):
		var tier:=clampi(int(id.get_slice("_",1)),1,3)
		detail.text="Proteção %d%% · Resistência %d · %.1f kg"%[roundi(BRInventory.PROTECTION_RATIO[tier]*100),int(BRInventory.PROTECTION_HP[tier]),float(preload("res://scripts/infantry_protection.gd").WEIGHT["vest" if id.begins_with("vest_") else "helmet"][tier])];detail.show();return
	var item: Dictionary=GameWeapons.ITEMS.get(id,{})
	if item.is_empty(): detail.hide();return
	detail.text="Dano %d · Alcance %d m"%[roundi(item.damage),roundi(item.range)]
	if item.kind=="firearm": detail.text+=" · %d disparos/min"%roundi(60/float(item.cooldown))
	detail.show()

func _amount(id: String) -> String:
	if id in ["grenade","smoke"]: return "×2"
	if id=="drone": return "×1"
	if id in GameLoadouts.EQUIPMENT: return "×%d"%int(WarRules.CLASSES.get(role,WarRules.CLASSES.soldier).charges)
	var item: Dictionary=GameWeapons.ITEMS.get(id,{})
	if item.get("kind","")=="launcher": return "×%d"%int(WarRules.CLASSES[role].charges)
	if item.get("kind","")=="firearm": return "%d / %d"%[int(item.mag),int(CombatRules.weapon(id).reserve)]
	return ""

func _changed() -> void:
	GameLoadouts.save(game,mode,slots,role,team);_update_preview();changed.emit()

func approved() -> Dictionary:
	return GameLoadouts.validate(slots,mode,game.profile.owned,role,team)

func _update_preview() -> void:
	if not is_instance_valid(preview) or not is_instance_valid(preview.stage): return
	var signature:=str([mode,team,role,game.profile.skin,game.profile.proportions])
	if preview_signature!=signature or not is_instance_valid(preview.actor):
		preview_signature=signature;preview.show_item("person",game.profile)
		if mode=="war": WarUniform.apply(preview.actor,team,role)
	var actor:=preview.actor
	actor.set_meta("approved_loadout",slots.duplicate())
	actor.infantry_protection=preload("res://scripts/infantry_protection.gd").new();actor.infantry_protection.deploy(actor)
	if not is_instance_valid(actor.weapon_root): actor.weapon_root=Node3D.new();preview.holder.add_child(actor.weapon_root)
	preview.held_slot=preview_slot if slots.has(preview_slot) else ("primary" if slots.has("primary") else ("sidearm" if slots.has("sidearm") else "melee"))
	var selected:=str(slots.get(preview.held_slot,""))
	if selected.is_empty(): actor.weapon_root.hide()
	elif actor.weapon_id!=selected or actor.weapon_root.get_child_count()==0:
		actor.weapon_id=selected;actor._refresh_weapon();actor.weapon_root.show()
	if not selected.is_empty(): actor.weapon_root.show()
	var optics: Dictionary={}
	if selected in GameLoadouts.OPTIC_WEAPONS and GameOpticCatalog.compatible(str(slots.get("optic","")),selected):optics[selected]=str(slots.optic)
	actor.set_meta("weapon_optics",optics)
	var attachments: Dictionary={}
	for weapon: String in optics:attachments[weapon]=GameAttachmentState.from_legacy(weapon,str(optics[weapon]))
	actor.set_meta("weapon_attachments",attachments)
	if actor.has_method("refresh_weapon_optics"): actor.call("refresh_weapon_optics")
	if not selected.is_empty():actor._update_weapon_pose();actor._pose_weapon_arms()
	preview._fit_camera()
	_preview_once()

func _preview_once() -> void:
	if is_instance_valid(preview) and is_instance_valid(preview.view): preview.view.render_target_update_mode=SubViewport.UPDATE_ONCE
