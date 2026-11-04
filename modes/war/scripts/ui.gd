extends Control
class_name WarUI
var game: Node3D
var deployment: Control
var objective_bar: Control
var context: Label
var vehicle_info: Label
var team_select: OptionButton
var class_select: OptionButton
var loadout_editor: GameLoadoutEditor
var submitting:=false
var spawn_select: OptionButton
var deploy_button: Button
var feedback: Label
var preview: GameItemPreview
var class_detail: Label
var clock := 0.0
var vehicle_panel: PanelContainer
var vehicle_health: ProgressBar
var markers: Array[Dictionary]=[]
var offline_operation:=false
var deployment_kicker: Label
var deployment_description: Label
var saved_deployment: Label
var resume_button: Button
var marker_clock:=.25
var combat_notice: PanelContainer
var combat_notice_text: Label
var combat_notice_left:=0.0
var death_notice: PanelContainer
var death_notice_text: Label
var death_countdown_text: Label
var minimap: WarTacticalMap
var deployment_map: WarTacticalMap
var tactical_panel: PanelContainer
var tactical_map: WarTacticalMap
var capture_panel: PanelContainer
var capture_label: Label
var capture_progress: ProgressBar
var invalid_spawn:=false
var spawn_signature:=""
var waiting_panel: PanelContainer
var round_panel: PanelContainer
var round_result: Label
var round_timer: Label

func _ready() -> void:
	offline_operation=bool(game.get("offline_operation"))
	add_to_group("game_hud")
	theme = GameUI.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := GameUI.panel(self)
	GameUI.rect(top,-255,16,255,73,Vector2(.5,0))
	objective_bar=preload("res://modes/war/scripts/objective_bar.gd").new()
	top.add_child(objective_bar)
	context = GameUI.label(self,"",12,FieldTheme.MUTED)
	GameUI.rect(context,24,-348,550,-320,Vector2(0,1))
	vehicle_panel=GameUI.panel(self)
	GameUI.rect(vehicle_panel,-385,-226,-24,-24,Vector2.ONE)
	var vehicle_column:=VBoxContainer.new();vehicle_panel.add_child(vehicle_column)
	vehicle_info = GameUI.label(vehicle_column,"",16)
	vehicle_health=ProgressBar.new();vehicle_health.show_percentage=false;vehicle_health.custom_minimum_size.y=4
	vehicle_column.add_child(vehicle_health)
	vehicle_panel.hide()
	for id in WarRules.OBJECTIVES:
		var point: Vector3=WarRules.OBJECTIVES[id].position
		markers.append({"id":id,"world":WarTerrain.point(point.x,point.z)+Vector3.UP*5,"at":Vector2.ZERO,"text":id,"color":FieldTheme.INK,"visible":false})
	# Reuse the infantry state widgets, with a compact War layout and no
	# duplicate deployment button or permanently empty scoreboard panel.
	var hud: GameInfantryHUD=game.infantry_hud
	hud.apply_layout_variant("war")
	hud.equipment_selected.connect(func(id: String):
		if is_instance_valid(game.local_player) and game.local_player.hp>0 and game.local_player.deployed and game.local_player.vehicle_id.is_empty(): game.select_gadget(id)
	)
	_build_deployment()
	_build_maps()
	# Shared pause/settings already expose audio and the shoulder camera.
	var alerts:=CanvasLayer.new();alerts.layer=45;add_child(alerts)
	combat_notice=GameUI.panel(alerts)
	GameUI.rect(combat_notice,-340,88,340,146,Vector2(.5,0))
	combat_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	combat_notice_text=GameUI.label(combat_notice,"",18,FieldTheme.BAD)
	combat_notice_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	combat_notice_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	combat_notice.hide()
	var death_layer:=CanvasLayer.new();death_layer.layer=46;add_child(death_layer)
	death_notice=GameUI.panel(death_layer)
	GameUI.rect(death_notice,-225,-64,225,64,Vector2(.5,.42))
	death_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var death_box:=VBoxContainer.new();death_box.alignment=BoxContainer.ALIGNMENT_CENTER
	death_box.add_theme_constant_override("separation",3);death_notice.add_child(death_box)
	death_notice_text=GameUI.label(death_box,"VOCÊ MORREU",25,FieldTheme.BAD)
	death_notice_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	death_countdown_text=GameUI.label(death_box,"RETORNO EM 08",16,FieldTheme.ACCENT)
	death_countdown_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	death_notice.hide()
	capture_panel=GameUI.panel(self)
	GameUI.rect(capture_panel,-160,-224,160,-152,Vector2(.5,1))
	var capture_box:=VBoxContainer.new();capture_panel.add_child(capture_box)
	capture_label=GameUI.label(capture_box,"",15,FieldTheme.ACCENT);capture_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	capture_progress=ProgressBar.new();capture_progress.show_percentage=false;capture_progress.custom_minimum_size.y=5;capture_box.add_child(capture_progress)
	capture_panel.hide()
	waiting_panel=GameUI.panel(self)
	GameUI.rect(waiting_panel,-220,104,220,178,Vector2(.5,0))
	var waiting_box:=VBoxContainer.new();waiting_panel.add_child(waiting_box)
	var waiting_title:=GameUI.label(waiting_box,"AGUARDANDO OPONENTE",20,FieldTheme.ACCENT);waiting_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var waiting_detail:=GameUI.label(waiting_box,"É preciso um jogador em cada equipe.",14,FieldTheme.MUTED);waiting_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	waiting_panel.hide()
	round_panel=GameUI.panel(game.ui_focus)
	round_panel.set_meta("preferred_size",Vector2(460,220))
	round_panel.set_meta("ui_back_locked",true)
	var round_box:=VBoxContainer.new();round_box.add_theme_constant_override("separation",16);round_panel.add_child(round_box)
	round_result=GameUI.label(round_box,"",25,FieldTheme.ACCENT);round_result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	round_timer=GameUI.label(round_box,"",18,FieldTheme.INK);round_timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	GameUI.button(round_box,"VOLTAR AO MENU",func(): game.show_menu())
	round_panel.hide()

func show_round_end() -> void:
	if not is_instance_valid(round_panel) or round_panel.visible: return
	game.ui_focus.close_all();game.ui_focus.open(round_panel);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func close_round_end() -> void:
	if is_instance_valid(round_panel) and round_panel.visible: game.ui_focus.close_all()

func _build_maps() -> void:
	minimap=WarTacticalMap.new();minimap.game=game;minimap.compact=true;add_child(minimap)
	GameUI.rect(minimap,24,-316,214,-126,Vector2(0,1))
	tactical_panel=GameUI.panel(game.ui_focus);tactical_panel.set_meta("preferred_size",Vector2(900,760))
	var box:=VBoxContainer.new();tactical_panel.add_child(box)
	GameUI.label(box,"SETOR DE OPERAÇÕES",22,FieldTheme.ACCENT)
	tactical_map=WarTacticalMap.new();tactical_map.game=game;tactical_map.custom_minimum_size=Vector2(600,580);tactical_map.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(tactical_map)
	GameUI.button(box,"VOLTAR",close_map);tactical_panel.hide()

func toggle_map() -> void:
	if tactical_panel.visible: close_map();return
	if game.ui_focus.blocked(): return
	tactical_map.team=game.local_player.war_team if is_instance_valid(game.local_player) else 0
	game.ui_focus.open(tactical_panel)

func close_map() -> void:
	game.ui_focus.close_top()
	if not game.ui_focus.blocked(): Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func show_combat_notice(message: String) -> void:
	combat_notice_text.text=message.left(180);combat_notice_left=8.0 if message.begins_with("FOGO AMIGO") else 2.0
	combat_notice_text.add_theme_color_override("font_color",FieldTheme.BAD if message.begins_with("FOGO AMIGO") else FieldTheme.ACCENT);combat_notice.show()

func _build_war_settings() -> void:
	var panel: PanelContainer=game._modal_card("ÁUDIO E CÂMERA · GUERRA")
	var column:=panel.find_child("Content",true,false) as VBoxContainer
	GameUI.button(column,"SENSIBILIDADE DE ARMAS E VEÍCULOS",func(): game.aim_settings_panel.present(game.ui_focus,game.aim_settings_context()))
	column.add_child(GameAudioSettingsPanel.new())
	var camera_options:=NavalStorage.read_json(NavalStorage.settings_folder().path_join("war-camera.json"))
	for field in ["distance","side"]:
		GameUI.label(column,"DISTÂNCIA DA CÂMERA" if field=="distance" else "DESLOCAMENTO NO OMBRO",12,FieldTheme.ACCENT)
		var slider:=HSlider.new();slider.min_value=2 if field=="distance" else .4;slider.max_value=4 if field=="distance" else 1.05;slider.step=.05
		slider.value=float(camera_options.get(field,3.25 if field=="distance" else .72));column.add_child(slider)
		slider.value_changed.connect(func(value: float):
			camera_options[field]=value
			NavalStorage.write_json(NavalStorage.settings_folder().path_join("war-camera.json"),camera_options)
			if is_instance_valid(game.local_player):
				if field=="distance": game.local_player.shoulder_distance=value
				else: game.local_player.shoulder_side=value
		)
	GameUI.button(column,"VOLTAR",func(): game.ui_focus.close_top())
	var pause_content: Node=game.pause_panel.find_child("Content",true,false)
	GameUI.button(pause_content,"ÁUDIO E CÂMERA · GUERRA",func(): game.ui_focus.open(panel))

func _build_deployment() -> void:
	deployment = PanelContainer.new()
	deployment.name = "WarDeployment"
	deployment.set_meta("fullscreen",true)
	deployment.theme = GameUI.THEME
	deployment.add_theme_stylebox_override("panel",FieldTheme.box(FieldTheme.BASE,FieldTheme.BORDER,26))
	var shell:=VBoxContainer.new();shell.add_theme_constant_override("separation",10);deployment.add_child(shell)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14)
	scroll.add_child(content)
	deployment_kicker=GameUI.label(content,"GUERRA · OFFLINE" if offline_operation else "GUERRA · CONQUISTA",13,FieldTheme.ACCENT)
	GameUI.label(content,"IMPLANTAÇÃO",32)
	deployment_description=GameUI.label(content,"" if offline_operation else "",15,FieldTheme.MUTED)
	deployment_description.hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	content.add_child(row)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation",9)
	row.add_child(form)
	if offline_operation:
		var count:=_choice(form,"PARTICIPANTES",["12","18"]);count.select(1)
		count.item_selected.connect(func(index: int):
			if game.bot_director and game.bot_director.bots.is_empty(): game.offline_participants=12 if index==0 else 18
		)
		count.set_meta("offline_population",true)
	team_select = _choice(form,"EQUIPE",[WarRules.team_name(0),WarRules.team_name(1)])
	class_select = _choice(form,"CLASSE",["Médico","Soldado","Antitanque","Atirador"])
	class_select.select(1)
	class_select.item_selected.connect(func(_i): _class_changed())
	team_select.item_selected.connect(func(_i): invalid_spawn=false;_class_changed();refresh_spawns())
	class_detail = GameUI.label(form,"",14,FieldTheme.MUTED)
	loadout_editor=GameLoadoutEditor.new();form.add_child(loadout_editor)
	spawn_select = _choice(form,"PONTO DE IMPLANTAÇÃO",["Base principal"])
	spawn_select.item_selected.connect(func(_i): invalid_spawn=false;_sync_map_selection())
	preview = GameItemPreview.new()
	preview.custom_minimum_size = Vector2(180,130)
	form.add_child(preview)
	deployment_map=WarTacticalMap.new();deployment_map.game=game;deployment_map.selectable=true
	deployment_map.size_flags_horizontal=Control.SIZE_EXPAND_FILL;deployment_map.size_flags_vertical=Control.SIZE_EXPAND_FILL
	row.add_child(deployment_map)
	deployment_map.spawn_chosen.connect(func(id: String):
		for index in spawn_select.item_count:
			if str(spawn_select.get_item_metadata(index))==id: spawn_select.select(index);invalid_spawn=false;_sync_map_selection();break
	)
	loadout_editor.preview=preview
	feedback = GameUI.label(shell,"Preparando treino offline..." if offline_operation else "Conectando ao setor...",15,FieldTheme.ACCENT)
	saved_deployment=GameUI.label(shell,"",13,FieldTheme.MUTED);saved_deployment.hide()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",12)
	shell.add_child(buttons)
	deploy_button = GameUI.button(buttons,"IMPLANTAR",_deploy,true)
	deploy_button.custom_minimum_size.x = 230
	resume_button=GameUI.button(buttons,"VOLTAR",func(): game.close_deployment());resume_button.disabled=true
	GameUI.button(buttons,"MENU PRINCIPAL",func(): game.pause_panel.confirm_leave())
	game.ui_focus.add_child(deployment)
	deployment.hide()
	var saved:=GameLoadouts.war_last(game)
	team_select.select(int(saved.team));class_select.select(WarRules.CLASSES.keys().find(saved.role))
	_class_changed.call_deferred()

func _choice(parent: Node,title: String,values: Array) -> OptionButton:
	GameUI.label(parent,title,12,FieldTheme.ACCENT)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 38
	for value in values: option.add_item(value)
	parent.add_child(option)
	return option

func role() -> String: return str(WarRules.CLASSES.keys()[class_select.selected])

func _class_changed() -> void:
	if not is_instance_valid(loadout_editor): return
	class_detail.text="";class_detail.hide()
	loadout_editor.configure(game,"war",role(),team_select.selected)
	if loadout_editor.equipment_changed: feedback.text="Equipamento atualizado."

func _preview() -> void:
	if is_instance_valid(loadout_editor): loadout_editor._update_preview()

func set_submitting(value: bool) -> void:
	submitting=value
	for control in [team_select,class_select,spawn_select]: control.disabled=value
	loadout_editor.mouse_filter=Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_PASS
	for control in loadout_editor.find_children("*","BaseButton",true,false): control.disabled=value
	deploy_button.disabled=value or not game.deployment_ready()

func _deploy() -> void:
	if submitting or invalid_spawn: return
	var approved:=loadout_editor.approved()
	if not approved.ok: feedback.text=str(approved.error);return
	GameLoadouts.save(game,"war",approved.slots,role(),team_select.selected)
	var spawn_id := str(spawn_select.get_item_metadata(spawn_select.selected))
	if spawn_id=="<null>": spawn_id="base"
	set_submitting(true)
	game.request_deploy(team_select.selected,role(),str(approved.equipped),WarRules.launcher_for_team(team_select.selected),spawn_id,approved.slots)

func refresh_spawns() -> void:
	var next:="%d:"%team_select.selected
	for id in WarRules.OBJECTIVES: next+="%s:%s;"%[id,game.objective_states.get(id,{}).get("owner",-1)]
	if next==spawn_signature: return
	spawn_signature=next
	var selected := str(spawn_select.get_item_metadata(spawn_select.selected)) if spawn_select.selected>=0 else "base"
	spawn_select.clear()
	for entry in [["Base principal","base"]]:
		spawn_select.add_item(entry[0]);spawn_select.set_item_metadata(spawn_select.item_count-1,entry[1])
	for id in WarRules.OBJECTIVES:
		if not WarRules.OBJECTIVES[id].active: continue
		if int(game.objective_states.get(id,{}).get("owner",-1))==team_select.selected:
			spawn_select.add_item(id+" · "+str(WarRules.OBJECTIVES[id].name))
			spawn_select.set_item_metadata(spawn_select.item_count-1,id)
	spawn_select.select(0)
	var found:=selected=="base" or selected=="<null>"
	for index in spawn_select.item_count:
		if str(spawn_select.get_item_metadata(index))==selected: spawn_select.select(index);found=true;break
	if not found: invalid_spawn=true
	_sync_map_selection()

func _sync_map_selection() -> void:
	if not is_instance_valid(deployment_map): return
	deployment_map.team=team_select.selected
	deployment_map.selected_spawn=str(spawn_select.get_item_metadata(spawn_select.selected)) if spawn_select.selected>=0 else ""
	deployment_map.refresh()

func restore_selection() -> void:
	if not is_instance_valid(game.local_player): return
	var state: Dictionary=game.members.get(game.local_player.peer_id,{})
	var choice: Dictionary=state.get("pending",{})
	if choice.is_empty(): choice=state
	var team:=int(choice.get("team",-1))
	if team not in [0,1]: return
	team_select.select(team)
	var chosen_role:=str(choice.get("role","soldier"))
	class_select.select(maxi(0,WarRules.CLASSES.keys().find(chosen_role)))
	_class_changed()
	var slots: Dictionary=choice.get("loadout",{})
	if not slots.is_empty():
		loadout_editor.slots=slots.duplicate();loadout_editor._rebuild();loadout_editor._update_preview()
	refresh_spawns()
	var wanted:=str(choice.get("spawn","base"))
	for index in spawn_select.item_count:
		if str(spawn_select.get_item_metadata(index))==wanted: spawn_select.select(index);invalid_spawn=false;_sync_map_selection();return
	invalid_spawn=wanted!="base"

func _process(delta: float) -> void:
	if combat_notice_left>0:
		combat_notice_left=maxf(0,combat_notice_left-delta)
		if combat_notice_left==0: combat_notice.hide()
	# Projection must follow the final render camera, not the 10 Hz state UI.
	# _draw reads its current transform after movement/camera scripts have run.
	queue_redraw()
	marker_clock+=delta
	if marker_clock>=.25: marker_clock=0;_refresh_marker_labels()
	clock += delta
	if clock<.1: return
	clock = 0
	var hud: GameInfantryHUD=game.infantry_hud
	hud.shop.hide()
	hud.rank.get_parent().hide()
	var actor:=game.local_player as WarPlayer
	if game.match_ended:
		if not round_panel.visible: show_round_end()
		var own_team:=actor.war_team if is_instance_valid(actor) else -1
		round_result.text="EMPATE" if game.winner<0 else ("VITÓRIA" if game.winner==own_team else "DERROTA")
		round_timer.text="PRÓXIMA PARTIDA · %02d:%02d"%[int(ceilf(game.round_restart_left))/60,int(ceilf(game.round_restart_left))%60]
	waiting_panel.visible=is_instance_valid(actor) and actor.hp>0 and actor.deployed and not game._battle_active() and not game.match_ended and not game.ui_focus.blocked()
	_refresh_capture(actor)
	minimap.visible=is_instance_valid(actor) and actor.hp>0 and actor.deployed and not game.ui_focus.blocked()
	var death_state: Dictionary=game.members.get(actor.peer_id,{}) if is_instance_valid(actor) else {}
	var is_dead: bool=is_instance_valid(actor) and actor.hp<=0 and bool(death_state.get("respawn_pending",false))
	death_notice.visible=is_dead and not deployment.visible
	if is_dead:
		if game.match_ended:
			death_countdown_text.text="FIM DA PARTIDA"
		else:
			var respawn_seconds:=ceili(game.deployment_wait_left())
			death_countdown_text.text="IMPLANTAÇÃO EM %d"%respawn_seconds if respawn_seconds>0 else "ESCOLHA ONDE IMPLANTAR"
	objective_bar.update_state(actor.war_team if is_instance_valid(actor) else -1,game.tickets,game.objective_states,maxi(0,int(game.match_left)))
	context.text = game.context_text() if game._battle_active() else ""
	vehicle_info.text = game.vehicle_hud_text()
	var riding: bool=is_instance_valid(game.local_player) and not game.local_player.vehicle_id.is_empty()
	vehicle_panel.visible=riding
	hud.ammo.get_parent().get_parent().visible=not riding and not game.water_restricted(game.local_player)
	hud.hp.get_parent().get_parent().visible=not riding
	_refresh_equipment(hud)
	if riding and game.vehicle_system:
		var vehicle: Node3D=game.vehicle_system.find_target(game.local_player.vehicle_id)
		if is_instance_valid(vehicle):
			var naval: bool=vehicle is WarShip and game.vehicle_system._local_is_operator()
			if naval!=bool(vehicle_panel.get_meta("naval_layout",false)):
				vehicle_panel.set_meta("naval_layout",naval)
				if naval: GameUI.rect(vehicle_panel,-390,-158,390,-24,Vector2(.5,1))
				else: GameUI.rect(vehicle_panel,-385,-226,-24,-24,Vector2.ONE)
			vehicle_health.max_value=60 if vehicle is WarDrone else float(vehicle.spec.hp)
			vehicle_health.value=vehicle.hp
	if deployment.visible:
		for child: Node in deployment.find_children("*","OptionButton",true,false):
			if child.has_meta("offline_population"): child.disabled=game.bot_director!=null and not game.bot_director.bots.is_empty()
		resume_button.disabled=not is_instance_valid(game.local_player) or game.local_player.hp<=0 or not game.local_player.deployed
		refresh_spawns()
		feedback.text = "Ponto perdido. Escolha onde implantar." if invalid_spawn else game.deployment_message()
		deploy_button.disabled = submitting or invalid_spawn or not game.deployment_ready()
		var wait_left: float=game.deployment_wait_left()
		deploy_button.text = ("REIMPLANTAÇÃO · %.1f s"%wait_left).replace(".",",") if wait_left>0 else ("PRÓXIMA VIDA" if is_instance_valid(game.local_player) and game.local_player.hp>0 and game.local_player.deployed else "IMPLANTAR")
		var pending: Dictionary=game.members.get(game.local_player.peer_id,{}).get("pending",{}) if is_instance_valid(game.local_player) else {}
		saved_deployment.visible=not pending.is_empty()
		if not pending.is_empty():
			var spawn:=str(pending.get("spawn","base"))
			var place: String={"base":"BASE PRINCIPAL","rally":"LINHA AVANÇADA"}.get(spawn,"SETOR "+spawn)
			var role_name:=str(WarRules.CLASSES.get(str(pending.get("role","soldier")),WarRules.CLASSES.soldier).name).to_upper()
			var text:="%s · %s · %s"%[WarRules.team_name(int(pending.get("team",0))).to_upper(),role_name,place]
			if saved_deployment.text!=text: saved_deployment.text=text

func _refresh_capture(actor: WarPlayer) -> void:
	capture_panel.hide()
	if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty() or game.ui_focus.blocked(): return
	for id in WarRules.OBJECTIVES:
		var point: Vector3=WarRules.OBJECTIVES[id].position
		if Vector2(actor.global_position.x-point.x,actor.global_position.z-point.z).length()>WarRules.CAPTURE_RADIUS: continue
		var state: Dictionary=game.objective_states[id]
		var side:=int(state.side);var owner:=int(state.owner)
		var label_text:="CONTESTADO" if state.contested else (("NEUTRALIZANDO" if owner>=0 and owner!=actor.war_team else "CAPTURANDO") if side==actor.war_team else ("PERDENDO" if side>=0 else ("CONTROLADO" if owner==actor.war_team else "NEUTRO")))
		capture_label.text="%s · %s%s"%[id,label_text," · %d%%"%roundi(float(state.progress)*100) if side>=0 and not state.contested else ""]
		capture_progress.value=float(state.progress)*100
		capture_panel.show();return

func _refresh_equipment(hud: GameInfantryHUD) -> void:
	var actor:=game.local_player as WarPlayer
	if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed or not actor.vehicle_id.is_empty() or actor.in_water() or not actor.get_meta("class_equipment",true):
		hud.set_equipment_context({});return
	var member: Dictionary=game.members.get(actor.peer_id,{})
	var role:=actor.war_class
	var launcher:=role=="antitank"
	var active: bool=(launcher and actor.gadget_equipped) or not actor.utility_mode.is_empty()
	var charges: int=maxi(0,int(member.get("charges",0)))
	var known:=member.has("charges") and member.has("last_gadget")
	var cooldown:=6.0 if role=="soldier" else (float(WarRules.SPECIAL.get(actor.gadget,WarRules.SPECIAL.rpg).cooldown) if launcher else 1.0)
	var left:=maxf(0.0,float(member.get("last_gadget",-100.0))+cooldown-float(game.war_clock))
	var status:="PRONTO"
	if not known: status=""
	elif not game._battle_active(): status="AGUARDANDO EQUIPES"
	elif charges==0: status="SEM CARGAS"
	elif left>0: status=("PRONTO EM %.1f s"%left).replace(".",",")
	elif active and actor.gadget=="stinger" and is_instance_valid(game.vehicle_system):
		status="SEM ALVO" if game.vehicle_system.lock_target.is_empty() else ("ALVO TRAVADO" if game.vehicle_system.lock_progress>=1.0 else "TRAVANDO ALVO")
	var amount:="×%d"%charges if known else "—"
	var titles:={"medic":"G · KIT MÉDICO","soldier":"H · REABASTECER","marksman":"G · BINÓCULOS"}
	var name_text: String=("KIT MÉDICO" if actor.utility_mode=="medic" else "BINÓCULOS") if not actor.utility_mode.is_empty() else ("JAVELIN" if actor.gadget=="stinger" else "RPG-7")
	var is_binoculars: bool=role=="marksman"
	hud.set_equipment_context({"visible":true,"launchers":launcher,"active":active,"id":actor.gadget,"allowed":[WarRules.launcher_for_team(actor.war_team)],"name":name_text,"amount":"" if is_binoculars else amount+" DISPONÍVEIS","can_select":launcher,"title":str(titles.get(role,"EQUIPAMENTO")),"state":"" if is_binoculars else (amount+" CARGAS · "+status if known else "—"),"empty":not is_binoculars and known and charges==0})

func _refresh_marker_labels() -> void:
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or not is_instance_valid(game.local_player): return
	for marker in markers:
		var state: Dictionary=game.objective_states.get(marker.id,{})
		var owner:=int(state.get("owner",-1))
		marker.text=str(marker.id)+" · %d m"%int(camera.global_position.distance_to(marker.world))
		marker.color=FieldTheme.ACCENT if owner==game.local_player.war_team else (FieldTheme.BAD if owner>=0 else FieldTheme.INK)

func _update_markers() -> void:
	# Reuse three records. Only projected positions change at render frequency.
	var camera:=get_viewport().get_camera_3d()
	var allowed: bool=not game.ui_focus.blocked() and is_instance_valid(game.local_player) and game.local_player.hp>0 and is_instance_valid(camera)
	var inverse:=get_global_transform_with_canvas().affine_inverse()
	for marker in markers:
		marker.visible=false
		if not allowed or camera.is_position_behind(marker.world): continue
		var screen: Vector2=inverse*camera.unproject_position(marker.world)
		if screen.x<20 or screen.y<80 or screen.x>size.x-20 or screen.y>size.y-180: continue
		marker.at=screen;marker.visible=true

func _draw() -> void:
	_update_markers()
	var font:=get_theme_default_font()
	for marker in markers:
		if not marker.visible: continue
		var p: Vector2=marker.at
		draw_circle(p,10,Color(0.04,.07,.08,.65))
		draw_arc(p,10,0,TAU,20,marker.color,1.5,true)
		draw_string(font,p+Vector2(15,4),marker.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,marker.color)
	var actor:=game.local_player as WarPlayer
	if not is_instance_valid(actor) or not actor.gadget_equipped or actor.gadget!="stinger" or game.ui_focus.blocked(): return
	var manager:=game.vehicle_system as WarVehicles
	var target:=manager.find_target(manager.lock_target) if manager else null
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(target) or not is_instance_valid(camera) or camera.is_position_behind(target.global_position): return
	var at:=camera.unproject_position(target.global_position)
	var locked:=manager.lock_progress>=1.
	var tint:=FieldTheme.ACCENT if locked else FieldTheme.INK
	draw_arc(at,23,-PI*.5,-PI*.5+TAU*manager.lock_progress,36,tint,2.5,true)
	for side in [-1.,1.]:
		for up in [-1.,1.]:
			var corner:=at+Vector2(side*27,up*27)
			draw_line(corner,corner-Vector2(side*9,0),tint,1.5,true);draw_line(corner,corner-Vector2(0,up*9),tint,1.5,true)
