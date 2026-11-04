extends Control
class_name BRHUD

var game: Node
var top: Label
var zone_text: Label
var shown_phase:=""
var action_notice: Label
var action_notice_until:=0.
var health: Label
var health_bar: ProgressBar
var protection_text: Label
var protection_rows: Array[Dictionary]=[]
var pack_label: Label
var pack_drop: Button
var capacity_bar: ProgressBar
var nearby_list: VBoxContainer
var nearby_signature:=-1
var ammunition: Label
var reload_text: Label
var prompt: Label
var death_text: Label
var minimap: BRMinimap
var waiting: PanelContainer
var waiting_count: Label
var waiting_roster: VBoxContainer
var waiting_total: Label
var waiting_signature:=-1
var live_widgets: Array[CanvasItem]=[]
var inventory_dividers: Array[Control]=[]
var start_button: Button
var result_panel: PanelContainer
var result_heading: Label
var result_detail: Label
var inventory_panel: PanelContainer
var pack_capacity: Label
var weapon_rows: Array[Dictionary]=[]
var ammo_rows: Array[Dictionary]=[]
var optic_rows: Array[Dictionary]=[]
var heal_button: Button
var heal_drop: Button
var cached_state: Dictionary={}
var cached_inventory: Dictionary={}
var cached_loot: Array=[]
var zone_overlay: ColorRect
var alert: Label
var microphone: Label
var speech: Label
var dead_results: Button
var statistics_panel: PanelContainer
var statistics_text: Label
var last_stage:=-1
var last_closing:=false
var notice_until:=0.
var notice_text:=""
var last_alive:=-1
var life_color:=Color.TRANSPARENT

func _ready() -> void:
	name="BattleRoyaleHUD";theme=GameUI.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE
	add_to_group("game_hud")
	zone_overlay=ColorRect.new();zone_overlay.color=Color(.22,.38,.65,.10);zone_overlay.mouse_filter=MOUSE_FILTER_IGNORE;zone_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(zone_overlay);zone_overlay.hide()
	var heading:=GameUI.panel(self,14);GameUI.rect(heading,-205,18,205,85,Vector2(.5,0))
	var headbox:=VBoxContainer.new();heading.add_child(headbox)
	top=GameUI.label(headbox,"BATTLE ROYALE",19,FieldTheme.ACCENT);top.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	zone_text=GameUI.label(headbox,"DESERTO AFEGÃO",13);zone_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	alert=GameUI.label(self,"",18,FieldTheme.ACCENT);GameUI.rect(alert,-300,91,300,121,Vector2(.5,0));alert.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	microphone=GameUI.label(self,"",13,FieldTheme.ACCENT);GameUI.rect(microphone,25,-217,345,-194,Vector2(0,1))
	speech=GameUI.label(self,"",13,FieldTheme.INK);GameUI.rect(speech,25,-191,345,-161,Vector2(0,1))
	var life:=GameUI.panel(self,18);GameUI.rect(life,20,-155,344,-20,Vector2(0,1))
	action_notice=GameUI.label(self,"",15,FieldTheme.ACCENT);GameUI.rect(action_notice,-260,-182,260,-155,Vector2(.5,1));action_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;action_notice.hide()
	var lifebox:=VBoxContainer.new();life.add_child(lifebox)
	health=GameUI.label(lifebox,"+ 100",38,FieldTheme.ACCENT)
	health_bar=ProgressBar.new();health_bar.custom_minimum_size.y=12;health_bar.show_percentage=false;health_bar.value=100;lifebox.add_child(health_bar)
	protection_text=GameUI.label(lifebox,"",13,FieldTheme.MUTED)
	GameUI.label(lifebox,"TAB · MOCHILA",12,FieldTheme.MUTED)
	var weapon:=GameUI.panel(self,14);GameUI.rect(weapon,-255,-132,-20,-20,Vector2.ONE)
	var weaponbox:=VBoxContainer.new();weapon.add_child(weaponbox)
	ammunition=GameUI.label(weaponbox,"SOCOS",23)
	reload_text=GameUI.label(weaponbox,"",13,FieldTheme.ACCENT)
	GameUI.label(weaponbox,"1 / 2 · ARMAS   3 · SOCOS",11,FieldTheme.MUTED)
	minimap=BRMinimap.new();GameUI.rect(minimap,-200,118,-20,298,Vector2(1,0));add_child(minimap)
	prompt=GameUI.label(self,"",16,FieldTheme.ACCENT);GameUI.rect(prompt,-240,55,240,86,Vector2(.5,.5));prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	death_text=GameUI.label(self,"",18,FieldTheme.BAD);GameUI.rect(death_text,-350,96,350,182,Vector2(.5,.5));death_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	dead_results=GameUI.button(self,"RESULTADOS",_open_statistics);GameUI.rect(dead_results,-85,189,85,231,Vector2(.5,.5));dead_results.hide()
	var menu:=GameUI.hud_menu_button(self,func():
		if is_instance_valid(game) and is_instance_valid(game.ui_focus): game.ui_focus.open(game.pause_panel)
	)
	live_widgets.assign([heading,alert,microphone,speech,life,weapon,minimap,prompt,death_text,dead_results,menu])
	waiting=GameUI.panel(self,24);GameUI.rect(waiting,-255,-285,255,285,Vector2(.5,.5));waiting.name="BRWaiting"
	var waitbox:=VBoxContainer.new();waitbox.add_theme_constant_override("separation",14);waiting.add_child(waitbox)
	GameUI.label(waitbox,"BATTLE ROYALE",25,FieldTheme.ACCENT)
	GameUI.label(waitbox,"DESERTO AFEGÃO",14,FieldTheme.MUTED)
	waiting_count=GameUI.label(waitbox,"Buscando partida",24,FieldTheme.ACCENT)
	_inventory_line(waitbox,false)
	waiting_total=GameUI.label(waitbox,"0 / 12",15,FieldTheme.MUTED)
	var roster_scroll:=ScrollContainer.new();roster_scroll.custom_minimum_size.y=240;roster_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;roster_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;waitbox.add_child(roster_scroll)
	waiting_roster=VBoxContainer.new();waiting_roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL;waiting_roster.add_theme_constant_override("separation",5);roster_scroll.add_child(waiting_roster)
	start_button=GameUI.button(waitbox,"INICIAR",func():
		if is_instance_valid(game): game.request_br_start()
	,true)
	GameUI.button(waitbox,"SAIR",func():
		if not is_instance_valid(game): return
		var pause_menu:=game.get("pause_panel") as GamePauseMenu
		if is_instance_valid(pause_menu): pause_menu.confirm_leave()
		else: game.leave_match()
	)
	result_panel=GameUI.panel(self,22);GameUI.rect(result_panel,-300,-180,300,180,Vector2(.5,.5))
	result_panel.set_meta("preferred_size",Vector2(620,460))
	result_panel.set_meta("ui_back_locked",true)
	var results:=VBoxContainer.new();results.add_theme_constant_override("separation",12);result_panel.add_child(results)
	result_heading=GameUI.label(results,"FIM DE PARTIDA",27,FieldTheme.ACCENT)
	result_detail=GameUI.label(results,"",16)
	GameUI.button(results,"VOLTAR",func():
		if is_instance_valid(game): game.leave_match()
	)
	result_panel.hide()
	statistics_panel=GameUI.panel(self,22);statistics_panel.set_meta("preferred_size",Vector2(620,470))
	var statistics:=VBoxContainer.new();statistics.add_theme_constant_override("separation",12);statistics_panel.add_child(statistics)
	GameUI.label(statistics,"RESULTADOS",25,FieldTheme.ACCENT)
	statistics_text=GameUI.label(statistics,"",17)
	GameUI.button(statistics,"ASSISTIR",func():
		if is_instance_valid(game.ui_focus) and statistics_panel in game.ui_focus.stack:game.ui_focus.close_top();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	)
	statistics_panel.hide()
	_build_inventory()

func _build_inventory() -> void:
	var panel:=BRInventoryPanel.new();panel.game=game;add_child(panel);inventory_panel=panel

func _inventory_line(parent: Node,vertical: bool) -> ColorRect:
	var line:=ColorRect.new();line.color=FieldTheme.BORDER.lightened(.24);line.mouse_filter=MOUSE_FILTER_IGNORE
	if vertical:line.custom_minimum_size.x=1;line.size_flags_vertical=Control.SIZE_EXPAND_FILL
	else:line.custom_minimum_size.y=1;line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(line);return line

func _input(event: InputEvent) -> void:
	# Tab must reach the backpack before focused buttons use it for traversal.
	if event is InputEventKey and event.keycode==KEY_TAB:_unhandled_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_P and is_instance_valid(game.local_player) and game.local_player.hp<=0 and cached_state.get("phase","")=="active":
		_open_statistics();get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_I,KEY_TAB]:
		if cached_state.get("phase","")!="active" or not is_instance_valid(game.local_player) or game.local_player.hp<=0: return
		if is_instance_valid(game.ui_focus) and game.ui_focus.blocked() and inventory_panel not in game.ui_focus.stack:return
		if inventory_panel.is_visible_in_tree(): _close_inventory()
		elif is_instance_valid(game.ui_focus): game.ui_focus.open(inventory_panel);_update_nearby()
		get_viewport().set_input_as_handled()

func _open_statistics() -> void:
	if not is_instance_valid(game.local_player) or game.local_player.hp>0 or cached_state.get("phase","")!="active":return
	statistics_text.text=_result_text(cached_state,cached_state.get("result",{}))
	if statistics_panel not in game.ui_focus.stack:game.ui_focus.open(statistics_panel)

func show_action_notice(message: String) -> void:
	action_notice.text=message.left(96);action_notice_until=Time.get_ticks_msec()*.001+2.5;action_notice.show()

func _close_inventory() -> void:
	if is_instance_valid(game.ui_focus) and inventory_panel in game.ui_focus.stack:
		game.ui_focus.close_top()
		if not game.ui_focus.blocked(): Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _weapons() -> Array:
	var value: Variant=cached_inventory.get("weapons",[])
	return value if value is Array else []

func _drop(index: int) -> void:
	var weapons:=_weapons()
	if index<weapons.size() and is_instance_valid(game): game.request_br_drop(str(weapons[index]))

func _select_weapon(index: int) -> void:
	if index<_weapons().size() and is_instance_valid(game):game.request_br_select_slot(index)

func _drop_protection(kind: String) -> void:
	if is_instance_valid(game):game.request_br_drop_protection(kind)

func _drop_optic(id: String) -> void:
	if is_instance_valid(game):game.request_br_drop_optic(id)

func _equip_optic(selection: int,slot: int) -> void:
	var weapons:=_weapons()
	if slot>=weapons.size() or not is_instance_valid(game):return
	var menu: OptionButton=weapon_rows[slot].optic
	game.request_br_optic(str(weapons[slot]),str(menu.get_item_metadata(selection)))

func _optic_title(id: String) -> String:
	return GameOpticCatalog.item_name(id) if GameOpticCatalog.valid(id) else "Mira de ferro"

func _drop_ammo(index: int) -> void:
	if index>=ammo_rows.size() or not is_instance_valid(game):return
	var calibre:=str(ammo_rows[index].calibre)
	var amount:=int(cached_inventory.get("ammo",{}).get(calibre,0))
	if amount>0:game.request_br_drop_ammo(calibre,mini(amount,30))

func _gear_name(kind: String,level: int) -> String:
	return str({"vest":"Colete","helmet":"Capacete","pack":"Mochila"}.get(kind,kind))+" %d"%level if level>0 else "—"

func _calibre(id: String) -> String:
	return str({"9mm":"9 mm","76239":"7,62 × 39","76251":"7,62 × 51","precision":"Precisão","rocket":"RPG-7","javelin":"Javelin"}.get(id,id))

func _loot_name(item: Dictionary) -> String:
	var kind:=str(item.get("kind",""))
	if kind=="weapon":return _name(str(item.get("weapon","")))
	if kind=="ammo":return "%s ×%d"%[_calibre(str(item.get("calibre",""))),int(item.get("amount",0))]
	if kind=="binoculars":return "Binóculos"
	if kind=="heal":return "Curativo ×%d"%int(item.get("amount",1))
	if kind in ["vest","helmet","pack"]:return _gear_name(kind,int(item.get("level",1)))
	if kind=="optic":return _optic_title(str(item.get("optic","")))+(" ×%d"%int(item.amount) if int(item.get("amount",1))>1 else "")
	return "Mochila"

func _take_nearby(id: int,part: int) -> void:
	if is_instance_valid(game):game.br_interact(id,part)

func _update_nearby() -> void:
	if inventory_panel is BRInventoryPanel:
		inventory_panel.present(cached_state,cached_inventory,cached_loot)

func _name(id: String) -> String:
	return str(GameWeapons.ITEMS.get(id,{"name":id}).get("name",id)).to_upper()

func refresh(state: Dictionary,own_inventory: Dictionary,loot: Array) -> void:
	if not is_node_ready(): return
	cached_state=state;cached_inventory=own_inventory;cached_loot=loot
	var phase:=str(state.get("phase","waiting"))
	waiting.visible=phase=="waiting";result_panel.visible=phase=="finished"
	action_notice.visible=phase=="active" and Time.get_ticks_msec()*.001<action_notice_until
	if phase!=shown_phase:
		shown_phase=phase
		if phase=="waiting":GameUI.fade(waiting)
		elif phase=="finished":GameUI.fade(result_panel)
		elif phase=="active":GameUI.scene_fade(self)
	for widget in live_widgets:widget.visible=phase!="waiting"
	var alive:=int(state.get("alive",0));var total:=int(state.get("total",alive))
	top.text="%d VIVOS    ·    %d ABATES"%[alive,int(state.get("kills",0))]
	_update_waiting(state)
	var zone: Dictionary=state.get("zone",{})
	var seconds:=maxi(0,int(ceil(float(zone.get("remaining",0)))))
	zone_text.text=("ZONA FECHANDO" if bool(zone.get("closing",false)) else "PRÓXIMA ZONA")+"  %d:%02d"%[seconds/60,seconds%60]
	if phase=="waiting": zone_text.text="DESERTO AFEGÃO"
	var actor: GamePlayer=game.local_player if is_instance_valid(game) else null
	dead_results.visible=is_instance_valid(actor) and actor.hp<=0 and phase=="active"
	if phase=="finished" and is_instance_valid(game.ui_focus) and statistics_panel in game.ui_focus.stack:game.ui_focus.close_top()
	if is_instance_valid(actor):
		health.text="+ %d"%maxi(0,int(ceil(actor.hp)));health_bar.value=actor.hp
		var color: Color=FieldTheme.BAD if actor.hp<=30 else (Color("e3bd6b") if actor.hp<=60 else FieldTheme.ACCENT)
		health.add_theme_color_override("font_color",color)
		if color!=life_color:
			life_color=color
			var fill:=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(3);health_bar.add_theme_stylebox_override("fill",fill)
		var gear: Dictionary=own_inventory.get("protection",{})
		protection_text.text="%s   ·   %s"%[_gear_name("vest",int(gear.get("vest",{}).get("level",0))),_gear_name("helmet",int(gear.get("helmet",{}).get("level",0)))]
		ammunition.text=_name(actor.weapon_id)
		if GameWeapons.ITEMS.get(actor.weapon_id,{}).get("kind","") in ["firearm","launcher"]: ammunition.text+="\n%d / %d"%[int(actor.ammo.get(actor.weapon_id,0)),int(actor.reserves.get(actor.weapon_id,0))]
		reload_text.text="RECARGA %.1f s"%actor.reload_left if actor.reload_left>0 else ""
		if float(state.get("heal_remaining",0))>0:reload_text.text="CURATIVO %.1f s"%float(state.heal_remaining)
		elif state.get("heal_recovering",false):reload_text.text="RECUPERANDO"
		minimap.present(zone,state.get("view_position",actor.global_position),float(state.get("view_yaw",actor.yaw)))
		_update_zone_warning(zone,actor,phase)
		_update_voice(actor,phase)
		_update_prompt(actor)
		if actor.hp<=0 and phase=="active":
			var result: Dictionary=state.get("result",{});var seconds_alive:=int(result.get("survival",0))
			death_text.text=str(state.get("death_notice","ELIMINADO"))+"\n#%d · %d abates · %d:%02d\nV · CÂMERA   ← / → · JOGADOR   P · RESULTADOS"%[int(result.get("placement",0)),int(result.get("kills",0)),seconds_alive/60,seconds_alive%60]
			if not str(state.get("spectating_name","")).is_empty():death_text.text+=" · "+str(state.spectating_name)
		else: death_text.text=""
		if actor.hp<=0 and inventory_panel.is_visible_in_tree(): _close_inventory()
	_update_inventory()
	if phase=="finished":
		var result: Dictionary=state.get("result",{})
		result_heading.text="VITÓRIA" if bool(result.get("victory",int(result.get("placement",0))==1)) else "FIM DE PARTIDA"
		result_detail.text=_result_text(state,result)

func _update_waiting(state: Dictionary) -> void:
	var countdown:=maxi(0,ceili(float(state.get("countdown",0))))
	var map_status:=str(state.get("map_status",""))
	var queue_status:=str(state.get("queue_status",""))
	waiting_count.text="Começa em %d s"%countdown if countdown>0 else (queue_status if not queue_status.is_empty() else "Buscando partida")
	if not map_status.is_empty():waiting_count.text=map_status
	start_button.visible=bool(state.get("can_start",false)) and countdown<=0
	start_button.disabled=int(state.get("total",0))<1 or not map_status.is_empty()
	var roster: Array=state.get("roster",[])
	waiting_total.text="%d / %d"%[int(state.get("total",roster.size())),int(state.get("capacity",12))]
	var signature:=hash(roster)
	if signature==waiting_signature:return
	waiting_signature=signature
	for child in waiting_roster.get_children():waiting_roster.remove_child(child);child.queue_free()
	for record: Dictionary in roster.slice(0,40):
		var row:=HBoxContainer.new();waiting_roster.add_child(row)
		var color: Color=FieldTheme.ACCENT if bool(record.get("local",false)) else FieldTheme.INK
		var label:=GameUI.label(row,str(record.get("name","")),16,color);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if true:
			var bot:=GameUI.label(row,"BOT" if bool(record.get("bot",false)) else str(record.get("status","Conectando")),11,FieldTheme.MUTED);bot.autowrap_mode=TextServer.AUTOWRAP_OFF;bot.custom_minimum_size.x=36;bot.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func _result_text(state: Dictionary,result: Dictionary) -> String:
	var elapsed:=int(result.get("survival",result.get("survival_seconds",state.get("elapsed",0))))
	var shots:=int(result.get("shots",0));var hits:=int(result.get("hits",0))
	var distance:=float(result.get("distance",0))/1000.
	var text:="%s\n\n#%d  ·  %d abates  ·  %d:%02d\n%.2f km  ·  %d dano causado  ·  %d recebido\n%d / %d acertos  ·  %.0f%% precisão\n%d itens recolhidos"%[str(state.get("winner_name","")),int(result.get("placement",0)),int(result.get("kills",state.get("kills",0))),elapsed/60,elapsed%60,distance,int(result.get("damage",0)),int(result.get("received",0)),hits,shots,minf(100.,100.*hits/maxi(1,shots)),int(result.get("items",0))]
	if not str(state.get("death_notice","")).is_empty():text+="\n"+str(state.death_notice)
	if state.get("phase","")=="finished":text+="\nNova partida em %d s"%maxi(0,int(ceil(float(state.get("countdown",0)))))
	var favorite:=str(result.get("favorite",""))
	if not favorite.is_empty():text+="\nMais usada · "+_name(favorite)
	return text

func _update_zone_warning(zone: Dictionary,actor: GamePlayer,phase: String) -> void:
	var current:=Time.get_ticks_msec()*.001
	var outside:=false
	if phase=="active" and actor.hp>0 and zone.has("center"):
		var center: Vector2=zone.center;var offset:=Vector2(actor.global_position.x,actor.global_position.z)-center
		var distance:=offset.length()-float(zone.get("radius",1500.))
		outside=distance>0
		if outside:
			var heading:=actor.yaw-atan2(offset.x,offset.y)
			var direction:=int(posmod(roundi(heading/(PI*.25)),8))
			var arrows:=["↑","↗","→","↘","↓","↙","←","↖"]
			alert.text="%s  ZONA · %d m"%[arrows[direction],ceili(distance)];alert.add_theme_color_override("font_color",FieldTheme.BAD)
		var closing:=bool(zone.get("closing",false));var stage:=int(zone.get("phase",zone.get("stage",0)))
		if stage!=last_stage or (closing and not last_closing):
			notice_text="ZONA FECHANDO" if closing else "PRÓXIMA ZONA";notice_until=current+3.5
		last_stage=stage;last_closing=closing
		var alive:=int(cached_state.get("alive",0))
		if alive!=last_alive and alive>1 and alive<=5:
			notice_text="%d SOBREVIVENTES"%alive;notice_until=current+3.5
		last_alive=alive
	elif phase=="waiting":
		last_stage=-1;last_alive=-1;last_closing=false;notice_until=0.
	zone_overlay.visible=outside
	if not outside:
		alert.add_theme_color_override("font_color",FieldTheme.ACCENT)
		alert.text=notice_text if current<notice_until and phase=="active" else ""

func _update_voice(actor: GamePlayer,phase: String) -> void:
	microphone.text="";speech.text=""
	if not game.get_meta("battle_royale",false) or phase!="active" or actor.hp<=0:return
	var voice:=game.get("voice") as BRVoiceRelay
	if not is_instance_valid(voice):return
	if voice.is_transmitting():microphone.text="●  MICROFONE"
	elif not GameVoiceSettings.enabled():microphone.text="VOZ DESLIGADA"
	var names:=PackedStringArray()
	for id in voice.talking:
		if not voice.voice_muted(int(id)):names.append(str(voice.roster.get(id,{}).get("name","")))
	speech.text=" · ".join(names.slice(0,3))

func _update_prompt(actor: GamePlayer) -> void:
	prompt.text=""
	if actor.hp<=0 or cached_state.get("phase","")!="active": return
	var nearest: Dictionary={};var best:=9.0
	for record: Dictionary in cached_loot:
		if record.get("taken",false) or not bool(record.get("active",true)): continue
		var point: Variant=record.get("position",record.get("pos",Vector3.INF))
		if not point is Vector3: continue
		var distance:=actor.global_position.distance_squared_to(point)
		if distance<best: nearest=record;best=distance
	if not nearest.is_empty():
		var id:=str(nearest.get("item",nearest.get("weapon",nearest.get("type",""))))
		var kind:=str(nearest.get("kind",nearest.get("type","")))
		var label:=_name(id)
		if kind in ["ammo","ammunition"]: label=str(nearest.get("calibre",nearest.get("caliber",id)))+"  ×"+str(nearest.get("amount",0))
		elif kind in ["medkit","heal"]: label="CURATIVO"
		elif kind in ["container","backpack"]: label="CORPO" if nearest.has("corpse_key") else "MOCHILA"
		elif kind in ["vest","helmet","pack"]:label=_gear_name(kind,int(nearest.get("level",1)))
		elif kind in ["optic","attachment"]:
			var definition=GameAttachmentRegistry.definition(str(nearest.get("attachment",nearest.get("optic",""))))
			label=str(definition.display_name) if definition else "Acessório"
		prompt.text="F · "+label

func _update_inventory() -> void:
	if inventory_panel is BRInventoryPanel:
		inventory_panel.present(cached_state,cached_inventory,cached_loot)

func _exit_tree() -> void:
	if is_instance_valid(inventory_panel) and inventory_panel.get_parent()!=self: inventory_panel.queue_free()
	if is_instance_valid(statistics_panel) and statistics_panel.get_parent()!=self:statistics_panel.queue_free()
