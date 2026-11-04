extends PanelContainer
class_name BRInventoryPanel
const REGISTRY=preload("res://scripts/attachments/registry.gd")
const STATE=preload("res://scripts/attachments/state.gd")
var game: Node
var inventory: Dictionary={}
var match_state: Dictionary={}
var nearby: Array=[]
var selected: Dictionary={}
var ground_list: VBoxContainer
var bag_list: VBoxContainer
var cards: Array[BRWeaponCard]=[]
var body_rows: Dictionary={}
var capacity: Label
var capacity_bar: ProgressBar
var item_title: Label
var item_detail: Label
var use_button: Button
var drop_button: Button
var notice: Label
var popup: PopupMenu
var item_popup: PopupMenu
var ground_popup: PopupMenu
var selected_ground: Dictionary={}
var choices: Array=[]
var menu_weapon:=""
var menu_socket:=""
var ground_signature:=-1
var bag_signature:=-1
var notice_until:=0.
var bag_buttons: Dictionary={}

func _ready() -> void:
	name="BRBackpack";theme=GameUI.THEME;set_meta("preferred_size",Vector2(1220,700))
	set_meta("ui_instant_close",true)
	var layout:=VBoxContainer.new();layout.add_theme_constant_override("separation",12);add_child(layout)
	var heading:=HBoxContainer.new();layout.add_child(heading)
	GameUI.label(heading,"INVENTÁRIO",25,FieldTheme.ACCENT).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	capacity=GameUI.label(heading,"",14,FieldTheme.MUTED);capacity.autowrap_mode=TextServer.AUTOWRAP_OFF
	# On narrow screens the five inventory sections remain reachable instead
	# of being clipped off the viewport.
	var horizontal:=ScrollContainer.new()
	horizontal.name="InventoryHorizontalScroll"
	horizontal.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	horizontal.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	horizontal.size_flags_vertical=Control.SIZE_EXPAND_FILL
	horizontal.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	layout.add_child(horizontal)
	var columns:=HBoxContainer.new()
	columns.add_theme_constant_override("separation",8)
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	horizontal.add_child(columns)
	var ground:=_column(columns,"CHÃO",150,1.)
	ground_list=_scroll(ground)
	_line(columns,true)
	var bag:=_column(columns,"MOCHILA",165,1.15)
	capacity_bar=ProgressBar.new();capacity_bar.custom_minimum_size.y=6;capacity_bar.show_percentage=false;bag.add_child(capacity_bar)
	bag_list=_scroll(bag)
	_line(bag)
	item_title=GameUI.label(bag,"",15,FieldTheme.ACCENT)
	item_detail=GameUI.label(bag,"",12,FieldTheme.MUTED);item_detail.custom_minimum_size.y=34
	var actions:=HBoxContainer.new();bag.add_child(actions)
	use_button=GameUI.button(actions,"USAR",_use_selected);use_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;use_button.add_theme_font_size_override("font_size",12)
	drop_button=GameUI.button(actions,"LARGAR",_drop_selected);drop_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;drop_button.add_theme_font_size_override("font_size",12)
	notice=GameUI.label(bag,"",12,FieldTheme.BAD);notice.custom_minimum_size.y=19
	_line(columns,true)
	var weapons:=_column(columns,"ARMAS",300,2.6)
	for index in 2:
		var card:=BRWeaponCard.new();card.index=index;card.size_flags_vertical=Control.SIZE_EXPAND_FILL
		card.weapon_pressed.connect(func(slot: int):game.request_br_select_slot(slot))
		card.drop_pressed.connect(func(slot: int):
			var owned: Array=inventory.get("weapons",[])
			if slot<owned.size():game.request_br_drop(str(owned[slot]))
		)
		card.socket_pressed.connect(_socket_clicked);weapons.add_child(card);cards.append(card)
	_line(columns,true)
	var equipment:=_column(columns,"EQUIPAMENTO",110,.65)
	for kind in ["helmet","pack","vest"]:
		var panel:=GameUI.panel(equipment,6);panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var content:=VBoxContainer.new();content.add_theme_constant_override("separation",7);panel.add_child(content)
		var label:=GameUI.label(content,"",13);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(45,40);icon.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(icon)
		icon.texture=_body_icon(kind)
		var condition:=ProgressBar.new();condition.custom_minimum_size.y=6;condition.show_percentage=false;content.add_child(condition)
		var drop:=GameUI.button(content,"LARGAR",_drop_body.bind(kind));drop.custom_minimum_size.y=26;drop.add_theme_font_size_override("font_size",10)
		body_rows[kind]={"root":panel,"label":label,"icon":icon,"condition":condition,"drop":drop}
	var footer:=HBoxContainer.new();layout.add_child(footer)
	GameUI.label(footer,"TAB · FECHAR    BACKSPACE · LARGAR ARMA",11,FieldTheme.MUTED).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	GameUI.button(footer,"VOLTAR",func():game.br_hud._close_inventory())
	popup=PopupMenu.new();popup.theme=GameUI.THEME;popup.id_pressed.connect(_choose_socket);add_child(popup)
	item_popup=PopupMenu.new();item_popup.theme=GameUI.THEME;item_popup.id_pressed.connect(_item_action);add_child(item_popup)
	ground_popup=PopupMenu.new();ground_popup.theme=GameUI.THEME;ground_popup.id_pressed.connect(_ground_action);add_child(ground_popup)
	visibility_changed.connect(func():
		if not visible and is_instance_valid(popup):popup.hide();item_popup.hide();ground_popup.hide()
	)
	hide()

func _column(parent: Node,title: String,width: float,ratio: float) -> VBoxContainer:
	var panel:=GameUI.panel(parent,8);panel.custom_minimum_size.x=width;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.size_flags_stretch_ratio=ratio
	panel.add_theme_stylebox_override("panel",FieldTheme.box(Color(.035,.065,.07,.9),FieldTheme.BORDER,8))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",9);panel.add_child(box)
	var caption:=GameUI.label(box,title,13,FieldTheme.ACCENT);caption.autowrap_mode=TextServer.AUTOWRAP_OFF;_line(box)
	return box

func _line(parent: Node,vertical:=false) -> void:
	var line:=ColorRect.new();line.name="Divider";line.color=FieldTheme.BORDER.lightened(.24);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if vertical:line.custom_minimum_size.x=1;line.size_flags_vertical=Control.SIZE_EXPAND_FILL
	else:line.custom_minimum_size.y=1;line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(line)

func _scroll(parent: Node) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(scroll)
	var list:=VBoxContainer.new();list.add_theme_constant_override("separation",6);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list);return list

func _body_icon(kind: String) -> Texture2D:
	var shape:=str({"helmet":"<path d='M8 30v-9a16 16 0 0132 0v9l-9 2H17zM13 32v6m23-6v6'/>","pack":"<path d='M12 12h24v29H12zM18 12V7h12v5M17 25h14v12H17zM8 17v17m32-17v17'/>","vest":"<path d='M13 6l8 5h6l8-5 6 12-7 5v19H14V23l-7-5zM21 11v29m6-29v29'/ >"}.get(kind,""))
	shape=shape.replace("/ >","/>")
	var svg:="<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48'><g fill='none' stroke='#b7cca1' stroke-width='2' stroke-linejoin='round'>"+shape+"</g></svg>"
	var image:=Image.new();image.load_svg_from_string(svg);return ImageTexture.create_from_image(image)

func present(state: Dictionary,data: Dictionary,loot: Array) -> void:
	if not is_node_ready():return
	match_state=state;inventory=data;nearby=loot
	capacity.text="%d / %d"%[int(data.get("weight",0)),int(data.get("capacity",60))]
	capacity_bar.max_value=float(data.get("capacity",60));capacity_bar.value=float(data.get("weight",0))
	if Time.get_ticks_msec()*.001>notice_until:notice.text=""
	_update_ground();_update_bag();_update_cards();_update_body();_update_selection()

func _item_name(item: Dictionary) -> String:
	match str(item.get("kind","")):
		"weapon":return str(GameWeapons.ITEMS.get(str(item.get("weapon","")),{}).get("name","—"))
		"ammo":return str({"9mm":"9 mm","76239":"7,62 × 39","76251":"7,62 × 51","precision":"Precisão","rocket":"RPG-7","javelin":"Javelin"}.get(str(item.get("calibre","")),"Munição"))
		"heal":return "Curativo"
		"binoculars":return "Binóculos"
		"attachment","optic":
			var definition=REGISTRY.definition(str(item.get("attachment",item.get("id",item.get("optic","")))))
			return str(definition.display_name) if definition else "Acessório"
		"vest","helmet","pack":return str({"vest":"Colete","helmet":"Capacete","pack":"Mochila"}[item.kind])+" %d"%int(item.get("level",0))
	return "Mochila"

func _item_icon(item: Dictionary) -> Texture2D:
	if item.kind in ["attachment","optic"]:
		var definition=REGISTRY.definition(str(item.get("attachment",item.get("id",item.get("optic","")))))
		return GameAttachmentIcons.texture(str(definition.category) if definition else "attachment")
	if item.kind=="weapon":return GameWeaponSilhouette.texture(str(item.weapon))
	return null

func _clear(parent: Node) -> void:
	for child in parent.get_children():parent.remove_child(child);child.queue_free()

func _update_ground() -> void:
	if not is_visible_in_tree() or not is_instance_valid(game.local_player):return
	var entries: Array=[]
	for item: Dictionary in nearby:
		if game.local_player.global_position.distance_squared_to(item.get("position",Vector3.INF))>9.:continue
		if item.get("kind","")=="container":
			for part: Dictionary in item.get("contents",[]):entries.append({"loot_id":item.id,"part":int(part.get("part_id",-1)),"item":part})
		else:entries.append({"loot_id":item.id,"part":-1,"item":item})
	var signature:=hash(entries)
	if signature==ground_signature:return
	ground_signature=signature;_clear(ground_list)
	if entries.is_empty():GameUI.label(ground_list,"—",15,FieldTheme.MUTED)
	for record: Dictionary in entries:
		var item: Dictionary=record.item;var button:=Button.new();ground_list.add_child(button);button.custom_minimum_size.y=42;button.text=_item_name(item)
		button.pressed.connect(_ground_clicked.bind(record,button))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",13);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",35);button.icon=_item_icon(item)
		if int(item.get("amount",1))>1:button.text+=" ×%d"%int(item.amount)

func _bag_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary]=[]
	for calibre in inventory.get("ammo",{}):
		if int(inventory.ammo[calibre])>0:entries.append({"kind":"ammo","calibre":str(calibre),"amount":int(inventory.ammo[calibre]),"key":"ammo:"+str(calibre)})
	if inventory.get("binoculars",false):entries.append({"kind":"binoculars","key":"binoculars"})
	if int(inventory.get("medkits",0))>0:entries.append({"kind":"heal","amount":int(inventory.medkits),"key":"heal"})
	for item: Dictionary in inventory.get("accessory_items",[]):
		var entry:=item.duplicate(true);entry.kind="attachment";entry.attachment=str(item.id);entry.key="attachment:"+str(item.get("uid",-1));entry.amount=1;entries.append(entry)
	entries.sort_custom(func(a: Dictionary,b: Dictionary):return _item_name(a).naturalnocasecmp_to(_item_name(b))<0)
	return entries

func _update_bag() -> void:
	var entries:=_bag_entries();var signature:=hash(entries)
	if signature==bag_signature:return
	bag_signature=signature;_clear(bag_list);bag_buttons.clear()
	var selected_key:=str(selected.get("key",""));selected={}
	if entries.is_empty():GameUI.label(bag_list,"—",15,FieldTheme.MUTED)
	for entry: Dictionary in entries:
		var button:=Button.new();bag_list.add_child(button);button.custom_minimum_size.y=42;button.text=_item_name(entry)+" ×%d"%int(entry.amount)
		button.pressed.connect(_item_clicked.bind(entry,button))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",13);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",31);button.icon=_item_icon(entry)
		bag_buttons[entry.key]=button
		if entry.key==selected_key:selected=entry

func _select_item(entry: Dictionary) -> void:
	selected=entry.duplicate(true);_update_selection();_update_cards()

func _item_clicked(entry: Dictionary,button: Button) -> void:
	_select_item(entry);item_popup.clear()
	item_popup.add_item(use_button.text,0);item_popup.set_item_disabled(0,use_button.disabled)
	item_popup.add_item("Largar",1)
	item_popup.position=Vector2i(button.global_position+Vector2(button.size.x,0));item_popup.popup()

func _item_action(action: int) -> void:
	if action==0:_use_selected()
	elif action==1:_drop_selected()

func _ground_clicked(record: Dictionary,button: Button) -> void:
	selected_ground=record.duplicate(true);ground_popup.clear()
	ground_popup.add_item("Pegar",0)
	var item: Dictionary=record.item
	ground_popup.add_item("Trocar arma" if item.get("kind","")=="weapon" and inventory.get("weapons",[]).size()>=2 else ("Equipar" if item.get("kind","") in ["weapon","attachment","optic","vest","helmet","pack"] else "Usar"),1)
	ground_popup.position=Vector2i(button.global_position+Vector2(button.size.x,0));ground_popup.popup()

func _ground_action(action: int) -> void:
	if selected_ground.is_empty():return
	if action==0:game.br_interact(int(selected_ground.loot_id),int(selected_ground.part))
	else:game.request_br_ground_use(int(selected_ground.loot_id),int(selected_ground.part))

func _update_selection() -> void:
	for key in bag_buttons:GameUI.accent(bag_buttons[key],key==selected.get("key",""))
	item_title.text=_item_name(selected) if not selected.is_empty() else ""
	item_detail.text="";use_button.text="USAR";use_button.disabled=selected.is_empty();drop_button.disabled=selected.is_empty()
	if selected.is_empty():return
	if selected.kind=="attachment":
		item_detail.text="";use_button.text="EQUIPAR";use_button.disabled=_first_target(selected).is_empty() or _blocked()
	elif selected.kind=="heal":use_button.disabled=not is_instance_valid(game.local_player) or game.local_player.hp>=100. or float(match_state.get("heal_remaining",0))>0.
	elif selected.kind=="ammo":use_button.text="RECARREGAR";use_button.disabled=_ammo_weapon(str(selected.calibre)).is_empty() or _blocked()
	if _blocked() and selected.kind=="attachment":item_detail.text="Aguarde a recarga"

func _blocked() -> bool:
	return not is_instance_valid(game.local_player) or game.local_player.hp<=0 or game.local_player.reload_left>0 or game.local_player.fire_cooldown>0 or float(match_state.get("heal_remaining",0))>0

func _update_cards() -> void:
	var weapons: Array=inventory.get("weapons",[])
	for index in cards.size():
		var id:=str(weapons[index]) if index<weapons.size() else ""
		var modules: Dictionary=inventory.get("weapon_attachments",{}).get(id,{})
		var current: bool=is_instance_valid(game.local_player) and game.local_player.weapon_id==id
		cards[index].present(id,modules,int(inventory.get("magazines",{}).get(id,0)),int(inventory.get("reserve_by_weapon",{}).get(id,0)),current,selected if selected.get("kind","")=="attachment" else {},_blocked())

func _update_body() -> void:
	for kind in body_rows:
		var row: Dictionary=body_rows[kind]
		var item: Dictionary=inventory.get("protection",{}).get(kind,{}) if kind!="pack" else {"level":inventory.get("backpack",0)}
		var level:=int(item.get("level",0));row.label.text=_item_name({"kind":kind,"level":level}) if level>0 else str({"helmet":"Capacete","vest":"Colete","pack":"Mochila"}[kind])
		row.icon.modulate=Color.WHITE if level>0 else Color(.35,.4,.38,.5);row.drop.disabled=level<=0
		row.condition.visible=kind!="pack" and level>0
		if level>0 and kind!="pack":row.condition.max_value=BRInventory.PROTECTION_HP[level];row.condition.value=float(item.get("durability",0))
		if kind=="pack":row.drop.disabled=level<=0 or float(inventory.get("weight",0))>BRInventory.CAPACITY

func _first_target(entry: Dictionary) -> Dictionary:
	var weapons: Array=inventory.get("weapons",[]).duplicate()
	if is_instance_valid(game.local_player) and game.local_player.weapon_id in weapons:weapons.erase(game.local_player.weapon_id);weapons.push_front(game.local_player.weapon_id)
	for weapon in weapons:
		var modules: Dictionary=inventory.get("weapon_attachments",{}).get(weapon,{})
		for path in STATE.sockets(str(weapon),modules):
			if STATE.can_install(str(weapon),modules,str(path),str(entry.id)).get("ok",false):return {"weapon":str(weapon),"socket":str(path)}
	return {}

func _use_selected() -> void:
	if selected.is_empty() or use_button.disabled:return
	match str(selected.kind):
		"binoculars":game.request_equip(game.local_player,"binoculars")
		"heal":game.request_br_heal()
		"ammo":game.request_br_use_ammo(str(selected.calibre),_ammo_weapon(str(selected.calibre)))
		"attachment":
			var target:=_first_target(selected)
			if not target.is_empty():game.request_br_attachment(target.weapon,target.socket,str(selected.id),int(selected.get("uid",-1)))

func _ammo_weapon(calibre: String) -> String:
	var owned: Array=inventory.get("weapons",[])
	if is_instance_valid(game.local_player) and game.local_player.weapon_id in owned and BRInventory.calibre_for(game.local_player.weapon_id)==calibre:return game.local_player.weapon_id
	for weapon in owned:
		if BRInventory.calibre_for(str(weapon))==calibre:return str(weapon)
	return ""

func _drop_selected() -> void:
	if selected.is_empty():return
	match str(selected.kind):
		"binoculars":game._request_br("drop_binoculars",{})
		"heal":game.request_br_drop_heal()
		"ammo":game.request_br_drop_ammo(str(selected.calibre),mini(30,int(selected.amount)))
		"attachment":game.request_br_drop_attachment(str(selected.id),int(selected.get("uid",-1)))

func _drop_body(kind: String) -> void:
	if kind=="pack":game.request_br_drop_pack()
	else:game.request_br_drop_protection(kind)

func _socket_clicked(index: int,path: String,button: Button) -> void:
	var owned: Array=inventory.get("weapons",[])
	if index>=owned.size() or _blocked():return
	menu_weapon=str(owned[index]);menu_socket=path
	var config: Dictionary=inventory.get("weapon_attachments",{}).get(menu_weapon,{})
	if selected.get("kind","")=="attachment" and STATE.can_install(menu_weapon,config,path,str(selected.id)).get("ok",false):
		game.request_br_attachment(menu_weapon,path,str(selected.id),int(selected.get("uid",-1)));return
	popup.clear();choices.clear()
	if config.has(path):
		popup.add_item("Retirar",0);choices.append({"id":"","uid":-1})
	for entry: Dictionary in inventory.get("accessory_items",[]):
		if not STATE.can_install(menu_weapon,config,path,str(entry.id)).get("ok",false):continue
		var definition=REGISTRY.definition(str(entry.id))
		popup.add_item(str(definition.display_name),choices.size());choices.append(entry)
	if choices.is_empty():popup.add_item("Indisponível",0);popup.set_item_disabled(0,true)
	popup.position=Vector2i(button.global_position+Vector2(0,button.size.y));popup.popup()

func _choose_socket(index: int) -> void:
	if index>=choices.size():return
	game.request_br_attachment(menu_weapon,menu_socket,str(choices[index].get("id","")),int(choices[index].get("uid",-1)))

func show_notice(message: String) -> void:
	notice.text=message;notice_until=Time.get_ticks_msec()*.001+2.5
