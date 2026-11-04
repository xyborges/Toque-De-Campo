extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var mode: Node3D = load("res://modes/naval/scripts/mode.gd").new()
	root.add_child(mode)
	await process_frame
	print("NAVAL_MENU_READY pages=",mode.pages.size())
	mode.queue_free()
	await process_frame
	quit()
