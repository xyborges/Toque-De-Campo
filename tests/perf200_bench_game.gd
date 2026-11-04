extends WarGame

# Only this isolated benchmark replaces the normal bot director. Production
# scenes and dedicated servers continue to instantiate the original director.
func _start_offline() -> void:
	await super._start_offline()
	if not is_inside_tree() or not join_ready or not is_instance_valid(bot_director): return
	if "--bot-motion-lod" not in OS.get_cmdline_user_args(): return
	var previous:=bot_director as WarBotDirector
	previous.stop();previous.queue_free()
	var replacement:=load("res://tests/perf200_bot_lod_prototype.gd").new() as WarBotDirector
	bot_director=replacement
	replacement.setup(self);world_root.add_child(replacement)
