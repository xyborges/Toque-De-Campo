extends WarGame

func _build_desert() -> void:
	super._build_desert()
	if DisplayServer.get_name()=="headless": return
	var visuals: Node3D=world_root.get_node_or_null("VegetationVisuals")
	if not is_instance_valid(visuals):
		visuals=load("res://modes/war/scripts/vegetation_visuals.gd").new()
		world_root.add_child(visuals);visuals.initialize(world_root)
	var choice:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vegetation-level="): choice=clampi(int(arg.trim_prefix("--vegetation-level=")),0,3)
	if not visuals.apply_level(choice): push_error("vegetation fixture could not activate")
