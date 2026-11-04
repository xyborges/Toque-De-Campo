extends "res://tests/late_join_fixture.gd"
var context_override: Dictionary={}
func scoreboard_context() -> Dictionary:
	return context_override if not context_override.is_empty() else super.scoreboard_context()
