extends PanelContainer
class_name GamePauseMenu
var game: Node
var focus: GameUIFocus
var settings: GameSettingsPanel
var leave_confirmation: PanelContainer
var session_hint: Label
func _ready() -> void:
	theme=GameUI.THEME;name="PauseMenu";add_theme_stylebox_override("panel",FieldTheme.box())
	set_meta("ui_back_action",Callable(self,"resume"))
	set_meta("preferred_size",Vector2(460,480))
	var column:=VBoxContainer.new();column.name="Content";column.add_theme_constant_override("separation",10);add_child(column)
	GameUI.label(column,"MENU DA PARTIDA",25)
	session_hint=GameUI.label(column,"",13,FieldTheme.MUTED)
	GameUI.button(column,"CONTINUAR",resume,true)
	GameUI.button(column,"CONFIGURAÇÕES",func(): settings.present())
	GameUI.button(column,"CONTROLES",func(): settings.present(2))
	if game.get_meta("battle_royale",false):
		GameUI.button(column,"VOZ",func():settings.present(1))
	else:GameUI.button(column,"PLACAR",_scoreboard)
	if game is NavalMode:
		GameUI.button(column,"FROTA",func(): game._navigate("fleet"))
	elif not game.get_meta("battle_royale",false):
		GameUI.button(column,"EQUIPAMENTO",func():
			if game.get_meta("war_mode",false): game.open_deployment()
			else: game.open_infantry_deployment()
		)
		if not game.get_meta("war_mode",false): GameUI.button(column,"ARSENAL",game._toggle_shop)
	GameUI.button(column,"SAIR DA PARTIDA",confirm_leave)
	leave_confirmation=PanelContainer.new();leave_confirmation.theme=GameUI.THEME;leave_confirmation.add_theme_stylebox_override("panel",FieldTheme.box())
	leave_confirmation.set_meta("preferred_size",Vector2(440,220))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);leave_confirmation.add_child(box)
	GameUI.label(box,"Sair da partida?",24)
	GameUI.button(box,"CANCELAR",func(): focus.close_top(),true)
	GameUI.button(box,"SAIR",func():
		if game is NavalMode: game._close_mode()
		else: game.show_menu()
	)
	focus.add_child(leave_confirmation);leave_confirmation.hide();hide()
	visibility_changed.connect(_update_session_hint)

func confirm_leave() -> void:
	focus.open(leave_confirmation)

func _update_session_hint() -> void:
	if not visible or not is_instance_valid(session_hint): return
	var online_session: bool=game is NavalMode or bool(game.get("online"))
	session_hint.text="ONLINE · A PARTIDA CONTINUA" if online_session else "OFFLINE · PARTIDA PAUSADA"

func resume() -> void:
	focus.close_all()
	if game is NavalMode:
		var ship:=game._own_ship() as NavalShip
		if is_instance_valid(ship) and ship.dead: game._refresh_lobby();game._open("lobby");return
	else:
		var player:=game.get("local_player") as GamePlayer
		if is_instance_valid(player) and (player.hp<=0 or (game.get_meta("war_mode",false) and not bool(player.get("deployed")))):
			if game.get_meta("battle_royale",false): Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;return
			if game.get_meta("war_mode",false): game.open_deployment()
			else: game.open_infantry_deployment()
			return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var actor: GamePlayer=game.get("local_player") if not game is NavalMode else null
	if is_instance_valid(actor): actor.mouse_captured=true;actor.trigger_held=false

func _scoreboard() -> void:
	var board:=game.get("scoreboard") as GameScoreboard
	if not is_instance_valid(board): return
	board.set_meta("scoreboard_home",weakref(board.get_parent()))
	board.set_meta("fullscreen",true);board.set_meta("menu_mode",true);focus.open(board)
	board.footer.text="ESC · VOLTAR"
