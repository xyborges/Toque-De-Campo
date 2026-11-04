extends Control
class_name GameScoreboard

const COLUMNS:=["position","name","points","kills","deaths","assists","kd","damage","objective","ping"]
const HEADINGS:=["#","JOGADOR","PONTOS","ABATES","MORTES","ASSIST.","K/D","DANO","OBJ.","PING"]
const WIDTHS:=[30,170,84,66,66,72,66,90,82,82]
var game: Node
var source: GameMatchStats
var active: Callable
var local_peer: Callable
var panel: PanelContainer
var lines: Array[Label]=[] # Diagnostic view of each reusable row's point cell.
var row_pool: Array[Dictionary]=[]
var groups: Array[Dictionary]=[]
var heading: Label
var map_label: Label
var timer: Label
var objective: Label
var tickets: Label
var footer: Label
var scroll: ScrollContainer
var cached_revision:=-1
var context_clock:=0.0
var current_context: Dictionary={}
var row_styles: Dictionary={}
var column_font:=17
var refresh_count:=0
var layout_signature:=""
var table_context:=""

func _ready() -> void:
	name="MatchScoreboard";theme=GameUI.THEME;z_index=80
	if source==null: source=game.match_stats
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);center.mouse_filter=MOUSE_FILTER_IGNORE;add_child(center)
	panel=GameUI.panel(center,20);panel.mouse_filter=MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",FieldTheme.box(Color(.035,.065,.07,.88),FieldTheme.BORDER,20))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);panel.add_child(box)
	heading=GameUI.label(box,"PLACAR DA PARTIDA",14,FieldTheme.ACCENT)
	var title_row:=HBoxContainer.new();box.add_child(title_row)
	map_label=GameUI.label(title_row,"",28);map_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	timer=GameUI.label(title_row,"",23,FieldTheme.ACCENT);timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	map_label.autowrap_mode=TextServer.AUTOWRAP_OFF;map_label.clip_text=true
	timer.autowrap_mode=TextServer.AUTOWRAP_OFF;timer.custom_minimum_size.x=230
	tickets=GameUI.label(box,"",19,FieldTheme.ACCENT)
	objective=GameUI.label(box,"",14,FieldTheme.MUTED)
	_separator(box)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.mouse_filter=MOUSE_FILTER_PASS;box.add_child(scroll)
	var table:=VBoxContainer.new();table.add_theme_constant_override("separation",12);table.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(table)
	for i in 3:
		var section:=VBoxContainer.new();section.add_theme_constant_override("separation",4);table.add_child(section)
		var caption:=GameUI.label(section,"",16,FieldTheme.ACCENT if i==0 else FieldTheme.BAD)
		var header_margin:=MarginContainer.new();header_margin.add_theme_constant_override("margin_left",8);header_margin.add_theme_constant_override("margin_right",8);section.add_child(header_margin)
		var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",6);header_margin.add_child(columns)
		var headers: Dictionary={}
		for j in COLUMNS.size():
			var cell:=GameUI.label(columns,HEADINGS[j],12,FieldTheme.MUTED);_column(cell,j);headers[COLUMNS[j]]=cell
		var rows:=VBoxContainer.new();rows.add_theme_constant_override("separation",3);section.add_child(rows)
		groups.append({"node":section,"title":caption,"headers":headers,"rows":rows})
		section.hide()
	row_styles.normal=FieldTheme.box(Color(.06,.11,.12,.22),Color.TRANSPARENT,8)
	row_styles.local=FieldTheme.box(Color(FieldTheme.ACCENT,.12),Color(FieldTheme.ACCENT,.40),8)
	row_styles.leader=FieldTheme.box(Color(FieldTheme.ACCENT,.06),Color(FieldTheme.BORDER,.4),8)
	for style: StyleBoxFlat in row_styles.values():
		style.content_margin_top=5;style.content_margin_bottom=5
	for i in 12: _new_row()
	_separator(box)
	footer=GameUI.label(box,"SEGURE TAB · PLACAR   |   Solte para fechar · O combate continua",13,FieldTheme.MUTED)
	resized.connect(_layout);visibility_changed.connect(_visibility_changed);_layout();hide()

func _separator(parent: Node) -> void:
	var line:=HSeparator.new();line.modulate=Color(FieldTheme.BORDER,.6);parent.add_child(line)

func _column(cell: Label,index: int) -> void:
	cell.custom_minimum_size.x=WIDTHS[index]
	cell.autowrap_mode=TextServer.AUTOWRAP_OFF
	cell.clip_text=true
	cell.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if index in [0,1] else HORIZONTAL_ALIGNMENT_RIGHT
	if index==1: cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func _new_row() -> void:
	var node:=PanelContainer.new();node.mouse_filter=MOUSE_FILTER_IGNORE;node.custom_minimum_size.y=36
	groups[0].rows.add_child(node)
	var layout:=HBoxContainer.new();layout.add_theme_constant_override("separation",6);node.add_child(layout)
	var cells: Dictionary={}
	for i in COLUMNS.size():
		var cell:=GameUI.label(layout,"",column_font);_column(cell,i);cells[COLUMNS[i]]=cell
	lines.append(cells.points)
	row_pool.append({"node":node,"cells":cells,"style":"","id":-1});node.hide()

func _input(event: InputEvent) -> void:
	if game.get_meta("battle_royale",false):hide();return
	if not event is InputEventKey or event.keycode!=KEY_TAB or event.echo: return
	if get_meta("menu_mode",false) and visible:
		if event.pressed:
			var focus: GameUIFocus=game.get("focus") if game is NavalMode else game.get("ui_focus")
			if focus: focus.close_top()
			remove_meta("menu_mode");get_viewport().set_input_as_handled()
		return
	var available: bool=active.call() if active.is_valid() else (game.mode!="menu" and is_instance_valid(game.world_root))
	if not available: hide();return
	visible=event.pressed
	# No input consumption, mouse capture, pause or gameplay state change.

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		if has_meta("menu_mode"): remove_meta("menu_mode")
		if has_meta("scoreboard_home"): _restore_home.call_deferred()
		return
	if not is_instance_valid(panel): return
	# TAB and programmatic opening share the same immediate initialization.
	context_clock=0.0
	_update_context();refresh()

func _restore_home() -> void:
	if visible or not has_meta("scoreboard_home"): return
	var prior: WeakRef=get_meta("scoreboard_home");remove_meta("scoreboard_home")
	if is_instance_valid(prior.get_ref()): reparent(prior.get_ref(),false);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(footer): footer.text="TAB · PLACAR"

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: hide()

func _text(label: Label,value: String) -> void:
	if label.text!=value: label.text=value

func _update_context() -> void:
	current_context=game.scoreboard_context() if game.has_method("scoreboard_context") else {"mode":"PARTIDA","map":"","network":false,"teams":false}
	# Grouping and column visibility can change independently of player statistics.
	var context_key:="%s:%s"%[bool(current_context.get("teams",false)),bool(current_context.get("network",false))]
	if context_key!=table_context:
		table_context=context_key;cached_revision=-1
	_text(heading,str(current_context.get("mode","PARTIDA")))
	_text(map_label,str(current_context.get("map","")))
	var seconds:=maxi(0,ceili(float(current_context.get("seconds",0))))
	_text(timer,"%s  %d:%02d"%[str(current_context.get("time_label","TEMPO")),seconds/60,seconds%60])
	_text(tickets,str(current_context.get("tickets","")));tickets.visible=not tickets.text.is_empty()
	_text(objective,str(current_context.get("objectives","")));objective.visible=not objective.text.is_empty()
	for group in groups:
		group.headers.ping.visible=bool(current_context.get("network",false))
	_layout()

func refresh() -> void:
	if cached_revision==source.revision: return
	cached_revision=source.revision;refresh_count+=1
	var rows:=source.snapshot()
	while row_pool.size()<rows.size() and row_pool.size()<64: _new_row()
	var team_mode:=bool(current_context.get("teams",false))
	var local_id:=int(local_peer.call() if local_peer.is_valid() else game.multiplayer.get_unique_id())
	var counts:=[0,0,0]
	for i in row_pool.size():
		var view: Dictionary=row_pool[i];var node: PanelContainer=view.node
		if i>=rows.size(): node.hide();continue
		var row: Dictionary=rows[i]
		var team:=int(row.get("team",-1))
		var section:=clampi(team,0,1) if team_mode and team>=0 else (2 if team_mode else 0)
		counts[section]+=1
		if node.get_parent()!=groups[section].rows: node.reparent(groups[section].rows,false)
		groups[section].rows.move_child(node,counts[section]-1);node.show()
		var own:=int(row.id)==local_id;var leader: bool=counts[section]==1
		var style: String="local" if own else ("leader" if leader else "normal")
		if view.style!=style: node.add_theme_stylebox_override("panel",row_styles[style]);view.style=style
		var cells: Dictionary=view.cells
		var values:=[str(counts[section]),str(row.name).left(24)+(" · VOCÊ" if own else ""),str(int(row.points)),str(int(row.kills)),str(int(row.deaths)),str(int(row.assists)),"%.2f"%(float(row.kills)/maxi(1,int(row.deaths))),str(roundi(row.damage)),str(int(row.objective)),str(int(row.get("ping",-1)))+" ms" if int(row.get("ping",-1))>0 else "—"]
		cells.name.tooltip_text=str(row.name)+(" · VOCÊ" if own else "")
		for j in COLUMNS.size():
			var cell: Label=cells[COLUMNS[j]];_text(cell,values[j])
			cell.visible=COLUMNS[j]!="ping" or bool(current_context.get("network",false))
			var color:=FieldTheme.INK
			if j==0 and counts[section]<=3: color=FieldTheme.ACCENT
			elif j==1 and own: color=FieldTheme.ACCENT
			elif j==2 and leader: color=FieldTheme.ACCENT
			elif j>=3: color=FieldTheme.MUTED if not own else FieldTheme.INK
			if cell.get_meta("color",Color.TRANSPARENT)!=color: cell.add_theme_color_override("font_color",color);cell.set_meta("color",color)
		view.id=int(row.id)
	for i in groups.size():
		groups[i].node.visible=counts[i]>0
		groups[i].title.visible=team_mode
		_text(groups[i].title,("EQUIPE %d · %d JOGADORES"%[i+1,counts[i]]) if i<2 else "AGUARDANDO IMPLANTAÇÃO")
	_layout()

func _layout() -> void:
	if not is_instance_valid(panel): return
	var dimensions:=get_viewport_rect().size
	panel.custom_minimum_size.x=minf(1240,dimensions.x*.94)
	var total:=0.0
	for group in groups:
		if not group.node.visible: continue
		var count:=0
		for row in group.rows.get_children():
			if row.visible: count+=1
		total+=count*39+32+(28 if bool(current_context.get("teams",false)) else 0)
	var extras:=180+(26 if tickets.visible else 0)+(22 if objective.visible else 0)
	var height:=clampf(total,70,maxf(100,dimensions.y*.86-extras))
	var signature:="%s:%s:%s:%s:%s"%[dimensions,total,height,tickets.visible,objective.visible]
	if signature==layout_signature: return
	layout_signature=signature
	scroll.custom_minimum_size.y=height
	panel.reset_size()

func _process(delta: float) -> void:
	if not visible: return
	context_clock+=delta
	if context_clock>=.25: context_clock=0;_update_context()
	refresh()
