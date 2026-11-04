extends Control
class_name GameInfantryHUD
const WEAPON_ZEROING=preload("res://scripts/weapon_zeroing.gd")
var game: Node
var hp: Label
var health: ProgressBar
var ammo: Label
var zeroing: Label
var rank: Label
var notice: Label
var dot: ColorRect
var damage: GameDamageFlash
var lobby: PanelContainer
var shop: Button
var match_info: Label
var reload_text: Label
var reload_bar: ProgressBar
var weapon_row: HBoxContainer
var weapon_buttons: Dictionary = {}
var slot_views: Dictionary={}
var slots_signature:=""
var fuse_bar: ProgressBar
var low_ammo: Label
var ammo_color:=Color.TRANSPARENT
var active_weapon := ""
var waiting: PanelContainer
var waiting_text: Label
var grenade_text: Label
var grenade_button: Button
var grenade_highlight:=false
var domination_panel: PanelContainer
var domination_title: Label
var domination_detail: Label
var domination_progress: ProgressBar
var supply_prompt: Label
# Optional mode equipment is described by the mode's authoritative inventory.
# The ordinary four slots keep their own ammunition while a launcher is held.
signal equipment_selected(id: String)
var equipment_context: Dictionary={}
var equipment_box: VBoxContainer
var equipment_title: Label
var equipment_state: Label
var equipment_actions: HBoxContainer
var equipment_buttons: Dictionary={}
var equipment_signature:=""
var equipment_color:=Color.TRANSPARENT
func _ready() -> void:
	name = "InfantryHUD"
	add_to_group("game_hud")
	theme = GameUI.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var life := GameUI.panel(self)
	GameUI.rect(life,22,-130,215,-22,Vector2(0,1))
	var left := VBoxContainer.new()
	life.add_child(left)
	hp = GameUI.label(left,"+ 100",28,FieldTheme.ACCENT)
	health = ProgressBar.new()
	health.show_percentage = false
	health.custom_minimum_size.y = 5
	health.value = 100
	left.add_child(health)
	match_info = GameUI.label(left,"OFFLINE",11,FieldTheme.MUTED)
	match_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	var armament := GameUI.panel(self)
	GameUI.rect(armament,-366,-358,-22,-22,Vector2.ONE)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation",8)
	armament.add_child(right)
	ammo = GameUI.label(right,"AK\n30 / 180",28)
	ammo.autowrap_mode=TextServer.AUTOWRAP_OFF
	zeroing=GameUI.label(right,"ZERAGEM · 0 m",11,FieldTheme.MUTED)
	zeroing.autowrap_mode=TextServer.AUTOWRAP_OFF
	low_ammo=GameUI.label(right,"",12,FieldTheme.BAD);low_ammo.hide()
	var slots:=VBoxContainer.new();slots.add_theme_constant_override("separation",3);right.add_child(slots)
	for key in [1,2,3,4]: _build_slot(slots,key)
	weapon_row=HBoxContainer.new();weapon_row.add_theme_constant_override("separation",3);right.add_child(weapon_row)
	for key in [5,6,9]: _build_slot(weapon_row,key,true)
	grenade_button=slot_views[3].button
	equipment_box=VBoxContainer.new();equipment_box.add_theme_constant_override("separation",3);right.add_child(equipment_box)
	equipment_title=GameUI.label(equipment_box,"",12,FieldTheme.ACCENT);equipment_title.autowrap_mode=TextServer.AUTOWRAP_OFF
	equipment_actions=HBoxContainer.new();equipment_actions.add_theme_constant_override("separation",4);equipment_box.add_child(equipment_actions)
	for id in ["rpg","stinger"]:
		var button:=GameUI.button(equipment_actions,"7 · RPG-7" if id=="rpg" else "8 · JAVELIN",func(): equipment_selected.emit(id))
		button.custom_minimum_size.y=27;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.add_theme_font_size_override("font_size",12)
		equipment_buttons[id]=button
	equipment_state=GameUI.label(equipment_box,"",11,FieldTheme.MUTED);equipment_state.autowrap_mode=TextServer.AUTOWRAP_OFF
	equipment_box.hide()
	shop = GameUI.button(right,"ARSENAL",game._toggle_shop)
	shop.name = "ShopButton"
	shop.custom_minimum_size.y = 28
	shop.add_theme_font_size_override("font_size",11)
	var board := GameUI.panel(self)
	GameUI.rect(board,-285,64,-22,210,Vector2(1,0))
	rank = GameUI.label(board,"",12)
	rank.name = "Ranking"
	rank.tab_stops = PackedFloat32Array([140,175])
	rank.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	rank.autowrap_mode = TextServer.AUTOWRAP_OFF
	board.hide() # The reusable TAB scoreboard owns match statistics.
	lobby = PanelContainer.new()
	GameUI.rect(lobby,22,22,275,100)
	add_child(lobby)
	var room := GameUI.label(lobby,"",12)
	room.name = "LobbyText"
	lobby.hide()
	dot = ColorRect.new()
	dot.color = FieldTheme.INK
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUI.rect(dot,-2,-2,2,2,Vector2(0.5,0.5))
	add_child(dot)
	damage = GameDamageFlash.new()
	damage.color = Color(0.02,0.02,0.03,0)
	damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage)
	waiting=GameUI.panel(self)
	GameUI.rect(waiting,-270,-76,270,76,Vector2(.5,.42))
	waiting.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var waiting_box:=VBoxContainer.new();waiting.add_child(waiting_box)
	GameUI.label(waiting_box,"AGUARDANDO JOGADORES",21,FieldTheme.ACCENT).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	waiting_text=GameUI.label(waiting_box,"",15)
	waiting_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	GameUI.label(waiting_box,"ESC · MENU",12,FieldTheme.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	waiting.hide()
	domination_panel=GameUI.panel(self);GameUI.rect(domination_panel,-265,20,265,110,Vector2(.5,0))
	domination_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var objective_box:=VBoxContainer.new();domination_panel.add_child(objective_box)
	domination_title=GameUI.label(objective_box,"DOMINAÇÃO · CASINHA",15,FieldTheme.ACCENT)
	domination_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	domination_detail=GameUI.label(objective_box,"",12,FieldTheme.INK);domination_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	domination_progress=ProgressBar.new();domination_progress.show_percentage=false;domination_progress.custom_minimum_size.y=4;objective_box.add_child(domination_progress)
	domination_panel.hide()
	supply_prompt=GameUI.label(self,"",14,FieldTheme.ACCENT)
	GameUI.rect(supply_prompt,-230,115,230,140,Vector2(.5,.5));supply_prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;supply_prompt.hide()
	grenade_text=GameUI.label(right,"G · GRANADA  2",12,FieldTheme.ACCENT)
	fuse_bar=ProgressBar.new();fuse_bar.show_percentage=false;fuse_bar.max_value=GameGrenades.FUSE;fuse_bar.custom_minimum_size.y=4;right.add_child(fuse_bar);fuse_bar.hide()
	notice = GameUI.label(self,"",18,FieldTheme.ACCENT)
	notice.anchor_left = 0.25
	notice.anchor_right = 0.75
	notice.anchor_top = 0.64
	notice.anchor_bottom = 0.70
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_text = GameUI.label(self,"",13,FieldTheme.ACCENT)
	GameUI.rect(reload_text,-140,50,140,75,Vector2(0.5,0.5))
	reload_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_bar = ProgressBar.new()
	reload_bar.show_percentage = false
	GameUI.rect(reload_bar,-85,80,85,83,Vector2(0.5,0.5))
	add_child(reload_bar)
	GameUI.hud_menu_button(self,func(): game.ui_focus.open(game.pause_panel))
	var feedback := GameUIFeedback.new()
	add_child(feedback)
	feedback.watch(self)
func apply_layout_variant(kind: String) -> void:
	# Layout is owned by its HUD. Modes supply a variant, not node surgery.
	if kind!="war": return
	GameUI.rect(hp.get_parent().get_parent(),24,-100,200,-24,Vector2(0,1))
	hp.add_theme_font_size_override("font_size",23)
	GameUI.rect(ammo.get_parent().get_parent(),-366,-370,-24,-24,Vector2.ONE)
	ammo.add_theme_font_size_override("font_size",23)
	shop.hide()
	weapon_row.add_theme_constant_override("separation",3)
	GameUI.rect(rank.get_parent(),-300,76,-24,365,Vector2(1,0))
	rank.get_parent().hide()

func _build_slot(parent: Node,key: int,compact:=false) -> void:
	var button:=GameUI.button(parent,"",func():
		if is_instance_valid(game.local_player): game.local_player.equip_quick_slot(key)
	)
	button.custom_minimum_size=Vector2(60 if compact else 0,28 if compact else 32)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var row:=HBoxContainer.new();row.mouse_filter=MOUSE_FILTER_IGNORE;button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.offset_left=7;row.offset_right=-7
	row.add_theme_constant_override("separation",6)
	var key_label:=GameUI.label(row,str(key),12,FieldTheme.MUTED);key_label.custom_minimum_size.x=12
	var icon:=TextureRect.new();icon.custom_minimum_size=Vector2(22,22);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=MOUSE_FILTER_IGNORE;row.add_child(icon)
	var label:=GameUI.label(row,"",13);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var amount:=GameUI.label(row,"",13);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amount.autowrap_mode=TextServer.AUTOWRAP_OFF
	if compact: label.hide();icon.custom_minimum_size.x=18
	slot_views[key]={"button":button,"label":label,"key_label":key_label,"amount":amount,"icon":icon,"id":"","selected":false,"color":Color.TRANSPARENT}

func _set_text(label: Label,value: String) -> void:
	if label.text!=value: label.text=value

func set_equipment_context(value: Dictionary) -> void:
	# Compare the small presentation packet, then mutate existing widgets only.
	# No nodes, textures or styleboxes are rebuilt by the regular HUD refresh.
	var signature:=str(value)
	if signature==equipment_signature: return
	equipment_signature=signature;equipment_context=value.duplicate()
	equipment_box.visible=bool(value.get("visible",false))
	if not equipment_box.visible: return
	var launcher:=bool(value.get("launchers",false))
	equipment_actions.visible=launcher;equipment_title.visible=not launcher
	_set_text(equipment_title,str(value.get("title","")))
	_set_text(equipment_state,str(value.get("state","")))
	var color:=FieldTheme.BAD if bool(value.get("empty",false)) else FieldTheme.MUTED
	if color!=equipment_color: equipment_color=color;equipment_state.add_theme_color_override("font_color",color)
	for id in equipment_buttons:
		var button: Button=equipment_buttons[id]
		button.visible=id in value.get("allowed",["rpg","stinger"])
		button.disabled=not bool(value.get("can_select",false))
		var selected: bool=bool(value.get("active",false)) and str(value.get("id",""))==id
		if bool(button.get_meta("equipment_selected",false))!=selected:
			button.set_meta("equipment_selected",selected);GameUI.accent(button,selected)

func _refresh_slots(player: GamePlayer) -> void:
	var slots:=GameInventorySlots.resolve(player)
	var signature:=str(slots)
	if signature!=slots_signature:
		slots_signature=signature;weapon_buttons.clear()
		for key in slot_views:
			var view: Dictionary=slot_views[key];var id:=str(slots.get(key,""));view.id=id
			# War launchers use the contextual 7/8 controls and shared charges.
			# They must not fall back into an extra melee slot with infinite ammo.
			if not id.is_empty() and id!="grenade" and str(GameWeapons.ITEMS.get(id,{}).get("kind",""))=="launcher": id="";view.id=""
			var grenade:=id=="grenade"
			view.button.visible=not id.is_empty()
			view.icon.texture=GameUI.icon(id) if not id.is_empty() else null
			_set_text(view.label,"GRANADA" if grenade else (str(GameWeapons.ITEMS[id].name).to_upper() if not id.is_empty() else {1:"PISTOLA",2:"PRINCIPAL",3:"GRANADA",4:"ARMA BRANCA"}.get(key,"EXTRA")))
			view.button.tooltip_text="%d · %s"%[key,view.label.text]
			if not grenade and not id.is_empty(): weapon_buttons[id]=view.button
	for key in slot_views:
		var view: Dictionary=slot_views[key];var id: String=view.id
		var grenade:=id=="grenade"
		view.button.disabled=player.hp<=0 or id.is_empty() or (grenade and (not player.grenades_enabled or (player.grenades<=0 and player.grenade_held_id.is_empty())))
		var selected: bool=player._grenade_active() if grenade else (not player._grenade_active() and not bool(equipment_context.get("active",false)) and id==player.weapon_id)
		if selected!=view.selected: view.selected=selected;GameUI.accent(view.button,selected)
		var color: Color=FieldTheme.ON_ACCENT if selected else (FieldTheme.MUTED if view.button.disabled else FieldTheme.INK)
		if color!=view.color:
			view.color=color
			for text_label: Label in [view.label,view.amount,view.key_label]: text_label.add_theme_color_override("font_color",color)
			view.icon.modulate=color
		var text:="—"
		if grenade: text="×%d"%player.grenades
		elif not id.is_empty(): text="%d / %d"%[int(player.ammo.get(id,0)),int(player.reserves.get(id,0))] if GameWeapons.ITEMS[id].kind=="firearm" else "∞"
		_set_text(view.amount,text)
	weapon_row.visible=not str(slot_views[5].id).is_empty() or not str(slot_views[6].id).is_empty() or not str(slot_views[9].id).is_empty()

func refresh() -> void:
	var waiting_for_players: bool=game.waiting_for_pvp()
	waiting.visible=waiting_for_players
	waiting_text.text="A partida começa com pelo menos 2 jogadores.\nConectados: %d/2 · Movimento e combate aguardando."%game.players.size()
	var player: GamePlayer = game.local_player
	if not is_instance_valid(player): return
	var objective: DesertDomination=game.domination if not game.get_meta("war_mode",false) else null
	domination_panel.visible=is_instance_valid(objective) and game.online
	supply_prompt.hide()
	if is_instance_valid(objective):
		domination_title.text=objective.headline(player.peer_id);domination_detail.text=objective.detail()
		domination_progress.value=objective.progress/DesertDomination.CAPTURE_SECONDS*100
		if player.hp>0 and DesertDomination.inside(player.global_position) and player.global_position.distance_to(DesertDomination.SUPPLY)<2.6:
			supply_prompt.show();var cooldown:=objective.supply_wait(player.peer_id)
			supply_prompt.text="MUNIÇÃO · PRONTA EM %d s"%ceili(cooldown) if cooldown>0 else "F · REABASTECER"
	var item: Dictionary = GameWeapons.ITEMS[player.weapon_id]
	_set_text(hp,"+ %d" % maxi(0,int(player.hp)))
	hp.add_theme_color_override("font_color",FieldTheme.BAD if player.hp<30 else FieldTheme.ACCENT)
	match_info.text = "PVP DESERTO · DOMINAÇÃO" if game.online else "TREINO · %02d:%02d" % [int(game.offline_elapsed)/60,int(game.offline_elapsed)%60]
	reload_text.visible = player.reload_left>0
	reload_bar.visible = player.reload_left>0
	reload_text.text = "RECARREGANDO · %.1f s" % player.reload_left
	reload_bar.value = (1.0-player.reload_left/maxf(player.reload_total,0.001))*100
	_refresh_slots(player)
	var grenade_active: bool=player._grenade_active()
	var special_active: bool=bool(equipment_context.get("visible",false)) and bool(equipment_context.get("active",false))
	var ammo_text: String="%s\n%s / %s" % [item.name.to_upper(),str(int(player.ammo.get(player.weapon_id,0))) if item.kind=="firearm" else "∞",str(int(player.reserves.get(player.weapon_id,0))) if item.kind=="firearm" else "—"]
	if special_active:
		ammo_text=str(equipment_context.get("name","EQUIPAMENTO"))+"\n"+str(equipment_context.get("amount","—"))
		reload_text.hide();reload_bar.hide()
	elif grenade_active: ammo_text="GRANADA\n×%d DISPONÍVEIS"%player.grenades
	_set_text(ammo,ammo_text)
	var zero_item:=player.weapon_spec(player.weapon_id)
	zeroing.visible=WEAPON_ZEROING.supported(zero_item) and not grenade_active and not special_active
	if zeroing.visible:
		_set_text(zeroing,"ZERAGEM · %d m · SCROLL AO MIRAR"%player.zeroing_distance())
	var magazine:=int(player.ammo.get(player.weapon_id,0))
	var warning:="SEM MUNIÇÃO · R PARA RECARREGAR" if magazine==0 and int(player.reserves.get(player.weapon_id,0))>0 else ("SEM MUNIÇÃO" if magazine==0 else "POUCA MUNIÇÃO")
	low_ammo.visible=item.kind=="firearm" and not grenade_active and not special_active and magazine<=maxi(1,int(item.mag)*.2)
	_set_text(low_ammo,warning)
	var color:=FieldTheme.BAD if low_ammo.visible or (special_active and bool(equipment_context.get("empty",false))) else FieldTheme.INK
	if color!=ammo_color: ammo_color=color;ammo.add_theme_color_override("font_color",color)
	grenade_text.visible=player.grenades_enabled
	_set_text(grenade_text,("ARMADA · %.1f s · SOLTE O CLIQUE"%player.grenade_fuse_left if not player.grenade_held_id.is_empty() or player.grenade_prime_pending else ("CLIQUE PARA ARMAR · PAVIO 5 s" if player.grenade_selected else "3 / G · GRANADA ×%d"%player.grenades)).replace(".",","))
	fuse_bar.visible=not player.grenade_held_id.is_empty() or player.grenade_prime_pending
	fuse_bar.value=player.grenade_fuse_left
	shop.text = "ARSENAL · %d MOEDAS" % int(game.profile.coins)
	if game.get_meta("war_mode",false):
		match_info.text = "GUERRA · CONQUISTA"
		shop.text = "IMPLANTAÇÃO · M"

var refresh_clock := 0.0

func pulse_damage(amount: float,current_hp: float) -> void:
	damage.pulse(amount,current_hp)

func reset_damage() -> void:
	damage.reset()
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	refresh_clock += delta
	if refresh_clock>=0.05:
		refresh_clock = 0.0
		refresh()
