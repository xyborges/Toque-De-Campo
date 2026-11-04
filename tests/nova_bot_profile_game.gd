extends WarGame

# Installs the profiling wrapper only in this test; never in normal matches.
func _start_offline() -> void:
	await super._start_offline()
	if not is_inside_tree() or not join_ready or not is_instance_valid(bot_director): return
	var previous:=bot_director as WarBotDirector
	previous.stop();previous.queue_free()
	var replacement:=load("res://tests/nova_bot_profile.gd").new() as WarBotDirector
	bot_director=replacement;replacement.setup(self);world_root.add_child(replacement)
