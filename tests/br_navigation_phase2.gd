extends SceneTree
class Context extends Node3D:
	var ui_focus: GameUIFocus
	var pause_panel: GamePauseMenu
	var online:=false
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	print(("PASS " if ok else "FAIL ")+title)
	if not ok: failures.append(title)
func run() -> void:
	var game:=Context.new()
	game.set_meta("battle_royale",true)
	root.add_child(game)
	game.ui_focus=GameUIFocus.new()
	game.add_child(game.ui_focus)
	game.pause_panel=GamePauseMenu.new()
	game.pause_panel.game=game
	game.pause_panel.focus=game.ui_focus
	game.ui_focus.add_child(game.pause_panel)
	var hud:=BRHUD.new()
	hud.game=game
	game.add_child(hud)
	await process_frame
	var exit_button: Button=null
	for button in hud.waiting.find_children("*","Button",true,false):
		if button.text=="SAIR": exit_button=button
	check(exit_button!=null,"BR waiting has leave button")
	if exit_button!=null: exit_button.pressed.emit()
	check(game.ui_focus.stack.size()==1 and game.ui_focus.stack.back()==game.pause_panel.leave_confirmation,"BR waiting opens shared confirmation")
	game.ui_focus.back()
	check(not game.ui_focus.blocked(),"BR exit confirmation can be cancelled")
	game.ui_focus.open(hud.result_panel)
	game.ui_focus.back()
	check(game.ui_focus.stack.back()==hud.result_panel,"BR end results resist ESC")
	game.ui_focus.close_all()
	game.queue_free()
	await process_frame
	print("BR_NAV_FAILURES=",failures.size()," ",failures)
	quit(0 if failures.is_empty() else 1)
