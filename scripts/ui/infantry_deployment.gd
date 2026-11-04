extends PanelContainer
class_name GameInfantryDeployment
var game: Node
var editor: GameLoadoutEditor
var preview: GameItemPreview
var spawn: OptionButton
var confirm: Button
var feedback: Label
var title: Label
var next_mode:="desert"
var pending:=false
var clock:=0.0

func _ready() -> void:
	name="InfantryDeployment";theme=GameUI.THEME;set_meta("fullscreen",true)
	add_theme_stylebox_override("panel",FieldTheme.box(FieldTheme.BASE,FieldTheme.BORDER,28))
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",14);scroll.add_child(content)
	title=GameUI.label(content,"IMPLANTAÇÃO",30)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",28);content.add_child(row)
	editor=GameLoadoutEditor.new();editor.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(editor)
	preview=GameItemPreview.new();preview.custom_minimum_size=Vector2(260,330);preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(preview);editor.preview=preview
	GameUI.label(content,"Ponto de entrada",14,FieldTheme.MUTED)
	spawn=OptionButton.new();content.add_child(spawn)
	feedback=GameUI.label(content,"",15,FieldTheme.BAD)
	var buttons:=HBoxContainer.new();buttons.add_theme_constant_override("separation",12);content.add_child(buttons)
	confirm=GameUI.button(buttons,"IMPLANTAR",_confirm,true);confirm.custom_minimum_size.x=200
	GameUI.button(buttons,"VOLTAR",func():
		if is_instance_valid(game.local_player) and game.local_player.hp>0: game.ui_focus.close_top()
		elif game.mode=="menu": game.ui_focus.close_top()
		else: game.ui_focus.open(game.pause_panel)
	)
	hide()

func present(kind: String) -> void:
	next_mode=kind;pending=false;confirm.disabled=false;feedback.text=""
	title.text={"training":"ESCRITÓRIO","desert":"DESERTO","pvp":"DESERTO · DOMINAÇÃO"}.get(kind,"IMPLANTAÇÃO")
	editor.configure(game,"desert" if kind=="pvp" else "offline_"+kind)
	spawn.clear()
	for entry in ([["Automático","auto"],["Oeste","west"],["Leste","east"]] if kind in ["pvp","desert"] else [["Recepção","auto"]]):
		spawn.add_item(entry[0]);spawn.set_item_metadata(spawn.item_count-1,entry[1])
	if editor.equipment_changed: feedback.text="Equipamento atualizado."
	game.ui_focus.open(self)

func _confirm() -> void:
	if pending: return
	var approved:=editor.approved()
	if not approved.ok: feedback.text=str(approved.error);return
	GameLoadouts.save(game,editor.mode,approved.slots)
	if is_instance_valid(game.local_player) and game.local_player.hp>0:
		game.ui_focus.close_top();return
	pending=true;confirm.disabled=true
	game.confirm_infantry_deployment(approved.slots,str(spawn.get_item_metadata(spawn.selected)),next_mode)

func notice(text: String) -> void:
	pending=false;confirm.disabled=false;feedback.text=text

func _process(delta: float) -> void:
	if not visible: return
	clock+=delta
	if clock<.1: return
	clock=0
	var alive: bool=is_instance_valid(game.local_player) and game.local_player.hp>0
	confirm.text="PRÓXIMA VIDA" if alive else "IMPLANTAR"
	var left: float=game.infantry_deployment_wait()
	confirm.disabled=pending or left>0
	if left>0: feedback.text="%d s"%ceili(left)
	elif feedback.text.ends_with(" s"): feedback.text=""
