extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var folder:=ProjectSettings.globalize_path("res://work/antialias197-test")
	DirAccess.make_dir_recursive_absolute(folder)
	for file in ["game-options.json","aim-sensitivity.json"]:
		if FileAccess.file_exists(folder.path_join(file)): DirAccess.remove_absolute(folder.path_join(file))
	NavalStorage._folder_path=folder;GameOptions.path="";GameAimSensitivity.cache_path=""
	var game:=load("res://tests/war_optics_fixture.gd").new() as WarGame;root.add_child(game);await process_frame
	var settings:=game.settings_panel as GameSettingsPanel
	check(is_instance_valid(settings.antialias) and settings.antialias.selected==0,"video menu defaults to antialiasing off")
	GameOptions.apply(root)
	if DisplayServer.get_name()!="headless": check(root.msaa_3d==Viewport.MSAA_DISABLED,"default disables MSAA in the rendering viewport")
	settings.antialias.select(2);settings.antialias.item_selected.emit(2);settings._flush()
	check(int(NavalStorage.read_json(folder.path_join("game-options.json")).get("aa",-1))==2,"MSAA choice is saved")
	if DisplayServer.get_name()!="headless": check(root.msaa_3d==Viewport.MSAA_4X,"MSAA choice applies during the match")
	GameOptions.path="";GameOptions.values={};GameOptions.ensure();GameOptions.apply(root)
	check(int(GameOptions.number("aa",-1))==2,"MSAA choice survives reload of settings")
	check(GameAimSensitivity.set_values("weapon:fal",.72,.65),"individual weapon sensitivity can be set")
	GameAimSensitivity.flush();GameAimSensitivity.cache_path="";GameAimSensitivity.profiles={}
	var aim:=GameAimSensitivity.values("weapon:fal")
	check(is_equal_approx(aim.normal,.72) and is_equal_approx(aim.aim,.65),"normal and aim sensitivity survive reload")
	check(folder.find("releases")<0,"preferences stay outside the versioned game release")
	game.show_menu();game.queue_free();await process_frame
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
