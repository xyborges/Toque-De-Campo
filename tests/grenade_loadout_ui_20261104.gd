extends SceneTree
## Checks grenade quick choices, visual labels and persistence through the real loadout editor.
class FakeGame extends Node:
	var profile: Dictionary={}
	var main_accounts: Node
	func _init() -> void:
		profile={"owned":GameWeapons.INFANTRY_IDS.duplicate(),"appearance_account":"smoke-ui-fixture"}

var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,description: String) -> void:
	checks+=1
	print(("PASS " if value else "FAIL ")+description)
	if not value:failures.append(description)

func run() -> void:
	var game:=FakeGame.new()
	root.add_child(game)
	var holder:=Control.new()
	root.add_child(holder)
	var editor:=GameLoadoutEditor.new()
	holder.add_child(editor)
	await process_frame
	for mode: String in ["war","desert","offline_training","offline_desert"]:
		for team in ([0,1] if mode=="war" else [0]):
			editor.configure(game,mode,"soldier",team)
			var scope: String=mode+":"+str(team)
			check(editor.choices.get("grenade",[])==["grenade","smoke"],scope+" has both grenade choices")
			var explosive: Button=editor.find_child("GrenadeChoice_grenade",true,false) as Button
			var smoke: Button=editor.find_child("GrenadeChoice_smoke",true,false) as Button
			check(is_instance_valid(explosive) and is_instance_valid(smoke),scope+" shows both quick-select buttons")
			check(is_instance_valid(editor.rows.get("grenade",{}).get("picker",null)) and editor.rows.grenade.picker.item_count==2,scope+" retains the standard weapon-slot picker")
			smoke.pressed.emit()
			check(str(editor.slots.get("grenade",""))=="smoke" and editor.approved().ok,scope+" selects smoke")
			check(str(editor.rows.grenade.button.text).contains("fumaça"),scope+" labels the equipped M18")
			check(editor.detail.visible and editor.detail.text.contains("sem dano"),scope+" explains smoke's effect")
			check(str(GameLoadouts.saved(game,mode,"soldier",team).slots.get("grenade",""))=="smoke",scope+" persists smoke across reopen")
			editor.configure(game,mode,"soldier",team)
			check(str(editor.slots.get("grenade",""))=="smoke",scope+" restores smoke into the loadout editor")
			explosive=editor.find_child("GrenadeChoice_grenade",true,false) as Button
			check(is_instance_valid(explosive),scope+" still has a clickable explosive choice")
			explosive.pressed.emit()
			check(str(editor.slots.get("grenade",""))=="grenade" and editor.approved().ok,scope+" selects explosive")
			check(str(GameLoadouts.saved(game,mode,"soldier",team).slots.get("grenade",""))=="grenade",scope+" persists explosive across reopen")
			editor._choose_grenade("invalid")
			check(str(editor.slots.get("grenade",""))=="grenade",scope+" rejects unsupported grenade option")
	for role: String in ["medic","antitank","marksman"]:
		check(not GameLoadouts.allowed("war",GameWeapons.INFANTRY_IDS,role,0).has("grenade"),"war class restriction remains unchanged: "+role)
	holder.queue_free()
	game.queue_free()
	await process_frame
	print("GRENADE_LOADOUT_UI_QA ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
