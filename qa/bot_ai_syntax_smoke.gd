extends SceneTree
# Forces GDScript compilation/instantiation, not just loading Resource objects.
# Run after Godot has indexed the project's global class_name scripts.
func _initialize() -> void:
	var director_script: Script=load("res://modes/war/scripts/bot_director.gd")
	var vehicles_script: Script=load("res://modes/war/scripts/vehicles.gd")
	if director_script==null or vehicles_script==null:
		push_error("WAR_AI_SCRIPTS_LOAD_FAILED")
		quit(1)
		return
	var director=director_script.new()
	var manager=vehicles_script.new()
	if director==null or manager==null:
		push_error("WAR_AI_SCRIPTS_INSTANTIATION_FAILED")
		quit(2)
		return
	director.free()
	manager.free()
	print("WAR_AI_SCRIPTS_INSTANTIATION_OK")
	quit(0)
