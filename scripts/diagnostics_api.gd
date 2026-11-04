extends RefCounted
class_name GameDiagnostics

static func session() -> Node:
	var tree:=Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("DiagnosticSession") if tree and tree.root else null

static func record(event: String,details: Dictionary={}) -> void:
	var target:=session()
	if target:target.record(event,details)

static func export_report() -> String:
	var target:=session()
	return str(target.export_report()) if target else ""
