extends "res://tests/combat_153_fixture.gd"
func gameplay_input_allowed() -> bool: return mode!="menu" and not ui_focus.blocked()
