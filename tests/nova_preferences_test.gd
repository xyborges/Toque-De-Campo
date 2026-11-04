extends SceneTree

# Local preference isolation/sanitization and visual-world dispatch only.
# Account IDs and every written file are confined to a unique work/ folder;
# this does not contact the account API or prove remote preference syncing.
class FakeVisuals extends Node:
	var received: Array[int]=[]
	func _ready() -> void: add_to_group("war_vegetation_visuals")
	func apply_level(value: int) -> void: received.append(value)

const ACCOUNT_A:="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const ACCOUNT_B:="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
var errors: Array[String]=[]
var notifications: Array[String]=[]
var test_dir:=""

func _initialize() -> void: run.call_deferred()

func check(value: bool,message: String) -> void:
	if not value: errors.append(message)

func account(id: String) -> void:
	NavalStorage.preference_account=id;GameOptions.ensure()

func reload_raw(value: Variant) -> void:
	var path:=NavalStorage.settings_folder().path_join("game-options.json")
	check(NavalStorage.write_json(path,{"war_vegetation":value}),"test preference write")
	GameOptions.path="";GameOptions.ensure()

func run() -> void:
	var previous_folder:=NavalStorage._folder_path
	var previous_account:=NavalStorage.preference_account
	var previous_callback:=NavalStorage.preference_changed
	var previous_path:=GameOptions.path
	var previous_values:=GameOptions.values.duplicate(true)
	var previous_dirty:=GameOptions.dirty
	var previous_aa:=root.msaa_3d
	test_dir=ProjectSettings.globalize_path("res://work/nova-preferences-test-data/run-"+str(Time.get_ticks_usec()))
	check(test_dir.begins_with(ProjectSettings.globalize_path("res://work/")),"test directory stays in workspace")
	NavalStorage._folder_path=test_dir
	NavalStorage.preference_changed=func(path: String): notifications.append(path)
	GameOptions.path="";GameOptions.values={};GameOptions.dirty=false
	account(ACCOUNT_A)
	check(GameOptions.number("war_vegetation",0)==0,"new account starts with original vegetation")
	GameOptions.set_value("war_vegetation",2);GameOptions.flush()
	var path_a:=GameOptions.path
	check(NavalStorage.read_json(path_a).get("war_vegetation")==2,"account A persists its own preset")
	account(ACCOUNT_B)
	check(GameOptions.number("war_vegetation",0)==0,"account B does not inherit account A")
	GameOptions.set_value("war_vegetation",3);GameOptions.flush()
	var path_b:=GameOptions.path
	check(path_a!=path_b and NavalStorage.read_json(path_b).get("war_vegetation")==3,"accounts use distinct files")
	account(ACCOUNT_A)
	check(GameOptions.number("war_vegetation",0)==2,"switching back reloads account A")
	for trial in [[-8,0],[99,3],[2.75,2],["2",0],[null,0],[true,0],[[2],0],[{"level":2},0]]:
		reload_raw(trial[0])
		check(GameOptions.number("war_vegetation",0)==int(trial[1]),"sanitizes preference "+str(trial[0]))
		if GameOptions.values.has("war_vegetation"):
			check(GameOptions.values.war_vegetation is int and int(GameOptions.values.war_vegetation) in [0,1,2,3],"stored preference is bounded integer")
	reload_raw(2)
	var world_a:=Node3D.new();world_a.name="WorldA";root.add_child(world_a)
	var world_b:=Node3D.new();world_b.name="WorldB";root.add_child(world_b)
	var first:=FakeVisuals.new();world_a.add_child(first)
	var nested_parent:=Node.new();world_a.add_child(nested_parent)
	var nested:=FakeVisuals.new();nested_parent.add_child(nested)
	var second:=FakeVisuals.new();world_b.add_child(second)
	var outside:=FakeVisuals.new();root.add_child(outside)
	GameOptions.apply(root,null)
	check(first.received.is_empty() and nested.received.is_empty() and second.received.is_empty() and outside.received.is_empty(),"no world means no vegetation dispatch")
	GameOptions.apply(root,world_a)
	if DisplayServer.get_name()=="headless":
		check(first.received.is_empty() and nested.received.is_empty(),"headless skips all visual managers")
	else:
		check(first.received==[2] and nested.received==[2],"dispatch reaches managers only inside world A")
	check(second.received.is_empty() and outside.received.is_empty(),"world B and unrelated manager remain untouched")
	account(ACCOUNT_B)
	check(GameOptions.number("war_vegetation",0)==3,"sanitizing A did not change B")
	GameOptions.apply(root,world_b)
	if DisplayServer.get_name()=="headless": check(second.received.is_empty(),"headless also skips second world")
	else: check(second.received==[3] and first.received==[2],"account B dispatch does not alter world A")
	check(outside.received.is_empty(),"unrelated manager never receives a quality change")
	for path: String in notifications: check(path.begins_with(test_dir),"settings callback only sees test files")
	check(not notifications.is_empty(),"existing change notification is exercised")
	root.msaa_3d=previous_aa
	NavalStorage.preference_changed=previous_callback;NavalStorage.preference_account=previous_account;NavalStorage._folder_path=previous_folder
	GameOptions.path=previous_path;GameOptions.values=previous_values;GameOptions.dirty=previous_dirty
	world_a.queue_free();world_b.queue_free();outside.queue_free()
	var report:={"ok":errors.is_empty(),"errors":errors,"headless":DisplayServer.get_name()=="headless","test_dir":test_dir,"accounts":2,"scope":"isolated local account folders; no live account API, preferences server, or UI automation"}
	# Avoid invoking a restored live account callback when writing the report.
	var report_file:=FileAccess.open(test_dir.path_join("report.json"),FileAccess.WRITE)
	if report_file: report_file.store_string(JSON.stringify(report));report_file.close()
	print("NOVA_PREFERENCES_TEST ",JSON.stringify(report))
	await process_frame;quit(0 if errors.is_empty() else 1)
