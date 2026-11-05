extends SceneTree
## End-to-end offline War deployment from the real loadout UI into authoritative life state.
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	print(("PASS " if value else "FAIL ")+label)
	if not value:failures.append(label)

func wait_for(condition: Callable,seconds:=35.0) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if condition.call():return true
	return false

func run() -> void:
	var game:=WarGame.new()
	game.offline_operation=true
	game.set_meta("test_mode",true)
	root.add_child(game)
	var ready:=await wait_for(func():return game.join_ready and is_instance_valid(game.war_ui) and game.war_ui.deployment.visible)
	check(ready,"War deployment UI becomes ready")
	if not ready:
		game.queue_free()
		await process_frame
		print("GRENADE_DEPLOY_SMOKE_QA ",JSON.stringify({"checks":checks,"failures":failures}))
		quit(1);return
	var ui:=game.war_ui as WarUI
	ui.team_select.select(0)
	ui.class_select.select(WarRules.CLASSES.keys().find("soldier"))
	ui._class_changed()
	check(ui.loadout_editor.choices.get("grenade",[])==["grenade","smoke"],"War soldier offers both grenade types")
	var button:=ui.loadout_editor.find_child("GrenadeChoice_smoke",true,false) as Button
	check(is_instance_valid(button),"M18 selectable from the real deployment screen")
	if not is_instance_valid(button):
		game.queue_free();await process_frame;quit(1);return
	button.pressed.emit()
	var approved:=ui.loadout_editor.approved()
	check(approved.ok and str(approved.slots.get("grenade",""))=="smoke","War UI validates selected M18 before deployment")
	ui.deploy_button.pressed.emit()
	var actor:=game.local_player as WarPlayer
	var spawned:=await wait_for(func():return is_instance_valid(actor) and actor.deployed,30)
	check(spawned,"War soldier is actually deployed after pressing Implantar")
	if spawned:
		check(actor.grenades_enabled and actor.grenades==2,"deployed soldier receives two equipped grenades")
		check(str(actor.get_meta("grenade_kind",""))=="smoke","authority applies chosen smoke type to the deployed life")
		check(str(GameInventorySlots.resolve(actor).get(3,""))=="grenade","grenade remains available in player quick slots")
	game.queue_free()
	await process_frame
	print("GRENADE_DEPLOY_SMOKE_QA ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
